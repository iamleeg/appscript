// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber_AppScriptLogicTests.m — Tests for NSNumber logical operator category
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
#import "NSNumber+AppScriptLogic.h"

@interface NSNumber_AppScriptLogicTests : XCTestCase
@end

@implementation NSNumber_AppScriptLogicTests

// MARK: - and:

- (void)test_and_trueAndTrue_returnsTrue {
    XCTAssertEqualObjects([@YES and:@YES], @YES);
}

- (void)test_and_trueAndFalse_returnsFalse {
    XCTAssertEqualObjects([@YES and:@NO], @NO);
}

- (void)test_and_falseAndTrue_returnsFalse {
    XCTAssertEqualObjects([@NO and:@YES], @NO);
}

- (void)test_and_falseAndFalse_returnsFalse {
    XCTAssertEqualObjects([@NO and:@NO], @NO);
}

- (void)test_and_nonZeroNumberAndTrue_returnsTrue {
    XCTAssertEqualObjects([@42 and:@YES], @YES);
}

- (void)test_and_zeroAndTrue_returnsFalse {
    XCTAssertEqualObjects([@0 and:@YES], @NO);
}

// MARK: - or:

- (void)test_or_trueOrTrue_returnsTrue {
    XCTAssertEqualObjects([@YES or:@YES], @YES);
}

- (void)test_or_trueOrFalse_returnsTrue {
    XCTAssertEqualObjects([@YES or:@NO], @YES);
}

- (void)test_or_falseOrTrue_returnsTrue {
    XCTAssertEqualObjects([@NO or:@YES], @YES);
}

- (void)test_or_falseOrFalse_returnsFalse {
    XCTAssertEqualObjects([@NO or:@NO], @NO);
}

- (void)test_or_zeroOrZero_returnsFalse {
    XCTAssertEqualObjects([@0 or:@0], @NO);
}

- (void)test_or_nonZeroOrZero_returnsTrue {
    XCTAssertEqualObjects([@1 or:@0], @YES);
}

// MARK: - not

- (void)test_not_true_returnsFalse {
    XCTAssertEqualObjects([@YES not], @NO);
}

- (void)test_not_false_returnsTrue {
    XCTAssertEqualObjects([@NO not], @YES);
}

- (void)test_not_nonZeroNumber_returnsFalse {
    XCTAssertEqualObjects([@42 not], @NO);
}

- (void)test_not_zero_returnsTrue {
    XCTAssertEqualObjects([@0 not], @YES);
}

- (void)test_not_appliedTwice_returnsOriginal {
    XCTAssertEqualObjects([[@YES not] not], @YES);
    XCTAssertEqualObjects([[@NO not] not], @NO);
}

// MARK: - Combined

- (void)test_notAndOr_demorgan_firstLaw {
    // NOT (A OR B) == (NOT A) AND (NOT B)
    NSNumber *a = @YES;
    NSNumber *b = @NO;
    NSNumber *lhs = [[a or:b] not];
    NSNumber *rhs = [[a not] and:[b not]];
    XCTAssertEqualObjects(lhs, rhs);
}

- (void)test_notAndOr_demorgan_secondLaw {
    // NOT (A AND B) == (NOT A) OR (NOT B)
    NSNumber *a = @YES;
    NSNumber *b = @NO;
    NSNumber *lhs = [[a and:b] not];
    NSNumber *rhs = [[a not] or:[b not]];
    XCTAssertEqualObjects(lhs, rhs);
}

@end
