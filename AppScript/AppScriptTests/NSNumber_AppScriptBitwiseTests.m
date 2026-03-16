// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber_AppScriptBitwiseTests.m — Tests for NSNumber bitwise operator category
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
#import "NSNumber+AppScriptBitwise.h"

@interface NSNumber_AppScriptBitwiseTests : XCTestCase
@end

@implementation NSNumber_AppScriptBitwiseTests

// MARK: - bitwiseOr:

- (void)test_bitwiseOr_disjointBits_returnsCombinedBits {
    XCTAssertEqual([@1 bitwiseOr:@2].unsignedIntegerValue, (NSUInteger)3);
}

- (void)test_bitwiseOr_overlappingBits_returnsUnion {
    XCTAssertEqual([@3 bitwiseOr:@6].unsignedIntegerValue, (NSUInteger)7);
}

- (void)test_bitwiseOr_withZero_returnsReceiver {
    XCTAssertEqual([@15 bitwiseOr:@0].unsignedIntegerValue, (NSUInteger)15);
}

- (void)test_bitwiseOr_windowStyleMaskComponents_returnsCombinedMask {
    // NSWindowStyleMaskTitled=1, Closable=2, Miniaturizable=4, Resizable=8 → 15
    NSNumber *mask = [[[[@1 bitwiseOr:@2] bitwiseOr:@4] bitwiseOr:@8] bitwiseOr:@0];
    XCTAssertEqual(mask.unsignedIntegerValue, (NSUInteger)15);
}

// MARK: - bitwiseAnd:

- (void)test_bitwiseAnd_commonBits_returnsIntersection {
    XCTAssertEqual([@6 bitwiseAnd:@3].unsignedIntegerValue, (NSUInteger)2);
}

- (void)test_bitwiseAnd_disjointBits_returnsZero {
    XCTAssertEqual([@5 bitwiseAnd:@2].unsignedIntegerValue, (NSUInteger)0);
}

- (void)test_bitwiseAnd_withSelf_returnsSelf {
    XCTAssertEqual([@12 bitwiseAnd:@12].unsignedIntegerValue, (NSUInteger)12);
}

- (void)test_bitwiseAnd_maskCheck_detectsBitPresence {
    // Check that bit 2 (value 4) is set in the combined mask 15
    NSNumber *mask = @15;
    NSNumber *bit = @4;
    XCTAssertNotEqual([mask bitwiseAnd:bit].unsignedIntegerValue, (NSUInteger)0);
}

// MARK: - bitwiseXor:

- (void)test_bitwiseXor_sameValues_returnsZero {
    XCTAssertEqual([@7 bitwiseXor:@7].unsignedIntegerValue, (NSUInteger)0);
}

- (void)test_bitwiseXor_differentValues_returnsSymmetricDifference {
    XCTAssertEqual([@5 bitwiseXor:@3].unsignedIntegerValue, (NSUInteger)6);
}

- (void)test_bitwiseXor_withZero_returnsReceiver {
    XCTAssertEqual([@9 bitwiseXor:@0].unsignedIntegerValue, (NSUInteger)9);
}

- (void)test_bitwiseXor_appliedTwice_returnsOriginal {
    NSNumber *original = @42;
    NSNumber *key = @13;
    NSNumber *encrypted = [original bitwiseXor:key];
    NSNumber *decrypted = [encrypted bitwiseXor:key];
    XCTAssertEqual(decrypted.unsignedIntegerValue, original.unsignedIntegerValue);
}

// MARK: - bitwiseNot

- (void)test_bitwiseNot_andOriginal_andedTogetherIsZero {
    NSNumber *value = @0xABCD;
    NSNumber *complement = [value bitwiseNot];
    NSNumber *result = [value bitwiseAnd:complement];
    XCTAssertEqual(result.unsignedIntegerValue, (NSUInteger)0);
}

- (void)test_bitwiseNot_orWithOriginal_givesAllOnes {
    NSNumber *value = @0xABCD;
    NSNumber *complement = [value bitwiseNot];
    NSNumber *result = [value bitwiseOr:complement];
    XCTAssertEqual(result.unsignedIntegerValue, NSUIntegerMax);
}

- (void)test_bitwiseNot_appliedTwice_returnsOriginal {
    NSNumber *value = @255;
    XCTAssertEqual([[value bitwiseNot] bitwiseNot].unsignedIntegerValue, value.unsignedIntegerValue);
}

@end
