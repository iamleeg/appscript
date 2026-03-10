// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASVariableDeclarationNode.h — AST node representing a variable declaration
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

/// AST node representing a variable declaration, optionally with an initializer expression.
///
/// Covers `id name = expr`, `weak id name = expr`, and `constant id name = expr` forms.
@interface ASVariableDeclarationNode : ASASTNode

/// The name of the declared variable.
@property (nonatomic, readonly, copy) NSString *variableName;

/// The initializer expression, or `nil` if the variable is declared without one.
@property (nonatomic, readonly, nullable) ASASTNode *initializer;

/// `YES` if the variable is declared with weak ownership semantics.
@property (nonatomic, readonly) BOOL isWeak;

/// `YES` if the variable is declared as a constant (immutable binding).
@property (nonatomic, readonly) BOOL isConstant;

/// Initializes a variable declaration node.
///
/// - Parameters:
///   - variableName: The name of the variable.
///   - initializer: The initializer expression node, or `nil`.
///   - isWeak: `YES` for a weak variable.
///   - isConstant: `YES` for a constant binding.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithVariableName:(NSString *)variableName
                         initializer:(nullable ASASTNode *)initializer
                              isWeak:(BOOL)isWeak
                          isConstant:(BOOL)isConstant
                                line:(NSUInteger)line
                              column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithVariableName:initializer:isWeak:isConstant:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
