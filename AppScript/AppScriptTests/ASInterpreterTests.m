// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASInterpreterTests.m — Unit tests for ASInterpreter
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
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASNull.h>
#import <AppScript/ASASTNode.h>
#import <AppScript/ASReturnNode.h>
#import <AppScript/ASVariableDeclarationNode.h>
#import <AppScript/ASAssignmentNode.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASStringLiteralNode.h>
#import <AppScript/ASNumberLiteralNode.h>
#import <AppScript/ASArrayLiteralNode.h>
#import <AppScript/ASDictionaryLiteralNode.h>

// ---------------------------------------------------------------------------
// Convenience node-construction helpers
// ---------------------------------------------------------------------------

static ASStringLiteralNode *stringNode(NSString *value) {
    return [[ASStringLiteralNode alloc] initWithValue:value line:1 column:1];
}

static ASNumberLiteralNode *numberNode(NSNumber *value) {
    return [[ASNumberLiteralNode alloc] initWithValue:value line:1 column:1];
}

static ASIdentifierNode *identNode(NSString *name) {
    return [[ASIdentifierNode alloc] initWithName:name line:1 column:1];
}

static ASReturnNode *returnNode(ASASTNode * _Nullable value) {
    return [[ASReturnNode alloc] initWithValue:value line:1 column:1];
}

static ASVariableDeclarationNode *varDeclNode(NSString *name,
                                               ASASTNode * _Nullable initializer) {
    return [[ASVariableDeclarationNode alloc] initWithVariableName:name
                                                       initializer:initializer
                                                            isWeak:NO
                                                        isConstant:NO
                                                              line:1
                                                            column:1];
}

static ASAssignmentNode *assignNode(NSString *name, ASASTNode *value) {
    return [[ASAssignmentNode alloc] initWithVariableName:name
                                                    value:value
                                                     line:1
                                                   column:1];
}

static ASMessageSendNode *messageSendNode(ASASTNode *receiver,
                                           NSArray<NSString *> *selectorParts,
                                           NSArray<ASASTNode *> *arguments) {
    return [[ASMessageSendNode alloc] initWithReceiver:receiver
                                         selectorParts:selectorParts
                                             arguments:arguments
                                                  line:1
                                                column:1];
}

// ---------------------------------------------------------------------------
// Test class
// ---------------------------------------------------------------------------

/// Tests for ASInterpreter, exercising evaluation of various AST shapes.
@interface ASInterpreterTests : XCTestCase
@property (nonatomic) ASInterpreter *interpreter;
@end

@implementation ASInterpreterTests

- (void)setUp {
    [super setUp];
    self.interpreter = [[ASInterpreter alloc] init];
}

- (void)tearDown {
    self.interpreter = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
// 1. Empty body returns nil
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_emptyBody_returnsNil {
    id result = [self.interpreter evaluateMethodBody:@[]
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertNil(result, @"An empty method body should return nil");
}

// ---------------------------------------------------------------------------
// 2. Return a string literal
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_returnLiteral_returnsValue {
    // body: return @"hello"
    NSArray<ASASTNode *> *body = @[ returnNode(stringNode(@"hello")) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @"hello",
                          @"Returning a string literal should yield the string value");
}

// ---------------------------------------------------------------------------
// 3. Declare a variable and return it
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_variableDeclarationAndReturn_returnsValue {
    // body: id x = @"world"; return x;
    NSArray<ASASTNode *> *body = @[
        varDeclNode(@"x", stringNode(@"world")),
        returnNode(identNode(@"x")),
    ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @"world",
                          @"A variable declared and returned should yield its initializer value");
}

// ---------------------------------------------------------------------------
// 4. Message send: [NSString string]
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_messageSend_invokesMethod {
    // body: return [NSString string]
    ASMessageSendNode *send = messageSendNode(identNode(@"NSString"),
                                              @[@"string"],
                                              @[]);
    NSArray<ASASTNode *> *body = @[ returnNode(send) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertNotNil(result, @"[NSString string] should not return nil");
    XCTAssertTrue([result isKindOfClass:[NSString class]],
                  @"[NSString string] should return an NSString");
    XCTAssertEqualObjects(result, @"",
                          @"[NSString string] should return an empty string");
}

// ---------------------------------------------------------------------------
// 5. Return self
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_selfReference_returnsSelf {
    // body: return self
    NSArray<ASASTNode *> *body = @[ returnNode(identNode(@"self")) ];

    id receiver = [NSObject new];
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:receiver
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqual(result, receiver,
                   @"Returning 'self' should yield the receiver object");
}

// ---------------------------------------------------------------------------
// 6. Parameter binding
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_parameterBinding_accessesParam {
    // body: return param  (where param is bound to @"bound-value")
    NSArray<ASASTNode *> *body = @[ returnNode(identNode(@"param")) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test:"
                                          arguments:@[ @"bound-value" ]
                                     parameterNames:@[ @"param" ]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @"bound-value",
                          @"A bound parameter should be accessible by its declared name");
}

// ---------------------------------------------------------------------------
// 7. Assignment updates variable
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_assignmentToVariable_updatesValue {
    // body: id x = @"first"; x = @"second"; return x;
    NSArray<ASASTNode *> *body = @[
        varDeclNode(@"x", stringNode(@"first")),
        assignNode(@"x", stringNode(@"second")),
        returnNode(identNode(@"x")),
    ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @"second",
                          @"Assigning a new value to a variable should update it");
}

// ---------------------------------------------------------------------------
// 8. Array literal
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_arrayLiteral_returnsArray {
    // body: return @[ @"a", @"b" ]
    ASArrayLiteralNode *arrayLit = [[ASArrayLiteralNode alloc]
                                    initWithElements:@[ stringNode(@"a"), stringNode(@"b") ]
                                               line:1
                                             column:1];
    NSArray<ASASTNode *> *body = @[ returnNode(arrayLit) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertTrue([result isKindOfClass:[NSArray class]],
                  @"An array literal should evaluate to an NSArray");
    XCTAssertEqual([(NSArray *)result count], (NSUInteger)2,
                   @"The array should have two elements");
    XCTAssertEqualObjects(result, (@[@"a", @"b"]),
                          @"The array contents should match the literal");
}

// ---------------------------------------------------------------------------
// 9. Dictionary literal
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_dictionaryLiteral_returnsDictionary {
    // body: return @{ @"key": @"val" }
    ASDictionaryLiteralNode *dictLit = [[ASDictionaryLiteralNode alloc]
                                        initWithKeys:@[ stringNode(@"key") ]
                                             values:@[ stringNode(@"val") ]
                                               line:1
                                             column:1];
    NSArray<ASASTNode *> *body = @[ returnNode(dictLit) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertTrue([result isKindOfClass:[NSDictionary class]],
                  @"A dictionary literal should evaluate to an NSDictionary");
    XCTAssertEqualObjects(result, (@{@"key": @"val"}),
                          @"The dictionary contents should match the literal");
}

// ---------------------------------------------------------------------------
// 10. Nested message send: [[NSMutableArray new] count]
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_nestedMessageSend_evaluatesCorrectly {
    // inner: [NSMutableArray new]
    ASMessageSendNode *newSend = messageSendNode(identNode(@"NSMutableArray"),
                                                  @[@"new"],
                                                  @[]);
    // outer: [<above> count]
    ASMessageSendNode *countSend = messageSendNode(newSend,
                                                    @[@"count"],
                                                    @[]);
    NSArray<ASASTNode *> *body = @[ returnNode(countSend) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertNotNil(result, @"count should not return nil");
    XCTAssertTrue([result isKindOfClass:[NSNumber class]],
                  @"count should return an NSNumber");
    XCTAssertEqual([result unsignedIntegerValue], (NSUInteger)0,
                   @"[[NSMutableArray new] count] should be 0");
}

// ---------------------------------------------------------------------------
// 11. nil identifier evaluates to ASNull, not NSNull and not ObjC nil
// ---------------------------------------------------------------------------

- (void)test_evaluateExpression_nilIdentifier_returnsASNull {
    // body: return nil
    NSArray<ASASTNode *> *body = @[ returnNode(identNode(@"nil")) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqual(result, [ASNull null],
                   @"The nil identifier should evaluate to [ASNull null]");
    XCTAssertNotEqual(result, [NSNull null],
                      @"The nil identifier must not evaluate to [NSNull null]");
}

// ---------------------------------------------------------------------------
// 12. A variable assigned nil holds ASNull, not NSNull and not ObjC nil
// ---------------------------------------------------------------------------

- (void)test_evaluateExpression_variableAssignedNil_holdsASNull {
    // body: id x = nil; return x;
    NSArray<ASASTNode *> *body = @[
        varDeclNode(@"x", identNode(@"nil")),
        returnNode(identNode(@"x")),
    ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqual(result, [ASNull null],
                   @"A variable assigned nil should evaluate to [ASNull null]");
    XCTAssertNotEqual(result, [NSNull null],
                      @"A variable assigned nil must not evaluate to [NSNull null]");
}

// ---------------------------------------------------------------------------
// 13. NSNull returned from a native API is distinct from ASNull
// ---------------------------------------------------------------------------

- (void)test_evaluateExpression_nativeNSNullReturnValue_isPreserved {
    // [NSNull null] returns [NSNull null] — a native ObjC object, not AppScript nil.
    // body: return [NSNull null]
    ASMessageSendNode *send = messageSendNode(identNode(@"NSNull"),
                                              @[@"null"],
                                              @[]);
    NSArray<ASASTNode *> *body = @[ returnNode(send) ];

    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqual(result, [NSNull null],
                   @"[NSNull null] from a native message send should be returned as-is");
    XCTAssertNotEqual(result, [ASNull null],
                      @"[NSNull null] from a native call must not be conflated with ASNull");
}

@end
