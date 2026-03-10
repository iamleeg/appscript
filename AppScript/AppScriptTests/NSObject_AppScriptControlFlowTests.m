// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSObject_AppScriptControlFlowTests.m — Tests for NSObject control flow category
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
#import "NSObject+AppScriptControlFlow.h"

@interface NSObject_AppScriptControlFlowTests : XCTestCase
@end

@implementation NSObject_AppScriptControlFlowTests

- (void)test_doWhile_conditionAlwaysFalse_neverRunsBlock {
    __block NSInteger callCount = 0;
    id result = [NSObject.new do:^id{ callCount++; return nil; }
                           while:^id{ return @NO; }];
    XCTAssertEqual(callCount, 0);
    XCTAssertNil(result);
}

- (void)test_doWhile_conditionTrueOnce_runsBlockOnce {
    __block NSInteger callCount = 0;
    __block NSInteger conditionCallCount = 0;
    id result = [NSObject.new do:^id{ callCount++; return nil; }
                           while:^id{
                               conditionCallCount++;
                               return conditionCallCount == 1 ? @YES : @NO;
                           }];
    XCTAssertEqual(callCount, 1);
    XCTAssertNil(result);
}

- (void)test_doWhile_countsDown_runsCorrectNumberOfTimes {
    __block NSInteger counter = 3;
    __block NSInteger blockCallCount = 0;
    [NSObject.new do:^id{ blockCallCount++; return nil; }
               while:^id{
                   return counter-- > 0 ? @YES : @NO;
               }];
    XCTAssertEqual(blockCallCount, 3);
}

- (void)test_doWhile_returnsLastBlockResult {
    __block NSInteger counter = 3;
    __block NSInteger blockValue = 0;
    id result = [NSObject.new do:^id{
                                   blockValue++;
                                   return @(blockValue);
                               }
                           while:^id{
                               return counter-- > 0 ? @YES : @NO;
                           }];
    XCTAssertEqualObjects(result, @3);
}

- (void)test_doUntil_alwaysRunsOnce {
    __block NSInteger callCount = 0;
    [NSObject.new do:^id{ callCount++; return nil; }
               until:^id{ return @YES; }];
    XCTAssertEqual(callCount, 1);
}

- (void)test_doUntil_runsUntilConditionMet {
    __block NSInteger counter = 0;
    [NSObject.new do:^id{ counter++; return nil; }
               until:^id{ return counter >= 3 ? @YES : @NO; }];
    XCTAssertEqual(counter, 3);
}

- (void)test_doUntil_returnsLastBlockResult {
    __block NSInteger counter = 0;
    id result = [NSObject.new do:^id{
                                    counter++;
                                    return @(counter);
                                }
                            until:^id{ return counter >= 3 ? @YES : @NO; }];
    XCTAssertEqualObjects(result, @3);
}

@end
