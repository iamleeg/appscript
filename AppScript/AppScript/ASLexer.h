// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLexer.h — Tokenizer that converts AppScript source text into an array of tokens
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

NS_ASSUME_NONNULL_BEGIN

/// Error domain used by ASLexer when tokenization fails.
extern NSString * const ASLexerErrorDomain;

/// Error codes used within ASLexerErrorDomain.
typedef NS_ENUM(NSInteger, ASLexerErrorCode) {
    /// An @"..." string literal was opened but never closed before end of input.
    ASLexerErrorUnterminatedStringLiteral = 1,
    /// A character was encountered that does not belong to any valid token.
    ASLexerErrorUnexpectedCharacter = 2,
};

/// Tokenizes AppScript source text into a flat array of ``ASToken`` objects.
///
/// Create an instance and call ``tokenize:error:`` to lex a source string.
/// The lexer is stateless between calls; the same instance may be reused.
@interface ASLexer : NSObject

/// Tokenizes the given AppScript source string.
///
/// The returned array always ends with an ``ASTokenType/ASTokenTypeEOF`` token.
/// Newlines are emitted as ``ASTokenType/ASTokenTypeNewline`` tokens and serve as
/// statement terminators; consecutive blank lines collapse to a single
/// newline token. Single-line comments introduced by `//` are discarded
/// and replaced by a single newline token for the line on which they appear.
///
/// - Parameters:
///   - source: The AppScript source text to tokenize.
///   - error: On failure, set to an NSError in ``ASLexerErrorDomain``.
/// - Returns: An array of ``ASToken`` objects, or nil if a lexical error occurred.
- (nullable NSArray<ASToken *> *)tokenize:(NSString *)source error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
