// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASClassDefinitionNode.h — AST node representing a class definition
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

@class ASPropertyNode;
@class ASMethodNode;

NS_ASSUME_NONNULL_BEGIN

/// AST node representing a class definition of the form
/// `@class ClassName : SuperclassName <Protocol1, Protocol2>`.
@interface ASClassDefinitionNode : ASASTNode

/// The name of the class being defined.
@property (nonatomic, readonly, copy) NSString *className;

/// The name of the superclass, or `nil` if none is specified.
@property (nonatomic, readonly, copy, nullable) NSString *superclassName;

/// The names of the protocols adopted by this class.
@property (nonatomic, readonly, copy) NSArray<NSString *> *protocolNames;

/// The property declarations in this class definition.
@property (nonatomic, readonly, copy) NSArray<ASPropertyNode *> *properties;

/// The method definitions in this class definition.
@property (nonatomic, readonly, copy) NSArray<ASMethodNode *> *methods;

/// Initializes a class definition node.
///
/// - Parameters:
///   - className: The name of the class.
///   - superclassName: The name of the superclass, or `nil`.
///   - protocolNames: The names of adopted protocols.
///   - properties: The property declaration nodes.
///   - methods: The method definition nodes.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithClassName:(NSString *)className
                   superclassName:(nullable NSString *)superclassName
                    protocolNames:(NSArray<NSString *> *)protocolNames
                       properties:(NSArray<ASPropertyNode *> *)properties
                          methods:(NSArray<ASMethodNode *> *)methods
                             line:(NSUInteger)line
                           column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithClassName:superclassName:protocolNames:properties:methods:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
