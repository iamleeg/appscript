// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASNumberLiteralNode.h — AST node representing a numeric literal
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

#import <AppScript/ASASTNode.h>

NS_ASSUME_NONNULL_BEGIN

/// AST node representing a numeric literal, either integer or floating-point.
@interface ASNumberLiteralNode : ASASTNode

/// The numeric value represented by this literal, boxed as an `NSNumber`.
@property (nonatomic, readonly, copy) NSNumber *value;

/// Initializes a numeric literal node.
///
/// - Parameters:
///   - value: The numeric value of the literal.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithValue:(NSNumber *)value
                         line:(NSUInteger)line
                       column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithValue:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
