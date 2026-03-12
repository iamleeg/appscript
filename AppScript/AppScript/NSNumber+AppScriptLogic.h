// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptLogic.h — Logical operators on NSNumber
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

/// Logical (boolean) operators on NSNumber, treating the receiver and arguments as boolean values.
///
/// Truthiness follows the same rule used throughout the AppScript runtime: any NSNumber whose
/// `-boolValue` is `YES` is considered true; any NSNumber whose `-boolValue` is `NO` is false.
/// All methods return `@YES` or `@NO`.
@interface NSNumber (AppScriptLogic)

/// Returns `@YES` if both the receiver and other are true; `@NO` otherwise.
///
/// Both operands are evaluated eagerly before the method is called.
/// Use `-[NSNumber ifTrue:ifFalse:]` when short-circuit behaviour is required.
- (NSNumber *)and:(NSNumber *)other;

/// Returns `@YES` if the receiver, other, or both are true; `@NO` if both are false.
///
/// Both operands are evaluated eagerly before the method is called.
/// Use `-[NSNumber ifTrue:ifFalse:]` when short-circuit behaviour is required.
- (NSNumber *)or:(NSNumber *)other;

/// Returns `@YES` if the receiver is false; `@NO` if the receiver is true.
- (NSNumber *)not;

@end

NS_ASSUME_NONNULL_END
