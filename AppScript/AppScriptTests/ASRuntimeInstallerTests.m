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
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASNumberLiteralNode.h>
#import <AppScript/ASOutObject.h>
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASSuperNode.h>
#import <AppScript/ASVariableDeclarationNode.h>
#import <AppScript/ASNull.h>
#import <AppScript/ASArrayLiteralNode.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

/// Build a class definition node with a single weak property.
static ASClassDefinitionNode *classWithWeakPropertyNamed(NSString *className,
                                                          NSString *propertyName) {
    ASPropertyNode *weakProp = [[ASPropertyNode alloc] initWithPropertyName:propertyName
                                                                   modifiers:@[@"weak"]
                                                                        line:1
                                                                      column:1];
    return [[ASClassDefinitionNode alloc] initWithClassName:className
                                             superclassName:@"NSObject"
                                              protocolNames:@[]
                                                 properties:@[weakProp]
                                                    methods:@[]
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
// Protocol used by test 7 to verify BOOL-returning protocol method encoding.
// ---------------------------------------------------------------------------

@protocol ASTestBoolProtocol <NSObject>
- (BOOL)returnsBool;
@end

// ---------------------------------------------------------------------------
// Protocols used by auto-conformance tests.
// ---------------------------------------------------------------------------

@protocol ASTestAutoConformProtocol <NSObject>
- (NSString *)autoMethod;
@end

@protocol ASTestPropertyConformProtocol <NSObject>
@property (nonatomic, strong) NSString *label;
@end

@protocol ASTestSelectorReturnProtocol <NSObject>
- (SEL)returnsSelector;
@end

@protocol ASTestVoidProtocol <NSObject>
- (void)doNothing;
@end

@protocol ASTestOutErrorProtocol <NSObject>
- (BOOL)saveData:(NSString *)data error:(NSError **)error;
@end

@interface ASTestStructSuperclass : NSObject
- (NSRange)echoRange:(NSRange)range;
@end

@implementation ASTestStructSuperclass
- (NSRange)echoRange:(NSRange)range {
    return NSMakeRange(0, 0);
}
@end

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
// 7. A class conforming to a protocol with a BOOL-returning method installs
//    the sentinel with the protocol's type encoding (not the all-id fallback),
//    and calling the method correctly unboxes the BOOL return value.
// ---------------------------------------------------------------------------

- (void)test_installNodes_protocolBOOLMethod_usesProtocolEncoding {
    NSString *className = uniqueClassName(@"ASTestBoolProto");

    // Force ASTestBoolProtocol into the ObjC runtime's protocol table.
    // Without a @protocol() expression the compiler may not emit it into __objc_protolist,
    // causing objc_getProtocol() to return NULL and class_addProtocol to be skipped.
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestBoolProtocol);

    // Build: - returnsBool { return YES }
    ASIdentifierNode *yesNode = [[ASIdentifierNode alloc] initWithName:@"YES" line:1 column:1];
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:yesNode line:1 column:1];
    ASMethodNode *method = [[ASMethodNode alloc] initWithSelectorParts:@[@"returnsBool"]
                                                        parameterNames:@[]
                                                                  body:@[ret]
                                                         isClassMethod:NO
                                                                  line:1
                                                                column:1];

    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[@"ASTestBoolProtocol"]
                                              properties:@[]
                                                 methods:@[method]
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

    // The sentinel IMP should carry the BOOL encoding from the protocol, not the all-id fallback.
    Method m = class_getInstanceMethod(installedClass, @selector(returnsBool));
    XCTAssertTrue(m != NULL, @"Method should be installed");
    const char *encoding = method_getTypeEncoding(m);
    // Protocol declares BOOL return: encoding must NOT start with '@' (id — the all-id fallback).
    // On arm64 macOS, BOOL is bool, encoding 'B'; on legacy x86 it was 'c' (signed char).
    XCTAssertNotEqual(encoding[0], '@',
                      @"Sentinel encoding should use protocol's BOOL return type, not id (@)");

    // Calling the method should return YES.
    id instance = [[installedClass alloc] init];
    BOOL boolResult = ((BOOL (*)(id, SEL))objc_msgSend)(instance, @selector(returnsBool));
    XCTAssertTrue(boolResult, @"-returnsBool should return YES as defined in the method body");
}

// ---------------------------------------------------------------------------
// 8b. A class declared with a protocol conformance responds YES to
//     conformsToProtocol: at both the instance and class level.
// ---------------------------------------------------------------------------

- (void)test_installNodes_protocolConformance_conformsToProtocolReturnsYES {
    NSString *className = uniqueClassName(@"ASTestProtoConforms");

    // Force ASTestBoolProtocol into the ObjC runtime's protocol table so that
    // objc_getProtocol() can find it and class_addProtocol() can register it.
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestBoolProtocol);

    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[@"ASTestBoolProtocol"]
                                              properties:@[]
                                                 methods:@[]
                                                    line:1
                                                  column:1];

    NSError *error = nil;
    BOOL installed = [self.installer installNodes:@[classDef]
                                       scriptPath:@"test.appscript"
                                            error:&error];
    XCTAssertTrue(installed, @"Installation should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"Class must be registered in the ObjC runtime");

    // Instance-level check
    id instance = [[installedClass alloc] init];
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestBoolProtocol)],
                  @"Instance should conform to ASTestBoolProtocol");

    // Class-level check
    XCTAssertTrue([installedClass conformsToProtocol:@protocol(ASTestBoolProtocol)],
                  @"Class object should also conform to ASTestBoolProtocol");
}

// ---------------------------------------------------------------------------
// 8c. A class declared with multiple comma-separated protocols conforms to
//     all of them and resolves method signatures across all listed protocols.
// ---------------------------------------------------------------------------

- (void)test_installNodes_multipleProtocols_conformsToAllAndResolvesSignatures {
    NSString *className = uniqueClassName(@"ASTestMultiProto");

    __attribute__((unused)) Protocol *_ensureBool = @protocol(ASTestBoolProtocol);
    __attribute__((unused)) Protocol *_ensureAuto = @protocol(ASTestAutoConformProtocol);
    __attribute__((unused)) Protocol *_ensureOut  = @protocol(ASTestOutErrorProtocol);

    // Build `- returnsBool { return YES }` (from ASTestBoolProtocol)
    ASIdentifierNode *yesNode = [[ASIdentifierNode alloc] initWithName:@"YES" line:1 column:1];
    ASReturnNode *retYes = [[ASReturnNode alloc] initWithValue:yesNode line:1 column:1];
    ASMethodNode *boolMethod = [[ASMethodNode alloc] initWithSelectorParts:@[@"returnsBool"]
                                                            parameterNames:@[]
                                                                      body:@[retYes]
                                                             isClassMethod:NO
                                                                      line:1
                                                                    column:1];

    // Build `- saveData: data error: outErr { return YES }` (from ASTestOutErrorProtocol)
    ASMethodNode *saveMethod = [[ASMethodNode alloc] initWithSelectorParts:@[@"saveData", @"error"]
                                                            parameterNames:@[@"data", @"outErr"]
                                                                      body:@[retYes]
                                                             isClassMethod:NO
                                                                      line:2
                                                                    column:1];

    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[@"ASTestBoolProtocol",
                                                           @"ASTestAutoConformProtocol",
                                                           @"ASTestOutErrorProtocol"]
                                              properties:@[]
                                                 methods:@[boolMethod, saveMethod]
                                                    line:1
                                                  column:1];

    NSError *error = nil;
    BOOL installed = [self.installer installNodes:@[classDef]
                                       scriptPath:@"test.appscript"
                                            error:&error];
    XCTAssertTrue(installed, @"Installation with multiple protocols should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"Class must be registered in the ObjC runtime");

    id instance = [[installedClass alloc] init];
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestBoolProtocol)],
                  @"Instance should conform to first protocol (ASTestBoolProtocol)");
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestAutoConformProtocol)],
                  @"Instance should conform to second protocol (ASTestAutoConformProtocol)");
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestOutErrorProtocol)],
                  @"Instance should conform to third protocol (ASTestOutErrorProtocol)");

    XCTAssertTrue([installedClass conformsToProtocol:@protocol(ASTestBoolProtocol)]);
    XCTAssertTrue([installedClass conformsToProtocol:@protocol(ASTestAutoConformProtocol)]);
    XCTAssertTrue([installedClass conformsToProtocol:@protocol(ASTestOutErrorProtocol)]);

    // Verify method signatures from multiple protocols are resolved properly
    BOOL boolResult = ((BOOL (*)(id, SEL))objc_msgSend)(instance, @selector(returnsBool));
    XCTAssertTrue(boolResult, @"-returnsBool from first protocol should unbox BOOL return");

    NSError *outError = nil;
    BOOL saveResult = [((id<ASTestOutErrorProtocol>)instance) saveData:@"payload" error:&outError];
    XCTAssertTrue(saveResult, @"-saveData:error: from third protocol should unbox BOOL return");
    XCTAssertNil(outError);
}

// ---------------------------------------------------------------------------
// 9. A category definition installs its methods on an existing class.
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

// ---------------------------------------------------------------------------
// 10–13. Weak property semantics: zeroing weak references via ASWeakPropertyBox.
// ---------------------------------------------------------------------------

- (void)test_weakProperty_getterReturnsValueWhileTargetIsAlive {
    NSString *className = uniqueClassName(@"ASTestWeakAlive");
    ASClassDefinitionNode *classDef = classWithWeakPropertyNamed(className, @"delegate");

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];
    XCTAssertTrue(result, @"Installing the class should succeed");
    XCTAssertNil(error);

    Class installedClass = NSClassFromString(className);
    id instance = [[installedClass alloc] init];
    NSObject *target = [[NSObject alloc] init];

    SEL setter = NSSelectorFromString(@"setDelegate:");
    SEL getter = NSSelectorFromString(@"delegate");

    XCTAssertTrue([instance respondsToSelector:setter], @"Should respond to -setDelegate:");
    XCTAssertTrue([instance respondsToSelector:getter], @"Should respond to -delegate");

    ((void (*)(id, SEL, id))objc_msgSend)(instance, setter, target);
    id retrieved = ((id (*)(id, SEL))objc_msgSend)(instance, getter);
    XCTAssertEqual(retrieved, target,
                   @"Weak property getter should return the target while it is alive");
}

- (void)test_weakProperty_getterReturnsNilAfterTargetDeallocated {
    NSString *className = uniqueClassName(@"ASTestWeakDealloc");
    ASClassDefinitionNode *classDef = classWithWeakPropertyNamed(className, @"delegate");

    NSError *error = nil;
    [self.installer installNodes:@[classDef] scriptPath:@"test.appscript" error:&error];

    Class installedClass = NSClassFromString(className);
    id instance = [[installedClass alloc] init];

    SEL setter = NSSelectorFromString(@"setDelegate:");
    SEL getter = NSSelectorFromString(@"delegate");

    @autoreleasepool {
        NSObject *target = [[NSObject alloc] init];
        ((void (*)(id, SEL, id))objc_msgSend)(instance, setter, target);
        id retrieved = ((id (*)(id, SEL))objc_msgSend)(instance, getter);
        XCTAssertNotNil(retrieved, @"Should be non-nil while target is alive");
        // `target` is released here when the autoreleasepool block exits.
    }

    id afterDealloc = ((id (*)(id, SEL))objc_msgSend)(instance, getter);
    XCTAssertNil(afterDealloc,
                 @"Weak property getter must return nil after the target has been deallocated");
}

- (void)test_weakProperty_owningObjectDeallocatesNormally {
    NSString *className = uniqueClassName(@"ASTestWeakOwnerDealloc");
    ASClassDefinitionNode *classDef = classWithWeakPropertyNamed(className, @"delegate");

    NSError *error = nil;
    [self.installer installNodes:@[classDef] scriptPath:@"test.appscript" error:&error];

    Class installedClass = NSClassFromString(className);
    NSObject *target = [[NSObject alloc] init];
    __weak NSObject *weakTarget = target;

    @autoreleasepool {
        id instance = [[installedClass alloc] init];
        SEL setter = NSSelectorFromString(@"setDelegate:");
        ((void (*)(id, SEL, id))objc_msgSend)(instance, setter, target);
        // `instance` is released here; weak property must not have retained `target`.
    }

    XCTAssertNotNil(weakTarget,
                    @"Target should still be alive — weak property must not have retained it");
    XCTAssertNotNil(target, @"Target object should be intact after owner dealloc");
}

- (void)test_weakProperty_settingNilIsHandledSafely {
    NSString *className = uniqueClassName(@"ASTestWeakNil");
    ASClassDefinitionNode *classDef = classWithWeakPropertyNamed(className, @"delegate");

    NSError *error = nil;
    [self.installer installNodes:@[classDef] scriptPath:@"test.appscript" error:&error];

    Class installedClass = NSClassFromString(className);
    id instance = [[installedClass alloc] init];

    SEL setter = NSSelectorFromString(@"setDelegate:");
    SEL getter = NSSelectorFromString(@"delegate");

    XCTAssertNoThrow(((void (*)(id, SEL, id))objc_msgSend)(instance, setter, nil),
                     @"Setting a weak property to nil should not crash");
    id result = ((id (*)(id, SEL))objc_msgSend)(instance, getter);
    XCTAssertNil(result, @"Getter should return nil after property is set to nil");
}

// ---------------------------------------------------------------------------
// Auto-conformance tests: ASAddMatchingProtocolsToClass
// ---------------------------------------------------------------------------

// 14. A class whose methods satisfy a protocol's required interface is automatically
//     conformed to that protocol after installation.
- (void)test_installClass_withMatchingProtocolMethods_autoConformsToProtocol {
    // Ensure the protocol is registered in the ObjC runtime.
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestAutoConformProtocol);

    NSString *className = uniqueClassName(@"ASTestAutoConform");
    ASMethodNode *method = zeroArgMethodNamed(@"autoMethod", @"auto");
    ASClassDefinitionNode *classDef = simpleClassNamed(className, @[method]);

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];
    XCTAssertTrue(result, @"Installation should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"Class must be registered");

    id instance = [[installedClass alloc] init];
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestAutoConformProtocol)],
                  @"Instance should auto-conform to ASTestAutoConformProtocol because all required methods are present");
}

// 15. A class that does NOT implement all of a protocol's required methods must NOT
//     be auto-conformed to that protocol.
- (void)test_installClass_withoutAllProtocolMethods_doesNotConform {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestAutoConformProtocol);

    NSString *className = uniqueClassName(@"ASTestNoAutoConform");
    // Install a class with no methods — autoMethod is missing.
    ASClassDefinitionNode *classDef = simpleClassNamed(className, @[]);

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];
    XCTAssertTrue(result, @"Installation should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"Class must be registered");

    id instance = [[installedClass alloc] init];
    XCTAssertFalse([instance conformsToProtocol:@protocol(ASTestAutoConformProtocol)],
                   @"Instance must NOT conform to ASTestAutoConformProtocol when autoMethod is absent");
}

// 16. A class with a synthesized property satisfying a property protocol is auto-conformed.
- (void)test_installClass_withMatchingPropertyProtocol_autoConforms {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestPropertyConformProtocol);

    NSString *className = uniqueClassName(@"ASTestPropertyConform");
    ASPropertyNode *labelProp = [[ASPropertyNode alloc] initWithPropertyName:@"label"
                                                                    modifiers:@[@"strong"]
                                                                         line:1
                                                                       column:1];
    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[]
                                              properties:@[labelProp]
                                                 methods:@[]
                                                    line:1
                                                  column:1];

    NSError *error = nil;
    BOOL result = [self.installer installNodes:@[classDef]
                                    scriptPath:@"test.appscript"
                                         error:&error];
    XCTAssertTrue(result, @"Installation should succeed");
    XCTAssertNil(error, @"No error should be set");

    Class installedClass = NSClassFromString(className);
    XCTAssertNotNil(installedClass, @"Class must be registered");

    id instance = [[installedClass alloc] init];
    XCTAssertTrue([instance conformsToProtocol:@protocol(ASTestPropertyConformProtocol)],
                  @"Instance should auto-conform to ASTestPropertyConformProtocol because getter and setter are synthesized");
}

// ---------------------------------------------------------------------------
// 17–18. NSError ** out-parameter handling in AppScript-implemented methods
// ---------------------------------------------------------------------------

- (void)test_installClass_methodWithNSErrorOutParam_writesBackErrorAndDoesNotCrash {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestOutErrorProtocol);

    NSString *className = uniqueClassName(@"ASTestOutError");

    // Build AppScript body for `- saveData: data error: outErr`:
    //   id err = [NSError errorWithDomain: @"ASTestErrorDomain" code: 42 userInfo: nil]
    //   [outErr setValue: err]
    //   return NO
    ASMessageSendNode *makeErr = [[ASMessageSendNode alloc]
        initWithReceiver:[[ASIdentifierNode alloc] initWithName:@"NSError" line:1 column:1]
           selectorParts:@[@"errorWithDomain", @"code", @"userInfo"]
               arguments:@[
                   [[ASStringLiteralNode alloc] initWithValue:@"ASTestErrorDomain" line:1 column:1],
                   [[ASNumberLiteralNode alloc] initWithValue:@42 line:1 column:1],
                   [[ASIdentifierNode alloc] initWithName:@"nil" line:1 column:1],
               ]
                    line:1
                  column:1];
    ASMessageSendNode *setVal = [[ASMessageSendNode alloc]
        initWithReceiver:[[ASIdentifierNode alloc] initWithName:@"outErr" line:2 column:1]
           selectorParts:@[@"setValue"]
               arguments:@[makeErr]
                    line:2
                  column:1];
    ASReturnNode *retNo = [[ASReturnNode alloc]
        initWithValue:[[ASIdentifierNode alloc] initWithName:@"NO" line:3 column:1]
                 line:3
               column:1];

    ASMethodNode *saveMethod = [[ASMethodNode alloc]
        initWithSelectorParts:@[@"saveData", @"error"]
               parameterNames:@[@"data", @"outErr"]
                         body:@[setVal, retNo]
                isClassMethod:NO
                         line:1
                       column:1];

    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
        initWithClassName:className
           superclassName:@"NSObject"
            protocolNames:@[@"ASTestOutErrorProtocol"]
               properties:@[]
                  methods:@[saveMethod]
                     line:1
                   column:1];

    NSError *installError = nil;
    BOOL installed = [self.installer installNodes:@[classDef]
                                       scriptPath:@"test.appscript"
                                            error:&installError];
    XCTAssertTrue(installed, @"Class installation should succeed");
    XCTAssertNil(installError);

    Class installedClass = NSClassFromString(className);
    id<ASTestOutErrorProtocol> instance = [[installedClass alloc] init];

    // 1. Call with non-NULL &callError — must not crash and must populate callError.
    NSError *callError = nil;
    BOOL ok = [instance saveData:@"hello" error:&callError];
    XCTAssertFalse(ok, @"saveData:error: should return NO");
    XCTAssertNotNil(callError, @"saveData:error: should write back the NSError via outErr");
    XCTAssertEqualObjects(callError.domain, @"ASTestErrorDomain");
    XCTAssertEqual(callError.code, 42);

    // 2. Call with NULL error — must not crash and must treat [outErr setValue:...] as no-op.
    BOOL okNull = [instance saveData:@"hello" error:nil];
    XCTAssertFalse(okNull, @"saveData:error: with nil error pointer should still return NO safely");
}

- (void)test_installClass_subclassOverridesNativeSuperclassStructMethod_withoutProtocol {
    NSString *className = uniqueClassName(@"ASTestStructSubclass");

    // Override `- echoRange: range { return range }` without adopting any protocol.
    ASReturnNode *retRange = [[ASReturnNode alloc]
        initWithValue:[[ASIdentifierNode alloc] initWithName:@"range" line:1 column:1]
                 line:1
               column:1];
    ASMethodNode *echoMethod = [[ASMethodNode alloc]
        initWithSelectorParts:@[@"echoRange"]
               parameterNames:@[@"range"]
                         body:@[retRange]
                isClassMethod:NO
                         line:1
                       column:1];

    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
        initWithClassName:className
           superclassName:@"ASTestStructSuperclass"
            protocolNames:@[]
               properties:@[]
                  methods:@[echoMethod]
                     line:1
                   column:1];

    NSError *installError = nil;
    BOOL installed = [self.installer installNodes:@[classDef]
                                       scriptPath:@"test.appscript"
                                            error:&installError];
    XCTAssertTrue(installed);
    XCTAssertNil(installError);

    Class installedClass = NSClassFromString(className);
    ASTestStructSuperclass *instance = [[installedClass alloc] init];
    NSRange result = [instance echoRange:NSMakeRange(12, 34)];
    XCTAssertEqual(result.location, (NSUInteger)12);
    XCTAssertEqual(result.length, (NSUInteger)34);
}

// ---------------------------------------------------------------------------
// Return value conversion failures
// ---------------------------------------------------------------------------

- (void)test_installNodes_unconvertibleReturnValue_raisesAtMethodDeclaration {
    // Ensure the protocol is emitted into the runtime so the installer can find it.
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestSelectorReturnProtocol);
    NSString *className = uniqueClassName(@"ASTestBadReturn");

    // Build (line 5): - returnsSelector { return 42 }
    ASNumberLiteralNode *fortyTwo = [[ASNumberLiteralNode alloc] initWithValue:@42 line:6 column:12];
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:fortyTwo line:6 column:5];
    ASMethodNode *method = [[ASMethodNode alloc] initWithSelectorParts:@[@"returnsSelector"]
                                                        parameterNames:@[]
                                                                  body:@[ret]
                                                         isClassMethod:NO
                                                                  line:5
                                                                column:1];
    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:@"NSObject"
                                           protocolNames:@[@"ASTestSelectorReturnProtocol"]
                                              properties:@[]
                                                 methods:@[method]
                                                    line:1
                                                  column:1];
    XCTAssertTrue([self.installer installNodes:@[classDef] scriptPath:@"bad.appscript" error:nil]);

    id instance = [[NSClassFromString(className) alloc] init];
    NSException *caught = nil;
    @try {
        (void)((SEL (*)(id, SEL))objc_msgSend)(instance, @selector(returnsSelector));
    } @catch (NSException *ex) {
        caught = ex;
    }

    XCTAssertEqualObjects(caught.name, ASRuntimeErrorException,
                          @"An unconvertible return value should raise instead of returning zero");
    XCTAssertEqualObjects(caught.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    XCTAssertEqualObjects(caught.userInfo[ASErrorScriptPathKey], @"bad.appscript");
    XCTAssertEqualObjects(caught.userInfo[ASErrorLineKey], @5);
    NSString *message = caught.userInfo[ASErrorMessageKey];
    NSString *expectedPrefix = [NSString stringWithFormat:
                                @"Cannot convert the return value of -[%@ returnsSelector] from ", className];
    XCTAssertTrue([message hasPrefix:expectedPrefix], @"%@", message);
    XCTAssertTrue([message hasSuffix:@" to SEL"], @"%@", message);
}

// ---------------------------------------------------------------------------
// Return value conversion for [super ...] dispatch to AppScript methods
// ---------------------------------------------------------------------------

/// Installs a class with one zero-argument instance method returning `value`,
/// declared at `line`, conforming to `protocolName`.
- (Class)installClassNamed:(NSString *)className
                superclass:(NSString *)superclassName
                  protocol:(nullable NSString *)protocolName
                  selector:(NSString *)selector
                      body:(NSArray<ASASTNode *> *)body
                      line:(NSUInteger)line {
    ASMethodNode *method = [[ASMethodNode alloc] initWithSelectorParts:@[selector]
                                                        parameterNames:@[]
                                                                  body:body
                                                         isClassMethod:NO
                                                                  line:line
                                                                column:1];
    ASClassDefinitionNode *classDef = [[ASClassDefinitionNode alloc]
                                       initWithClassName:className
                                          superclassName:superclassName
                                           protocolNames:protocolName ? @[protocolName] : @[]
                                              properties:@[]
                                                 methods:@[method]
                                                    line:1
                                                  column:1];
    XCTAssertTrue([self.installer installNodes:@[classDef] scriptPath:@"super.appscript" error:nil]);
    return NSClassFromString(className);
}

- (ASReturnNode *)returnNumber:(NSNumber *)n {
    return [[ASReturnNode alloc] initWithValue:[[ASNumberLiteralNode alloc] initWithValue:n line:1 column:1]
                                          line:1
                                        column:1];
}

- (void)test_superSend_unconvertibleReturnValueOfAppScriptSuperclass_raisesAtSuperclassDeclaration {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestSelectorReturnProtocol);
    NSString *baseName = uniqueClassName(@"ASTestSuperBase");
    NSString *subName = uniqueClassName(@"ASTestSuperSub");

    // Base (line 5): - returnsSelector { return 42 }
    [self installClassNamed:baseName superclass:@"NSObject" protocol:@"ASTestSelectorReturnProtocol"
                   selector:@"returnsSelector" body:@[[self returnNumber:@42]] line:5];

    // Sub (line 20): - returnsSelector { id x = [super returnsSelector]  return @"description" }
    ASMessageSendNode *superSend = [[ASMessageSendNode alloc] initWithReceiver:[[ASSuperNode alloc] initWithLine:21 column:12]
                                                                 selectorParts:@[@"returnsSelector"]
                                                                     arguments:@[]
                                                                          line:21
                                                                        column:12];
    ASVariableDeclarationNode *decl = [[ASVariableDeclarationNode alloc] initWithVariableName:@"x"
                                                                                  initializer:superSend
                                                                                       isWeak:NO
                                                                                   isConstant:NO
                                                                                         line:21
                                                                                       column:5];
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:[[ASStringLiteralNode alloc] initWithValue:@"description" line:22 column:12]
                                                       line:22
                                                     column:5];
    Class sub = [self installClassNamed:subName superclass:baseName protocol:nil
                               selector:@"returnsSelector" body:@[decl, ret] line:20];

    NSException *caught = nil;
    @try {
        (void)((SEL (*)(id, SEL))objc_msgSend)([[sub alloc] init], @selector(returnsSelector));
    } @catch (NSException *ex) {
        caught = ex;
    }

    XCTAssertEqualObjects(caught.name, ASRuntimeErrorException,
                          @"A super send must check the superclass method's typed return value");
    XCTAssertEqualObjects(caught.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    XCTAssertEqualObjects(caught.userInfo[ASErrorLineKey], @5, @"Location should be the superclass method's declaration");
    NSString *message = caught.userInfo[ASErrorMessageKey];
    NSString *expectedPrefix = [NSString stringWithFormat:
                                @"Cannot convert the return value of -[%@ returnsSelector] from ", baseName];
    XCTAssertTrue([message hasPrefix:expectedPrefix], @"%@", message);
}

- (void)test_checkedReturnValue_untypedMethod_returnsValueUnchanged {
    Class cls = [self installClassNamed:uniqueClassName(@"ASTestUntyped") superclass:@"NSObject" protocol:nil
                               selector:@"anything" body:@[[self returnNumber:@42]] line:3];
    id value = @[@1];
    id checked = [ASRuntimeInstaller checkedReturnValue:value
                                                ofSelector:@"anything"
                                             definingClass:cls
                                             isClassMethod:NO];
    XCTAssertEqual(checked, value, @"An id-returning method's value passes through untouched");
}

- (void)test_checkedReturnValue_typedMethod_returnsValueConvertedThroughReturnType {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestBoolProtocol);
    Class cls = [self installClassNamed:uniqueClassName(@"ASTestTypedBool") superclass:@"NSObject"
                               protocol:@"ASTestBoolProtocol" selector:@"returnsBool"
                                   body:@[[self returnNumber:@7]] line:3];
    id checked = [ASRuntimeInstaller checkedReturnValue:@7
                                                ofSelector:@"returnsBool"
                                             definingClass:cls
                                             isClassMethod:NO];
    XCTAssertEqualObjects(checked, @YES, @"A BOOL-returning method's value should come back as a BOOL");
}

- (void)test_checkedReturnValue_voidMethod_returnsNil {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestVoidProtocol);
    Class cls = [self installClassNamed:uniqueClassName(@"ASTestTypedVoid") superclass:@"NSObject"
                               protocol:@"ASTestVoidProtocol" selector:@"doNothing"
                                   body:@[[self returnNumber:@7]] line:3];
    id checked = [ASRuntimeInstaller checkedReturnValue:@7
                                                ofSelector:@"doNothing"
                                             definingClass:cls
                                             isClassMethod:NO];
    XCTAssertNil(checked, @"A void method yields nil, as it does through normal dispatch");
}

- (void)test_checkedReturnValue_unconvertibleValue_raisesAtDeclaration {
    __attribute__((unused)) Protocol *_ensure = @protocol(ASTestSelectorReturnProtocol);
    Class cls = [self installClassNamed:uniqueClassName(@"ASTestTypedSel") superclass:@"NSObject"
                               protocol:@"ASTestSelectorReturnProtocol" selector:@"returnsSelector"
                                   body:@[[self returnNumber:@42]] line:9];
    NSException *caught = nil;
    @try {
        [ASRuntimeInstaller checkedReturnValue:@42
                                    ofSelector:@"returnsSelector"
                                 definingClass:cls
                                 isClassMethod:NO];
    } @catch (NSException *ex) {
        caught = ex;
    }
    XCTAssertEqualObjects(caught.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    XCTAssertEqualObjects(caught.userInfo[ASErrorScriptPathKey], @"super.appscript");
    XCTAssertEqualObjects(caught.userInfo[ASErrorLineKey], @9);
}

// ---------------------------------------------------------------------------
// Lifetime of object return values through forwarding
// ---------------------------------------------------------------------------

- (void)test_forwardedObjectReturnValue_createdByScript_isStillValidForTheCaller {
    // - makeArray { return @[ @"a", @"b" ] }
    // The array is owned only by the forwarding machinery while the call returns, so it
    // must still be alive when the Objective-C caller receives it.
    ASArrayLiteralNode *literal = [[ASArrayLiteralNode alloc] initWithElements:@[
        [[ASStringLiteralNode alloc] initWithValue:@"a" line:2 column:15],
        [[ASStringLiteralNode alloc] initWithValue:@"b" line:2 column:20],
    ] line:2 column:12];
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:literal line:2 column:5];
    Class cls = [self installClassNamed:uniqueClassName(@"ASTestReturnsNewArray") superclass:@"NSObject"
                               protocol:nil selector:@"makeArray" body:@[ret] line:1];
    id receiver = [[cls alloc] init];

    for (NSUInteger i = 0; i < 100; i++) {
        @autoreleasepool {
            NSArray *returned = ((id (*)(id, SEL))objc_msgSend)(receiver, NSSelectorFromString(@"makeArray"));
            XCTAssertEqualObjects(returned, (@[@"a", @"b"]));
        }
    }
}

@end
