// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber_AppScriptArithmeticTests.m — Tests for NSNumber arithmetic category
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
#import <AppScript/NSNumber+AppScriptArithmetic.h>

@interface NSNumber_AppScriptArithmeticTests : XCTestCase
@end

@implementation NSNumber_AppScriptArithmeticTests

- (void)test_numberByAdding_positiveNumbers_returnsSum {
    NSNumber *result = [@3 numberByAdding:@4];
    XCTAssertEqualWithAccuracy([result doubleValue], 7.0, 1e-10);
}

- (void)test_numberByAdding_negativeNumber_returnsCorrectSum {
    NSNumber *result = [@10 numberByAdding:@(-3)];
    XCTAssertEqualWithAccuracy([result doubleValue], 7.0, 1e-10);
}

- (void)test_numberBySubtracting_positiveNumbers_returnsDifference {
    NSNumber *result = [@10 numberBySubtracting:@4];
    XCTAssertEqualWithAccuracy([result doubleValue], 6.0, 1e-10);
}

- (void)test_numberBySubtracting_resultingInNegative_returnsNegative {
    NSNumber *result = [@3 numberBySubtracting:@7];
    XCTAssertEqualWithAccuracy([result doubleValue], -4.0, 1e-10);
}

- (void)test_numberByMultiplyingBy_positiveNumbers_returnsProduct {
    NSNumber *result = [@6 numberByMultiplyingBy:@7];
    XCTAssertEqualWithAccuracy([result doubleValue], 42.0, 1e-10);
}

- (void)test_numberByMultiplyingBy_byZero_returnsZero {
    NSNumber *result = [@99 numberByMultiplyingBy:@0];
    XCTAssertEqualWithAccuracy([result doubleValue], 0.0, 1e-10);
}

- (void)test_numberByDividingBy_positiveNumbers_returnsQuotient {
    NSNumber *result = [@10 numberByDividingBy:@4];
    XCTAssertEqualWithAccuracy([result doubleValue], 2.5, 1e-10);
}

- (void)test_numberByDividingBy_byZero_returnsInfinity {
    NSNumber *result = [@1 numberByDividingBy:@0];
    XCTAssertEqual([result doubleValue], INFINITY);
}

- (void)test_negated_positiveNumber_returnsNegative {
    NSNumber *result = [@5 negated];
    XCTAssertEqualWithAccuracy([result doubleValue], -5.0, 1e-10);
}

- (void)test_negated_negativeNumber_returnsPositive {
    NSNumber *result = [@(-3) negated];
    XCTAssertEqualWithAccuracy([result doubleValue], 3.0, 1e-10);
}

- (void)test_negated_zero_returnsZero {
    NSNumber *result = [@0 negated];
    XCTAssertEqualWithAccuracy([result doubleValue], 0.0, 1e-10);
}

- (void)test_negated_doubleValue_preservesPrecision {
    NSNumber *result = [@3.14159 negated];
    XCTAssertEqualWithAccuracy([result doubleValue], -3.14159, 1e-10);
}

- (void)test_negated_appliedTwice_returnsOriginalValue {
    NSNumber *result = [[@7 negated] negated];
    XCTAssertEqualWithAccuracy([result doubleValue], 7.0, 1e-10);
}

@end
