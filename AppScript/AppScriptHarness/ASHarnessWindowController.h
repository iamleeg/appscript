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

/// Window controller that presents the integration-test results in a table view.
///
/// The window contains a table with four columns (status indicator, test name,
/// expected output, actual output), a Run button to (re-)execute the test suite,
/// and a summary label showing the pass/fail counts.
///
/// Create one instance at application launch and call `-showWindow:` to display it.
/// Invoke `-runTests` to execute the test suite; the UI updates when the run completes.
@interface ASHarnessWindowController : NSWindowController

/// Executes all integration tests found in the app bundle and refreshes the table.
///
/// Loads AppScript files from the bundle (if not already loaded), discovers every
/// `.as` script in the `Scripts` subdirectory, instantiates the corresponding `*Test`
/// class, calls `-runTests`, and compares the result to the paired `.expected` file.
- (IBAction)runTests:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
