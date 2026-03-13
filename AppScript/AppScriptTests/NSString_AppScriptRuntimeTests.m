// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSString_AppScriptRuntimeTests.m — Unit tests for NSString (AppScriptRuntime)
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
#import <AppScript/NSString+AppScriptRuntime.h>

@interface NSString_AppScriptRuntimeTests : XCTestCase
@end

@implementation NSString_AppScriptRuntimeTests

- (void)test_as_class_knownClassName_returnsClass {
    id result = [@"NSArray" as_class];
    XCTAssertNotNil(result, @"as_class should return a non-nil value for a known class name");
    XCTAssertEqual(result, (id)[NSArray class],
                   @"as_class should return the NSArray class for the string 'NSArray'");
}

- (void)test_as_class_unknownClassName_returnsNil {
    id result = [@"NoSuchClassExistsInThisProcess_AppScript" as_class];
    XCTAssertNil(result, @"as_class should return nil for an unknown class name");
}

- (void)test_as_class_resultCanReceiveClassLevelMessages {
    id cls = [@"NSMutableArray" as_class];
    XCTAssertNotNil(cls);
    // Verify the result is actually a usable class object by sending a class-level message.
    id instance = [cls new];
    XCTAssertNotNil(instance);
    XCTAssertTrue([instance isKindOfClass:[NSMutableArray class]]);
}

@end
