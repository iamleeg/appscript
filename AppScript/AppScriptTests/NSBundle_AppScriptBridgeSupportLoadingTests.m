// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle_AppScriptBridgeSupportLoadingTests.m — Tests for NSBundle+AppScriptBridgeSupportLoading
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
#import <AppScript/NSBundle+AppScriptBridgeSupportLoading.h>

@interface NSBundle_AppScriptBridgeSupportLoadingTests : XCTestCase
@end

@implementation NSBundle_AppScriptBridgeSupportLoadingTests

- (void)test_loadBridgeSupportForFramework_unknownFramework_returnsError {
    NSError *error = nil;
    BOOL result = [NSBundle loadBridgeSupportForFramework:@"_NonExistentFramework_XYZ"
                                                    error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ASBridgeSupportLoadingErrorDomain);
    XCTAssertEqual(error.code, ASBridgeSupportLoadingErrorBridgeSupportNotFound);
}

- (void)test_loadBridgeSupportForFramework_Foundation_installsProxyClass {
    // Foundation's BridgeSupport is at a known system path.
    NSError *error = nil;
    BOOL result = [NSBundle loadBridgeSupportForFramework:@"Foundation" error:&error];

    // Either succeeds (first load) or fails with duplicate-load (if another test already loaded it).
    if (!result) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, ASBridgeSupportLoadingErrorDomain);
        XCTAssertEqual(error.code, ASBridgeSupportLoadingErrorDuplicateLoad,
                       @"The only acceptable failure is a duplicate load: %@", error);
    }

    // Either way, the proxy class must exist by now.
    XCTAssertNotNil(NSClassFromString(@"ASFoundation"),
                    @"ASFoundation proxy class should be registered after loading Foundation BridgeSupport");
}

- (void)test_loadBridgeSupportForFramework_duplicateLoad_returnsError {
    // Load Foundation first (it may already be loaded from a previous test).
    [NSBundle loadBridgeSupportForFramework:@"Foundation" error:nil];

    // A second attempt must always fail with duplicate-load.
    NSError *error = nil;
    BOOL result = [NSBundle loadBridgeSupportForFramework:@"Foundation" error:&error];

    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ASBridgeSupportLoadingErrorDomain);
    XCTAssertEqual(error.code, ASBridgeSupportLoadingErrorDuplicateLoad);
}

- (void)test_loadBridgeSupportForFramework_convenienceNilError_returnsBOOL {
    // Convenience variant must not crash when there's nothing to load.
    BOOL result = [NSBundle loadBridgeSupportForFramework:@"_NonExistentFramework_ABC"];
    XCTAssertFalse(result);
}

@end
