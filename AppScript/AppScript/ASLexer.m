// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLexer.m — Tokenizer that converts AppScript source text into an array of tokens
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

#import "ASLexer.h"

NSString * const ASLexerErrorDomain = @"ASLexerErrorDomain";

// ---------------------------------------------------------------------------
// Internal helper: mutable scanning state
// ---------------------------------------------------------------------------

@interface ASLexerState : NSObject

@property (nonatomic, readonly) NSString *source;
@property (nonatomic) NSUInteger pos;       // current character index
@property (nonatomic) NSUInteger line;      // current 1-based line
@property (nonatomic) NSUInteger column;    // current 1-based column
@property (nonatomic, readonly) NSUInteger length;

- (instancetype)initWithSource:(NSString *)source NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Returns the character at the current position, or 0 if at end.
- (unichar)current;
/// Returns the character one position ahead, or 0 if out of range.
- (unichar)peek;
/// Advances position by one, updating line/column tracking.
- (void)advance;
/// Returns YES if the current position is past the end of the source.
- (BOOL)isAtEnd;

@end

@implementation ASLexerState

- (instancetype)initWithSource:(NSString *)source {
    self = [super init];
    if (self) {
        _source = source;
        _pos = 0;
        _line = 1;
        _column = 1;
        _length = source.length;
    }
    return self;
}

- (unichar)current {
    if (_pos >= _length) { return 0; }
    return [_source characterAtIndex:_pos];
}

- (unichar)peek {
    if (_pos + 1 >= _length) { return 0; }
    return [_source characterAtIndex:_pos + 1];
}

- (void)advance {
    if (_pos >= _length) { return; }
    unichar ch = [_source characterAtIndex:_pos];
    _pos++;
    if (ch == '\n') {
        _line++;
        _column = 1;
    } else {
        _column++;
    }
}

- (BOOL)isAtEnd {
    return _pos >= _length;
}

@end

// ---------------------------------------------------------------------------
// ASLexer implementation
// ---------------------------------------------------------------------------

@implementation ASLexer

- (nullable NSArray<ASToken *> *)tokenize:(NSString *)source error:(NSError **)error {
    ASLexerState *state = [[ASLexerState alloc] initWithSource:source];
    NSMutableArray<ASToken *> *tokens = [NSMutableArray array];

    // Track whether the last emitted significant token was a newline, so we
    // can collapse consecutive newline tokens.
    BOOL lastWasNewline = NO;

    while (![state isAtEnd]) {
        unichar ch = [state current];

        // --- Skip spaces and tabs ---
        if (ch == ' ' || ch == '\t') {
            [state advance];
            continue;
        }

        // --- Newline ---
        if (ch == '\n') {
            NSUInteger newlineLine = state.line;
            NSUInteger newlineCol = state.column;
            [state advance];
            if (!lastWasNewline) {
                ASToken *tok = [[ASToken alloc] initWithType:ASTokenTypeNewline
                                                        text:@"\n"
                                                        line:newlineLine
                                                      column:newlineCol];
                [tokens addObject:tok];
                lastWasNewline = YES;
            }
            // Blank lines: keep collapsing
            continue;
        }

        // --- Single-line comment: // ---
        if (ch == '/' && [state peek] == '/') {
            NSUInteger commentLine = state.line;
            // Consume through end of line (or end of input)
            while (![state isAtEnd] && [state current] != '\n') {
                [state advance];
            }
            // Consume the newline itself, if present
            if (![state isAtEnd] && [state current] == '\n') {
                [state advance];
            }
            // Emit one newline token for this line (collapse if previous was also newline)
            if (!lastWasNewline) {
                ASToken *tok = [[ASToken alloc] initWithType:ASTokenTypeNewline
                                                        text:@"\n"
                                                        line:commentLine
                                                      column:1];
                [tokens addObject:tok];
                lastWasNewline = YES;
            }
            continue;
        }

        // --- @ prefix tokens ---
        if (ch == '@') {
            NSUInteger tokLine = state.line;
            NSUInteger tokCol = state.column;
            unichar next = [state peek];

            // @" — string literal
            if (next == '"') {
                [state advance]; // consume @
                [state advance]; // consume "
                NSMutableString *literal = [NSMutableString stringWithString:@"@\""];
                BOOL terminated = NO;
                while (![state isAtEnd]) {
                    unichar sc = [state current];
                    if (sc == '\\') {
                        // Escape sequence: consume both \ and the next char
                        [literal appendFormat:@"%C", sc];
                        [state advance];
                        if (![state isAtEnd]) {
                            [literal appendFormat:@"%C", [state current]];
                            [state advance];
                        }
                    } else if (sc == '"') {
                        [literal appendString:@"\""];
                        [state advance];
                        terminated = YES;
                        break;
                    } else {
                        [literal appendFormat:@"%C", sc];
                        [state advance];
                    }
                }
                if (!terminated) {
                    if (error) {
                        *error = [NSError errorWithDomain:ASLexerErrorDomain
                                                     code:ASLexerErrorUnterminatedStringLiteral
                                                 userInfo:@{
                            NSLocalizedDescriptionKey: @"Unterminated string literal",
                            @"line": @(tokLine),
                            @"column": @(tokCol),
                        }];
                    }
                    return nil;
                }
                ASToken *tok = [[ASToken alloc] initWithType:ASTokenTypeStringLiteral
                                                        text:literal
                                                        line:tokLine
                                                      column:tokCol];
                [tokens addObject:tok];
                lastWasNewline = NO;
                continue;
            }

            // @[ — emit @ then [
            if (next == '[') {
                [state advance]; // consume @
                ASToken *atTok = [[ASToken alloc] initWithType:ASTokenTypeAt
                                                          text:@"@"
                                                          line:tokLine
                                                        column:tokCol];
                [tokens addObject:atTok];
                NSUInteger bracketLine = state.line;
                NSUInteger bracketCol = state.column;
                [state advance]; // consume [
                ASToken *bracketTok = [[ASToken alloc] initWithType:ASTokenTypeLeftBracket
                                                               text:@"["
                                                               line:bracketLine
                                                             column:bracketCol];
                [tokens addObject:bracketTok];
                lastWasNewline = NO;
                continue;
            }

            // @{ — emit @ then {
            if (next == '{') {
                [state advance]; // consume @
                ASToken *atTok = [[ASToken alloc] initWithType:ASTokenTypeAt
                                                          text:@"@"
                                                          line:tokLine
                                                        column:tokCol];
                [tokens addObject:atTok];
                NSUInteger braceLine = state.line;
                NSUInteger braceCol = state.column;
                [state advance]; // consume {
                ASToken *braceTok = [[ASToken alloc] initWithType:ASTokenTypeLeftBrace
                                                             text:@"{"
                                                             line:braceLine
                                                           column:braceCol];
                [tokens addObject:braceTok];
                lastWasNewline = NO;
                continue;
            }

            // @word keywords
            if (next != 0 && (isalpha(next) || next == '_')) {
                [state advance]; // consume @
                // Collect the word following @
                NSMutableString *word = [NSMutableString string];
                while (![state isAtEnd]) {
                    unichar wc = [state current];
                    if (isalnum(wc) || wc == '_') {
                        [word appendFormat:@"%C", wc];
                        [state advance];
                    } else {
                        break;
                    }
                }
                NSString *atWord = [@"@" stringByAppendingString:word];
                ASTokenType kwType;
                BOOL isKeyword = YES;
                if ([word isEqualToString:@"class"]) {
                    kwType = ASTokenTypeKwClass;
                } else if ([word isEqualToString:@"category"]) {
                    kwType = ASTokenTypeKwCategory;
                } else if ([word isEqualToString:@"end"]) {
                    kwType = ASTokenTypeKwEnd;
                } else if ([word isEqualToString:@"property"]) {
                    kwType = ASTokenTypeKwProperty;
                } else {
                    isKeyword = NO;
                }

                if (isKeyword) {
                    ASToken *tok = [[ASToken alloc] initWithType:kwType
                                                            text:atWord
                                                            line:tokLine
                                                          column:tokCol];
                    [tokens addObject:tok];
                } else {
                    // Emit bare @ then identifier
                    ASToken *atTok = [[ASToken alloc] initWithType:ASTokenTypeAt
                                                              text:@"@"
                                                              line:tokLine
                                                            column:tokCol];
                    [tokens addObject:atTok];
                    // The word starts right after @; column offset by 1
                    ASToken *idTok = [[ASToken alloc] initWithType:ASTokenTypeIdentifier
                                                              text:word
                                                              line:tokLine
                                                            column:tokCol + 1];
                    [tokens addObject:idTok];
                }
                lastWasNewline = NO;
                continue;
            }

            // Bare @ with nothing useful following
            [state advance]; // consume @
            ASToken *atTok = [[ASToken alloc] initWithType:ASTokenTypeAt
                                                      text:@"@"
                                                      line:tokLine
                                                    column:tokCol];
            [tokens addObject:atTok];
            lastWasNewline = NO;
            continue;
        }

        // --- Number literals ---
        if (isdigit(ch)) {
            NSUInteger tokLine = state.line;
            NSUInteger tokCol = state.column;
            NSMutableString *num = [NSMutableString string];
            BOOL seenDot = NO;
            while (![state isAtEnd]) {
                unichar nc = [state current];
                if (isdigit(nc)) {
                    [num appendFormat:@"%C", nc];
                    [state advance];
                } else if (nc == '.' && !seenDot) {
                    seenDot = YES;
                    [num appendFormat:@"%C", nc];
                    [state advance];
                } else {
                    break;
                }
            }
            ASToken *tok = [[ASToken alloc] initWithType:ASTokenTypeNumberLiteral
                                                    text:num
                                                    line:tokLine
                                                  column:tokCol];
            [tokens addObject:tok];
            lastWasNewline = NO;
            continue;
        }

        // --- Identifiers and keywords ---
        if (isalpha(ch) || ch == '_') {
            NSUInteger tokLine = state.line;
            NSUInteger tokCol = state.column;
            NSMutableString *ident = [NSMutableString string];
            while (![state isAtEnd]) {
                unichar ic = [state current];
                if (isalnum(ic) || ic == '_') {
                    [ident appendFormat:@"%C", ic];
                    [state advance];
                } else {
                    break;
                }
            }
            ASTokenType identType;
            if ([ident isEqualToString:@"YES"] || [ident isEqualToString:@"NO"]) {
                identType = ASTokenTypeBoolLiteral;
            } else if ([ident isEqualToString:@"nil"]) {
                identType = ASTokenTypeNilLiteral;
            } else if ([ident isEqualToString:@"id"]) {
                identType = ASTokenTypeKwId;
            } else if ([ident isEqualToString:@"weak"]) {
                identType = ASTokenTypeKwWeak;
            } else if ([ident isEqualToString:@"constant"]) {
                identType = ASTokenTypeKwConstant;
            } else if ([ident isEqualToString:@"return"]) {
                identType = ASTokenTypeKwReturn;
            } else if ([ident isEqualToString:@"self"]) {
                identType = ASTokenTypeKwSelf;
            } else if ([ident isEqualToString:@"_cmd"]) {
                identType = ASTokenTypeKwCmd;
            } else {
                identType = ASTokenTypeIdentifier;
            }
            ASToken *tok = [[ASToken alloc] initWithType:identType
                                                    text:ident
                                                    line:tokLine
                                                  column:tokCol];
            [tokens addObject:tok];
            lastWasNewline = NO;
            continue;
        }

        // --- Single-character punctuation ---
        {
            NSUInteger tokLine = state.line;
            NSUInteger tokCol = state.column;
            ASTokenType punctType;
            NSString *punctText = [NSString stringWithCharacters:&ch length:1];
            BOOL recognised = YES;
            switch (ch) {
                case '[': punctType = ASTokenTypeLeftBracket;  break;
                case ']': punctType = ASTokenTypeRightBracket; break;
                case '{': punctType = ASTokenTypeLeftBrace;    break;
                case '}': punctType = ASTokenTypeRightBrace;   break;
                case '(': punctType = ASTokenTypeLeftParen;    break;
                case ')': punctType = ASTokenTypeRightParen;   break;
                case '<': punctType = ASTokenTypeLeftAngle;    break;
                case '>': punctType = ASTokenTypeRightAngle;   break;
                case ':': punctType = ASTokenTypeColon;        break;
                case ',': punctType = ASTokenTypeComma;        break;
                case '=': punctType = ASTokenTypeEquals;       break;
                case '+': punctType = ASTokenTypePlus;         break;
                case '-': punctType = ASTokenTypeMinus;        break;
                case '^': punctType = ASTokenTypeCaret;        break;
                case '*': punctType = ASTokenTypeAsterisk;     break;
                default:  recognised = NO;                     break;
            }

            if (recognised) {
                [state advance];
                ASToken *tok = [[ASToken alloc] initWithType:punctType
                                                        text:punctText
                                                        line:tokLine
                                                      column:tokCol];
                [tokens addObject:tok];
                lastWasNewline = NO;
                continue;
            }

            // Unexpected character
            [state advance];
            if (error) {
                NSString *desc = [NSString stringWithFormat:
                    @"Unexpected character '%@' at line %lu column %lu",
                    punctText, (unsigned long)tokLine, (unsigned long)tokCol];
                *error = [NSError errorWithDomain:ASLexerErrorDomain
                                             code:ASLexerErrorUnexpectedCharacter
                                         userInfo:@{
                    NSLocalizedDescriptionKey: desc,
                    @"line": @(tokLine),
                    @"column": @(tokCol),
                }];
            }
            return nil;
        }
    }

    // Emit EOF
    ASToken *eofTok = [[ASToken alloc] initWithType:ASTokenTypeEOF
                                               text:@""
                                               line:state.line
                                             column:state.column];
    [tokens addObject:eofTok];
    return [tokens copy];
}

@end
