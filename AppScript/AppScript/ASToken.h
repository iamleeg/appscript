// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASToken.h — Token type enum and token class for the AppScript lexer
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

/// The type of a lexical token produced by the AppScript lexer.
typedef NS_ENUM(NSInteger, ASTokenType) {
    // Literals
    /// An NSString literal of the form @"...".
    ASTokenTypeStringLiteral,
    /// An integer or floating-point number literal, e.g. 42 or 3.14.
    ASTokenTypeNumberLiteral,
    /// The boolean keywords YES or NO.
    ASTokenTypeBoolLiteral,
    /// The nil keyword.
    ASTokenTypeNilLiteral,

    // Keywords
    /// The @class keyword.
    ASTokenTypeKwClass,
    /// The @category keyword.
    ASTokenTypeKwCategory,
    /// The @end keyword.
    ASTokenTypeKwEnd,
    /// The @property keyword.
    ASTokenTypeKwProperty,
    /// The id keyword.
    ASTokenTypeKwId,
    /// The weak keyword.
    ASTokenTypeKwWeak,
    /// The constant keyword.
    ASTokenTypeKwConstant,
    /// The return keyword.
    ASTokenTypeKwReturn,
    /// The self keyword.
    ASTokenTypeKwSelf,
    /// The _cmd keyword.
    ASTokenTypeKwCmd,

    // Identifiers
    /// A non-keyword identifier, e.g. a variable or method name.
    ASTokenTypeIdentifier,

    // Punctuation
    /// A bare @ character, used as a prefix for @[...] and @{...}.
    ASTokenTypeAt,
    /// The [ character.
    ASTokenTypeLeftBracket,
    /// The ] character.
    ASTokenTypeRightBracket,
    /// The { character.
    ASTokenTypeLeftBrace,
    /// The } character.
    ASTokenTypeRightBrace,
    /// The ( character.
    ASTokenTypeLeftParen,
    /// The ) character.
    ASTokenTypeRightParen,
    /// The < character.
    ASTokenTypeLeftAngle,
    /// The > character.
    ASTokenTypeRightAngle,
    /// The : character.
    ASTokenTypeColon,
    /// The , character.
    ASTokenTypeComma,
    /// The = character.
    ASTokenTypeEquals,
    /// The + character.
    ASTokenTypePlus,
    /// The - character.
    ASTokenTypeMinus,
    /// The ^ character.
    ASTokenTypeCaret,
    /// The * character.
    ASTokenTypeAsterisk,
    /// A newline character; significant as a statement terminator.
    ASTokenTypeNewline,

    // End of input
    /// A synthetic token marking the end of the token stream.
    ASTokenTypeEOF,
};

/// A single lexical token produced by the AppScript lexer.
///
/// Each token records its type, raw source text, and 1-based source location.
@interface ASToken : NSObject

/// The syntactic category of this token.
@property (nonatomic, readonly) ASTokenType type;

/// The raw source text of this token as it appeared in the input.
@property (nonatomic, readonly, copy) NSString *text;

/// The 1-based line number at which this token begins.
@property (nonatomic, readonly) NSUInteger line;

/// The 1-based column number at which this token begins.
@property (nonatomic, readonly) NSUInteger column;

/// Initializes a token with the given type, source text, and source location.
///
/// - Parameters:
///   - type: The syntactic category of the token.
///   - text: The raw source text of the token.
///   - line: The 1-based line number where the token starts.
///   - column: The 1-based column number where the token starts.
- (instancetype)initWithType:(ASTokenType)type
                        text:(NSString *)text
                        line:(NSUInteger)line
                      column:(NSUInteger)column NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use -initWithType:text:line:column: instead.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
