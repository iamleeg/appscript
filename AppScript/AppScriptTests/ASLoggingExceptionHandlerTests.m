// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLoggingExceptionHandlerTests.m — Tests for ASLoggingExceptionHandler
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
#import <AppScript/ASLoggingExceptionHandler.h>

@interface ASLoggingExceptionHandlerTests : XCTestCase
@end

@implementation ASLoggingExceptionHandlerTests

- (ASExceptionContext *)contextWithPath:(NSString *)path line:(NSUInteger)line {
    return [[ASExceptionContext alloc] initWithReceiver:nil selector:NULL scriptPath:path
                                                   line:line locals:@{} hybridCallStack:@[]
                                  crossedScriptBoundary:NO];
}

- (void)test_handleException_returnsReraise {
    ASLoggingExceptionHandler *handler = [[ASLoggingExceptionHandler alloc] init];
    NSException *ex = [NSException exceptionWithName:@"Boom" reason:@"bang" userInfo:nil];
    XCTAssertEqual([handler handleException:ex context:[self contextWithPath:@"a.as" line:1]],
                   ASExceptionDispositionReraise);
}

- (void)test_summary_containsNameMessageAndLocation {
    NSException *ex = [NSException exceptionWithName:@"Boom" reason:@"bang" userInfo:nil];
    NSString *s = [ASLoggingExceptionHandler summaryForException:ex
                                                         context:[self contextWithPath:@"/x/a.as" line:12]];
    XCTAssertEqualObjects(s, @"AppScript exception Boom: bang (/x/a.as:12)");
}

- (void)test_summary_toleratesMissingReasonAndPath {
    NSException *ex = [NSException exceptionWithName:@"Boom" reason:nil userInfo:nil];
    NSString *s = [ASLoggingExceptionHandler summaryForException:ex
                                                         context:[self contextWithPath:nil line:0]];
    XCTAssertEqualObjects(s, @"AppScript exception Boom: (no reason) ((unknown script):0)");
}

@end
