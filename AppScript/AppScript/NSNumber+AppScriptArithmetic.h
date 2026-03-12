// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptArithmetic.h — Arithmetic operations on NSNumber
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

/// Arithmetic operations on NSNumber, using double-precision floating-point arithmetic.
@interface NSNumber (AppScriptArithmetic)

/// Returns a new NSNumber whose value is the sum of the receiver and other.
- (NSNumber *)numberByAdding:(NSNumber *)other;

/// Returns a new NSNumber whose value is the receiver minus other.
- (NSNumber *)numberBySubtracting:(NSNumber *)other;

/// Returns a new NSNumber whose value is the receiver multiplied by other.
- (NSNumber *)numberByMultiplyingBy:(NSNumber *)other;

/// Returns a new NSNumber whose value is the receiver divided by other.
/// If other is zero, returns an NSNumber wrapping positive infinity.
- (NSNumber *)numberByDividingBy:(NSNumber *)other;

/// Returns a new NSNumber whose value is the arithmetic negation of the receiver.
- (NSNumber *)negated;

@end

NS_ASSUME_NONNULL_END
