// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppDelegate.h — AppScriptHarness application delegate
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
#import <AppScript/NSBundle+AppScriptLoading.h>

NS_ASSUME_NONNULL_BEGIN

/// Application delegate for the AppScriptHarness integration test runner.
///
/// Loads all `.as` test scripts from the app bundle, runs each test class,
/// compares results to `.expected` files, then exits with code 0 (all pass)
/// or 1 (any failure).
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

NS_ASSUME_NONNULL_END
