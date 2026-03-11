// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASTestRunner.h — Discovers and executes AppScript integration tests
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Discovers every subclass of ASTestCase registered in the Objective-C runtime,
/// runs each one, and returns an array of ASTestResult objects.
///
/// This class encapsulates all C-level runtime introspection so that the caller
/// (which may be implemented in AppScript) only needs to send messages.
@interface ASTestRunner : NSObject

/// Runs all discovered ASTestCase subclasses and returns an NSArray of ASTestResult objects.
/// Results are logged to stdout as they complete. The array is unsorted.
- (NSArray *)runAllTests;

@end

NS_ASSUME_NONNULL_END
