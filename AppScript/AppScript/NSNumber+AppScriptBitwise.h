// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptBitwise.h — Bitwise operators on NSNumber
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

/// Bitwise operators on NSNumber, operating on the integer representation of the receiver.
///
/// All methods use the `NSUInteger` representation of each operand so that
/// `bitwiseNot` produces the expected unsigned complement rather than a
/// sign-extended negative value.  The result is always returned as an
/// `NSNumber` wrapping an `NSUInteger`.
@interface NSNumber (AppScriptBitwise)

/// Returns a new NSNumber whose value is the bitwise OR of the receiver and other.
- (NSNumber *)bitwiseOr:(NSNumber *)other;

/// Returns a new NSNumber whose value is the bitwise AND of the receiver and other.
- (NSNumber *)bitwiseAnd:(NSNumber *)other;

/// Returns a new NSNumber whose value is the bitwise XOR of the receiver and other.
- (NSNumber *)bitwiseXor:(NSNumber *)other;

/// Returns a new NSNumber whose value is the bitwise NOT (one's complement) of the receiver.
- (NSNumber *)bitwiseNot;

@end

NS_ASSUME_NONNULL_END
