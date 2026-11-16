// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASOutObjectTests.m — Unit tests for ASOutObject
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
#import <AppScript/ASOutObject.h>

/// Unit tests for the ASOutObject container class.
@interface ASOutObjectTests : XCTestCase
@end

@implementation ASOutObjectTests

- (void)test_outObject_returnsInstanceWithNilValue {
    ASOutObject *outObj = [ASOutObject outObject];
    XCTAssertNotNil(outObj, @"+outObject should return a non-nil instance");
    XCTAssertNil(outObj.value, @"+outObject should initialise value to nil");
}

- (void)test_init_returnsInstanceWithNilValue {
    ASOutObject *outObj = [[ASOutObject alloc] init];
    XCTAssertNotNil(outObj, @"-init should return a non-nil instance");
    XCTAssertNil(outObj.value, @"-init should initialise value to nil");
}

- (void)test_initWithValue_storesInitialValue {
    NSError *err = [NSError errorWithDomain:@"TestDomain" code:42 userInfo:nil];
    ASOutObject *outObj = [[ASOutObject alloc] initWithValue:err];
    XCTAssertEqualObjects(outObj.value, err, @"-initWithValue: should store the supplied object");
}

- (void)test_setValue_updatesStoredValue {
    ASOutObject *outObj = [ASOutObject outObject];
    NSError *err = [NSError errorWithDomain:@"TestDomain" code:99 userInfo:nil];
    outObj.value = err;
    XCTAssertEqualObjects(outObj.value, err, @"Setting value should update the stored object");
}

- (void)test_outObject_hasNilPointeeTypeEncoding {
    XCTAssertNil([ASOutObject outObject].pointeeTypeEncoding,
                 @"+outObject should start with no pointee type");
}

- (void)test_initWithValue_pointeeTypeEncoding_storesBoth {
    ASOutObject *outObj = [[ASOutObject alloc] initWithValue:@7 pointeeTypeEncoding:@"q"];
    XCTAssertEqualObjects(outObj.value, @7);
    XCTAssertEqualObjects(outObj.pointeeTypeEncoding, @"q");
}

- (void)test_initWithValue_leavesPointeeTypeEncodingNil {
    ASOutObject *outObj = [[ASOutObject alloc] initWithValue:@"x"];
    XCTAssertNil(outObj.pointeeTypeEncoding, @"-initWithValue: is for object out-parameters");
}

- (void)test_setPointeeTypeEncoding_updatesType {
    ASOutObject *outObj = [ASOutObject outObject];
    outObj.pointeeTypeEncoding = @"d";
    XCTAssertEqualObjects(outObj.pointeeTypeEncoding, @"d");
}

@end
