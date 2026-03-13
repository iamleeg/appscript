// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASSuperNode.h — AST node representing the 'super' pseudo-receiver
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

/// AST node representing the `super` keyword when used as a message receiver.
///
/// `ASSuperNode` is produced by the parser whenever `super` appears as the
/// receiver of a message-send expression. It carries no payload beyond its
/// source location. The interpreter treats it specially: rather than looking
/// up a value in the scope chain, it dispatches the enclosing message send to
/// the superclass of the statically-defining class, while keeping `self` as
/// the actual receiver — matching `objc_msgSendSuper` semantics.
///
/// `super` is not a first-class value; it is a parse error to use it anywhere
/// other than as the direct receiver of a message send, and a parse error to
/// use it inside a block literal.
@interface ASSuperNode : ASASTNode

/// Initializes a super node at the given source location.
///
/// - Parameters:
///   - line: The 1-based source line number where `super` appears.
///   - column: The 1-based source column number where `super` appears.
- (instancetype)initWithLine:(NSUInteger)line
                      column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
