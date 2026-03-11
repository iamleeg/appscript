// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASHarnessWindowController.h — Window controller for the AppScriptHarness test runner UI
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Base window controller that builds the test-runner UI programmatically.
///
/// Subclasses (including the AppScript implementation ASHarnessController) override
/// `-runTests:` to discover and run tests, then update `results`, `summaryLabel`,
/// and `runButton` accordingly. The table view data source and delegate are also
/// expected to be implemented by the subclass.
@interface ASHarnessWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

/// The table view displaying test results. Set during -buildUI.
@property (nonatomic, strong) NSTableView *tableView;

/// Label showing the pass/fail summary. Set during -buildUI.
@property (nonatomic, strong) NSTextField *summaryLabel;

/// Button that triggers a test run. Set during -buildUI.
@property (nonatomic, strong) NSButton *runButton;

/// Ordered test results from the most recent run. Updated by -runTests:.
@property (nonatomic, copy) NSArray *results;

/// Executes all integration tests and refreshes the table.
/// The base implementation does nothing; subclasses provide the behaviour.
- (IBAction)runTests:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
