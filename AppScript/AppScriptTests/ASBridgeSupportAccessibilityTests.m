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
#import <objc/runtime.h>
#import <dlfcn.h>
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASBridgeSupportInstaller.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportFunction.h>
#import <AppScript/ASBridgeSupportConstant.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASBridgeSupportStructField.h>
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
    // Load Foundation's companion dylib so NSZeroRect is dlsym-able.
    NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
    NSURL *companionURL = [[[foundationBundle resourceURL]
                             URLByAppendingPathComponent:@"BridgeSupport"]
                             URLByAppendingPathComponent:@"Foundation.dylib"];
    dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

    ASBridgeSupportStructField *originField = [[ASBridgeSupportStructField alloc]
        initWithName:@"origin" typeEncoding:@"{CGPoint=dd}"];
    ASBridgeSupportStructField *sizeField = [[ASBridgeSupportStructField alloc]
        initWithName:@"size" typeEncoding:@"{CGSize=dd}"];
    ASBridgeSupportStruct *rectStruct = [[ASBridgeSupportStruct alloc]
        initWithCanonicalName:@"CGRect"
                       fields:@[originField, sizeField]];

    ASBridgeSupportConstant *constant = [[ASBridgeSupportConstant alloc]
        initWithName:@"NSZeroRect"
        typeEncoding:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];

    ASBridgeSupportFunction *func = [[ASBridgeSupportFunction alloc]
                     initWithName:@"setFrame"
               returnTypeEncoding:@"v"
            argumentTypeEncodings:@[@"{CGRect={CGPoint=dd}{CGSize=dd}}"]
                       isVariadic:NO
                         isInline:NO
       hasFunctionPointerArguments:NO];

    return [[ASBridgeSupportDocument alloc]
        initWithFunctions:@[func]
                constants:@[constant]
             enumerations:@[]
                  structs:@[rectStruct]];
}

- (void)test_identifierResolutionForProxyClass {
    // 1. Install a proxy class ASTestAccessibilityFW1
    ASBridgeSupportDocument *doc = [self createTestDocument];
    [self.installer installDocument:doc frameworkName:@"TestAccessibilityFW1" error:nil];
    
    // 2. Evaluate bare identifier 'ASTestAccessibilityFW1'
    // body: return ASTestAccessibilityFW1
    ASIdentifierNode *ident = [[ASIdentifierNode alloc] initWithName:@"ASTestAccessibilityFW1" line:1 column:1];
    NSArray<ASASTNode *> *body = @[ [[ASReturnNode alloc] initWithValue:ident line:1 column:1] ];
    
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                       definingClass:[NSObject class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    
    XCTAssertNotNil(result, @"ASTestAccessibilityFW1 should be resolved to a class object");
    XCTAssertTrue(class_isMetaClass(object_getClass(result)),
                  @"Result should be a Class object");
}

- (void)test_structUnboxingAtCallSite {
    // 1. Install proxy class ASTestAccessibilityFW2
    ASBridgeSupportDocument *doc = [self createTestDocument];
    [self.installer installDocument:doc frameworkName:@"TestAccessibilityFW2" error:nil];
    
    // 2. Create a mock object that implements -setFrame:
    ASStructMock *mock = [[ASStructMock alloc] init];
    mock.lastFrame = NSMakeRect(1, 2, 3, 4);
    
    // AppScript code: [mock setFrame:[ASTestAccessibilityFW2 NSZeroRect]]
    ASIdentifierNode *receiverIdent = [[ASIdentifierNode alloc] initWithName:@"mock" line:1 column:1];
    ASIdentifierNode *classIdent = [[ASIdentifierNode alloc] initWithName:@"ASTestAccessibilityFW2" line:1 column:1];
    ASMessageSendNode *constSend = [[ASMessageSendNode alloc] initWithReceiver:classIdent 
                                                               selectorParts:@[@"NSZeroRect"] 
                                                                 arguments:@[] 
                                                                      line:1 
                                                                    column:1];
    
    // Outer send: [mock setFrame: <constSend>]
    ASMessageSendNode *outerSend = [[ASMessageSendNode alloc] initWithReceiver:receiverIdent 
                                                                selectorParts:@[@"setFrame"] 
                                                                  arguments:@[constSend] 
                                                                       line:1 
                                                                     column:1];
    
    NSArray<ASASTNode *> *body = @[ [[ASReturnNode alloc] initWithValue:outerSend line:1 column:1] ];
    
    id result = [self.interpreter evaluateMethodBody:body
                                        withReceiver:[NSObject new]
                                       definingClass:[NSObject class]
                                           selector:@"test:"
                                          arguments:@[mock]
                                     parameterNames:@[@"mock"]
                                         scriptPath:@"test.appscript"];
    
    XCTAssertNil(result, @"setFrame: returns void");
    XCTAssertTrue(NSEqualRects(mock.lastFrame, NSZeroRect),
                  @"mock.lastFrame should be updated to NSZeroRect");
}

@end
