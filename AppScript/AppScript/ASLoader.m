// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLoader.m — API for loading AppScript scripts from arbitrary paths and runtime strings
// Copyright (C) 2026 Graham Lee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import <AppScript/ASLoader.h>
#import <AppScript/ASLexer.h>
#import <AppScript/ASParser.h>
#import <AppScript/ASRuntimeInstaller.h>
#import <AppScript/ASClassDefinitionNode.h>

NSString * const ASLoaderErrorDomain = @"ASLoaderErrorDomain";

// ---------------------------------------------------------------------------
// Private interface for tracking loaded scripts
// ---------------------------------------------------------------------------

@interface ASLoader ()
@property (nonatomic, strong) ASRuntimeInstaller *installer;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadedPaths;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadedSourceHashes;
@property (nonatomic, strong) dispatch_queue_t loadedScriptsQueue;
@end

@implementation ASLoader

// ---------------------------------------------------------------------------
// Class setup
// ---------------------------------------------------------------------------

+ (void)initialize {
    if (self == [ASLoader class]) {
        // Ensure ASRuntimeInstaller is initialized
        [ASRuntimeInstaller new];
    }
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

- (instancetype)init {
    self = [super init];
    if (self) {
        _installer = [[ASRuntimeInstaller alloc] init];
        _loadedPaths = [NSMutableSet set];
        _loadedSourceHashes = [NSMutableSet set];
        _loadedScriptsQueue = dispatch_queue_create("_ASLoaderLoadedScriptsQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// ---------------------------------------------------------------------------
// Helper: Compute hash of source string
// ---------------------------------------------------------------------------

- (NSString *)hashOfString:(NSString *)string {
    const char *bytes = [string UTF8String];
    NSUInteger length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    // Simple hash using CRC32-like algorithm
    uint32_t hash = 0;
    for (NSUInteger i = 0; i < length; i++) {
        hash = hash * 31 + bytes[i];
    }

    return [NSString stringWithFormat:@"%08x", hash];
}

// ---------------------------------------------------------------------------
// Atomic claim helpers (test-and-set in one dispatch_sync block)
// ---------------------------------------------------------------------------

/// Returns YES if the path was newly claimed; NO if it was already claimed.
- (BOOL)claimPath:(NSString *)absolutePath {
    __block BOOL claimed = NO;
    dispatch_sync(self.loadedScriptsQueue, ^{
        if (![self.loadedPaths containsObject:absolutePath]) {
            [self.loadedPaths addObject:absolutePath];
            claimed = YES;
        }
    });
    return claimed;
}

/// Atomically claims all paths. Returns YES if every path was newly claimed
/// (and marks them all). Returns NO and sets error if any was already claimed;
/// in that case no paths are marked.
- (BOOL)claimPaths:(NSArray<NSString *> *)absolutePaths error:(NSError **)error {
    __block NSString *duplicate = nil;
    dispatch_sync(self.loadedScriptsQueue, ^{
        for (NSString *path in absolutePaths) {
            if ([self.loadedPaths containsObject:path]) {
                duplicate = path;
                return;
            }
        }
        // All clear — mark every path
        for (NSString *path in absolutePaths) {
            [self.loadedPaths addObject:path];
        }
    });

    if (duplicate) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script at path \"%@\" has already been loaded.", duplicate]
            }];
        }
        return NO;
    }
    return YES;
}

/// Returns YES if the hash was newly claimed; NO if it was already claimed.
- (BOOL)claimSourceHash:(NSString *)hash {
    __block BOOL claimed = NO;
    dispatch_sync(self.loadedScriptsQueue, ^{
        if (![self.loadedSourceHashes containsObject:hash]) {
            [self.loadedSourceHashes addObject:hash];
            claimed = YES;
        }
    });
    return claimed;
}

/// Atomically claims all hashes. Returns YES if every hash was newly claimed
/// (and marks them all). Returns NO and sets error if any was already claimed;
/// in that case no hashes are marked.
- (BOOL)claimSourceHashes:(NSArray<NSString *> *)hashes error:(NSError **)error {
    __block NSString *duplicate = nil;
    dispatch_sync(self.loadedScriptsQueue, ^{
        for (NSString *hash in hashes) {
            if ([self.loadedSourceHashes containsObject:hash]) {
                duplicate = hash;
                return;
            }
        }
        // All clear — mark every hash
        for (NSString *hash in hashes) {
            [self.loadedSourceHashes addObject:hash];
        }
    });

    if (duplicate) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script has already been loaded (hash: %@).", duplicate]
            }];
        }
        return NO;
    }
    return YES;
}

// ---------------------------------------------------------------------------
// Helper: Shared lex+parse+install pipeline
// ---------------------------------------------------------------------------

- (BOOL)loadSource:(NSString *)source scriptPath:(NSString *)path error:(NSError **)error {
    ASLexer *lexer = [ASLexer new];
    ASParser *parser = [ASParser new];

    // Lex
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [lexer tokenize:source error:&lexError];
    if (!tokens) {
        if (error) {
            NSMutableDictionary *info = [@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Lexer error in %@", path]
            } mutableCopy];
            if (lexError) info[NSUnderlyingErrorKey] = lexError;
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorLexerFailure
                                     userInfo:info];
        }
        return NO;
    }

    // Parse
    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [parser parseTokens:tokens error:&parseError];
    if (!nodes) {
        if (error) {
            NSMutableDictionary *info = [@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Parser error in %@", path]
            } mutableCopy];
            if (parseError) info[NSUnderlyingErrorKey] = parseError;
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorParserFailure
                                     userInfo:info];
        }
        return NO;
    }

    // Install
    NSError *installError = nil;
    BOOL installed = [self.installer installNodes:nodes scriptPath:path error:&installError];
    if (!installed) {
        if (error) {
            NSMutableDictionary *info = [@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Runtime install error in %@", path]
            } mutableCopy];
            if (installError) info[NSUnderlyingErrorKey] = installError;
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorInstallFailure
                                     userInfo:info];
        }
        return NO;
    }

    return YES;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

- (BOOL)loadScriptFromFileAtPath:(NSString *)filePath error:(NSError **)error {
    return [self loadScriptFromFileAtPath:filePath scriptName:nil error:error];
}

- (BOOL)loadScriptFromString:(NSString *)source error:(NSError **)error {
    return [self loadScriptFromString:source scriptName:nil error:error];
}

- (BOOL)loadScriptFromFileAtPath:(NSString *)filePath
                      scriptName:(nullable NSString *)scriptName
                           error:(NSError **)error {
    NSString *absolutePath = [filePath stringByResolvingSymlinksInPath];

    // 1. File existence check — no state change on failure; allows retry
    if (![[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorFileNotFound
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"No AppScript source file found at path: %@", absolutePath]
            }];
        }
        return NO;
    }

    // 2. Atomically claim the path
    if (![self claimPath:absolutePath]) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script at path \"%@\" has already been loaded.", absolutePath]
            }];
        }
        return NO;
    }

    // 3. Read file
    NSError *readError = nil;
    NSString *source = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:absolutePath]
                                               encoding:NSUTF8StringEncoding
                                                  error:&readError];
    if (!source) {
        if (error) {
            NSMutableDictionary *info = [@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Could not read AppScript source file: %@", absolutePath]
            } mutableCopy];
            if (readError) info[NSUnderlyingErrorKey] = readError;
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorFileReadFailure
                                     userInfo:info];
        }
        return NO;
    }

    // 4. Lex → parse → install (path already claimed)
    return [self loadSource:source scriptPath:scriptName ?: absolutePath error:error];
}

- (BOOL)loadScriptFromString:(NSString *)source
                  scriptName:(nullable NSString *)scriptName
                       error:(NSError **)error {
    NSString *hash = [self hashOfString:source];

    // Atomically claim the hash
    if (![self claimSourceHash:hash]) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script has already been loaded (hash: %@).", hash]
            }];
        }
        return NO;
    }

    return [self loadSource:source scriptPath:scriptName ?: hash error:error];
}

- (BOOL)loadScriptsFromFilesAtPaths:(NSArray<NSString *> *)filePaths error:(NSError **)error {
    // 1. Resolve all paths
    NSMutableArray<NSString *> *absolutePaths = [NSMutableArray arrayWithCapacity:filePaths.count];
    for (NSString *path in filePaths) {
        [absolutePaths addObject:[path stringByResolvingSymlinksInPath]];
    }

    // 2. Check all files exist before touching state
    for (NSString *absolutePath in absolutePaths) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
            if (error) {
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorFileNotFound
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"No AppScript source file found at path: %@", absolutePath]
                }];
            }
            return NO;
        }
    }

    // 3. Atomically claim all paths (all-or-nothing)
    if (![self claimPaths:absolutePaths error:error]) {
        return NO;
    }

    // 4. Read all files
    NSMutableDictionary<NSString *, NSString *> *pathToSource = [NSMutableDictionary dictionary];
    for (NSString *absolutePath in absolutePaths) {
        NSError *readError = nil;
        NSString *source = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:absolutePath]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&readError];
        if (!source) {
            if (error) {
                NSMutableDictionary *info = [@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Could not read AppScript source file: %@", absolutePath]
                } mutableCopy];
                if (readError) info[NSUnderlyingErrorKey] = readError;
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorFileReadFailure
                                         userInfo:info];
            }
            return NO;
        }
        pathToSource[absolutePath] = source;
    }

    // 5. Lex + parse all files
    ASParser *parser = [ASParser new];
    NSMutableDictionary<NSString *, NSArray<ASASTNode *> *> *pathToNodes = [NSMutableDictionary dictionary];

    for (NSUInteger i = 0; i < filePaths.count; i++) {
        NSString *absolutePath = absolutePaths[i];
        NSString *source = pathToSource[absolutePath];

        ASLexer *lexer = [ASLexer new];
        NSError *lexError = nil;
        NSArray<ASToken *> *tokens = [lexer tokenize:source error:&lexError];
        if (!tokens) {
            if (error) {
                NSMutableDictionary *info = [@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Lexer error in %@", absolutePath]
                } mutableCopy];
                if (lexError) info[NSUnderlyingErrorKey] = lexError;
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorLexerFailure
                                         userInfo:info];
            }
            return NO;
        }

        NSError *parseError = nil;
        NSArray<ASASTNode *> *nodes = [parser parseTokens:tokens error:&parseError];
        if (!nodes) {
            if (error) {
                NSMutableDictionary *info = [@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Parser error in %@", absolutePath]
                } mutableCopy];
                if (parseError) info[NSUnderlyingErrorKey] = parseError;
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorParserFailure
                                         userInfo:info];
            }
            return NO;
        }
        pathToNodes[absolutePath] = nodes;
    }

    // 6. Topological sort by superclass dependency (Kahn's algorithm)
    NSMutableDictionary<NSString *, NSNumber *> *classToScriptIndex = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < filePaths.count; i++) {
        NSString *absolutePath = absolutePaths[i];
        for (ASASTNode *node in pathToNodes[absolutePath]) {
            if ([node isKindOfClass:[ASClassDefinitionNode class]]) {
                NSString *className = ((ASClassDefinitionNode *)node).className;
                classToScriptIndex[className] = @(i);
            }
        }
    }

    NSMutableArray<NSNumber *> *inDegree = [NSMutableArray array];
    NSMutableArray<NSMutableArray<NSNumber *> *> *dependents = [NSMutableArray array];
    for (NSUInteger i = 0; i < filePaths.count; i++) {
        [inDegree addObject:@0];
        [dependents addObject:[NSMutableArray array]];
    }

    for (NSUInteger i = 0; i < filePaths.count; i++) {
        NSString *absolutePath = absolutePaths[i];
        for (ASASTNode *node in pathToNodes[absolutePath]) {
            if (![node isKindOfClass:[ASClassDefinitionNode class]]) continue;
            NSString *superclassName = ((ASClassDefinitionNode *)node).superclassName;
            if (!superclassName) continue;
            NSNumber *depIndex = classToScriptIndex[superclassName];
            if (depIndex == nil) continue;
            NSUInteger j = depIndex.unsignedIntegerValue;
            if (j == i) continue;
            [dependents[j] addObject:@(i)];
            inDegree[i] = @(inDegree[i].unsignedIntegerValue + 1);
        }
    }

    NSMutableArray<NSNumber *> *queue = [NSMutableArray array];
    for (NSUInteger i = 0; i < filePaths.count; i++) {
        if (inDegree[i].unsignedIntegerValue == 0) {
            [queue addObject:@(i)];
        }
    }

    NSMutableArray<NSNumber *> *sortedIndices = [NSMutableArray array];
    while (queue.count > 0) {
        NSNumber *idxNum = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [sortedIndices addObject:idxNum];
        for (NSNumber *dependent in dependents[idxNum.unsignedIntegerValue]) {
            NSUInteger newDegree = inDegree[dependent.unsignedIntegerValue].unsignedIntegerValue - 1;
            inDegree[dependent.unsignedIntegerValue] = @(newDegree);
            if (newDegree == 0) {
                [queue addObject:dependent];
            }
        }
    }

    // 7. Install in sorted order
    for (NSNumber *idxNum in sortedIndices) {
        NSUInteger idx = idxNum.unsignedIntegerValue;
        NSString *absolutePath = absolutePaths[idx];
        NSArray<ASASTNode *> *nodes = pathToNodes[absolutePath];

        NSError *installError = nil;
        BOOL installed = [self.installer installNodes:nodes
                                           scriptPath:absolutePath
                                                error:&installError];
        if (!installed) {
            if (error) {
                NSMutableDictionary *info = [@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Runtime install error in %@", absolutePath]
                } mutableCopy];
                if (installError) info[NSUnderlyingErrorKey] = installError;
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorInstallFailure
                                         userInfo:info];
            }
            return NO;
        }
    }

    return YES;
}

- (BOOL)loadScriptsFromStrings:(NSArray<NSString *> *)sources error:(NSError **)error {
    // 1. Compute all hashes
    NSMutableArray<NSString *> *hashes = [NSMutableArray arrayWithCapacity:sources.count];
    for (NSString *source in sources) {
        [hashes addObject:[self hashOfString:source]];
    }

    // 2. Atomically claim all hashes (all-or-nothing)
    if (![self claimSourceHashes:hashes error:error]) {
        return NO;
    }

    // 3. Lex → parse → install each source in order
    for (NSUInteger i = 0; i < sources.count; i++) {
        if (![self loadSource:sources[i] scriptPath:hashes[i] error:error]) {
            return NO;
        }
    }

    return YES;
}

@end
