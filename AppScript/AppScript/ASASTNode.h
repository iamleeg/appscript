// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASASTNode.h — Base class for all AppScript AST nodes
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Abstract base class for all nodes in the AppScript abstract syntax tree.
///
/// Every node records its source location so that diagnostics and error messages
/// can point back to the original script text.
@interface ASASTNode : NSObject

/// The 1-based line number at which this node begins in the source.
@property (nonatomic, readonly) NSUInteger lineNumber;

/// The 1-based column number at which this node begins in the source.
@property (nonatomic, readonly) NSUInteger columnNumber;

/// Initializes a node with the given source location.
///
/// - Parameters:
///   - line: The 1-based line number of the node's start position.
///   - column: The 1-based column number of the node's start position.
- (instancetype)initWithLine:(NSUInteger)line
                      column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use `-initWithLine:column:` instead.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
