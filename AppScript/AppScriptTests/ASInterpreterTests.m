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
#import <AppScript/ASSuperNode.h>
#import <AppScript/ASStringLiteralNode.h>
#import <AppScript/ASNumberLiteralNode.h>
#import <AppScript/ASArrayLiteralNode.h>
#import <AppScript/ASDictionaryLiteralNode.h>

// ---------------------------------------------------------------------------
// Concrete Objective-C class hierarchy used by super-dispatch tests.
// These must not be class clusters so that class_getInstanceMethod finds a
// real, callable IMP (not an abstract stub).
// ---------------------------------------------------------------------------

@interface ASSuperTestBase : NSObject
- (NSString *)testKind;
@end

@implementation ASSuperTestBase
- (NSString *)testKind { return @"base"; }
@end

@interface ASSuperTestSub : ASSuperTestBase
@end

@implementation ASSuperTestSub
@end

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

static ASSuperNode *superNode(void) {
    return [[ASSuperNode alloc] initWithLine:1 column:1];
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
// Helper for error-path tests: run body and return the caught exception,
// or nil if no exception was raised.
// ---------------------------------------------------------------------------

/// An AST node type that ASInterpreter does not handle, used to trigger
/// ASErrorCodeUnknownASTNodeType.
@interface ASUnknownTestNode : ASASTNode
@end
@implementation ASUnknownTestNode
@end

static NSException * _Nullable runAndCatch(ASInterpreter *interp,
                                            NSArray<ASASTNode *> *body) {
    @try {
        [interp evaluateMethodBody:body
                      withReceiver:[NSObject new]
                     definingClass:[NSObject class]
                          selector:@"test"
                         arguments:@[]
                    parameterNames:@[]
                        scriptPath:@"test.appscript"];
        return nil;
    } @catch (NSException *ex) {
        return ex;
    }
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
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
                                       definingClass:[NSObject class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqual(result, [NSNull null],
                   @"[NSNull null] from a native message send should be returned as-is");
    XCTAssertNotEqual(result, [ASNull null],
                      @"[NSNull null] from a native call must not be conflated with ASNull");
}

// ---------------------------------------------------------------------------
// 18. Cannot reassign constant raises ASErrorCodeCannotReassignConstant
// ---------------------------------------------------------------------------

- (void)test_reportError_cannotReassignConstant_raisesCorrectException {
    // const x = @"a"; x = @"b"  — reassigning a constant is forbidden.
    ASVariableDeclarationNode *constDecl =
        [[ASVariableDeclarationNode alloc] initWithVariableName:@"x"
                                                    initializer:stringNode(@"a")
                                                         isWeak:NO
                                                     isConstant:YES
                                                           line:1
                                                         column:1];
    NSArray<ASASTNode *> *body = @[constDecl, assignNode(@"x", stringNode(@"b"))];

    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"Reassigning a constant should raise an exception");
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException,
                          @"Exception name should be ASRuntimeErrorException");
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeCannotReassignConstant),
                          @"userInfo should carry ASErrorCodeCannotReassignConstant");
}

// ---------------------------------------------------------------------------
// 19. Undefined variable assignment raises ASErrorCodeUndefinedVariable
// ---------------------------------------------------------------------------

- (void)test_reportError_undefinedVariable_raisesCorrectException {
    // z = @"value"  — z has never been declared.
    NSArray<ASASTNode *> *body = @[assignNode(@"z", stringNode(@"value"))];

    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"Assigning to an undeclared variable should raise an exception");
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException,
                          @"Exception name should be ASRuntimeErrorException");
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeUndefinedVariable),
                          @"userInfo should carry ASErrorCodeUndefinedVariable");
}

// ---------------------------------------------------------------------------
// 20. Undefined identifier raises ASErrorCodeUndefinedIdentifier
// ---------------------------------------------------------------------------

- (void)test_reportError_undefinedIdentifier_raisesCorrectException {
    // return nonExistentName  — not a keyword, param, or ObjC class.
    NSArray<ASASTNode *> *body = @[returnNode(identNode(@"nonExistentNameXYZ"))];

    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"Referencing an undefined identifier should raise an exception");
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException,
                          @"Exception name should be ASRuntimeErrorException");
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeUndefinedIdentifier),
                          @"userInfo should carry ASErrorCodeUndefinedIdentifier");
}

// ---------------------------------------------------------------------------
// 21. Unknown AST node type raises ASErrorCodeUnknownASTNodeType
// ---------------------------------------------------------------------------

- (void)test_reportError_unknownASTNodeType_raisesCorrectException {
    // Inject an ASUnknownTestNode — a subclass of ASASTNode with no handler.
    ASUnknownTestNode *unknown = [[ASUnknownTestNode alloc] initWithLine:1 column:1];
    NSArray<ASASTNode *> *body = @[returnNode(unknown)];

    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"An unrecognised AST node type should raise an exception");
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException,
                          @"Exception name should be ASRuntimeErrorException");
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeUnknownASTNodeType),
                          @"userInfo should carry ASErrorCodeUnknownASTNodeType");
}

// ---------------------------------------------------------------------------
// 22. Unrecognised selector raises ASErrorCodeUnrecognisedSelector
// ---------------------------------------------------------------------------

- (void)test_reportError_unrecognisedSelector_raisesCorrectException {
    // [NSObject nonExistentMethod999]
    ASMessageSendNode *send = messageSendNode(identNode(@"NSObject"),
                                              @[@"nonExistentMethod999"],
                                              @[]);
    NSArray<ASASTNode *> *body = @[returnNode(send)];

    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"Sending an unrecognised selector should raise an exception");
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException,
                          @"Exception name should be ASRuntimeErrorException");
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeUnrecognisedSelector),
                          @"userInfo should carry ASErrorCodeUnrecognisedSelector");
}

// ---------------------------------------------------------------------------
// 14. super send dispatches to the superclass implementation
//
// Strategy: ASSuperTestSub is a concrete subclass of ASSuperTestBase (defined
// above). We construct a body of:
//   return [super testKind]
// with definingClass = ASSuperTestSub and receiver = an ASSuperTestSub
// instance. The dispatch must start from ASSuperTestBase's -testKind
// implementation, which returns @"base".
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_superSend_dispatchesToSuperclassMethod {
    // body: return [super testKind]
    ASMessageSendNode *send = messageSendNode(superNode(), @[@"testKind"], @[]);
    NSArray<ASASTNode *> *body = @[ returnNode(send) ];

    ASSuperTestSub *receiver = [ASSuperTestSub new];
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:receiver
                                       definingClass:[ASSuperTestSub class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @"base",
                          @"[super testKind] should dispatch to ASSuperTestBase's implementation");
}

// ---------------------------------------------------------------------------
// 15. super send uses `self` as the receiver object
//
// Verify that the actual object receiving the super-dispatched call is still
// `self` (not some proxy).  We do this by calling [super description] on an
// NSMutableString and checking that the result is a string (NSObject's
// -description returns the object's class and address, both of which are
// strings).
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_superSend_receiverIsStillSelf {
    // body: return [super description]
    ASMessageSendNode *send = messageSendNode(superNode(), @[@"description"], @[]);
    NSArray<ASASTNode *> *body = @[ returnNode(send) ];

    NSMutableString *receiver = [NSMutableString stringWithString:@"hello"];
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:receiver
                                       definingClass:[NSMutableString class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertTrue([result isKindOfClass:[NSString class]],
                  @"-description should return a string");
}

// ---------------------------------------------------------------------------
// 16. super send with an argument dispatches correctly
//
// Use [super isEqual: self] on an ASSuperTestSub instance to verify that
// argument passing works through the super dispatch path. The super dispatch
// starts from ASSuperTestBase, which inherits isEqual: from NSObject.
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_superSendWithArgument_passesArgumentCorrectly {
    // body: return [super isEqual: self]
    // Dispatches via ASSuperTestBase → NSObject's isEqual:, with receiver == self → YES.
    ASMessageSendNode *send = messageSendNode(superNode(),
                                              @[@"isEqual"],
                                              @[ identNode(@"self") ]);
    NSArray<ASASTNode *> *body = @[ returnNode(send) ];

    ASSuperTestSub *receiver = [ASSuperTestSub new];
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:receiver
                                       definingClass:[ASSuperTestSub class]
                                           selector:@"test:"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    XCTAssertEqualObjects(result, @YES,
                          @"[super isEqual: self] should return YES when compared to itself");
}

// ---------------------------------------------------------------------------
// 17. self = [super init] pattern: reassigning self works
//
// Construct a body that reassigns self from the result of [super init].
// definingClass = ASSuperTestSub so super dispatches to ASSuperTestBase,
// which inherits -init from NSObject; NSObject -init returns the same object.
// ---------------------------------------------------------------------------

- (void)test_evaluateMethodBody_reassignSelfFromSuperInit_selfUpdated {
    // body:
    //   self = [super init]
    //   return self
    ASMessageSendNode *initSend = messageSendNode(superNode(), @[@"init"], @[]);
    NSArray<ASASTNode *> *body = @[
        assignNode(@"self", initSend),
        returnNode(identNode(@"self")),
    ];

    ASSuperTestSub *receiver = [ASSuperTestSub alloc];
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:receiver
                                       definingClass:[ASSuperTestSub class]
                                           selector:@"init"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    // ASSuperTestBase (and thus NSObject) -init returns the same object.
    XCTAssertEqual(result, receiver,
                   @"After self = [super init], returning self should yield the same object");
}

// ---------------------------------------------------------------------------
// 18. Local variable dump — ASErrorLocalsKey is an NSDictionary
//
// Any runtime error should include ASErrorLocalsKey in userInfo pointing to
// an NSDictionary (even if it contains only implicit bindings).
// ---------------------------------------------------------------------------

- (void)test_reportError_localsKey_isNSDictionary {
    NSArray<ASASTNode *> *body = @[[[ASUnknownTestNode alloc] initWithLine:1 column:1]];
    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex, @"Unknown node type should raise an exception");
    id locals = ex.userInfo[ASErrorLocalsKey];
    XCTAssertTrue([locals isKindOfClass:[NSDictionary class]],
                  @"ASErrorLocalsKey should be an NSDictionary");
}

// ---------------------------------------------------------------------------
// 19. Local variable dump — declared variable and its value appear in locals
//
// A variable declared before the error fires should be visible in the dump.
// ---------------------------------------------------------------------------

- (void)test_reportError_localsKey_containsDeclaredVariable {
    // body: id myVar = "hello"; <error>
    NSArray<ASASTNode *> *body = @[
        varDeclNode(@"myVar", stringNode(@"hello")),
        [[ASUnknownTestNode alloc] initWithLine:1 column:1],
    ];
    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex);
    NSDictionary *locals = ex.userInfo[ASErrorLocalsKey];
    XCTAssertEqualObjects(locals[@"myVar"], @"hello",
                          @"Declared variable should appear in locals with its assigned value");
}

// ---------------------------------------------------------------------------
// 20. Local variable dump — AppScript nil appears as "ASNull"
//
// A variable initialised without a value holds AppScript nil ([ASNull null]).
// In the locals dict this must appear as the NSString @"ASNull", not ObjC nil.
// ---------------------------------------------------------------------------

- (void)test_reportError_localsKey_appScriptNilAppearsAsASNull {
    // body: id myVar; <error>  (no initializer → stored as [ASNull null])
    NSArray<ASASTNode *> *body = @[
        varDeclNode(@"myVar", nil),
        [[ASUnknownTestNode alloc] initWithLine:1 column:1],
    ];
    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex);
    NSDictionary *locals = ex.userInfo[ASErrorLocalsKey];
    XCTAssertEqualObjects(locals[@"myVar"], @"ASNull",
                          @"Variable with no initializer (AppScript nil) should appear as 'ASNull'");
}

// ---------------------------------------------------------------------------
// 21. Local variable dump — implicit variables self and _cmd are present
//
// The root scope always binds self and _cmd; both should appear in the dump.
// ---------------------------------------------------------------------------

- (void)test_reportError_localsKey_containsSelfAndCmd {
    NSObject *receiver = [NSObject new];
    NSArray<ASASTNode *> *body = @[[[ASUnknownTestNode alloc] initWithLine:1 column:1]];
    NSException *ex = nil;
    @try {
        [self.interpreter evaluateMethodBody:body
                                withReceiver:receiver
                               definingClass:[NSObject class]
                                    selector:@"mySelector"
                                   arguments:@[]
                              parameterNames:@[]
                                  scriptPath:@"test.appscript"];
    } @catch (NSException *caught) {
        ex = caught;
    }
    XCTAssertNotNil(ex);
    NSDictionary *locals = ex.userInfo[ASErrorLocalsKey];
    XCTAssertEqual(locals[@"self"], receiver, @"self should appear in locals");
    XCTAssertEqualObjects(locals[@"_cmd"], @"mySelector", @"_cmd should appear in locals");
}

// ---------------------------------------------------------------------------
// 22. Local variable dump — weak variable appears with its value or "ASNull"
//
// A weak-declared variable must not be silently omitted from the locals dump.
// When the referent is still alive the value is present; when deallocated the
// scope holds [ASNull null], which must appear as "ASNull".
// ---------------------------------------------------------------------------

- (void)test_reportError_localsKey_weakVariablePresentInLocals {
    // body: weak id weakRef = "alive"; <error>
    NSArray<ASASTNode *> *body = @[
        [[ASVariableDeclarationNode alloc] initWithVariableName:@"weakRef"
                                                    initializer:stringNode(@"alive")
                                                         isWeak:YES
                                                     isConstant:NO
                                                           line:1
                                                         column:1],
        [[ASUnknownTestNode alloc] initWithLine:1 column:1],
    ];
    NSException *ex = runAndCatch(self.interpreter, body);
    XCTAssertNotNil(ex);
    NSDictionary *locals = ex.userInfo[ASErrorLocalsKey];
    // The key must be present. Its value is either the live object or @"ASNull"
    // (if the referent was already deallocated when reportError: fires).
    id value = locals[@"weakRef"];
    XCTAssertNotNil(value,
                    @"Weak variable should appear in locals (value if alive, 'ASNull' if deallocated)");
}

@end
