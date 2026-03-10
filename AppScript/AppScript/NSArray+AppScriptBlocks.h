// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSArray+AppScriptBlocks.h — NSArray helpers for AppScript block integration
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

/// NSArray helpers that bridge AppScript block conventions (all `id` parameters
/// and `id` return values) to Foundation APIs that require specific C-primitive
/// return types.
///
/// AppScript blocks always return `id`.  Foundation's `sortedArrayUsingComparator:`
/// requires a block returning `NSComparisonResult` (an `NSInteger`).  This category
/// provides an adaptor so AppScript code can perform comparison-based sorting by
/// returning an `NSNumber` wrapping the comparison result from the comparator block.
@interface NSArray (AppScriptBlocks)

/// Returns the array sorted by the given comparator block.
///
/// The comparator block receives two elements and must return an `NSNumber`
/// wrapping an `NSComparisonResult` value: a negative number (e.g. `@(-1)`) for
/// ascending order, `@0` for equal elements, or a positive number (e.g. `@1`) for
/// descending order.  In AppScript, pass the result of `[a compare:b]` directly.
///
/// - Parameter comparatorBlock: A two-argument block returning `NSNumber`.
/// - Returns: A new array sorted according to the comparator.
- (NSArray *)as_sortedArrayUsingBlock:(id (^)(id, id))comparatorBlock;

@end

NS_ASSUME_NONNULL_END
