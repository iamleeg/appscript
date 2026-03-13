// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLexerTests.m — Unit tests for ASLexer
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

#import <XCTest/XCTest.h>
#import <AppScript/ASLexer.h>
#import <AppScript/ASToken.h>

@interface ASLexerTests : XCTestCase
@property (nonatomic) ASLexer *lexer;
@end

@implementation ASLexerTests

- (void)setUp {
    [super setUp];
    self.lexer = [[ASLexer alloc] init];
}

- (void)tearDown {
    self.lexer = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Lex source, assert no error, and return the tokens array.
- (NSArray<ASToken *> *)tokensForSource:(NSString *)source {
    NSError *error = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&error];
    XCTAssertNil(error, @"Unexpected lexer error: %@", error);
    XCTAssertNotNil(tokens);
    return tokens;
}

// ---------------------------------------------------------------------------
// 1. Empty string → just EOF token
// ---------------------------------------------------------------------------

- (void)test_tokenize_emptyString_producesEOF {
    NSArray<ASToken *> *tokens = [self tokensForSource:@""];
    XCTAssertEqual(tokens.count, 1U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 2. Single newline → newline token + EOF
// ---------------------------------------------------------------------------

- (void)test_tokenize_singleNewline_producesNewlineThenEOF {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"\n"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNewline);
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 3. Integer literal
// ---------------------------------------------------------------------------

- (void)test_tokenize_integerLiteral_producesNumberToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"42"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNumberLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"42");
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 4. Float literal
// ---------------------------------------------------------------------------

- (void)test_tokenize_floatLiteral_producesNumberToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"3.14"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNumberLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"3.14");
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 5. String literal @"hello"
// ---------------------------------------------------------------------------

- (void)test_tokenize_stringLiteral_producesStringToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"@\"hello\""];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeStringLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"@\"hello\"");
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 6. YES and NO → bool literal tokens
// ---------------------------------------------------------------------------

- (void)test_tokenize_YES_producesBoolLiteralToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"YES"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeBoolLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"YES");
}

- (void)test_tokenize_NO_producesBoolLiteralToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"NO"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeBoolLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"NO");
}

// ---------------------------------------------------------------------------
// 7. nil → nil literal token
// ---------------------------------------------------------------------------

- (void)test_tokenize_nil_producesNilLiteralToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"nil"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNilLiteral);
    XCTAssertEqualObjects(tokens[0].text, @"nil");
}

// ---------------------------------------------------------------------------
// 8. @class keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_atClass_producesKwClassToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"@class"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwClass);
    XCTAssertEqualObjects(tokens[0].text, @"@class");
}

// ---------------------------------------------------------------------------
// 9. @end keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_atEnd_producesKwEndToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"@end"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwEnd);
    XCTAssertEqualObjects(tokens[0].text, @"@end");
}

// ---------------------------------------------------------------------------
// 10. @property keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_atProperty_producesKwPropertyToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"@property"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwProperty);
    XCTAssertEqualObjects(tokens[0].text, @"@property");
}

// ---------------------------------------------------------------------------
// 11. id keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_id_producesKwIdToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"id"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwId);
    XCTAssertEqualObjects(tokens[0].text, @"id");
}

// ---------------------------------------------------------------------------
// 12. weak keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_weak_producesKwWeakToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"weak"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwWeak);
    XCTAssertEqualObjects(tokens[0].text, @"weak");
}

// ---------------------------------------------------------------------------
// 13. constant keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_constant_producesKwConstantToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"constant"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwConstant);
    XCTAssertEqualObjects(tokens[0].text, @"constant");
}

// ---------------------------------------------------------------------------
// 14. return keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_return_producesKwReturnToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"return"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwReturn);
    XCTAssertEqualObjects(tokens[0].text, @"return");
}

// ---------------------------------------------------------------------------
// 15. self keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_self_producesKwSelfToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"self"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwSelf);
    XCTAssertEqualObjects(tokens[0].text, @"self");
}

// ---------------------------------------------------------------------------
// 16. _cmd keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_cmd_producesKwCmdToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"_cmd"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwCmd);
    XCTAssertEqualObjects(tokens[0].text, @"_cmd");
}

// ---------------------------------------------------------------------------
// 17. Plain identifier
// ---------------------------------------------------------------------------

- (void)test_tokenize_plainIdentifier_producesIdentifierToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"myVariable"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeIdentifier);
    XCTAssertEqualObjects(tokens[0].text, @"myVariable");
}

// ---------------------------------------------------------------------------
// 18. All single-character punctuation tokens
// ---------------------------------------------------------------------------

- (void)test_tokenize_allPunctuation_producesCorrectTypes {
    NSString *source = @"[]{}()<>:,=+-^*";
    NSArray<ASToken *> *tokens = [self tokensForSource:source];

    // 15 punct + EOF = 16
    XCTAssertEqual(tokens.count, 16U);

    ASTokenType expected[] = {
        ASTokenTypeLeftBracket,
        ASTokenTypeRightBracket,
        ASTokenTypeLeftBrace,
        ASTokenTypeRightBrace,
        ASTokenTypeLeftParen,
        ASTokenTypeRightParen,
        ASTokenTypeLeftAngle,
        ASTokenTypeRightAngle,
        ASTokenTypeColon,
        ASTokenTypeComma,
        ASTokenTypeEquals,
        ASTokenTypePlus,
        ASTokenTypeMinus,
        ASTokenTypeCaret,
        ASTokenTypeAsterisk,
        ASTokenTypeEOF,
    };

    for (NSUInteger i = 0; i < 16; i++) {
        XCTAssertEqual(tokens[i].type, expected[i],
                       @"Token %lu has wrong type", (unsigned long)i);
    }
}

// ---------------------------------------------------------------------------
// 19. Single-line comment emits one newline, not comment text
// ---------------------------------------------------------------------------

- (void)test_tokenize_lineComment_emitsNewlineNotCommentText {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"// a comment"];
    // Comment-only line → newline token + EOF
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNewline);
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

- (void)test_tokenize_lineCommentWithTrailingContent_emitsTokensCorrectly {
    // "foo // comment\nbar" → identifier(foo), newline, identifier(bar), EOF
    NSArray<ASToken *> *tokens = [self tokensForSource:@"foo // comment\nbar"];
    XCTAssertEqual(tokens.count, 4U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeIdentifier);
    XCTAssertEqualObjects(tokens[0].text, @"foo");
    XCTAssertEqual(tokens[1].type, ASTokenTypeNewline);
    XCTAssertEqual(tokens[2].type, ASTokenTypeIdentifier);
    XCTAssertEqualObjects(tokens[2].text, @"bar");
    XCTAssertEqual(tokens[3].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 20. Unterminated string literal → nil + error
// ---------------------------------------------------------------------------

- (void)test_tokenize_unterminatedString_returnsNilAndError {
    NSError *error = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:@"@\"oops" error:&error];
    XCTAssertNil(tokens, @"Expected nil for unterminated string literal");
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ASLexerErrorDomain);
    XCTAssertEqual(error.code, ASLexerErrorUnterminatedStringLiteral);
}

// ---------------------------------------------------------------------------
// 21. Simple two-token line: "id x" → kw_id, identifier, newline(?), EOF
//     (no newline because there's no \n in the source)
// ---------------------------------------------------------------------------

- (void)test_tokenize_idFollowedByIdentifier_producesCorrectSequence {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"id x"];
    // kw_id, identifier, EOF (no newline — source has no \n)
    XCTAssertEqual(tokens.count, 3U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwId);
    XCTAssertEqualObjects(tokens[0].text, @"id");
    XCTAssertEqual(tokens[1].type, ASTokenTypeIdentifier);
    XCTAssertEqualObjects(tokens[1].text, @"x");
    XCTAssertEqual(tokens[2].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 22. Line numbers tracked correctly across newlines
// ---------------------------------------------------------------------------

- (void)test_tokenize_multipleLines_lineNumbersAreCorrect {
    // Line 1: foo
    // Line 2: bar
    NSArray<ASToken *> *tokens = [self tokensForSource:@"foo\nbar"];
    // foo(line=1), newline, bar(line=2), EOF
    XCTAssertEqual(tokens.count, 4U);

    XCTAssertEqual(tokens[0].type, ASTokenTypeIdentifier);
    XCTAssertEqual(tokens[0].line, 1U);

    XCTAssertEqual(tokens[1].type, ASTokenTypeNewline);

    XCTAssertEqual(tokens[2].type, ASTokenTypeIdentifier);
    XCTAssertEqual(tokens[2].line, 2U);
}

// ---------------------------------------------------------------------------
// 23. Column numbers tracked correctly
// ---------------------------------------------------------------------------

- (void)test_tokenize_singleLine_columnNumbersAreCorrect {
    // "id x" — id starts at col 1, x starts at col 4
    NSArray<ASToken *> *tokens = [self tokensForSource:@"id x"];
    XCTAssertEqual(tokens[0].column, 1U);
    XCTAssertEqual(tokens[1].column, 4U);
}

- (void)test_tokenize_consecutiveNewlines_collapseToSingleNewlineToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"\n\n\n"];
    // Three newlines → collapsed to one newline token + EOF
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeNewline);
    XCTAssertEqual(tokens[1].type, ASTokenTypeEOF);
}

// ---------------------------------------------------------------------------
// 24. super keyword
// ---------------------------------------------------------------------------

- (void)test_tokenize_super_producesKwSuperToken {
    NSArray<ASToken *> *tokens = [self tokensForSource:@"super"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeKwSuper);
    XCTAssertEqualObjects(tokens[0].text, @"super");
}

- (void)test_tokenize_superIdentifier_isNotKeyword {
    // "superman" must tokenize as a plain identifier, not as the super keyword.
    NSArray<ASToken *> *tokens = [self tokensForSource:@"superman"];
    XCTAssertEqual(tokens.count, 2U);
    XCTAssertEqual(tokens[0].type, ASTokenTypeIdentifier);
    XCTAssertEqualObjects(tokens[0].text, @"superman");
}

@end
