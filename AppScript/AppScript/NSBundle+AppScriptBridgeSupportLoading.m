// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle+AppScriptBridgeSupportLoading.m — Entry point for loading BridgeSupport metadata
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

#import "NSBundle+AppScriptBridgeSupportLoading.h"
#import "ASBridgeSupportParser.h"
#import "ASBridgeSupportInstaller.h"
#import "ASBridgeSupportDocument.h"

NSString * const ASBridgeSupportLoadingErrorDomain = @"ASBridgeSupportLoadingErrorDomain";

@implementation NSBundle (AppScriptBridgeSupportLoading)

+ (BOOL)loadBridgeSupportForFramework:(NSString *)frameworkName error:(NSError **)error {
    // --- Locate the BridgeSupport file ---
    NSURL *bridgeSupportURL = nil;

    // 1. Try the system framework bundle.
    NSString *frameworkPath = [NSString stringWithFormat:
        @"/System/Library/Frameworks/%@.framework", frameworkName];
    NSBundle *frameworkBundle = [NSBundle bundleWithPath:frameworkPath];
    if (frameworkBundle != nil) {
        bridgeSupportURL = [frameworkBundle URLForResource:frameworkName
                                            withExtension:@"bridgesupport"
                                             subdirectory:@"BridgeSupport"];
    }

    // 2. Fallback: system-wide BridgeSupport directory.
    if (bridgeSupportURL == nil) {
        NSString *fallbackPath = [NSString stringWithFormat:
            @"/System/Library/BridgeSupport/%@.bridgesupport", frameworkName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fallbackPath]) {
            bridgeSupportURL = [NSURL fileURLWithPath:fallbackPath];
        }
    }

    if (bridgeSupportURL == nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASBridgeSupportLoadingErrorDomain
                                         code:ASBridgeSupportLoadingErrorBridgeSupportNotFound
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"No BridgeSupport file found for framework '%@'", frameworkName],
            }];
        }
        return NO;
    }

    // --- Parse ---
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSError *parseError = nil;
    ASBridgeSupportDocument *document = [parser parseURL:bridgeSupportURL error:&parseError];
    if (document == nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASBridgeSupportLoadingErrorDomain
                                         code:ASBridgeSupportLoadingErrorParseFailed
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Failed to parse BridgeSupport for framework '%@': %@",
                    frameworkName, parseError.localizedDescription],
                NSUnderlyingErrorKey: parseError,
            }];
        }
        return NO;
    }

    // --- Install ---
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSError *installError = nil;
    BOOL installed = [installer installDocument:document
                                  frameworkName:frameworkName
                                          error:&installError];
    if (!installed) {
        if (installError.code == ASBridgeSupportInstallerErrorDuplicateFramework &&
            [installError.domain isEqualToString:ASBridgeSupportInstallerErrorDomain]) {
            if (error) {
                *error = [NSError errorWithDomain:ASBridgeSupportLoadingErrorDomain
                                             code:ASBridgeSupportLoadingErrorDuplicateLoad
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"BridgeSupport for framework '%@' has already been loaded", frameworkName],
                    NSUnderlyingErrorKey: installError,
                }];
            }
        } else {
            if (error) {
                *error = [NSError errorWithDomain:ASBridgeSupportLoadingErrorDomain
                                             code:ASBridgeSupportLoadingErrorParseFailed
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Failed to install BridgeSupport for framework '%@': %@",
                        frameworkName, installError.localizedDescription],
                    NSUnderlyingErrorKey: installError,
                }];
            }
        }
        return NO;
    }

    return YES;
}

+ (BOOL)loadBridgeSupportForFramework:(NSString *)frameworkName {
    return [self loadBridgeSupportForFramework:frameworkName error:nil];
}

@end
