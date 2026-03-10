// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASDictionaryLiteralNode.h — AST node representing a dictionary literal
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

/// AST node representing an Objective-C dictionary literal of the form `@{ key: value, ... }`.
///
/// The `keys` and `values` arrays are parallel: `keys[i]` is the key expression
/// corresponding to `values[i]`.
@interface ASDictionaryLiteralNode : ASASTNode

/// The key expression nodes. Parallel to `values`.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *keys;

/// The value expression nodes. Parallel to `keys`.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *values;

/// Initializes a dictionary literal node.
///
/// - Parameters:
///   - keys: The key expression nodes.
///   - values: The value expression nodes, parallel to `keys`.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithKeys:(NSArray<ASASTNode *> *)keys
                      values:(NSArray<ASASTNode *> *)values
                        line:(NSUInteger)line
                      column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithKeys:values:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
