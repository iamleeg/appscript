// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockRegistryTests.m — Unit tests for ASBlockRegistry
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
#import <AppScript/AppScript.h>

@interface ASTestRegistryBase : NSObject
@end
@implementation ASTestRegistryBase
@end
@interface ASTestRegistrySub : ASTestRegistryBase
@end
@implementation ASTestRegistrySub
@end

static ASBridgeSupportBlockSignature *makeSignature(NSString *className, NSString *selector, BOOL isClassMethod,
                                                    NSUInteger index, NSArray<NSString *> *params, NSString *ret) {
    return [[ASBridgeSupportBlockSignature alloc] initWithClassName:className
                                                       selectorName:selector
                                                      isClassMethod:isClassMethod
                                                      argumentIndex:index
                                             parameterTypeEncodings:params
                                                 returnTypeEncoding:ret];
}

@interface ASBlockRegistryTests : XCTestCase
@end

@implementation ASBlockRegistryTests

- (void)test_signatureForReceiver_instanceMethodOnSubclass_findsSuperclassEntry {
    ASBlockRegistry *registry = [ASBlockRegistry sharedRegistry];
    [registry registerSignature:makeSignature(@"ASTestRegistryBase", @"visit:", NO, 0, @[@"@", @"q"], @"v")];
    ASBridgeSupportBlockSignature *found = [registry signatureForReceiver:[[ASTestRegistrySub alloc] init]
                                                                 selector:NSSelectorFromString(@"visit:")
                                                            argumentIndex:0];
    XCTAssertNotNil(found, @"a subclass instance should find its superclass's registration");
    NSArray *expected = @[@"@", @"q"];
    XCTAssertEqualObjects(found.parameterTypeEncodings, expected);
}

- (void)test_signatureForReceiver_classMethod_matchesOnlyClassReceivers {
    ASBlockRegistry *registry = [ASBlockRegistry sharedRegistry];
    [registry registerSignature:makeSignature(@"ASTestRegistryBase", @"makeWith:", YES, 0, @[@"q"], @"v")];
    XCTAssertNotNil([registry signatureForReceiver:[ASTestRegistrySub class]
                                          selector:NSSelectorFromString(@"makeWith:")
                                     argumentIndex:0],
                    @"a class receiver finds a class-method signature, through its superclass");
    XCTAssertNil([registry signatureForReceiver:[[ASTestRegistrySub alloc] init]
                                       selector:NSSelectorFromString(@"makeWith:")
                                  argumentIndex:0],
                 @"an instance receiver must not match a class-method signature");
}

- (void)test_signatureForReceiver_unknownSelectorOrIndex_returnsNil {
    ASBlockRegistry *registry = [ASBlockRegistry sharedRegistry];
    [registry registerSignature:makeSignature(@"ASTestRegistryBase", @"visit2:", NO, 1, @[@"@"], @"v")];
    id receiver = [[ASTestRegistryBase alloc] init];
    XCTAssertNil([registry signatureForReceiver:receiver selector:NSSelectorFromString(@"visit2:") argumentIndex:0]);
    XCTAssertNil([registry signatureForReceiver:receiver selector:NSSelectorFromString(@"neverRegistered:") argumentIndex:1]);
}

- (void)test_registerSignature_sameKey_replacesEarlierSignature {
    ASBlockRegistry *registry = [ASBlockRegistry sharedRegistry];
    [registry registerSignature:makeSignature(@"ASTestRegistryBase", @"replace:", NO, 0, @[@"@"], @"v")];
    [registry registerSignature:makeSignature(@"ASTestRegistryBase", @"replace:", NO, 0, @[@"q"], @"q")];
    ASBridgeSupportBlockSignature *found = [registry signatureForReceiver:[[ASTestRegistryBase alloc] init]
                                                                 selector:NSSelectorFromString(@"replace:")
                                                            argumentIndex:0];
    XCTAssertEqualObjects(found.returnTypeEncoding, @"q", @"the later registration wins");
}

- (void)test_builtInSignatures_frameworkControlFlowHelpers_areRegistered {
    ASBlockRegistry *registry = [ASBlockRegistry sharedRegistry];
    ASBridgeSupportBlockSignature *ifTrue = [registry signatureForReceiver:@YES
                                                                  selector:NSSelectorFromString(@"ifTrue:")
                                                             argumentIndex:0];
    XCTAssertNotNil(ifTrue, @"-[NSNumber ifTrue:] is a framework helper, so it needs no BridgeSupport");
    XCTAssertEqual(ifTrue.parameterTypeEncodings.count, 0u);
    XCTAssertEqualObjects(ifTrue.returnTypeEncoding, @"@");
    for (NSUInteger index = 0; index < 2; index++) {
        XCTAssertNotNil([registry signatureForReceiver:@NO selector:NSSelectorFromString(@"ifTrue:ifFalse:") argumentIndex:index]);
        XCTAssertNotNil([registry signatureForReceiver:[NSObject new] selector:NSSelectorFromString(@"do:while:") argumentIndex:index]);
        XCTAssertNotNil([registry signatureForReceiver:[NSObject new] selector:NSSelectorFromString(@"do:until:") argumentIndex:index]);
    }
    XCTAssertNotNil([registry signatureForReceiver:@NO selector:NSSelectorFromString(@"ifFalse:") argumentIndex:0]);
}

- (void)test_builtInSignatures_nativeNSArrayBlockMethods_areRegisteredOnAFreshRegistry {
    // A fresh registry holds only the built-ins, so this doesn't depend on BridgeSupport files that
    // other tests may have loaded into the shared one.
    ASBlockRegistry *registry = [[ASBlockRegistry alloc] init];
    ASBridgeSupportBlockSignature *sort = [registry signatureForReceiver:@[]
                                                                selector:NSSelectorFromString(@"sortedArrayUsingComparator:")
                                                           argumentIndex:0];
    XCTAssertNotNil(sort, @"-[NSArray sortedArrayUsingComparator:] should work where BridgeSupport isn't available");
    NSArray *sortParameters = @[@"@", @"@"];
    XCTAssertEqualObjects(sort.parameterTypeEncodings, sortParameters);
    XCTAssertEqualObjects(sort.returnTypeEncoding, @"q", @"an NSComparator returns an NSComparisonResult");
    ASBridgeSupportBlockSignature *enumerate = [registry signatureForReceiver:@[]
                                                                     selector:NSSelectorFromString(@"enumerateObjectsUsingBlock:")
                                                                argumentIndex:0];
    XCTAssertNotNil(enumerate);
    NSArray *enumerateParameters = @[@"@", @"Q", @"^B"];
    XCTAssertEqualObjects(enumerate.parameterTypeEncodings, enumerateParameters);
    XCTAssertEqualObjects(enumerate.returnTypeEncoding, @"v");
}

- (void)test_builtInSignatures_removedAsSortedArrayHelper_isNotRegistered {
    ASBlockRegistry *registry = [[ASBlockRegistry alloc] init];
    XCTAssertNil([registry signatureForReceiver:@[]
                                       selector:NSSelectorFromString(@"as_sortedArrayUsingBlock:")
                                  argumentIndex:0],
                 @"the as_ workaround was removed in favour of the native method");
}

- (void)test_isObjectOnly_objectParametersAndReturn_isYES_scalarsAreNO {
    XCTAssertTrue([makeSignature(@"X", @"a:", NO, 0, @[@"@", @"@"], @"@") isObjectOnly]);
    XCTAssertTrue([makeSignature(@"X", @"a:", NO, 0, @[@"@"], @"v") isObjectOnly]);
    XCTAssertFalse([makeSignature(@"X", @"a:", NO, 0, @[@"@", @"Q"], @"v") isObjectOnly]);
    XCTAssertFalse([makeSignature(@"X", @"a:", NO, 0, @[@"@", @"@"], @"q") isObjectOnly]);
}

@end
