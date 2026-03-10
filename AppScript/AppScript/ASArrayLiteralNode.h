// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASArrayLiteralNode.h — AST node representing an array literal
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

#import "ASASTNode.h"

NS_ASSUME_NONNULL_BEGIN

/// AST node representing an Objective-C array literal of the form `@[element1, element2]`.
@interface ASArrayLiteralNode : ASASTNode

/// The expression nodes for the elements of the array literal.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *elements;

/// Initializes an array literal node.
///
/// - Parameters:
///   - elements: The expression nodes for the array elements.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithElements:(NSArray<ASASTNode *> *)elements
                            line:(NSUInteger)line
                          column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithElements:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
