// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASFrameworkImportTests.m — Checks that framework sources import public headers with angle brackets
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

#import <XCTest/XCTest.h>

/// Framework headers that are not installed in the framework's Headers directory, and so
/// are imported with quotes.
static NSArray<NSString *> *ASProjectOnlyHeaders(void) {
    return @[@"ASFfiSupport.h"];
}

/// The framework source directory, found from this file's path (`../AppScript`).
static NSString *ASFrameworkSourceDirectory(void) {
    NSString *thisFile = @__FILE__;
    if (![thisFile isAbsolutePath]) {
        thisFile = [[[NSFileManager defaultManager] currentDirectoryPath]
                    stringByAppendingPathComponent:thisFile];
    }
    NSString *testsDirectory = [thisFile stringByDeletingLastPathComponent];
    return [[[testsDirectory stringByDeletingLastPathComponent]
             stringByAppendingPathComponent:@"AppScript"] stringByStandardizingPath];
}

@interface ASFrameworkImportTests : XCTestCase
@end

@implementation ASFrameworkImportTests

/// A client that imports <AppScript/AppScript.h> or any public header with
/// -Wquoted-include-in-framework-header gets a warning for every quoted sibling import.
/// Framework sources use the angle-bracketed form throughout, so GNUstep never sees both
/// forms of one header in a translation unit (asu-2j2, ADR 34).
- (void)test_frameworkSources_importPublicHeadersWithAngleBrackets {
    NSString *directory = ASFrameworkSourceDirectory();
    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory
                                                                                    error:NULL];
    NSMutableSet<NSString *> *publicHeaders = [NSMutableSet set];
    for (NSString *file in files) {
        if ([file.pathExtension isEqualToString:@"h"]) {
            [publicHeaders addObject:file];
        }
    }
    [publicHeaders minusSet:[NSSet setWithArray:ASProjectOnlyHeaders()]];
    XCTAssertGreaterThanOrEqual(publicHeaders.count, (NSUInteger)40,
                                @"Expected the framework headers in %@", directory);

    NSMutableArray<NSString *> *violations = [NSMutableArray array];
    for (NSString *file in [files sortedArrayUsingSelector:@selector(compare:)]) {
        if (![file.pathExtension isEqualToString:@"h"] && ![file.pathExtension isEqualToString:@"m"]) {
            continue;
        }
        NSString *contents = [NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:file]
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
        NSArray<NSString *> *lines = [contents componentsSeparatedByString:@"\n"];
        for (NSUInteger i = 0; i < lines.count; i++) {
            NSString *line = lines[i];
            if (![line hasPrefix:@"#import \""]) {
                continue;
            }
            NSArray<NSString *> *parts = [line componentsSeparatedByString:@"\""];
            if (parts.count >= 2 && [publicHeaders containsObject:parts[1]]) {
                [violations addObject:[NSString stringWithFormat:@"%@:%lu %@",
                                       file, (unsigned long)(i + 1), line]];
            }
        }
    }
    XCTAssertEqual(violations.count, (NSUInteger)0,
                   @"Import public framework headers as <AppScript/X.h>:\n%@",
                   [violations componentsJoinedByString:@"\n"]);
}

@end
