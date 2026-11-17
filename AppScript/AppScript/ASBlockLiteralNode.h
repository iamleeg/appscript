// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockLiteralNode.h — AST node representing a block literal expression
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

/// AST node representing a block literal, e.g. `^{ ... }` or `^(param1, param2) { ... }`.
@interface ASBlockLiteralNode : ASASTNode

/// The parameter names declared for this block. Empty for a zero-argument block.
@property (nonatomic, readonly, copy) NSArray<NSString *> *parameterNames;

/// The statements making up the block body.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *body;

/// Initializes a block literal node.
///
/// - Parameters:
///   - parameterNames: The parameter names for the block.
///   - body: The list of statement nodes in the block body.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithParameterNames:(NSArray<NSString *> *)parameterNames
                                  body:(NSArray<ASASTNode *> *)body
                                  line:(NSUInteger)line
                                column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithParameterNames:body:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
