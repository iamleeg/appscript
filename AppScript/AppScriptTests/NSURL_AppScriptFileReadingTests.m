// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSURL_AppScriptFileReadingTests.m — Unit tests for NSURL (AppScriptFileReading)
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
#import <AppScript/NSURL+AppScriptFileReading.h>

@interface NSURL_AppScriptFileReadingTests : XCTestCase
@property (nonatomic, copy) NSURL *tempFileURL;
@end

@implementation NSURL_AppScriptFileReadingTests

- (void)setUp {
    [super setUp];
    // Write a temporary UTF-8 file for use in read tests.
    NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    self.tempFileURL = [tempDir URLByAppendingPathComponent:
                        [NSString stringWithFormat:@"ASFileReadingTest_%@.txt",
                         [[NSUUID UUID] UUIDString]]];
    [@"hello AppScript" writeToURL:self.tempFileURL
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:NULL];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.tempFileURL error:NULL];
    self.tempFileURL = nil;
    [super tearDown];
}

- (void)test_as_stringContents_existingUTF8File_returnsContents {
    NSString *result = [self.tempFileURL as_stringContents];
    XCTAssertEqualObjects(result, @"hello AppScript");
}

- (void)test_as_stringContents_nonExistentFile_returnsNil {
    NSURL *missing = [NSURL fileURLWithPath:@"/tmp/does_not_exist_appscript_test.txt"];
    NSString *result = [missing as_stringContents];
    XCTAssertNil(result, @"Reading a non-existent file should return nil");
}

@end
