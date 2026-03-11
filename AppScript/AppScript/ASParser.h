// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASParser.h — Parser that converts a token stream into an array of AST nodes
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
#import "ASToken.h"
#import "ASASTNode.h"

NS_ASSUME_NONNULL_BEGIN

/// Error domain used by ASParser when parsing fails.
extern NSString * const ASParserErrorDomain;

/// Error codes used within ASParserErrorDomain.
typedef NS_ENUM(NSInteger, ASParserErrorCode) {
    /// A token was encountered that does not match the expected grammar.
    ASParserErrorUnexpectedToken = 1,
    /// End of input was reached before the grammar was satisfied.
    ASParserErrorUnexpectedEOF = 2,
};

/// Parses a flat token array produced by ASLexer into a list of top-level AST nodes.
///
/// Create an instance and call ``parseTokens:error:`` to parse a token stream
/// previously produced by ``ASLexer``. The parser is stateless between calls;
/// the same instance may be reused.
@interface ASParser : NSObject

/// Parses an AppScript source file represented as a token stream.
///
/// - Parameters:
///   - tokens: The token stream produced by ASLexer, including EOF but excluding comment tokens.
///   - error: On failure, set to a description of the parse error, including the source line and column.
/// - Returns: An array of top-level AST nodes (ASClassDefinitionNode and ASCategoryDefinitionNode),
///            or nil if a parse error occurs.
- (nullable NSArray<ASASTNode *> *)parseTokens:(NSArray<ASToken *> *)tokens
                                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
