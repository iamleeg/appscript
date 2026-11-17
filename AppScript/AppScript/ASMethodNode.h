// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASMethodNode.h — AST node representing a method definition
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

/// AST node representing an instance or class method definition.
///
/// The selector is represented as parallel arrays: `selectorParts` holds the
/// keyword portions of the selector and `parameterNames` holds the corresponding
/// variable names. For a zero-argument method, both arrays contain a single
/// element and `parameterNames` is empty.
@interface ASMethodNode : ASASTNode

/// The keyword parts of the selector, e.g. `@["writeToFile", "atomically"]`
/// for the selector `writeToFile:atomically:`.
@property (nonatomic, readonly, copy) NSArray<NSString *> *selectorParts;

/// The parameter variable names, parallel to `selectorParts`.
/// Empty for zero-argument methods.
@property (nonatomic, readonly, copy) NSArray<NSString *> *parameterNames;

/// The statements making up the method body.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *body;

/// `YES` if this is a class method (`+`), `NO` for an instance method (`-`).
@property (nonatomic, readonly) BOOL isClassMethod;

/// The full Objective-C selector string assembled from `selectorParts` and `parameterNames`.
///
/// For zero-argument methods this is simply the single selector part with no colon.
/// For methods with parameters, each part has a colon appended and the parts are
/// concatenated, e.g. `"writeToFile:atomically:"`.
@property (nonatomic, readonly) NSString *selector;

/// Initializes a method node with the given selector, parameters, body, and source location.
///
/// - Parameters:
///   - selectorParts: The keyword parts of the selector.
///   - parameterNames: The parameter variable names, parallel to `selectorParts`.
///   - body: The list of statement nodes in the method body.
///   - isClassMethod: `YES` for a class method, `NO` for an instance method.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithSelectorParts:(NSArray<NSString *> *)selectorParts
                       parameterNames:(NSArray<NSString *> *)parameterNames
                                 body:(NSArray<ASASTNode *> *)body
                        isClassMethod:(BOOL)isClassMethod
                                 line:(NSUInteger)line
                               column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithSelectorParts:parameterNames:body:isClassMethod:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
