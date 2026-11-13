// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASParserTests.m — Unit tests for ASParser
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
#import <AppScript/ASCategoryDefinitionNode.h>
#import <AppScript/ASPropertyNode.h>
#import <AppScript/ASMethodNode.h>
#import <AppScript/ASVariableDeclarationNode.h>
#import <AppScript/ASAssignmentNode.h>
#import <AppScript/ASReturnNode.h>
#import <AppScript/ASSuperNode.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASBlockLiteralNode.h>
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASStringLiteralNode.h>

@interface ASParserTests : XCTestCase
@property (nonatomic) ASLexer *lexer;
@property (nonatomic) ASParser *parser;
@end

@implementation ASParserTests

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

/// Lex source and parse it, asserting no errors. Returns the top-level node array.
- (NSArray<ASASTNode *> *)parseSource:(NSString *)source {
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError, @"Unexpected lexer error: %@", lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(parseError, @"Unexpected parse error: %@", parseError);
    XCTAssertNotNil(nodes);
    return nodes;
}

// ---------------------------------------------------------------------------
// 1. Empty input → empty array, no error
// ---------------------------------------------------------------------------

- (void)test_parseTokens_emptyInput_returnsEmptyArray {
    NSArray<ASASTNode *> *nodes = [self parseSource:@""];
    XCTAssertEqual(nodes.count, 0U);
}

// ---------------------------------------------------------------------------
// 2. Minimal class definition
// ---------------------------------------------------------------------------

- (void)test_parseTokens_simpleClassDefinition_returnsClassNode {
    NSString *source = @"@class Foo : NSObject\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    XCTAssertTrue([nodes[0] isKindOfClass:[ASClassDefinitionNode class]]);

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqualObjects(classNode.className, @"Foo");
    XCTAssertEqualObjects(classNode.superclassName, @"NSObject");
    XCTAssertEqual(classNode.properties.count, 0U);
    XCTAssertEqual(classNode.methods.count, 0U);
}

// ---------------------------------------------------------------------------
// 3. Class with protocol list
// ---------------------------------------------------------------------------

- (void)test_parseTokens_classWithProtocols_storesProtocolNames {
    NSString *source = @"@class Foo : NSObject <NSCopying, NSCoding>\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.protocolNames.count, 2U);
    XCTAssertEqualObjects(classNode.protocolNames[0], @"NSCopying");
    XCTAssertEqualObjects(classNode.protocolNames[1], @"NSCoding");
}

- (void)test_parseTokens_weakProperty_storesWeakModifier {
    // "weak" is a keyword token, not an identifier. The property modifier loop
    // must accept it so that weak delegate properties parse without hanging.
    NSString *source = @"@class Foo : NSObject\n@property (weak) delegate\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.properties.count, 1U);

    ASPropertyNode *prop = classNode.properties[0];
    XCTAssertEqualObjects(prop.propertyName, @"delegate");
    XCTAssertEqual(prop.modifiers.count, 1U);
    XCTAssertEqualObjects(prop.modifiers[0], @"weak");
}

- (void)test_parseTokens_classWithSameNameProtocol_storesProtocolName {
    // The AppScript interop pattern uses the same name for the class and its
    // protocol (e.g. @class Paper : NSObject <Paper>). Verify the parser stores
    // the protocol name without confusion.
    NSString *source = @"@class Foo : NSObject <Foo>\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqualObjects(classNode.className, @"Foo");
    XCTAssertEqual(classNode.protocolNames.count, 1U);
    XCTAssertEqualObjects(classNode.protocolNames[0], @"Foo");
}

- (void)test_parseTokens_classWithMultipleProtocolsIncludingClassName_storesAllProtocolNames {
    NSString *source = @"@class Foo : NSObject <Proto1, Proto2, Foo>\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqualObjects(classNode.className, @"Foo");
    XCTAssertEqual(classNode.protocolNames.count, 3U);
    XCTAssertEqualObjects(classNode.protocolNames[0], @"Proto1");
    XCTAssertEqualObjects(classNode.protocolNames[1], @"Proto2");
    XCTAssertEqualObjects(classNode.protocolNames[2], @"Foo");
}

- (void)test_parseTokens_unterminatedProtocolListAtNewline_returnsErrorWithoutHanging {
    NSString *source = @"@class Foo : NSObject <Proto1, Proto2\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

- (void)test_parseTokens_emptyProtocolBrackets_returnsError {
    NSString *source = @"@class Foo : NSObject <>\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

- (void)test_parseTokens_protocolsMissingComma_returnsError {
    NSString *source = @"@class Foo : NSObject <Proto1 Proto2>\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

- (void)test_parseTokens_protocolsTrailingComma_returnsError {
    NSString *source = @"@class Foo : NSObject <Proto1, >\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

- (void)test_parseTokens_unexpectedTokenInPropertyModifiers_returnsErrorWithoutHanging {
    NSString *source = @"@class Foo : NSObject\n@property (strong : readonly) name\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

- (void)test_parseTokens_unexpectedTokenInBlockParameters_returnsErrorWithoutHanging {
    NSString *source = @"@class Foo : NSObject\n- run {\nid blk = ^(x : y) {\nreturn x\n}\n}\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

// ---------------------------------------------------------------------------
// 4. Class with a property
// ---------------------------------------------------------------------------

- (void)test_parseTokens_classWithProperty_storesPropertyNode {
    NSString *source = @"@class Foo : NSObject\n@property name\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.properties.count, 1U);

    ASPropertyNode *prop = classNode.properties[0];
    XCTAssertEqualObjects(prop.propertyName, @"name");
    XCTAssertEqual(prop.modifiers.count, 0U);
}

// ---------------------------------------------------------------------------
// 5. Property with modifiers
// ---------------------------------------------------------------------------

- (void)test_parseTokens_propertyWithModifiers_storesModifiers {
    NSString *source = @"@class Foo : NSObject\n@property (strong, readonly) name\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.properties.count, 1U);

    ASPropertyNode *prop = classNode.properties[0];
    XCTAssertEqualObjects(prop.propertyName, @"name");
    XCTAssertEqual(prop.modifiers.count, 2U);
    XCTAssertEqualObjects(prop.modifiers[0], @"strong");
    XCTAssertEqualObjects(prop.modifiers[1], @"readonly");
}

// ---------------------------------------------------------------------------
// 6. Instance method
// ---------------------------------------------------------------------------

- (void)test_parseTokens_instanceMethod_storesMethodNode {
    NSString *source = @"@class Foo : NSObject\n- doSomething {\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.methods.count, 1U);

    ASMethodNode *method = classNode.methods[0];
    XCTAssertFalse(method.isClassMethod);
    XCTAssertEqual(method.selectorParts.count, 1U);
    XCTAssertEqualObjects(method.selectorParts[0], @"doSomething");
    XCTAssertEqual(method.parameterNames.count, 0U);
}

// ---------------------------------------------------------------------------
// 7. Class method
// ---------------------------------------------------------------------------

- (void)test_parseTokens_classMethod_storesMethodNode {
    NSString *source = @"@class Foo : NSObject\n+ create {\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.methods.count, 1U);

    ASMethodNode *method = classNode.methods[0];
    XCTAssertTrue(method.isClassMethod);
    XCTAssertEqualObjects(method.selectorParts[0], @"create");
}

// ---------------------------------------------------------------------------
// 8. Multi-keyword method
// ---------------------------------------------------------------------------

- (void)test_parseTokens_multiKeywordMethod_storesAllSelectorParts {
    NSString *source = @"@class Foo : NSObject\n- writeToFile: path atomically: flag {\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.methods.count, 1U);

    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.selectorParts.count, 2U);
    XCTAssertEqualObjects(method.selectorParts[0], @"writeToFile");
    XCTAssertEqualObjects(method.selectorParts[1], @"atomically");
    XCTAssertEqual(method.parameterNames.count, 2U);
    XCTAssertEqualObjects(method.parameterNames[0], @"path");
    XCTAssertEqualObjects(method.parameterNames[1], @"flag");
}

// ---------------------------------------------------------------------------
// 9. Variable declaration in method body
// ---------------------------------------------------------------------------

- (void)test_parseTokens_variableDeclaration_returnsDeclarationNode {
    NSString *source = @"@class Foo : NSObject\n- run {\nid x = @\"hello\"\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    XCTAssertEqual(classNode.methods.count, 1U);

    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);
    XCTAssertTrue([method.body[0] isKindOfClass:[ASVariableDeclarationNode class]]);

    ASVariableDeclarationNode *decl = (ASVariableDeclarationNode *)method.body[0];
    XCTAssertEqualObjects(decl.variableName, @"x");
    XCTAssertFalse(decl.isWeak);
    XCTAssertFalse(decl.isConstant);
    XCTAssertNotNil(decl.initializer);
}

// ---------------------------------------------------------------------------
// 10. Weak variable declaration
// ---------------------------------------------------------------------------

- (void)test_parseTokens_weakVariableDeclaration_setsIsWeak {
    NSString *source = @"@class Foo : NSObject\n- run {\nweak id x = self\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    ASVariableDeclarationNode *decl = (ASVariableDeclarationNode *)method.body[0];
    XCTAssertEqualObjects(decl.variableName, @"x");
    XCTAssertTrue(decl.isWeak);
    XCTAssertFalse(decl.isConstant);
}

// ---------------------------------------------------------------------------
// 11. Constant variable declaration
// ---------------------------------------------------------------------------

- (void)test_parseTokens_constantDeclaration_setsIsConstant {
    NSString *source = @"@class Foo : NSObject\n- run {\nconstant id x = @42\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    ASVariableDeclarationNode *decl = (ASVariableDeclarationNode *)method.body[0];
    XCTAssertEqualObjects(decl.variableName, @"x");
    XCTAssertFalse(decl.isWeak);
    XCTAssertTrue(decl.isConstant);
}

// ---------------------------------------------------------------------------
// 12. Message send (zero-arg)
// ---------------------------------------------------------------------------

- (void)test_parseTokens_messageSend_returnsMessageSendNode {
    NSString *source = @"@class Foo : NSObject\n- run {\n[obj doSomething]\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    XCTAssertTrue([method.body[0] isKindOfClass:[ASMessageSendNode class]]);
    ASMessageSendNode *msg = (ASMessageSendNode *)method.body[0];
    XCTAssertEqual(msg.selectorParts.count, 1U);
    XCTAssertEqualObjects(msg.selectorParts[0], @"doSomething");
    XCTAssertEqual(msg.arguments.count, 0U);
}

// ---------------------------------------------------------------------------
// 13. Multi-keyword message send
// ---------------------------------------------------------------------------

- (void)test_parseTokens_multiKeywordMessageSend_storesAllParts {
    NSString *source = @"@class Foo : NSObject\n- run {\n[obj writeToFile: path atomically: flag]\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    XCTAssertTrue([method.body[0] isKindOfClass:[ASMessageSendNode class]]);
    ASMessageSendNode *msg = (ASMessageSendNode *)method.body[0];
    XCTAssertEqual(msg.selectorParts.count, 2U);
    XCTAssertEqualObjects(msg.selectorParts[0], @"writeToFile");
    XCTAssertEqualObjects(msg.selectorParts[1], @"atomically");
    XCTAssertEqual(msg.arguments.count, 2U);
}

// ---------------------------------------------------------------------------
// 14. Return statement
// ---------------------------------------------------------------------------

- (void)test_parseTokens_returnStatement_returnsReturnNode {
    NSString *source = @"@class Foo : NSObject\n- getValue {\nreturn @\"result\"\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    XCTAssertTrue([method.body[0] isKindOfClass:[ASReturnNode class]]);
    ASReturnNode *ret = (ASReturnNode *)method.body[0];
    XCTAssertNotNil(ret.value);
}

// ---------------------------------------------------------------------------
// 15. Block literal with parameters
// ---------------------------------------------------------------------------

- (void)test_parseTokens_blockLiteral_storesParameterNames {
    // Block on a single statement line with body on next line.
    NSString *source = @"@class Foo : NSObject\n- run {\nid blk = ^(x, y) {\nreturn x\n}\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    XCTAssertTrue([method.body[0] isKindOfClass:[ASVariableDeclarationNode class]]);
    ASVariableDeclarationNode *decl = (ASVariableDeclarationNode *)method.body[0];
    XCTAssertNotNil(decl.initializer);
    XCTAssertTrue([decl.initializer isKindOfClass:[ASBlockLiteralNode class]]);

    ASBlockLiteralNode *block = (ASBlockLiteralNode *)decl.initializer;
    XCTAssertEqual(block.parameterNames.count, 2U);
    XCTAssertEqualObjects(block.parameterNames[0], @"x");
    XCTAssertEqualObjects(block.parameterNames[1], @"y");
    XCTAssertEqual(block.body.count, 1U);
}

// ---------------------------------------------------------------------------
// 16. Category definition
// ---------------------------------------------------------------------------

- (void)test_parseTokens_categoryDefinition_returnsCategoryNode {
    NSString *source = @"@category NSString (Extras)\n- trimmed {\nreturn self\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    XCTAssertEqual(nodes.count, 1U);
    XCTAssertTrue([nodes[0] isKindOfClass:[ASCategoryDefinitionNode class]]);

    ASCategoryDefinitionNode *catNode = (ASCategoryDefinitionNode *)nodes[0];
    XCTAssertEqualObjects(catNode.className, @"NSString");
    XCTAssertEqualObjects(catNode.categoryName, @"Extras");
    XCTAssertEqual(catNode.methods.count, 1U);
}

// ---------------------------------------------------------------------------
// 17. Unexpected token → nil + error
// ---------------------------------------------------------------------------

- (void)test_parseTokens_unexpectedToken_returnsNilAndError {
    NSError *lexError = nil;
    // A bare identifier at top level is not valid
    NSArray<ASToken *> *tokens = [self.lexer tokenize:@"notAKeyword" error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
    XCTAssertNotNil(parseError.userInfo[NSLocalizedDescriptionKey]);
}

// ---------------------------------------------------------------------------
// 18. Unterminated class (no @end) → nil + error
// ---------------------------------------------------------------------------

- (void)test_parseTokens_unterminatedClass_returnsNilAndError {
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:@"@class Foo : NSObject\n" error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *nodes = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(nodes);
    XCTAssertNotNil(parseError);
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedEOF);
    XCTAssertNotNil(parseError.userInfo[NSLocalizedDescriptionKey]);
}

// ---------------------------------------------------------------------------
// 19. super as receiver produces ASSuperNode
// ---------------------------------------------------------------------------

- (void)test_parseTokens_superAsReceiver_producesASSuperNode {
    NSString *source = @"@class Foo : NSObject\n- run {\n[super init]\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    XCTAssertTrue([method.body[0] isKindOfClass:[ASMessageSendNode class]]);
    ASMessageSendNode *msg = (ASMessageSendNode *)method.body[0];
    XCTAssertTrue([msg.receiver isKindOfClass:[ASSuperNode class]],
                  @"Receiver of [super init] should be an ASSuperNode");
    XCTAssertEqualObjects(msg.selectorParts[0], @"init");
}

// ---------------------------------------------------------------------------
// 20. super send with an argument parses correctly
// ---------------------------------------------------------------------------

- (void)test_parseTokens_superSendWithArgument_parsesCorrectly {
    NSString *source = @"@class Foo : NSObject\n- run {\n[super initWithValue: x]\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 1U);

    ASMessageSendNode *msg = (ASMessageSendNode *)method.body[0];
    XCTAssertTrue([msg.receiver isKindOfClass:[ASSuperNode class]],
                  @"Receiver should be ASSuperNode");
    XCTAssertEqual(msg.arguments.count, 1U);
}

// ---------------------------------------------------------------------------
// 21. self = [super init] parses as assignment to 'self'
// ---------------------------------------------------------------------------

- (void)test_parseTokens_selfEqualsSuper_parsesAsSelfAssignment {
    NSString *source = @"@class Foo : NSObject\n- init {\nself = [super init]\nreturn self\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    XCTAssertEqual(method.body.count, 2U,
                   @"Method body should have two statements: assignment and return");

    XCTAssertTrue([method.body[0] isKindOfClass:[ASAssignmentNode class]],
                  @"First statement should be an assignment");
    ASAssignmentNode *assign = (ASAssignmentNode *)method.body[0];
    XCTAssertEqualObjects(assign.variableName, @"self",
                          @"Assignment target should be 'self'");
    XCTAssertTrue([assign.value isKindOfClass:[ASMessageSendNode class]],
                  @"Assignment value should be a message send");
    ASMessageSendNode *send = (ASMessageSendNode *)assign.value;
    XCTAssertTrue([send.receiver isKindOfClass:[ASSuperNode class]],
                  @"The message send receiver should be ASSuperNode");
}

// ---------------------------------------------------------------------------
// 22. super inside a block literal is a parse error
// ---------------------------------------------------------------------------

- (void)test_parseTokens_unnamedKeywordMessageSend_storesEmptySelectorParts {
    // [ASFoundation NSMakeRect:10 :20 :300 :400] — Objective-C unnamed keyword parts
    NSString *source = @"@class Foo : NSObject\n- run {\n[ASFoundation NSMakeRect:10 :20 :300 :400]\n}\n@end";
    NSArray<ASASTNode *> *nodes = [self parseSource:source];

    ASClassDefinitionNode *classNode = (ASClassDefinitionNode *)nodes[0];
    ASMethodNode *method = classNode.methods[0];
    ASMessageSendNode *msg = (ASMessageSendNode *)method.body[0];
    XCTAssertEqual(msg.selectorParts.count, 4U);
    XCTAssertEqualObjects(msg.selectorParts[0], @"NSMakeRect");
    XCTAssertEqualObjects(msg.selectorParts[1], @"");
    XCTAssertEqualObjects(msg.selectorParts[2], @"");
    XCTAssertEqualObjects(msg.selectorParts[3], @"");
    XCTAssertEqual(msg.arguments.count, 4U);
    XCTAssertEqualObjects(msg.selector, @"NSMakeRect::::");
}

- (void)test_parseTokens_superInsideBlock_returnsError {
    // Attempt to use super inside a block — should produce a parse error.
    NSString *source = @"@class Foo : NSObject\n- run {\nid b = ^{\n[super init]\n}\n}\n@end";
    NSError *lexError = nil;
    NSArray<ASToken *> *tokens = [self.lexer tokenize:source error:&lexError];
    XCTAssertNil(lexError);
    XCTAssertNotNil(tokens);

    NSError *parseError = nil;
    NSArray<ASASTNode *> *result = [self.parser parseTokens:tokens error:&parseError];
    XCTAssertNil(result,
                 @"Parsing should fail when 'super' appears inside a block literal");
    XCTAssertNotNil(parseError,
                    @"An error should be returned when 'super' is inside a block literal");
    XCTAssertEqualObjects(parseError.domain, ASParserErrorDomain);
    XCTAssertEqual(parseError.code, ASParserErrorUnexpectedToken);
}

@end
