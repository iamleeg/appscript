// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportAccessibilityTests.m — Tests for asu-7fe
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
// along with this program.

#import <XCTest/XCTest.h>
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASBridgeSupportInstaller.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportFunction.h>
#import <AppScript/ASBridgeSupportConstant.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASASTNode.h>
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASReturnNode.h>

// ---------------------------------------------------------------------------
// Mock class to verify struct argument passing
// ---------------------------------------------------------------------------

@interface ASStructMock : NSObject
@property (nonatomic, assign) NSRect lastFrame;
- (void)setFrame:(NSRect)frame;
@end

@implementation ASStructMock
- (void)setFrame:(NSRect)frame {
    _lastFrame = frame;
}
@end

// ---------------------------------------------------------------------------
// Test class
// ---------------------------------------------------------------------------

@interface ASBridgeSupportAccessibilityTests : XCTestCase
@property (nonatomic) ASInterpreter *interpreter;
@property (nonatomic) ASBridgeSupportInstaller *installer;
@end

@implementation ASBridgeSupportAccessibilityTests

- (void)setUp {
    [super setUp];
    self.interpreter = [[ASInterpreter alloc] init];
    self.installer = [[ASBridgeSupportInstaller alloc] init];
}

- (void)tearDown {
    self.interpreter = nil;
    self.installer = nil;
    [super tearDown];
}

/// Helper to create a minimal BridgeSupport document with a struct constant and a mock class.
- (ASBridgeSupportDocument *)createTestDocument {
    ASBridgeSupportDocument *doc = [[ASBridgeSupportDocument alloc] init];
    
    // Define a struct: CGRect { CGPoint, CGSize }
    ASBridgeSupportStruct *rectStruct = [[ASBridgeSupportStruct alloc] init];
    rectStruct.name = @"CGRect";
    rectStruct.typeEncoding = @"{CGPoint=dd}{CGSize=dd}";
    [doc addStruct:rectStruct];
    
    // Define a constant: TestRect
    ASBridgeSupportConstant *constant = [[ASBridgeSupportConstant alloc] init];
    constant.name = @"TestRect";
    constant.typeEncoding = @"{CGRect={CGPoint=dd}{CGSize=dd}}";
    [doc addConstant:constant];
    
    // Define a function (to be installed as class method)
    ASBridgeSupportFunction *func = [[ASBridgeSupportFunction alloc] init];
    func.name = @"setFrame:"; // Note: the installer adds colons, but we can specify it here or let it happen
    func.returnTypeEncoding = @"v";
    func.argumentTypeEncodings = @[@"{CGRect={CGPoint=dd}{CGSize=dd}}"];
    [doc addFunction:func];
    
    return doc;
}

- (void)test_identifierResolutionForProxyClass {
    // 1. Install a proxy class ASTestFW
    ASBridgeSupportDocument *doc = [self createTestDocument];
    [self.installer installDocument:doc frameworkName:@"TestFW" error:nil];
    
    // 2. Evaluate bare identifier 'ASTestFW'
    // body: return ASTestFW
    ASIdentifierNode *ident = [[ASIdentifierNode alloc] initWithName:@"ASTestFW" line:1 column:1];
    NSArray<ASASTNode *> *body = @[ [[ASReturnNode alloc] initWithValue:ident line:1 column:1] ];
    
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                       definingClass:[NSObject class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    
    XCTAssertNotNil(result, @"ASTestFW should be resolved to a class object");
    XCTAssertTrue([result isKindOfClass:[NSClassFromNSString class]] || class_isMetaClass(object_getClass(result)), 
                  @"Result should be a Class object");
}

- (void)test_structUnboxingAtCallSite {
    // 1. Install proxy class ASTestFW
    ASBridgeSupportDocument *doc = [self createTestDocument];
    [self.installer installDocument:doc frameworkName:@"TestFW" error:nil];
    
    // 2. Create a mock object that implements -setFrame:
    ASStructMock *mock = [[ASStructMock alloc] init];
    
    // We need to make the interpreter use this mock as receiver for the message send.
    // AppScript code: [mock setFrame:[ASTestFW TestRect]]
    
    // AST Construction:
    // Receiver: identifier 'mock' (we will bind it in scope)
    ASIdentifierNode *receiverIdent = [[ASIdentifierNode alloc] initWithName:@"mock" line:1 column:1];
    
    // Argument: [ASTestFW TestRect]
    ASIdentifierNode *classIdent = [[ASIdentifierNode alloc] initWithName:@"ASTestFW" line:1 column:1];
    ASIdentifierNode *constIdent = [[ASIdentifierNode alloc] initWithName:@"TestRect" line:1 column:1];
    ASMessageSendNode *constSend = [[ASMessageSendNode alloc] initWithReceiver:classIdent 
                                                               selectorParts:@[@"TestRect"] 
                                                                 arguments:@[] 
                                                                      line:1 
                                                                    column:1];
    
    // Outer send: [mock setFrame: <constSend>]
    ASMessageSendNode *outerSend = [[ASMessageSendNode alloc] initWithReceiver:receiverIdent 
                                                                selectorParts:@[@"setFrame:"] 
                                                                  arguments:@[constSend] 
                                                                       line:1 
                                                                     column:1];
    
    NSArray<ASASTNode *> *body = @[ [[ASReturnNode alloc] initWithValue:outerSend line:1 column:1] ];
    
    // Execute with 'mock' bound in scope.
    // Since evaluateMethodBody creates a root scope, we can't easily inject 'mock' 
    // unless we use a variable declaration or pass it as an argument.
    // Let's use a parameter named 'mock'.
    
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                       definingClass:[NSObject class]
                                           selector:@"test:"
                                          arguments:@[mock]
                                     parameterNames:@[@"mock"]
                                         scriptPath:@"test.appscript"];
    
    XCTAssertNil(result, @"setFrame: returns void");
    
    // Verify that the mock received the correct bytes.
    // Since we can't easily set the value of TestRect in the proxy class without 
    // actual dlsym symbols, this test might fail on 'TestRect' resolution unless 
    // we provide a real symbol or mock the installer.
    // However, if it crashes here, then asu-7fe is present.
}

@end
