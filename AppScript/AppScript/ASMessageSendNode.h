// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASMessageSendNode.h — AST node representing a message send expression
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

/// AST node representing an Objective-C message send expression of the form
/// `[receiver selectorPart1:arg1 selectorPart2:arg2]`.
@interface ASMessageSendNode : ASASTNode

/// The receiver expression.
@property (nonatomic, readonly) ASASTNode *receiver;

/// The keyword parts of the selector, e.g. `@["writeToFile", "atomically"]`.
@property (nonatomic, readonly, copy) NSArray<NSString *> *selectorParts;

/// The argument expressions, parallel to `selectorParts`. Empty for zero-argument sends.
@property (nonatomic, readonly, copy) NSArray<ASASTNode *> *arguments;

/// The full Objective-C selector string assembled from `selectorParts` and `arguments`.
///
/// For zero-argument messages this is simply the single selector part with no colon.
/// For messages with arguments, each part has a colon appended and the parts are
/// concatenated, e.g. `"writeToFile:atomically:"`.
@property (nonatomic, readonly) NSString *selector;

/// Initializes a message send node.
///
/// - Parameters:
///   - receiver: The expression node for the message receiver.
///   - selectorParts: The keyword parts of the selector.
///   - arguments: The argument expression nodes, parallel to `selectorParts`.
///   - line: The 1-based source line number.
///   - column: The 1-based source column number.
- (instancetype)initWithReceiver:(ASASTNode *)receiver
                   selectorParts:(NSArray<NSString *> *)selectorParts
                       arguments:(NSArray<ASASTNode *> *)arguments
                            line:(NSUInteger)line
                          column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithReceiver:selectorParts:arguments:line:column:` instead.
- (instancetype)initWithLine:(NSUInteger)line column:(NSUInteger)column NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
