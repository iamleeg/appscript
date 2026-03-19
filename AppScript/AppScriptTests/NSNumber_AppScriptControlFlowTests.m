// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber_AppScriptControlFlowTests.m — Tests for NSNumber control flow category
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
#import <AppScript/NSNumber+AppScriptControlFlow.h>

@interface NSNumber_AppScriptControlFlowTests : XCTestCase
@end

@implementation NSNumber_AppScriptControlFlowTests

- (void)test_ifTrueIfFalse_receiverIsTrue_executesOnlyTrueBlock {
    __block BOOL trueBlockRan = NO;
    __block BOOL falseBlockRan = NO;
    [@YES ifTrue:^id{ trueBlockRan = YES; return nil; }
         ifFalse:^id{ falseBlockRan = YES; return nil; }];
    XCTAssertTrue(trueBlockRan);
    XCTAssertFalse(falseBlockRan);
}

- (void)test_ifTrueIfFalse_receiverIsFalse_executesOnlyFalseBlock {
    __block BOOL trueBlockRan = NO;
    __block BOOL falseBlockRan = NO;
    [@NO ifTrue:^id{ trueBlockRan = YES; return nil; }
        ifFalse:^id{ falseBlockRan = YES; return nil; }];
    XCTAssertFalse(trueBlockRan);
    XCTAssertTrue(falseBlockRan);
}

- (void)test_ifTrueIfFalse_trueBlockReturnsValue_returnsValue {
    id result = [@YES ifTrue:^id{ return @"hello"; }
                    ifFalse:^id{ return @"world"; }];
    XCTAssertEqualObjects(result, @"hello");
}

- (void)test_ifTrueIfFalse_falseBlockReturnsValue_returnsValue {
    id result = [@NO ifTrue:^id{ return @"hello"; }
                   ifFalse:^id{ return @"world"; }];
    XCTAssertEqualObjects(result, @"world");
}

- (void)test_ifTrueIfFalse_trueBlockIsNil_returnsNil {
    id result = [@YES ifTrue:nil
                    ifFalse:^id{ return @"world"; }];
    XCTAssertNil(result);
}

- (void)test_ifTrueIfFalse_falseBlockIsNil_returnsNil {
    id result = [@NO ifTrue:^id{ return @"hello"; }
                   ifFalse:nil];
    XCTAssertNil(result);
}

@end
