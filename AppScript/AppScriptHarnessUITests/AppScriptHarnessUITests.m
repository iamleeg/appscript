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
    self.continueAfterFailure = NO;
    [[[XCUIApplication alloc] init] launch];
}

- (void)testAllScriptTestsPass {
    XCUIApplication *app = [[XCUIApplication alloc] init];

    XCUIElement *runButton = app.buttons[@"Run Tests"];
    XCTAssertTrue([runButton waitForExistenceWithTimeout:5], @"Run Tests button should exist");
    [runButton click];

    // Wait for the summary label to reflect a completed run (it won't contain "Running…").
    NSPredicate *finishedPredicate = [NSPredicate predicateWithFormat:
                                      @"value CONTAINS 'passed'"];
    XCUIElement *summaryLabel = app.staticTexts.firstMatch;
    [self expectationForPredicate:finishedPredicate evaluatedWithObject:summaryLabel handler:nil];
    [self waitForExpectationsWithTimeout:30 handler:nil];

    // Find the summary label that contains "passed" (the result label, not a column header).
    XCUIElement *resultLabel = nil;
    for (XCUIElement *label in app.staticTexts.allElementsBoundByIndex) {
        if ([label.value isKindOfClass:[NSString class]] &&
            [(NSString *)label.value containsString:@"passed"]) {
            resultLabel = label;
            break;
        }
    }
    XCTAssertNotNil(resultLabel, @"A summary label showing pass/fail counts should exist");

    NSString *summary = (NSString *)resultLabel.value;
    XCTAssertTrue([summary containsString:@"0 failed"],
                  @"Summary should report 0 failed, got: %@", summary);
    XCTAssertFalse([summary containsString:@"0 passed"],
                   @"Summary should not report 0 passed, got: %@", summary);

    // Verify there is at least one row in the results table.
    XCUIElement *table = app.tables.firstMatch;
    XCTAssertTrue(table.cells.count > 0, @"Results table should contain at least one row");
}

@end
