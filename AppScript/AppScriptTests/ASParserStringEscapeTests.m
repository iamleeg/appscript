// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASParserStringEscapeTests.m — Tests for escape sequence handling in string literals
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
#import <AppScript/ASParser.h>
#import <AppScript/ASASTNode.h>
#import <AppScript/ASClassDefinitionNode.h>
#import <AppScript/ASMethodNode.h>
#import <AppScript/ASReturnNode.h>
#import <AppScript/ASStringLiteralNode.h>

/// Tests that verify ASParser correctly unescapes C / Objective-C escape sequences
/// in AppScript string literals (appscript-ewo).
@interface ASParserStringEscapeTests : XCTestCase
@property (nonatomic) ASLexer *lexer;
@property (nonatomic) ASParser *parser;
@end

@implementation ASParserStringEscapeTests

- (void)setUp {
    [super setUp];
    self.lexer = [[ASLexer alloc] init];
    self.parser = [[ASParser alloc] init];
}

- (void)tearDown {
    self.lexer = nil;
    self.parser = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parses a complete AppScript class that returns the given literal string and
/// returns the resulting ASStringLiteralNode value, asserting no errors occur.
- (NSString *)parseStringLiteral:(NSString *)literal {
    // Build source:  @class T : NSObject\n- run {\nreturn <literal>\n}\n@end
    NSString *source = [NSString stringWithFormat:
        @"@class T : NSObject\n- run {\nreturn %@\n}\n@end", literal];

    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError, @"Unexpected lexer error: %@", lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(parseError, @"Unexpected parse error: %@", parseError);
    XCTAssertNotNil(nodes);

    ASClassDefinitionNode *cls = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = cls.methods[0];
    ASReturnNode *ret = (ASReturnNode *)method.body[0];
    XCTAssertTrue([ret.value isKindOfClass:[ASStringLiteralNode class]],
                  @"Expected ASStringLiteralNode, got %@", [ret.value class]);
    return ((ASStringLiteralNode *)ret.value).value;
}

/// Attempts to parse an AppScript class with the given literal and returns the
/// parse error, asserting that parsing fails.
- (NSError *)parseStringLiteralExpectingError:(NSString *)literal {
    NSString *source = [NSString stringWithFormat:
        @"@class T : NSObject\n- run {\nreturn %@\n}\n@end", literal];

    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError, @"Unexpected lexer error: %@", lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes, @"Expected nil result for invalid string literal");
    XCTAssertNotNil(parseError, @"Expected a parse error for invalid string literal");
    return parseError;
}

// ---------------------------------------------------------------------------
// AC1–AC5: Basic C escape sequences
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_newlineEscape_producesNewline {
    // @"\n" should yield a single newline character.
    NSString *value = [self parseStringLiteral:@"@\"\\n\""];
    XCTAssertEqualObjects(value, @"\n");
    XCTAssertEqual(value.length, 1U);
}

- (void)test_stringLiteral_tabEscape_producesTab {
    // @"\t" should yield a single tab character.
    NSString *value = [self parseStringLiteral:@"@\"\\t\""];
    XCTAssertEqualObjects(value, @"\t");
    XCTAssertEqual(value.length, 1U);
}

- (void)test_stringLiteral_carriageReturnEscape_producesCarriageReturn {
    // @"\r" should yield a single carriage return.
    NSString *value = [self parseStringLiteral:@"@\"\\r\""];
    XCTAssertEqualObjects(value, @"\r");
    XCTAssertEqual(value.length, 1U);
}

- (void)test_stringLiteral_backslashEscape_producesBackslash {
    // @"\\" should yield a single backslash.
    NSString *value = [self parseStringLiteral:@"@\"\\\\\""];
    XCTAssertEqualObjects(value, @"\\");
    XCTAssertEqual(value.length, 1U);
}

- (void)test_stringLiteral_doubleQuoteEscape_producesDoubleQuote {
    // @"\"" should yield a single double-quote character.
    NSString *value = [self parseStringLiteral:@"@\"\\\"\""];
    XCTAssertEqualObjects(value, @"\"");
    XCTAssertEqual(value.length, 1U);
}

// ---------------------------------------------------------------------------
// AC6–AC10: Additional single-character escapes
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_nullEscape_producesNullCharacter {
    // @"\0" should yield U+0000.
    NSString *value = [self parseStringLiteral:@"@\"\\0\""];
    XCTAssertEqual(value.length, 1U);
    XCTAssertEqual([value characterAtIndex:0], (unichar)0x0000);
}

- (void)test_stringLiteral_bellEscape_producesBell {
    // @"\a" should yield U+0007.
    NSString *value = [self parseStringLiteral:@"@\"\\a\""];
    XCTAssertEqual(value.length, 1U);
    XCTAssertEqual([value characterAtIndex:0], (unichar)0x0007);
}

- (void)test_stringLiteral_backspaceEscape_producesBackspace {
    // @"\b" should yield U+0008.
    NSString *value = [self parseStringLiteral:@"@\"\\b\""];
    XCTAssertEqual(value.length, 1U);
    XCTAssertEqual([value characterAtIndex:0], (unichar)0x0008);
}

- (void)test_stringLiteral_formFeedEscape_producesFormFeed {
    // @"\f" should yield U+000C.
    NSString *value = [self parseStringLiteral:@"@\"\\f\""];
    XCTAssertEqual(value.length, 1U);
    XCTAssertEqual([value characterAtIndex:0], (unichar)0x000C);
}

- (void)test_stringLiteral_verticalTabEscape_producesVerticalTab {
    // @"\v" should yield U+000B.
    NSString *value = [self parseStringLiteral:@"@\"\\v\""];
    XCTAssertEqual(value.length, 1U);
    XCTAssertEqual([value characterAtIndex:0], (unichar)0x000B);
}

// ---------------------------------------------------------------------------
// AC11: Hex escape
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_hexEscape_producesCorrectCharacter {
    // @"\x41" should yield 'A' (0x41).
    NSString *value = [self parseStringLiteral:@"@\"\\x41\""];
    XCTAssertEqualObjects(value, @"A");
    XCTAssertEqual(value.length, 1U);
}

// ---------------------------------------------------------------------------
// AC12: \uNNNN Unicode escape
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_fourDigitUnicodeEscape_producesCorrectCharacter {
    // @"\u0041" should yield 'A'.
    NSString *value = [self parseStringLiteral:@"@\"\\u0041\""];
    XCTAssertEqualObjects(value, @"A");
    XCTAssertEqual(value.length, 1U);
}

// ---------------------------------------------------------------------------
// AC13: \UNNNNNNNN Unicode escape
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_eightDigitUnicodeEscape_producesCorrectCharacter {
    // @"\U00000041" should yield 'A'.
    NSString *value = [self parseStringLiteral:@"@\"\\U00000041\""];
    XCTAssertEqualObjects(value, @"A");
    XCTAssertEqual(value.length, 1U);
}

// ---------------------------------------------------------------------------
// AC14: Octal escape
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_octalEscape_producesCorrectCharacter {
    // @"\101" should yield 'A' (octal 101 = decimal 65 = 'A').
    NSString *value = [self parseStringLiteral:@"@\"\\101\""];
    XCTAssertEqualObjects(value, @"A");
    XCTAssertEqual(value.length, 1U);
}

// ---------------------------------------------------------------------------
// AC15: Unrecognised escape sequence → parse error
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_unrecognisedEscape_returnsParseError {
    // @"\q" is not a valid escape sequence and should cause a parse error.
    NSError *error = [self parseStringLiteralExpectingError:@"@\"\\q\""];
    XCTAssertEqualObjects(error.domain, ASParserErrorDomain);
    XCTAssertEqual(error.code, ASParserErrorInvalidEscapeSequence);
    XCTAssertNotNil(error.userInfo[NSLocalizedDescriptionKey]);
    XCTAssertTrue([error.userInfo[NSLocalizedDescriptionKey] containsString:@"q"],
                  @"Error message should mention the unrecognised character");
}

// ---------------------------------------------------------------------------
// AC16: Plain strings (no escapes) are unaffected
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_noEscapeSequences_returnsRawContent {
    NSString *value = [self parseStringLiteral:@"@\"hello, world\""];
    XCTAssertEqualObjects(value, @"hello, world");
}

// ---------------------------------------------------------------------------
// AC17: Mixed escaped and plain characters in one literal
// ---------------------------------------------------------------------------

- (void)test_stringLiteral_mixedContent_unescapesCorrectly {
    // @"line1\nline2" should yield "line1" + newline + "line2".
    NSString *value = [self parseStringLiteral:@"@\"line1\\nline2\""];
    XCTAssertEqualObjects(value, @"line1\nline2");
}

@end
