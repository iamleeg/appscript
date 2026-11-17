// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASFrameworkSourceTests.m — Checks framework imports, and that the build lists match the source directory
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

/// The file names (without directories) of the `.h`/`.m` entries in a GNUmakefile variable
/// whose value is a backslash-continued list.
static NSSet<NSString *> *ASMakefileListNamed(NSString *makefile, NSString *variable) {
    NSString *pattern = [NSString stringWithFormat:@"^%@\\s*=\\s*\\\\\n((?:[ \\t]+\\S+[ \\t]*\\\\\n)*[ \\t]+\\S+[ \\t]*)$",
                         [NSRegularExpression escapedPatternForString:variable]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:makefile options:0
                                                      range:NSMakeRange(0, makefile.length)];
    if (match == nil) {
        return nil;
    }
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    NSString *body = [makefile substringWithRange:[match rangeAtIndex:1]];
    for (NSString *token in [body componentsSeparatedByCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if ([token hasSuffix:@".h"] || [token hasSuffix:@".m"]) {
            [names addObject:token.lastPathComponent];
        }
    }
    return names;
}

/// The headers in the Xcode project's `publicHeaders` list for the framework folder.
static NSSet<NSString *> *ASXcodePublicHeaders(NSString *project) {
    NSRange start = [project rangeOfString:@"publicHeaders = ("];
    if (start.location == NSNotFound) {
        return nil;
    }
    NSUInteger from = NSMaxRange(start);
    NSRange end = [project rangeOfString:@");" options:0
                                   range:NSMakeRange(from, project.length - from)];
    NSString *body = [project substringWithRange:NSMakeRange(from, end.location - from)];
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    for (NSString *token in [body componentsSeparatedByCharactersInSet:
                             [NSCharacterSet characterSetWithCharactersInString:@" \t\n\",()"]]) {
        if ([token hasSuffix:@".h"]) {
            [names addObject:token];
        }
    }
    return names;
}

/// The names of the files in `directory` with the given extension.
static NSSet<NSString *> *ASFilesWithExtension(NSString *directory, NSString *extension) {
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL]) {
        if ([file.pathExtension isEqualToString:extension]) {
            [names addObject:file];
        }
    }
    return names;
}

/// "missing from <list>: a, b; not in the directory: c" for two sets that should be equal.
static NSString *ASSetDifference(NSSet<NSString *> *directory, NSSet<NSString *> *list, NSString *listName) {
    NSMutableSet *missing = [directory mutableCopy];
    [missing minusSet:list];
    NSMutableSet *extra = [list mutableCopy];
    [extra minusSet:directory];
    NSArray *byName = @[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]];
    return [NSString stringWithFormat:@"missing from %@: %@; listed but not in the directory: %@",
            listName,
            [[missing sortedArrayUsingDescriptors:byName] componentsJoinedByString:@", "],
            [[extra sortedArrayUsingDescriptors:byName] componentsJoinedByString:@", "]];
}

@interface ASFrameworkSourceTests : XCTestCase
@end

@implementation ASFrameworkSourceTests

/// The public headers: every header in the source directory except the umbrella header and
/// the project-only ones.
- (NSSet<NSString *> *)publicHeaders {
    NSMutableSet<NSString *> *headers = [ASFilesWithExtension(ASFrameworkSourceDirectory(), @"h") mutableCopy];
    [headers removeObject:@"AppScript.h"];
    [headers minusSet:[NSSet setWithArray:ASProjectOnlyHeaders()]];
    return headers;
}

- (NSString *)contentsOfFrameworkFile:(NSString *)relativePath {
    NSString *path = [[[ASFrameworkSourceDirectory() stringByDeletingLastPathComponent]
                       stringByAppendingPathComponent:relativePath] stringByStandardizingPath];
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    XCTAssertNotNil(contents, @"Couldn't read %@", path);
    return contents ?: @"";
}

// Adding or removing a framework file means editing the GNUmakefile's lists and Xcode's
// public-header list by hand; these tests fail when any of them disagree with the
// directory (asu-85b). Xcode's own source membership follows the folder automatically.

- (void)test_makefileObjCFiles_matchSourceDirectory {
    NSSet *sources = ASFilesWithExtension(ASFrameworkSourceDirectory(), @"m");
    NSSet *listed = ASMakefileListNamed([self contentsOfFrameworkFile:@"GNUmakefile"], @"AppScript_OBJC_FILES");
    XCTAssertNotNil(listed, @"AppScript_OBJC_FILES not found in the GNUmakefile");
    XCTAssertGreaterThanOrEqual(sources.count, (NSUInteger)40);
    XCTAssertEqualObjects(listed, sources, @"%@",
                          ASSetDifference(sources, listed, @"AppScript_OBJC_FILES"));
}

- (void)test_makefileHeaderFiles_matchPublicHeaders {
    NSMutableSet *expected = [[self publicHeaders] mutableCopy];
    [expected addObject:@"AppScript.h"];
    NSSet *listed = ASMakefileListNamed([self contentsOfFrameworkFile:@"GNUmakefile"], @"AppScript_HEADER_FILES");
    XCTAssertNotNil(listed, @"AppScript_HEADER_FILES not found in the GNUmakefile");
    XCTAssertEqualObjects(listed, expected, @"%@",
                          ASSetDifference(expected, listed, @"AppScript_HEADER_FILES"));
}

- (void)test_xcodePublicHeaders_matchPublicHeaders {
    NSMutableSet *expected = [[self publicHeaders] mutableCopy];
    [expected addObject:@"AppScript.h"];
    NSSet *listed = ASXcodePublicHeaders([self contentsOfFrameworkFile:@"AppScript.xcodeproj/project.pbxproj"]);
    XCTAssertNotNil(listed, @"publicHeaders not found in the Xcode project");
    XCTAssertEqualObjects(listed, expected, @"%@",
                          ASSetDifference(expected, listed, @"Xcode publicHeaders"));
}

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
