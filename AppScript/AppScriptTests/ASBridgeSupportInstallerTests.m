// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportInstallerTests.m — Tests for ASBridgeSupportInstaller
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
#import <dlfcn.h>
#import <AppScript/ASBridgeSupportInstaller.h>
#import <AppScript/ASBridgeSupportParser.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportFunction.h>

@interface ASBridgeSupportInstallerTests : XCTestCase
@end

@implementation ASBridgeSupportInstallerTests

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static NSInteger _ASTestCounter = 0;

/// Returns a unique framework name for each call to avoid class-name collisions
/// across test cases within the same process.
- (NSString *)uniqueFrameworkName {
    return [NSString stringWithFormat:@"TestFW%ld", (long)++_ASTestCounter];
}

- (ASBridgeSupportDocument *)parseXML:(NSString *)xml {
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    ASBridgeSupportDocument *doc = [parser parseData:data error:&error];
    XCTAssertNotNil(doc, @"Parse failed: %@", error);
    return doc;
}

/// Calls a zero-argument class method on `cls` and returns the result.
- (id)callClassMethod:(SEL)sel onClass:(Class)cls {
    NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
    XCTAssertNotNil(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = cls;
    [inv invoke];
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

/// Calls a one-argument class method on `cls` and returns the result.
- (id)callClassMethod:(SEL)sel onClass:(Class)cls withArg:(id)arg {
    NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
    XCTAssertNotNil(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = cls;
    [inv setArgument:&arg atIndex:2];
    [inv invoke];
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

/// Calls a two-argument class method on `cls` and returns the result.
- (id)callClassMethod:(SEL)sel onClass:(Class)cls withArg:(id)arg1 arg:(id)arg2 {
    NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
    XCTAssertNotNil(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = cls;
    [inv setArgument:&arg1 atIndex:2];
    [inv setArgument:&arg2 atIndex:3];
    [inv invoke];
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

// ---------------------------------------------------------------------------
// Proxy class creation
// ---------------------------------------------------------------------------

- (void)test_installDocument_singleFunction_proxyClassCreated {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    NSError *error = nil;
    BOOL ok = [installer installDocument:doc frameworkName:frameworkName error:&error];

    XCTAssertTrue(ok);
    XCTAssertNil(error);
    NSString *className = [@"AS" stringByAppendingString:frameworkName];
    XCTAssertNotNil(NSClassFromString(className));
}

- (void)test_installDocument_duplicateFramework_returnsError {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    NSError *error = nil;
    BOOL first = [installer installDocument:doc frameworkName:frameworkName error:&error];
    XCTAssertTrue(first);
    XCTAssertNil(error);

    BOOL second = [installer installDocument:doc frameworkName:frameworkName error:&error];
    XCTAssertFalse(second);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ASBridgeSupportInstallerErrorDomain);
    XCTAssertEqual(error.code, ASBridgeSupportInstallerErrorDuplicateFramework);
}

// ---------------------------------------------------------------------------
// Function skipping
// ---------------------------------------------------------------------------

- (void)test_installDocument_variadicFunction_notInstalled {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='NSLog' variadic='true'><arg type64='@'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    [installer installDocument:doc frameworkName:frameworkName error:nil];

    NSString *className = [@"AS" stringByAppendingString:frameworkName];
    Class proxyClass = NSClassFromString(className);
    XCTAssertNotNil(proxyClass); // class created
    XCTAssertFalse([proxyClass respondsToSelector:NSSelectorFromString(@"NSLog:")]);
}

- (void)test_installDocument_functionPointerFunction_notInstalled {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='atexit'>"
                    @"<arg function_pointer='true'/>"
                    @"<retval type64='i'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    [installer installDocument:doc frameworkName:frameworkName error:nil];

    NSString *className = [@"AS" stringByAppendingString:frameworkName];
    Class proxyClass = NSClassFromString(className);
    XCTAssertNotNil(proxyClass);
    XCTAssertFalse([proxyClass respondsToSelector:NSSelectorFromString(@"atexit:")]);
}

- (void)test_installDocument_unresolvedSymbol_skippedSilently {
    // Use a function name that definitely doesn't exist
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='_nonexistent_function_xyz_12345'>"
                    @"<retval type64='i'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    NSError *error = nil;
    BOOL ok = [installer installDocument:doc frameworkName:frameworkName error:&error];
    XCTAssertTrue(ok, @"Install should succeed even when a symbol is missing");
    XCTAssertNil(error);
}

// ---------------------------------------------------------------------------
// Function calls — double return type
// ---------------------------------------------------------------------------

- (void)test_installDocument_sinDouble_callsCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"sin:") onClass:cls withArg:@(0.0)];

    XCTAssertEqualWithAccuracy(result.doubleValue, 0.0, 1e-15);
}

- (void)test_installDocument_cosDouble_callsCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='cos'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"cos:") onClass:cls withArg:@(0.0)];

    XCTAssertEqualWithAccuracy(result.doubleValue, 1.0, 1e-15);
}

- (void)test_installDocument_twoDoubleArgs_callsCorrectly {
    // atan2(0, 1) = 0.0 (angle of point (1,0) from origin)
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='atan2'>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<retval type64='d'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"atan2::") onClass:cls withArg:@(0.0) arg:@(1.0)];

    XCTAssertEqualWithAccuracy(result.doubleValue, 0.0, 1e-15);
}

// ---------------------------------------------------------------------------
// Function calls — integer return type
// ---------------------------------------------------------------------------

- (void)test_installDocument_absInt_callsCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='abs'><arg type64='i'/><retval type64='i'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"abs:") onClass:cls withArg:@(-42)];

    XCTAssertEqual(result.intValue, 42);
}

// ---------------------------------------------------------------------------
// Function calls — void return type
// ---------------------------------------------------------------------------

- (void)test_installDocument_voidFunction_returnsNil {
    // Use a real no-op void function: free(NULL) is well-defined and does nothing
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='free'><arg type64='^v'/><retval type64='v'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"free:") onClass:cls withArg:[NSNull null]];

    XCTAssertNil(result, @"void functions must return nil");
}

// ---------------------------------------------------------------------------
// Constant installation — numeric types
// ---------------------------------------------------------------------------

- (void)test_installDocument_doubleConstant_returnsValue {
    // NSFoundationVersionNumber is a double constant available in all processes.
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='NSFoundationVersionNumber' type64='d'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"NSFoundationVersionNumber") onClass:cls];

    XCTAssertGreaterThan(result.doubleValue, 0.0, @"NSFoundationVersionNumber must be positive");
}

- (void)test_installDocument_enumNSNotFound_returnsNegativeOne {
    // In real Foundation BridgeSupport, NSNotFound is an <enum> with value64='-1'
    // (the BridgeSupport generator represents NSUIntegerMax as -1 in a signed field).
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSNotFound' value64='-1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"NSNotFound") onClass:cls];

    XCTAssertEqual(result.longLongValue, -1LL);
}

- (void)test_installDocument_idConstant_returnsValue {
    // NSBundleDidLoadNotification is a well-known NSString * constant in Foundation.
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='NSBundleDidLoadNotification' type64='@'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    id result = [self callClassMethod:NSSelectorFromString(@"NSBundleDidLoadNotification") onClass:cls];

    XCTAssertEqualObjects(result, NSBundleDidLoadNotification);
}

- (void)test_installDocument_unresolvedConstant_skippedSilently {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='_NonexistentConst_xyz_12345' type64='d'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    NSError *error = nil;
    BOOL ok = [installer installDocument:doc frameworkName:frameworkName error:&error];

    XCTAssertTrue(ok, @"Install should succeed even when a constant symbol is missing");
    XCTAssertNil(error);
}

// ---------------------------------------------------------------------------
// Enumeration installation
// ---------------------------------------------------------------------------

- (void)test_installDocument_enumeration_returnsValue {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSASCIIStringEncoding' value64='1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"NSASCIIStringEncoding") onClass:cls];

    XCTAssertEqual(result.longLongValue, 1LL);
}

- (void)test_installDocument_negativeEnumeration_returnsValue {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSNotAnIndexPath' value64='-1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSNumber *result = [self callClassMethod:NSSelectorFromString(@"NSNotAnIndexPath") onClass:cls];

    XCTAssertEqual(result.longLongValue, -1LL);
}

// ---------------------------------------------------------------------------
// Struct constant installation
// ---------------------------------------------------------------------------

- (void)test_installDocument_structConstant_NSZeroRect_returnsNSValue {
    // Load Foundation's companion dylib so NSZeroRect is dlsym-able.
    NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
    NSURL *companionURL = [[[foundationBundle resourceURL]
                             URLByAppendingPathComponent:@"BridgeSupport"]
                             URLByAppendingPathComponent:@"Foundation.dylib"];
    dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='NSZeroRect' type64='{CGRect={CGPoint=dd}{CGSize=dd}}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSValue *result = [self callClassMethod:NSSelectorFromString(@"NSZeroRect") onClass:cls];

    XCTAssertNotNil(result, @"NSZeroRect constant should be returned as NSValue");
    XCTAssertTrue([result isKindOfClass:[NSValue class]]);
    NSRect rect = [result rectValue];
    XCTAssertEqual(rect.origin.x, 0.0);
    XCTAssertEqual(rect.origin.y, 0.0);
    XCTAssertEqual(rect.size.width, 0.0);
    XCTAssertEqual(rect.size.height, 0.0);
}

// ---------------------------------------------------------------------------
// Geometry struct return functions
// ---------------------------------------------------------------------------

- (void)test_installDocument_NSMakeRect_returnsNSValue {
    // Load Foundation's companion dylib so NSMakeRect is dlsym-able.
    NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
    NSURL *companionURL = [[[foundationBundle resourceURL]
                             URLByAppendingPathComponent:@"BridgeSupport"]
                             URLByAppendingPathComponent:@"Foundation.dylib"];
    dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='NSMakeRect'>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<retval type64='{CGRect={CGPoint=dd}{CGSize=dd}}'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSMethodSignature *sig = [cls methodSignatureForSelector:NSSelectorFromString(@"NSMakeRect::::")];
    XCTAssertNotNil(sig);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = NSSelectorFromString(@"NSMakeRect::::");
    inv.target = cls;
    id a0 = @(10.0), a1 = @(20.0), a2 = @(300.0), a3 = @(400.0);
    [inv setArgument:&a0 atIndex:2];
    [inv setArgument:&a1 atIndex:3];
    [inv setArgument:&a2 atIndex:4];
    [inv setArgument:&a3 atIndex:5];
    [inv invoke];
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];

    XCTAssertNotNil(result);
    XCTAssertTrue([result isKindOfClass:[NSValue class]]);
    NSRect rect = [(NSValue *)result rectValue];
    XCTAssertEqual(rect.origin.x, 10.0);
    XCTAssertEqual(rect.origin.y, 20.0);
    XCTAssertEqual(rect.size.width, 300.0);
    XCTAssertEqual(rect.size.height, 400.0);
}

- (void)test_installDocument_NSMakeSize_returnsNSValue {
    NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
    NSURL *companionURL = [[[foundationBundle resourceURL]
                             URLByAppendingPathComponent:@"BridgeSupport"]
                             URLByAppendingPathComponent:@"Foundation.dylib"];
    dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='NSMakeSize'>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<retval type64='{CGSize=dd}'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSValue *result = [self callClassMethod:NSSelectorFromString(@"NSMakeSize::") onClass:cls withArg:@(50.0) arg:@(75.0)];

    XCTAssertNotNil(result);
    XCTAssertTrue([result isKindOfClass:[NSValue class]]);
    NSSize size = [result sizeValue];
    XCTAssertEqual(size.width, 50.0);
    XCTAssertEqual(size.height, 75.0);
}

- (void)test_installDocument_NSMakePoint_returnsNSValue {
    NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
    NSURL *companionURL = [[[foundationBundle resourceURL]
                             URLByAppendingPathComponent:@"BridgeSupport"]
                             URLByAppendingPathComponent:@"Foundation.dylib"];
    dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='NSMakePoint'>"
                    @"<arg type64='d'/>"
                    @"<arg type64='d'/>"
                    @"<retval type64='{CGPoint=dd}'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];
    [installer installDocument:doc frameworkName:frameworkName error:nil];
    Class cls = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);

    NSValue *result = [self callClassMethod:NSSelectorFromString(@"NSMakePoint::") onClass:cls withArg:@(15.0) arg:@(25.0)];

    XCTAssertNotNil(result);
    XCTAssertTrue([result isKindOfClass:[NSValue class]]);
    NSPoint point = [result pointValue];
    XCTAssertEqual(point.x, 15.0);
    XCTAssertEqual(point.y, 25.0);
}

// ---------------------------------------------------------------------------
// Convenience method
// ---------------------------------------------------------------------------

- (void)test_installDocument_convenienceNoError_succeeds {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    NSString *frameworkName = [self uniqueFrameworkName];

    BOOL ok = [installer installDocument:doc frameworkName:frameworkName];

    XCTAssertTrue(ok);
    XCTAssertNotNil(NSClassFromString([@"AS" stringByAppendingString:frameworkName]));
}

@end
