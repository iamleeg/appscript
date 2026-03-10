// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASCategoryDefinitionNode.h — AST node representing a category definition
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

@class ASMethodNode;

NS_ASSUME_NONNULL_BEGIN

/// AST node representing a category definition of the form
/// `@category ClassName (CategoryName)`.
@interface ASCategoryDefinitionNode : ASASTNode

/// The name of the class being extended.
@property (nonatomic, readonly, copy) NSString *className;

/// The name of the category.
@property (nonatomic, readonly, copy) NSString *categoryName;

/// The method definitions added by this category.
@property (nonatomic, readonly, copy) NSArray<ASMethodNode *> *methods;

/// Initializes a category definition node.
///
/// - Parameters:
///   - className: The name of the class being extended.
///   - categoryName: The name of the category.
///   - methods: The method definition nodes added by the category.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithClassName:(NSString *)className
                     categoryName:(NSString *)categoryName
                          methods:(NSArray<ASMethodNode *> *)methods
                             line:(NSUInteger)line
                           column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithClassName:categoryName:methods:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
