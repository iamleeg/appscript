// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASPropertyNode.h — AST node representing a property declaration
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

/// AST node representing a `@property` declaration, including its modifiers.
///
/// Example: `@property (strong, readonly) name` produces a node with
/// `propertyName` equal to `"name"` and `modifiers` equal to `@["strong", "readonly"]`.
@interface ASPropertyNode : ASASTNode

/// The name of the declared property.
@property (nonatomic, readonly, copy) NSString *propertyName;

/// The list of modifier strings applied to the property, e.g. `"strong"`, `"weak"`, `"readonly"`.
@property (nonatomic, readonly, copy) NSArray<NSString *> *modifiers;

/// Initializes a property node with the given name, modifiers, and source location.
///
/// - Parameters:
///   - propertyName: The declared property name.
///   - modifiers: An array of modifier keyword strings.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithPropertyName:(NSString *)propertyName
                           modifiers:(NSArray<NSString *> *)modifiers
                                line:(NSUInteger)line
                              column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithPropertyName:modifiers:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
