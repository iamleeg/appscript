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

#import "ASLoader.h"
#import "ASLexer.h"
#import "ASParser.h"
#import "ASRuntimeInstaller.h"
#import "ASClassDefinitionNode.h"

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
// Helper: Check if script has already been loaded
// ---------------------------------------------------------------------------

- (BOOL)hasLoadedPath:(NSString *)path error:(NSError **)error {
    __block BOOL alreadyLoaded = NO;
    dispatch_sync(self.loadedScriptsQueue, ^{
        alreadyLoaded = [self.loadedPaths containsObject:path];
    });
    
    if (alreadyLoaded) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script at path \"%@\" has already been loaded.", path]
            }];
        }
    }
    return alreadyLoaded;
}

- (BOOL)hasLoadedSourceHash:(NSString *)hash error:(NSError **)error {
    __block BOOL alreadyLoaded = NO;
    dispatch_sync(self.loadedScriptsQueue, ^{
        alreadyLoaded = [self.loadedSourceHashes containsObject:hash];
    });
    
    if (alreadyLoaded) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The script has already been loaded (hash: %@).", hash]
            }];
        }
    }
    return alreadyLoaded;
}

// ---------------------------------------------------------------------------
// Helper: Mark script as loaded
// ---------------------------------------------------------------------------

- (void)markPathAsLoaded:(NSString *)path {
    dispatch_sync(self.loadedScriptsQueue, ^{
        [self.loadedPaths addObject:path];
    });
}

- (void)markSourceHashAsLoaded:(NSString *)hash {
    dispatch_sync(self.loadedScriptsQueue, ^{
        [self.loadedSourceHashes addObject:hash];
    });
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
// Helper: Load and install nodes from source
// ---------------------------------------------------------------------------

- (BOOL)loadAndInstallNodesFromSource:(NSString *)source
                             scriptPath:(nullable NSString *)scriptPath
                                 error:(NSError **)error {
    ASLexer *lexer = [ASLexer new];
    ASParser *parser = [ASParser new];
    
    // Lex
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [lexer tokenize:source error:&lexError];
    if (!tokens) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorLexerFailure
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Lexer error in %@", scriptPath ?: @"<source string>"],
                NSUnderlyingErrorKey: lexError ?: [NSNull null]
            }];
        }
        return NO;
    }
    
    // Parse
    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [parser parseTokens:tokens error:&parseError];
    if (!nodes) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorParserFailure
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Parser error in %@", scriptPath ?: @"<source string>"],
                NSUnderlyingErrorKey: parseError ?: [NSNull null]
            }];
        }
        return NO;
    }
    
    // Install
    NSString *path = scriptPath ?: @"<source string>";
    NSError *installError = nil;
    BOOL installed = [self.installer installNodes:nodes
                                       scriptPath:path
                                            error:&installError];
    if (!installed) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorInstallFailure
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Runtime install error in %@", path],
                NSUnderlyingErrorKey: installError ?: [NSNull null]
            }];
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
    // Check if already loaded
    NSString *absolutePath = [filePath stringByResolvingSymlinksInPath];
    if ([self hasLoadedPath:absolutePath error:error]) {
        return NO;
    }
    
    // Read file
    NSError *readError = nil;
    NSString *source = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:absolutePath]
                                               encoding:NSUTF8StringEncoding
                                                  error:&readError];
    if (!source) {
        if (error) {
            *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                         code:ASLoaderErrorFileReadFailure
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Could not read AppScript source file: %@", absolutePath],
                NSUnderlyingErrorKey: readError ?: [NSNull null]
            }];
        }
        return NO;
    }
    
    // Load and install
    BOOL success = [self loadAndInstallNodesFromSource:source
                                            scriptPath:scriptName ?: absolutePath
                                                error:error];
    
    if (success) {
        [self markPathAsLoaded:absolutePath];
    }
    
    return success;
}

- (BOOL)loadScriptFromString:(NSString *)source
                  scriptName:(nullable NSString *)scriptName
                       error:(NSError **)error {
    // Compute hash for duplicate detection
    NSString *hash = [self hashOfString:source];
    if ([self hasLoadedSourceHash:hash error:error]) {
        return NO;
    }
    
    // Load and install
    BOOL success = [self loadAndInstallNodesFromSource:source
                                            scriptPath:scriptName ?: hash
                                                error:error];
    
    if (success) {
        [self markSourceHashAsLoaded:hash];
    }
    
    return success;
}

- (BOOL)loadScriptsFromFilesAtPaths:(NSArray<NSString *> *)filePaths error:(NSError **)error {
    // Build a map of absolute path → script name
    NSMutableDictionary<NSString *, NSString *> *pathToName = [NSMutableDictionary dictionary];
    for (NSString *path in filePaths) {
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        pathToName[absolutePath] = path;
    }
    
    // Check for duplicates
    for (NSString *path in filePaths) {
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        if ([self hasLoadedPath:absolutePath error:error]) {
            return NO;
        }
    }
    
    // Read all files
    NSMutableDictionary<NSString *, NSString *> *pathToSource = [NSMutableDictionary dictionary];
    for (NSString *path in filePaths) {
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        NSError *readError = nil;
        NSString *source = [NSString stringWithContentsOfURL:[NSURL fileURLWithPath:absolutePath]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&readError];
        if (!source) {
            if (error) {
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorFileReadFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Could not read AppScript source file: %@", absolutePath],
                    NSUnderlyingErrorKey: readError ?: [NSNull null]
                }];
            }
            return NO;
        }
        pathToSource[absolutePath] = source;
    }
    
    // Build nodes for each script
    ASParser *parser = [ASParser new];
    NSMutableDictionary<NSString *, NSArray<ASASTNode *> *> *pathToNodes = [NSMutableDictionary dictionary];
    
    for (NSString *path in filePaths) {
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        NSString *source = pathToSource[absolutePath];
        
        // Lex
        ASLexer *lexer = [ASLexer new];
        NSError *lexError = nil;
        NSArray<ASToken *> *tokens = [lexer tokenize:source error:&lexError];
        if (!tokens) {
            if (error) {
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorLexerFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Lexer error in %@", absolutePath],
                    NSUnderlyingErrorKey: lexError ?: [NSNull null]
                }];
            }
            return NO;
        }
        
        // Parse
        NSError *parseError = nil;
        NSArray<ASASTNode *> *nodes = [parser parseTokens:tokens error:&parseError];
        if (!nodes) {
            if (error) {
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorParserFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Parser error in %@", absolutePath],
                    NSUnderlyingErrorKey: parseError ?: [NSNull null]
                }];
            }
            return NO;
        }
        pathToNodes[absolutePath] = nodes;
    }
    
    // Topologically sort by superclass dependency
    NSMutableDictionary<NSString *, NSNumber *> *classToScriptIndex = [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < filePaths.count; i++) {
        NSString *path = filePaths[i];
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        NSArray<ASASTNode *> *nodes = pathToNodes[absolutePath];
        for (ASASTNode *node in nodes) {
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
        NSString *path = filePaths[i];
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        NSArray<ASASTNode *> *nodes = pathToNodes[absolutePath];
        for (ASASTNode *node in nodes) {
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
    
    // Install in sorted order
    for (NSNumber *idxNum in sortedIndices) {
        NSUInteger idx = idxNum.unsignedIntegerValue;
        NSString *path = filePaths[idx];
        NSString *absolutePath = [path stringByResolvingSymlinksInPath];
        NSArray<ASASTNode *> *nodes = pathToNodes[absolutePath];
        
        NSError *installError = nil;
        BOOL installed = [self.installer installNodes:nodes
                                           scriptPath:absolutePath
                                                error:&installError];
        if (!installed) {
            if (error) {
                *error = [NSError errorWithDomain:ASLoaderErrorDomain
                                             code:ASLoaderErrorInstallFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Runtime install error in %@", absolutePath],
                    NSUnderlyingErrorKey: installError ?: [NSNull null]
                }];
            }
            return NO;
        }
        
        [self markPathAsLoaded:absolutePath];
    }
    
    return YES;
}

- (BOOL)loadScriptsFromStrings:(NSArray<NSString *> *)sources error:(NSError **)error {
    // Check for duplicates
    for (NSString *source in sources) {
        NSString *hash = [self hashOfString:source];
        if ([self hasLoadedSourceHash:hash error:error]) {
            return NO;
        }
    }
    
    // Load and install each source
    for (NSString *source in sources) {
        NSString *hash = [self hashOfString:source];
        
        NSError *installError = nil;
        BOOL installed = [self loadAndInstallNodesFromSource:source
                                                    scriptPath:hash
                                                        error:&installError];
        if (!installed) {
            if (error) {
                // Copy the error from installError
                *error = installError;
            }
            return NO;
        }
        
        [self markSourceHashAsLoaded:hash];
    }
    
    return YES;
}

@end
