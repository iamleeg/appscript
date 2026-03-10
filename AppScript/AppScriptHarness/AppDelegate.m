// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppDelegate.m — AppScriptHarness application delegate implementation
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

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSError *error = nil;
    if (![[NSBundle mainBundle] loadAppScriptsInBundle:&error]) {
        fprintf(stderr, "Failed to load AppScripts: %s\n", error.localizedDescription.UTF8String);
        exit(1);
    }

    NSArray<NSURL *> *scriptURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"as"
                                                                           subdirectory:@"Scripts"];
    NSInteger passed = 0;
    NSInteger failed = 0;

    for (NSURL *scriptURL in scriptURLs) {
        NSString *baseName = scriptURL.lastPathComponent.stringByDeletingPathExtension;
        NSString *className = [baseName stringByAppendingString:@"Test"];

        NSURL *expectedURL = [[scriptURL URLByDeletingPathExtension]
                              URLByAppendingPathExtension:@"expected"];

        Class cls = NSClassFromString(className);
        if (cls == nil) {
            fprintf(stdout, "FAIL: %s (class not found)\n", className.UTF8String);
            failed++;
            continue;
        }

        id instance = [cls new];
        id result = [instance runTests];
        NSString *got = [[result description]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSError *readError = nil;
        NSString *expectedRaw = [NSString stringWithContentsOfURL:expectedURL
                                                         encoding:NSUTF8StringEncoding
                                                            error:&readError];
        if (expectedRaw == nil) {
            fprintf(stdout, "FAIL: %s (could not read expected file: %s)\n",
                    className.UTF8String,
                    readError.localizedDescription.UTF8String);
            failed++;
            continue;
        }

        NSString *expected = [expectedRaw
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if ([got isEqualToString:expected]) {
            fprintf(stdout, "PASS: %s\n", className.UTF8String);
            passed++;
        } else {
            fprintf(stdout, "FAIL: %s (expected: \"%s\", got: \"%s\")\n",
                    className.UTF8String,
                    expected.UTF8String,
                    got.UTF8String);
            failed++;
        }
    }

    fprintf(stdout, "%ld passed, %ld failed\n", (long)passed, (long)failed);
    exit(failed == 0 ? 0 : 1);
}

@end
