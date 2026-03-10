// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASRuntimeInstallerTests.m — Unit tests for ASRuntimeInstaller
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
#import <AppScript/ASRuntimeInstaller.h>
#import <AppScript/ASASTNode.h>
#import <AppScript/ASClassDefinitionNode.h>
#import <AppScript/ASCategoryDefinitionNode.h>
#import <AppScript/ASMethodNode.h>
#import <AppScript/ASPropertyNode.h>
#import <AppScript/ASReturnNode.h>
#import <AppScript/ASStringLiteralNode.h>

// ---------------------------------------------------------------------------
// Convenience helpers
// ---------------------------------------------------------------------------

static NSString *uniqueClassName(NSString *prefix) {
    return [NSString stringWithFormat:@"%@_%@", prefix,
            [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

/// Build a zero-argument instance method node with the given selector and a body of `return @"value"`.
static ASMethodNode *zeroArgMethodNamed(NSString *selectorName, NSString *returnValue) {
    ASStringLiteralNode *literal = [[ASStringLiteralNode alloc] initWithValue:returnValue
                                                                         line:1
                                                                       column:1];
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:literal line:1 column:1];
    return [[ASMethodNode alloc] initWithSelectorParts:@[selectorName]
                                       parameterNames:@[]
                                                 body:@[ret]
                                        isClassMethod:NO
                                                 line:1
                                               column:1];
}

/// Build a simple class definition node for a class with NSObject as superclass.
static ASClassDefinitionNode *simpleClassNamed(NSString *className,
                                                NSArray<ASMethodNode *> *methods) {
    return [[ASClassDefinitionNode alloc] initWithClassName:className
                                             superclassName:@"NSObject"
                                              protocolNames:@[]
                                                 properties:@[]
                                                    methods:methods
                                                       line:1
                                                     column:1];
}

// ---------------------------------------------------------------------------
// Test class
// ---------------------------------------------------------------------------

/// Tests for ASRuntimeInstaller — verifying that AppScript class/category definitions are
/// correctly registered as live Objective-C classes with callable methods.
@interface ASRuntimeInstallerTests : XCTestCase
@property (nonatomic) ASRuntimeInstaller *installer;
@end

@implementation ASRuntimeInstallerTests

- (void)setUp {
    [super setUp];
    self.installer = [[ASRuntimeInstaller alloc] init];
}

- (void)tearDown {
    self.installer = nil;
    [super tearDown];
}

// ---------------------------------------------------------------------------
// 1. Empty node array succeeds.
// ---------------------------------------------------------------------------

- (void)test_installNodes_emptyArray_returnsYES {
    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[]
                                    scriptPath:@"test.appscript"
                                         error:&error];
    XCTAssertTrue(result, @"Installing an empty node array should succeed");
    XCTAssertNil(error, @"No error should be set for an empty node array");
}

// ---------------------------------------------------------------------------
// 2. A class definition registers the class in the runtime.
// ---------------------------------------------------------------------------

- (void)test_installNodes_classDefinition_registersClass {
    NSString *className = uniqueClassName(@"ASTestRegister");
    ASClassDefinitionNode *classDef = simpleClassNamed(className, @[]);

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];

    XCTAssertTrue(result, @"Installing a valid class definition should succeed");
    XCTAssertNil(error, @"No error should be set for a valid class definition");
    XCTAssertNotNil(NSClassFromString(className),
                    @"The installed class should be findable by NSClassFromString");
}

// ---------------------------------------------------------------------------
// 3. A method defined on an installed class responds and returns the correct value.
// ---------------------------------------------------------------------------

- (void)test_installNodes_classDefinition_methodResponds {
    NSString *className = uniqueClassName(@"ASTestMethod");
    ASMethodNode *greetMethod = zeroArgMethodNamed(@"greet", @"hello");
    ASClassDefinitionNode *classDef = simpleClassNamed(className, @[greetMethod]);

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];

    XCTAssertTrue(result, @"Installing the class should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"The class must be registered");

    id instance = [[installedClass alloc] init];
    XCTAssertNotNil(instance, @"Should be able to instantiate the class");

    SEL greetSel = NSSelectorFromString(@"greet");
    XCTAssertTrue([instance respondsToSelector:greetSel],
                  @"The instance should respond to -greet");

    // Invoke via performSelector (safe for id-returning methods).
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id returned = [instance performSelector:greetSel];
#pragma clang diagnostic pop

    XCTAssertEqualObjects(returned, @"hello",
                          @"-greet should return @\"hello\" as defined in the method body");
}

// ---------------------------------------------------------------------------
// 4. Specifying an unknown superclass returns NO with the correct error.
// ---------------------------------------------------------------------------

- (void)test_installNodes_unknownSuperclass_returnsNO {
    NSString *className = uniqueClassName(@"ASTestBadSuper");
    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSNonexistentClass123"
                                           protocolNames:@[]
                                              properties:@[]
                                                 methods:@[]
                                                    line:1
                                                  column:1];

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];

    XCTAssertFalse(result, @"Installing a class with an unknown superclass should fail");
    XCTAssertNotNil(error, @"An error should be set");
    XCTAssertEqualObjects(error.domain, ASRuntimeInstallerErrorDomain,
                          @"Error should be in ASRuntimeInstallerErrorDomain");
    XCTAssertEqual(error.code, ASRuntimeInstallerErrorUnknownSuperclass,
                   @"Error code should be ASRuntimeInstallerErrorUnknownSuperclass");
}

// ---------------------------------------------------------------------------
// 5. Installing the same class name twice returns NO with a duplicate-class error.
// ---------------------------------------------------------------------------

- (void)test_installNodes_duplicateClass_returnsNO {
    NSString *className = uniqueClassName(@"ASTestDuplicate");
    ASClassDefinitionNode *classDef = simpleClassNamed(className, @[]);

    // First install should succeed.
    NSError *error = nil;
    BOOL first = [self.installer installNodes:@[classDef]
                                   scriptPath:@"test.appscript"
                                        error:&error];
    XCTAssertTrue(first, @"First installation should succeed");

    // Second install with the same class name should fail.
    NSError *secondError = nil;
    BOOL second = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&secondError];

    XCTAssertFalse(second, @"Installing the same class name a second time should fail");
    XCTAssertNotNil(secondError, @"An error should be set on the second attempt");
    XCTAssertEqualObjects(secondError.domain, ASRuntimeInstallerErrorDomain,
                          @"Error should be in ASRuntimeInstallerErrorDomain");
    XCTAssertEqual(secondError.code, ASRuntimeInstallerErrorDuplicateClass,
                   @"Error code should be ASRuntimeInstallerErrorDuplicateClass");
}

// ---------------------------------------------------------------------------
// 6. A synthesized property has getter and setter accessible via respondsToSelector:.
// ---------------------------------------------------------------------------

- (void)test_installNodes_property_synthesizesAccessors {
    NSString *className = uniqueClassName(@"ASTestProperty");
    ASPropertyNode *nameProp = [[ASPropertyNode alloc] initWithPropertyName:@"name"
                                                                   modifiers:@[@"strong"]
                                                                        line:1
                                                                      column:1];
    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[]
                                              properties:@[nameProp]
                                                 methods:@[]
                                                    line:1
                                                  column:1];

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];

    XCTAssertTrue(result, @"Installing the class should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"The class must be registered");

    id instance = [[installedClass alloc] init];
    XCTAssertNotNil(instance, @"Should be able to instantiate the class");

    XCTAssertTrue([instance respondsToSelector:NSSelectorFromString(@"name")],
                  @"The instance should respond to the getter -name");
    XCTAssertTrue([instance respondsToSelector:NSSelectorFromString(@"setName:")],
                  @"The instance should respond to the setter -setName:");
}

// ---------------------------------------------------------------------------
// 7. A category definition installs its methods on an existing class.
// ---------------------------------------------------------------------------

- (void)test_installNodes_categoryDefinition_addsMethod {
    // We add a category on NSString that returns a known value.
    // Use a unique selector to avoid collision with existing NSString methods.
    NSString *selectorName = [NSString stringWithFormat:@"appScriptGreeting_%@",
                              [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];

    ASMethodNode *method = zeroArgMethodNamed(selectorName, @"hello from category");
    ASCategoryDefinitionNode *categoryDef = [[ASCategoryDefinitionNode alloc]
                                             initWithClassName:@"NSString"
                                               categoryName:@"AppScriptTest"
                                                    methods:@[method]
                                                       line:1
                                                     column:1];

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[categoryDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];

    XCTAssertTrue(result, @"Installing a category should succeed");
    XCTAssertNil(error, @"No error should be set");

    NSString *testString = @"test";
    SEL categorySel = NSSelectorFromString(selectorName);
    XCTAssertTrue([testString respondsToSelector:categorySel],
                  @"NSString instance should respond to the category method");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id returned = [testString performSelector:categorySel];
#pragma clang diagnostic pop

    XCTAssertEqualObjects(returned, @"hello from category",
                          @"The category method should return the value defined in its body");
}

@end
