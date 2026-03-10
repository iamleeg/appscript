// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASTestResult.h — Model object representing a single harness test outcome
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

/// Immutable record of one integration-test result produced by the harness runner.
@interface ASTestResult : NSObject

/// The base name of the script file (without extension), used as the display name.
@property (nonatomic, readonly, copy) NSString *testName;

/// Whether the test passed (actual output matched expected output).
@property (nonatomic, readonly, getter=isPassed) BOOL passed;

/// The content of the paired `.expected` file, trimmed of surrounding whitespace.
/// Set to an error description string when the expected file could not be read.
@property (nonatomic, readonly, copy) NSString *expected;

/// The string produced by calling `-description` on the value returned by `-runTests`,
/// trimmed of surrounding whitespace, or an error description string on failure.
@property (nonatomic, readonly, copy) NSString *actual;

/// Designated initialiser.
- (instancetype)initWithTestName:(NSString *)testName
                          passed:(BOOL)passed
                        expected:(NSString *)expected
                          actual:(NSString *)actual NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
