// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppScriptHarnessUITests.m — UI tests for AppScriptHarness
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

@interface AppScriptHarnessUITests : XCTestCase

@end

@implementation AppScriptHarnessUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // UI tests must launch the application that they test.
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testLaunchPerformance {
    // This measures how long it takes to launch your application.
    [self measureWithMetrics:@[[[XCTApplicationLaunchMetric alloc] init]] block:^{
        [[[XCUIApplication alloc] init] launch];
    }];
}

@end
