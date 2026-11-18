// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASExceptionContextTests.m — Tests for ASExceptionContext
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
#import <AppScript/ASExceptionContext.h>

@interface ASExceptionContextTests : XCTestCase
@end

@implementation ASExceptionContextTests

- (void)test_init_exposesAllFields {
    NSString *receiver = @"receiver";
    ASExceptionContext *ctx =
        [[ASExceptionContext alloc] initWithReceiver:receiver
                                            selector:@selector(length)
                                          scriptPath:@"/tmp/a.as"
                                                line:7
                                              locals:@{@"x": @1}
                                     hybridCallStack:@[@"frame0", @"frame1"]
                               crossedScriptBoundary:YES];
    XCTAssertEqual(ctx.receiver, receiver);
    XCTAssertEqual(ctx.selector, @selector(length));
    XCTAssertEqualObjects(ctx.scriptPath, @"/tmp/a.as");
    XCTAssertEqual(ctx.line, (NSUInteger)7);
    XCTAssertEqualObjects(ctx.locals, @{@"x": @1});
    XCTAssertEqualObjects(ctx.hybridCallStack, (@[@"frame0", @"frame1"]));
    XCTAssertTrue(ctx.crossedScriptBoundary);
}

- (void)test_init_copiesMutableInputs {
    NSMutableDictionary *locals = [@{@"x": @1} mutableCopy];
    NSMutableArray *stack = [@[@"a"] mutableCopy];
    ASExceptionContext *ctx =
        [[ASExceptionContext alloc] initWithReceiver:nil selector:NULL scriptPath:nil
                                                line:0 locals:locals hybridCallStack:stack
                               crossedScriptBoundary:NO];
    locals[@"y"] = @2;
    [stack addObject:@"b"];
    XCTAssertEqual(ctx.locals.count, (NSUInteger)1);
    XCTAssertEqual(ctx.hybridCallStack.count, (NSUInteger)1);
}

@end
