// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASAssignmentNode.h — AST node representing a variable reassignment
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

/// AST node representing a reassignment to an already-declared variable,
/// of the form `name = expr`.
@interface ASAssignmentNode : ASASTNode

/// The name of the variable being reassigned.
@property (nonatomic, readonly, copy) NSString *variableName;

/// The expression whose value is assigned to the variable.
@property (nonatomic, readonly) ASASTNode *value;

/// Initializes an assignment node.
///
/// - Parameters:
///   - variableName: The name of the target variable.
///   - value: The expression node providing the new value.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithVariableName:(NSString *)variableName
                               value:(ASASTNode *)value
                                line:(NSUInteger)line
                              column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithVariableName:value:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
