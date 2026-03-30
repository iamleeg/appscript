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

@end
