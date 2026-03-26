// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASStructValueTests.m — Tests for ASStructValue field accessor dispatch
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
#import <AppScript/ASStructValue.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASBridgeSupportStructField.h>
#import <AppScript/ASBridgeSupportParser.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportInstaller.h>

@interface ASStructValueTests : XCTestCase
@end

@implementation ASStructValueTests

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

- (NSString *)uniqueFrameworkName {
    // Use a UUID to avoid proxy-class-name collisions when multiple test
    // classes share the same xctest process (counters can alias if tests
    // run in unexpected order).
    return [@"SVTestFW_" stringByAppendingString:
            [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

/// Parse BridgeSupport XML, install via ASBridgeSupportInstaller, and return the document.
- (ASBridgeSupportDocument *)installXML:(NSString *)xml {
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    ASBridgeSupportDocument *doc = [parser parseData:data error:&error];
    XCTAssertNotNil(doc, @"Parse failed: %@", error);

    ASBridgeSupportInstaller *installer = [[ASBridgeSupportInstaller alloc] init];
    BOOL ok = [installer installDocument:doc frameworkName:[self uniqueFrameworkName] error:&error];
    XCTAssertTrue(ok, @"Install failed: %@", error);
    return doc;
}

/// Calls a zero-argument instance method on `obj` via NSInvocation and returns the result.
- (id)callMethod:(SEL)sel onObject:(id)obj {
    NSMethodSignature *sig = [obj methodSignatureForSelector:sel];
    XCTAssertNotNil(sig, @"No method signature for %@", NSStringFromSelector(sel));
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = sel;
    inv.target = obj;
    [inv invoke];
    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];
    return result;
}

/// Builds a minimal BridgeSupport XML string containing the given <struct> elements.
- (NSString *)xmlWithStructElements:(NSString *)structElements {
    return [NSString stringWithFormat:
            @"<?xml version='1.0'?><signatures version='1.0'>%@</signatures>",
            structElements];
}

// ---------------------------------------------------------------------------
// CGSize: width and height
// ---------------------------------------------------------------------------

- (void)test_CGSize_widthAndHeight_returnCorrectNSNumbers {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
    ]];

    NSSize size = NSMakeSize(42.5, 13.0);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&size
                                                      length:sizeof(NSSize)
                                               canonicalName:@"CGSize"
                                         runtimeTypeEncoding:@"{CGSize=dd}"];

    NSNumber *width  = [self callMethod:@selector(width)  onObject:sv];
    NSNumber *height = [self callMethod:@selector(height) onObject:sv];

    XCTAssertEqualWithAccuracy([width doubleValue],  42.5, 1e-9);
    XCTAssertEqualWithAccuracy([height doubleValue], 13.0, 1e-9);
}

// ---------------------------------------------------------------------------
// CGPoint: x and y
// ---------------------------------------------------------------------------

- (void)test_CGPoint_xAndY_returnCorrectNSNumbers {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSPoint' type64='{CGPoint=\"x\"d\"y\"d}'/>"
    ]];

    NSPoint point = NSMakePoint(7.0, -3.5);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&point
                                                      length:sizeof(NSPoint)
                                               canonicalName:@"CGPoint"
                                         runtimeTypeEncoding:@"{CGPoint=dd}"];

    NSNumber *x = [self callMethod:@selector(x) onObject:sv];
    NSNumber *y = [self callMethod:@selector(y) onObject:sv];

    XCTAssertEqualWithAccuracy([x doubleValue],  7.0,  1e-9);
    XCTAssertEqualWithAccuracy([y doubleValue], -3.5,  1e-9);
}

// ---------------------------------------------------------------------------
// NSRange: location and length
// ---------------------------------------------------------------------------

- (void)test_NSRange_locationAndLength_returnCorrectNSNumbers {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSRange' type64='{_NSRange=\"location\"Q\"length\"Q}'/>"
    ]];

    NSRange range = NSMakeRange(10, 5);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&range
                                                      length:sizeof(NSRange)
                                               canonicalName:@"NSRange"
                                         runtimeTypeEncoding:@"{_NSRange=QQ}"];

    NSNumber *location = [self callMethod:@selector(location) onObject:sv];
    NSNumber *length   = [self callMethod:@selector(length)   onObject:sv];

    XCTAssertEqual([location unsignedLongLongValue], (unsigned long long)10);
    XCTAssertEqual([length   unsignedLongLongValue], (unsigned long long)5);
}

// ---------------------------------------------------------------------------
// CGRect: origin and size return ASStructValue; chained access works
// ---------------------------------------------------------------------------

- (void)test_CGRect_originAndSize_returnASStructValue {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSPoint' type64='{CGPoint=\"x\"d\"y\"d}'/>"
        @"<struct name='NSSize'  type64='{CGSize=\"width\"d\"height\"d}'/>"
        @"<struct name='NSRect'  type64='{CGRect=\"origin\"{CGPoint}\"size\"{CGSize}}'/>"
    ]];

    NSRect rect = NSMakeRect(1.0, 2.0, 100.0, 200.0);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&rect
                                                      length:sizeof(NSRect)
                                               canonicalName:@"CGRect"
                                         runtimeTypeEncoding:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];

    id origin = [self callMethod:@selector(origin) onObject:sv];
    id size   = [self callMethod:@selector(size)   onObject:sv];

    XCTAssertTrue([origin isKindOfClass:[ASStructValue class]],
                  @"Expected ASStructValue for origin, got %@", [origin class]);
    XCTAssertTrue([size isKindOfClass:[ASStructValue class]],
                  @"Expected ASStructValue for size, got %@", [size class]);
}

- (void)test_CGRect_chainedOriginX_returnsCorrectValue {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSPoint' type64='{CGPoint=\"x\"d\"y\"d}'/>"
        @"<struct name='NSSize'  type64='{CGSize=\"width\"d\"height\"d}'/>"
        @"<struct name='NSRect'  type64='{CGRect=\"origin\"{CGPoint}\"size\"{CGSize}}'/>"
    ]];

    NSRect rect = NSMakeRect(1.0, 2.0, 100.0, 200.0);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&rect
                                                      length:sizeof(NSRect)
                                               canonicalName:@"CGRect"
                                         runtimeTypeEncoding:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];

    ASStructValue *origin = [self callMethod:@selector(origin) onObject:sv];
    NSNumber *x = [self callMethod:@selector(x) onObject:origin];
    XCTAssertEqualWithAccuracy([x doubleValue], 1.0, 1e-9);
}

- (void)test_CGRect_chainedSizeWidth_returnsCorrectValue {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSPoint' type64='{CGPoint=\"x\"d\"y\"d}'/>"
        @"<struct name='NSSize'  type64='{CGSize=\"width\"d\"height\"d}'/>"
        @"<struct name='NSRect'  type64='{CGRect=\"origin\"{CGPoint}\"size\"{CGSize}}'/>"
    ]];

    NSRect rect = NSMakeRect(1.0, 2.0, 100.0, 200.0);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&rect
                                                      length:sizeof(NSRect)
                                               canonicalName:@"CGRect"
                                         runtimeTypeEncoding:@"{CGRect={CGPoint=dd}{CGSize=dd}}"];

    ASStructValue *size = [self callMethod:@selector(size) onObject:sv];
    NSNumber *width = [self callMethod:@selector(width) onObject:size];
    XCTAssertEqualWithAccuracy([width doubleValue], 100.0, 1e-9);
}

// ---------------------------------------------------------------------------
// asNSValue
// ---------------------------------------------------------------------------

- (void)test_asNSValue_CGSize_returnsCorrectNSValue {
    [self installXML:[self xmlWithStructElements:
        @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
    ]];

    NSSize size = NSMakeSize(8.0, 16.0);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&size
                                                      length:sizeof(NSSize)
                                               canonicalName:@"CGSize"
                                         runtimeTypeEncoding:@"{CGSize=dd}"];

    NSValue *nsv = [sv asNSValue];
    XCTAssertNotNil(nsv);
    NSSize extracted = NSZeroSize;
    [nsv getValue:&extracted];
    XCTAssertEqualWithAccuracy(extracted.width,  8.0,  1e-9);
    XCTAssertEqualWithAccuracy(extracted.height, 16.0, 1e-9);
}

// ---------------------------------------------------------------------------
// Registry: registerStruct / registeredStructNamed
// ---------------------------------------------------------------------------

- (void)test_registerStruct_thenRegisteredStructNamed_returnsIt {
    ASBridgeSupportStructField *f = [[ASBridgeSupportStructField alloc]
                                      initWithName:@"value" typeEncoding:@"d"];
    ASBridgeSupportStruct *s = [[ASBridgeSupportStruct alloc]
                                 initWithCanonicalName:@"_TestScalar" fields:@[f]];
    [ASStructValue registerStruct:s];
    ASBridgeSupportStruct *found = [ASStructValue registeredStructNamed:@"_TestScalar"];
    XCTAssertNotNil(found);
    XCTAssertEqualObjects(found.canonicalName, @"_TestScalar");
}

- (void)test_registerStruct_duplicate_doesNotOverwrite {
    ASBridgeSupportStructField *f1 = [[ASBridgeSupportStructField alloc]
                                       initWithName:@"a" typeEncoding:@"d"];
    ASBridgeSupportStruct *s1 = [[ASBridgeSupportStruct alloc]
                                  initWithCanonicalName:@"_TestDup" fields:@[f1]];
    [ASStructValue registerStruct:s1];

    // Second register with different fields — should NOT override.
    ASBridgeSupportStructField *f2 = [[ASBridgeSupportStructField alloc]
                                       initWithName:@"b" typeEncoding:@"d"];
    ASBridgeSupportStruct *s2 = [[ASBridgeSupportStruct alloc]
                                  initWithCanonicalName:@"_TestDup" fields:@[f1, f2]];
    [ASStructValue registerStruct:s2];

    ASBridgeSupportStruct *found = [ASStructValue registeredStructNamed:@"_TestDup"];
    XCTAssertEqual(found.fields.count, 1u, @"First registration should be preserved");
}

@end
