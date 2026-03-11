// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle+AppScriptLoading.m — Top-level entry point for loading .appscript files from a bundle
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

#import "NSBundle+AppScriptLoading.h"
#import "ASLexer.h"
#import "ASParser.h"
#import "ASRuntimeInstaller.h"
#import "ASClassDefinitionNode.h"

NSString * const ASBundleLoadingErrorDomain = @"ASBundleLoadingErrorDomain";

// _ASLoadedBundlesQueue is the owning queue for _ASLoadedBundles. All reads
// and writes of that mutable set must be performed synchronously on this queue
// to guarantee mutual exclusion.
static dispatch_queue_t _ASLoadedBundlesQueue;
static NSMutableSet<NSString *> *_ASLoadedBundles;

@implementation NSBundle (AppScriptLoading)

+ (void)load {
    _ASLoadedBundlesQueue = dispatch_queue_create("_ASLoadedBundlesQueue", DISPATCH_QUEUE_SERIAL);
    _ASLoadedBundles = [[NSMutableSet alloc] init];
}

// Returns a stable string key for a bundle: its bundleIdentifier when available,
// otherwise its bundlePath. A path is always non-nil, so the return is always usable.
static NSString *bundleKey(NSBundle *bundle) {
    NSString *identifier = bundle.bundleIdentifier;
    return identifier ? identifier : bundle.bundlePath;
}

- (BOOL)loadScriptsWithError:(NSError **)error {
    // -----------------------------------------------------------------------
    // 1. Duplicate-load check (synchronous on the owning queue).
    // -----------------------------------------------------------------------
    NSString *key = bundleKey(self);
    __block BOOL alreadyLoaded = NO;
    dispatch_sync(_ASLoadedBundlesQueue, ^{
        alreadyLoaded = [_ASLoadedBundles containsObject:key];
    });

    if (alreadyLoaded) {
        if (error) {
            *error = [NSError errorWithDomain:ASBundleLoadingErrorDomain
                                         code:ASBundleLoadingErrorDuplicateLoad
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"The bundle \"%@\" has already been loaded.", key]
            }];
        }
        return NO;
    }

    // -----------------------------------------------------------------------
    // 2. Discover .appscript files.
    // -----------------------------------------------------------------------
    NSArray<NSURL *> *scriptURLs =
        [self URLsForResourcesWithExtension:@"appscript" subdirectory:nil];

    if (scriptURLs.count == 0) {
        // Nothing to do — mark the bundle as loaded and return success.
        dispatch_sync(_ASLoadedBundlesQueue, ^{
            [_ASLoadedBundles addObject:key];
        });
        return YES;
    }

    // -----------------------------------------------------------------------
    // 3. Lex and parse all files, collecting (url, nodes) pairs.
    // -----------------------------------------------------------------------
    ASLexer *lexer = [ASLexer new];
    ASParser *parser = [ASParser new];
    ASRuntimeInstaller *installer = [ASRuntimeInstaller new];

    // Each entry: @{ @"url": NSURL, @"nodes": NSArray<ASASTNode *> }
    NSMutableArray<NSDictionary *> *parsedScripts = [NSMutableArray array];

    for (NSURL *url in scriptURLs) {
        // 3a. Read source text.
        NSError *readError = nil;
        NSString *source = [NSString stringWithContentsOfURL:url
                                                    encoding:NSUTF8StringEncoding
                                                       error:&readError];
        if (!source) {
            if (error) {
                *error = [NSError errorWithDomain:ASBundleLoadingErrorDomain
                                             code:ASBundleLoadingErrorLexerFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Could not read AppScript source file: %@", url.path],
                    NSUnderlyingErrorKey: readError ?: [NSNull null]
                }];
            }
            return NO;
        }

        // 3b. Lex.
        NSError *lexError = nil;
        NSArray<ASToken *> *tokens = [lexer tokenize:source error:&lexError];
        if (!tokens) {
            if (error) {
                *error = [NSError errorWithDomain:ASBundleLoadingErrorDomain
                                             code:ASBundleLoadingErrorLexerFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Lexer error in %@", url.path],
                    NSUnderlyingErrorKey: lexError
                }];
            }
            return NO;
        }

        // 3c. Parse.
        NSError *parseError = nil;
        NSArray<ASASTNode *> *nodes = [parser parseTokens:tokens error:&parseError];
        if (!nodes) {
            if (error) {
                *error = [NSError errorWithDomain:ASBundleLoadingErrorDomain
                                             code:ASBundleLoadingErrorParserFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Parser error in %@", url.path],
                    NSUnderlyingErrorKey: parseError
                }];
            }
            return NO;
        }

        [parsedScripts addObject:@{ @"url": url, @"nodes": nodes }];
    }

    // -----------------------------------------------------------------------
    // 4. Topologically sort parsed scripts by intra-bundle superclass dependency.
    //
    // Build a map of className → script index for every class defined across
    // all parsed scripts. Then perform Kahn's algorithm: repeatedly pick a
    // script whose classes have no unsatisfied intra-bundle superclass
    // dependency (i.e., the superclass is either already in the ObjC runtime
    // or has already been scheduled). Scripts with no intra-bundle dependencies
    // are placed first; the relative order of independent scripts is
    // unspecified but stable.
    // -----------------------------------------------------------------------

    // Map class name → index of the script that defines it (within parsedScripts).
    NSMutableDictionary<NSString *, NSNumber *> *classToScriptIndex =
        [NSMutableDictionary dictionary];
    for (NSUInteger i = 0; i < parsedScripts.count; i++) {
        NSArray<ASASTNode *> *nodes = parsedScripts[i][@"nodes"];
        for (ASASTNode *node in nodes) {
            if ([node isKindOfClass:[ASClassDefinitionNode class]]) {
                NSString *className = ((ASClassDefinitionNode *)node).className;
                classToScriptIndex[className] = @(i);
            }
        }
    }

    // in-degree[i] = number of scripts that script i must wait for.
    NSMutableArray<NSNumber *> *inDegree = [NSMutableArray array];
    // dependents[i] = list of script indices that depend on script i.
    NSMutableArray<NSMutableArray<NSNumber *> *> *dependents = [NSMutableArray array];
    for (NSUInteger i = 0; i < parsedScripts.count; i++) {
        [inDegree addObject:@0];
        [dependents addObject:[NSMutableArray array]];
    }

    for (NSUInteger i = 0; i < parsedScripts.count; i++) {
        NSArray<ASASTNode *> *nodes = parsedScripts[i][@"nodes"];
        for (ASASTNode *node in nodes) {
            if (![node isKindOfClass:[ASClassDefinitionNode class]]) continue;
            NSString *superclassName = ((ASClassDefinitionNode *)node).superclassName;
            if (!superclassName) continue;
            NSNumber *depIndex = classToScriptIndex[superclassName];
            if (depIndex == nil) continue;          // superclass is in the ObjC runtime already
            NSUInteger j = depIndex.unsignedIntegerValue;
            if (j == i) continue;                   // class in same file as its superclass
            [dependents[j] addObject:@(i)];
            inDegree[i] = @(inDegree[i].unsignedIntegerValue + 1);
        }
    }

    // Kahn's algorithm: start with all scripts that have in-degree 0.
    NSMutableArray<NSNumber *> *queue = [NSMutableArray array];
    for (NSUInteger i = 0; i < parsedScripts.count; i++) {
        if (inDegree[i].unsignedIntegerValue == 0) {
            [queue addObject:@(i)];
        }
    }

    NSMutableArray<NSDictionary *> *sortedScripts = [NSMutableArray array];
    while (queue.count > 0) {
        NSNumber *idxNum = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [sortedScripts addObject:parsedScripts[idxNum.unsignedIntegerValue]];
        for (NSNumber *dependent in dependents[idxNum.unsignedIntegerValue]) {
            NSUInteger newDegree = inDegree[dependent.unsignedIntegerValue].unsignedIntegerValue - 1;
            inDegree[dependent.unsignedIntegerValue] = @(newDegree);
            if (newDegree == 0) {
                [queue addObject:dependent];
            }
        }
    }

    // If sortedScripts doesn't contain all scripts, there's a cycle — fall back
    // to the original order so the installer can report a meaningful error.
    if (sortedScripts.count != parsedScripts.count) {
        sortedScripts = parsedScripts;
    }

    // -----------------------------------------------------------------------
    // 5. Install in dependency order.
    // -----------------------------------------------------------------------
    for (NSDictionary *entry in sortedScripts) {
        NSURL *url = entry[@"url"];
        NSArray<ASASTNode *> *nodes = entry[@"nodes"];

        NSError *installError = nil;
        BOOL installed = [installer installNodes:nodes
                                      scriptPath:url.path
                                           error:&installError];
        if (!installed) {
            if (error) {
                *error = [NSError errorWithDomain:ASBundleLoadingErrorDomain
                                             code:ASBundleLoadingErrorInstallFailure
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Runtime install error in %@", url.path],
                    NSUnderlyingErrorKey: installError
                }];
            }
            return NO;
        }
    }

    // -----------------------------------------------------------------------
    // 6. Mark bundle as successfully loaded.
    // -----------------------------------------------------------------------
    dispatch_sync(_ASLoadedBundlesQueue, ^{
        [_ASLoadedBundles addObject:key];
    });

    return YES;
}

@end
