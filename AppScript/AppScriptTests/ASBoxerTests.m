// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBoxerTests.m — Unit tests for ASBoxer boxing and unboxing behaviour
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
#import <AppScript/ASBoxer.h>
#import <AppScript/ASOutObject.h>
#import <AppScript/ASStructValue.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASBridgeSupportStructField.h>

@protocol ASBoxerTestOutErrorProtocol <NSObject>
- (BOOL)performOperationWithError:(NSError **)error;
@end

/// Tests for the ASBoxer utility class, covering boxing of arguments and return values as well
/// as unboxing of Objective-C objects into NSInvocation argument and return-value slots.
@interface ASBoxerTests : XCTestCase
@end

@implementation ASBoxerTests

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates an invocation for `selector` on `target`, invokes it, and returns the invocation.
- (NSInvocation *)invokedInvocationForSelector:(SEL)selector onTarget:(id)target {
    NSMethodSignature *sig = [target methodSignatureForSelector:selector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = selector;
    [inv invoke];
    return inv;
}

// ---------------------------------------------------------------------------
// Return-value boxing tests
// ---------------------------------------------------------------------------

- (void)test_boxedReturnValue_idReturnType_returnsObject {
    // +[NSString string] returns an empty NSString (id return type, '@')
    NSMethodSignature *sig = [NSString methodSignatureForSelector:@selector(string)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [NSString class];
    inv.selector = @selector(string);
    [inv invoke];

    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertNotNil(result, @"Boxing an id return value should not yield nil");
    XCTAssertTrue([result isKindOfClass:[NSString class]],
                  @"Boxing an id-returning method should return an NSString");
    XCTAssertEqualObjects(result, @"",
                          @"[NSString string] should return an empty string");
}

- (void)test_boxedReturnValue_NSIntegerReturnType_returnsNSNumber {
    // -[NSArray count] returns NSUInteger ('Q' on 64-bit / 'I' on 32-bit)
    NSArray *array = @[@1, @2, @3];
    NSInvocation *inv = [self invokedInvocationForSelector:@selector(count) onTarget:array];

    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertNotNil(result, @"Boxing an NSUInteger return value should not yield nil");
    XCTAssertTrue([result isKindOfClass:[NSNumber class]],
                  @"Boxing an NSUInteger should return an NSNumber");
    XCTAssertEqual([result unsignedIntegerValue], (NSUInteger)3,
                   @"count of @[@1,@2,@3] should be 3");
}

- (void)test_boxedReturnValue_BOOLReturnType_returnsNSNumber {
    // -[NSArray containsObject:] returns BOOL
    NSArray *array = @[@"hello", @"world"];
    NSMethodSignature *sig = [array methodSignatureForSelector:@selector(containsObject:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = array;
    inv.selector = @selector(containsObject:);

    id searchObject = @"hello";
    [inv setArgument:&searchObject atIndex:2];
    [inv invoke];

    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertNotNil(result, @"Boxing a BOOL return value should not yield nil");
    XCTAssertTrue([result isKindOfClass:[NSNumber class]],
                  @"Boxing a BOOL should return an NSNumber");
    XCTAssertTrue([result boolValue],
                  @"containsObject:@\"hello\" in @[@\"hello\",@\"world\"] should be YES");
}

- (void)test_boxedReturnValue_voidReturnType_returnsNil {
    // We need a method with a void return type. Use NSMutableArray -removeAllObjects.
    NSMutableArray *mutableArray = [NSMutableArray arrayWithObject:@1];
    NSMethodSignature *sig = [mutableArray methodSignatureForSelector:@selector(removeAllObjects)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = mutableArray;
    inv.selector = @selector(removeAllObjects);
    [inv invoke];

    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertNil(result, @"Boxing a void return value should yield nil");
}

// ---------------------------------------------------------------------------
// Argument unboxing tests
// ---------------------------------------------------------------------------

- (void)test_unboxObject_NSNumberToNSInteger_setsCorrectValue {
    // -[NSString stringByPaddingToLength:withString:startingAtIndex:] takes NSUInteger as
    // argument 0. We verify unboxing by setting the argument then invoking and checking output.
    NSString *source = @"ab";
    NSMethodSignature *sig = [source methodSignatureForSelector:
                              @selector(stringByPaddingToLength:withString:startingAtIndex:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = source;
    inv.selector = @selector(stringByPaddingToLength:withString:startingAtIndex:);

    // Unbox NSNumber @5 into argument 0 (NSUInteger length)
    [ASBoxer unboxObject:@5
     intoArgumentAtIndex:0
            ofInvocation:inv];

    // Set the remaining arguments directly
    id padString = @"-";
    NSUInteger startIndex = 0;
    [inv setArgument:&padString atIndex:3];
    [inv setArgument:&startIndex atIndex:4];
    [inv invoke];

    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];

    XCTAssertEqualObjects(result, @"ab---",
                          @"Unboxing @5 as NSUInteger length should pad to 5 characters");
}

- (void)test_unboxObject_NSStringToCString_setsCorrectValue {
    // -[NSString stringWithUTF8String:] is a class method taking const char *.
    // We exercise C-string unboxing by unboxing an NSString into argument 0 of the invocation,
    // then invoking it and verifying the round-trip.
    NSMethodSignature *sig = [NSString methodSignatureForSelector:@selector(stringWithUTF8String:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [NSString class];
    inv.selector = @selector(stringWithUTF8String:);

    [ASBoxer unboxObject:@"hello"
     intoArgumentAtIndex:0
            ofInvocation:inv];
    [inv invoke];

    __unsafe_unretained id result = nil;
    [inv getReturnValue:&result];

    XCTAssertEqualObjects(result, @"hello",
                          @"Unboxing NSString @\"hello\" as C string should round-trip correctly");
}

// ---------------------------------------------------------------------------
// Round-trip argument boxing test
// ---------------------------------------------------------------------------

- (void)test_boxedArgument_NSUIntegerArgument_returnsCorrectNSNumber {
    // Build an invocation for -[NSArray objectAtIndex:] with index 1,
    // then box argument 0 back out and verify it matches.
    NSArray *array = @[@"zero", @"one", @"two"];
    NSMethodSignature *sig = [array methodSignatureForSelector:@selector(objectAtIndex:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = array;
    inv.selector = @selector(objectAtIndex:);

    NSUInteger idx = 1;
    [inv setArgument:&idx atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertNotNil(boxed, @"Boxing an NSUInteger argument should not yield nil");
    XCTAssertTrue([boxed isKindOfClass:[NSNumber class]],
                  @"Boxing an NSUInteger argument should return NSNumber");
    XCTAssertEqual([boxed unsignedIntegerValue], (NSUInteger)1,
                   @"Boxed argument value should equal the original index 1");
}

// ---------------------------------------------------------------------------
// Class ('#') return-type boxing
// ---------------------------------------------------------------------------

- (void)test_unboxObject_ClassArgument_setsCorrectValue {
    // +[NSArray isSubclassOfClass:] takes a Class argument ('#' encoding).
    // Unboxing a Class id into a '#' argument should work correctly.
    NSMethodSignature *sig = [NSArray methodSignatureForSelector:@selector(isSubclassOfClass:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = [NSMutableArray class];
    inv.selector = @selector(isSubclassOfClass:);

    [ASBoxer unboxObject:[NSArray class] intoArgumentAtIndex:0 ofInvocation:inv];
    [inv invoke];

    BOOL result = NO;
    [inv getReturnValue:&result];

    XCTAssertTrue(result,
                  @"[NSMutableArray isSubclassOfClass:[NSArray class]] should return YES");
}

- (void)test_boxedReturnValue_classReturnType_returnsClassObject {
    // -[NSObject class] has return type '#' (Class).
    // ASBoxer must return the Class as an id, not wrap it in NSValue.
    NSArray *array = @[];
    NSInvocation *inv = [self invokedInvocationForSelector:@selector(class) onTarget:array];

    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertNotNil(result, @"Boxing a Class return value should not yield nil");
    // The result must be a Class object (a subclass of NSArray), not an NSValue wrapper.
    XCTAssertFalse([result isKindOfClass:[NSValue class]],
                   @"Boxing a Class return value must not produce an NSValue wrapper");
    // Sending a class-level message to the result should work: it is a real Class.
    XCTAssertTrue([result isSubclassOfClass:[NSArray class]],
                   @"Boxing [NSArray class] should yield a Class that is a subclass of NSArray");
}

// ---------------------------------------------------------------------------
// Object out-parameter ('^@', e.g. NSError **) boxing, unboxing, and write-back
// ---------------------------------------------------------------------------

- (void)test_isObjectOutParameterAtIndex_errorPointer_returnsYES {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^@"];
    XCTAssertTrue([ASBoxer isObjectOutParameterAtIndex:0 inSignature:sig],
                  @"^@ should be recognised as an object out-parameter");
}

- (void)test_isObjectOutParameterAtIndex_qualifiedOutErrorPointer_returnsYES {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:o^@"];
    XCTAssertTrue([ASBoxer isObjectOutParameterAtIndex:0 inSignature:sig],
                  @"o^@ (out-qualified id *) should be recognised as an object out-parameter");
}

- (void)test_isObjectOutParameterAtIndex_regularIdParameter_returnsNO {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:@"];
    XCTAssertFalse([ASBoxer isObjectOutParameterAtIndex:0 inSignature:sig],
                   @"@ (plain id) must not be treated as an object out-parameter");
}

- (void)test_boxedArgument_nonNullErrorPointer_returnsASOutObject {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^@"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];

    NSError * __autoreleasing initialError = nil;
    NSError * __autoreleasing *errPtr = &initialError;
    [inv setArgument:&errPtr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertNotNil(boxed, @"Boxing a non-NULL NSError ** should not return nil");
    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]],
                  @"Boxing a non-NULL NSError ** should return an ASOutObject");
    XCTAssertNil(((ASOutObject *)boxed).value,
                 @"Initial value of ASOutObject should match the nil pointed-to NSError *");
}

- (void)test_boxedArgument_nullErrorPointer_returnsASOutObjectWithNilValue {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^@"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];

    NSError * __autoreleasing *errPtr = NULL;
    [inv setArgument:&errPtr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertNotNil(boxed, @"Boxing a NULL NSError ** should still return an ASOutObject so [outError setValue:...] is safe");
    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]],
                  @"Boxing a NULL NSError ** should return an ASOutObject");
    XCTAssertNil(((ASOutObject *)boxed).value,
                 @"ASOutObject for a NULL NSError ** should have a nil value");

    // Writing back to an invocation with a NULL error pointer must be a safe no-op.
    ((ASOutObject *)boxed).value = [NSError errorWithDomain:@"ASTestDomain" code:1 userInfo:nil];
    XCTAssertNoThrow([ASBoxer writeBackObject:boxed atArgumentIndex:0 toInvocation:inv],
                     @"writeBackObject on a NULL error pointer must not crash");
}

- (void)test_writeBackObject_updatesPointedToError {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^@"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];

    NSError * __autoreleasing callerError = nil;
    NSError * __autoreleasing *errPtr = &callerError;
    [inv setArgument:&errPtr atIndex:2];

    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];
    NSError *producedError = [NSError errorWithDomain:@"ASTestDomain" code:123 userInfo:nil];
    outObj.value = producedError;

    [ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv];

    XCTAssertEqualObjects(callerError, producedError,
                          @"writeBackObject:atArgumentIndex:toInvocation: should write ASOutObject.value into *errPtr");
}

// ---------------------------------------------------------------------------
// Scalar and struct out-parameters ('^q', '^d', '^B', '^{...}')
// ---------------------------------------------------------------------------

- (void)test_isOutParameterAtIndex_objectScalarAndStructPointers_returnYES {
    for (NSString *types in @[@"B@:^@", @"B@:^q", @"B@:^d", @"B@:^B", @"B@:^Q", @"B@:o^{_NSRange=QQ}"]) {
        NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:types.UTF8String];
        XCTAssertTrue([ASBoxer isOutParameterAtIndex:0 inSignature:sig],
                      @"%@ should be a bridged out-parameter", types);
    }
}

- (void)test_isOutParameterAtIndex_voidPointerPointerToPointerAndPlainValues_returnNO {
    for (NSString *types in @[@"B@:^v", @"B@:^^c", @"B@:q", @"B@:@"]) {
        NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:types.UTF8String];
        XCTAssertFalse([ASBoxer isOutParameterAtIndex:0 inSignature:sig],
                       @"%@ should not be a bridged out-parameter", types);
    }
}

- (void)test_pointeeTypeEncodingOfOutParameter_scalarStructAndObject {
    XCTAssertEqualObjects([ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:0
                                inSignature:[NSMethodSignature signatureWithObjCTypes:"B@:^q"]], @"q");
    XCTAssertEqualObjects([ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:0
                                inSignature:[NSMethodSignature signatureWithObjCTypes:"B@:o^{_NSRange=QQ}"]],
                          @"{_NSRange=QQ}");
    XCTAssertNil([ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:0
                                inSignature:[NSMethodSignature signatureWithObjCTypes:"B@:^@"]],
                 @"an object out-parameter has no scalar pointee type");
}

- (void)test_boxedArgument_longLongPointer_returnsOutObjectSeededFromPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^q"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    long long number = 7;
    long long *ptr = &number;
    [inv setArgument:&ptr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]], @"a ^q should be boxed as an ASOutObject");
    XCTAssertEqualObjects(((ASOutObject *)boxed).value, @7);
    XCTAssertEqualObjects(((ASOutObject *)boxed).pointeeTypeEncoding, @"q");
}

- (void)test_boxedArgument_doublePointer_returnsOutObjectSeededFromPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^d"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    double number = 2.5;
    double *ptr = &number;
    [inv setArgument:&ptr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]]);
    XCTAssertEqualObjects(((ASOutObject *)boxed).value, @2.5);
    XCTAssertEqualObjects(((ASOutObject *)boxed).pointeeTypeEncoding, @"d");
}

- (void)test_boxedArgument_boolPointer_returnsOutObjectSeededFromPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^B"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    bool flag = true;
    bool *ptr = &flag;
    [inv setArgument:&ptr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]]);
    XCTAssertEqualObjects(((ASOutObject *)boxed).value, @YES);
    XCTAssertEqualObjects(((ASOutObject *)boxed).pointeeTypeEncoding, @"B");
}

- (void)test_boxedArgument_nullScalarPointer_returnsTypedOutObjectWithNilValue {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^q"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    long long *ptr = NULL;
    [inv setArgument:&ptr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]],
                  @"a NULL ^q should still be an ASOutObject, as a NULL ^@ is");
    XCTAssertNil(((ASOutObject *)boxed).value);
    XCTAssertEqualObjects(((ASOutObject *)boxed).pointeeTypeEncoding, @"q");
    ((ASOutObject *)boxed).value = @5;
    XCTAssertTrue([ASBoxer writeBackObject:boxed atArgumentIndex:0 toInvocation:inv],
                  @"writing to a NULL pointer is discarded, not an error");
}

- (void)test_boxedArgument_nsRangePointer_returnsOutObjectWithStructValue {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^{_NSRange=QQ}"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    NSRange range = NSMakeRange(3, 4);
    NSRange *ptr = &range;
    [inv setArgument:&ptr atIndex:2];

    id boxed = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([boxed isKindOfClass:[ASOutObject class]]);
    id value = ((ASOutObject *)boxed).value;
    XCTAssertTrue([value isKindOfClass:[ASStructValue class]], @"the pointee should box as an ASStructValue");
    NSData *expected = [NSData dataWithBytes:&range length:sizeof(range)];
    XCTAssertEqualObjects(((ASStructValue *)value).bytes, expected);
    XCTAssertEqualObjects(((ASOutObject *)boxed).pointeeTypeEncoding, @"{_NSRange=QQ}");
}

- (void)test_writeBackObject_longLongPointer_storesNumberInPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^q"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    long long caller = 1;
    long long *ptr = &caller;
    [inv setArgument:&ptr atIndex:2];
    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];
    outObj.value = @99;

    BOOL ok = [ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv];

    XCTAssertTrue(ok);
    XCTAssertEqual(caller, 99LL, @"write-back should store the NSNumber in *ptr");
}

- (void)test_writeBackObject_unmodifiedScalarOutObject_keepsPointeeValue {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^d"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    double caller = 6.25;
    double *ptr = &caller;
    [inv setArgument:&ptr atIndex:2];
    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];

    XCTAssertTrue([ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv]);

    XCTAssertEqual(caller, 6.25, @"a value the script didn't touch should round-trip unchanged");
}

- (void)test_writeBackObject_nsRangePointer_storesStructInPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^{_NSRange=QQ}"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    NSRange caller = NSMakeRange(0, 0);
    NSRange *ptr = &caller;
    [inv setArgument:&ptr atIndex:2];
    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];
    NSRange produced = NSMakeRange(10, 20);
    outObj.value = [[ASStructValue alloc] initWithBytes:&produced
                                                 length:sizeof(produced)
                                          canonicalName:@"NSRange"
                                    runtimeTypeEncoding:@"{_NSRange=QQ}"];

    BOOL ok = [ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv];

    XCTAssertTrue(ok);
    XCTAssertTrue(NSEqualRanges(caller, produced), @"write-back should store the struct in *ptr");
}

- (void)test_writeBackObject_stringForScalarPointer_returnsNOAndLeavesPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^q"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    long long caller = 1;
    long long *ptr = &caller;
    [inv setArgument:&ptr atIndex:2];
    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];
    outObj.value = @"not a number";

    BOOL ok = [ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv];

    XCTAssertFalse(ok, @"an NSString can't convert to long long");
    XCTAssertEqual(caller, 1LL, @"a failed conversion must not change the pointee");
}

- (void)test_writeBackObject_nilForScalarPointer_returnsNOAndLeavesPointee {
    NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"B@:^q"];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    long long caller = 1;
    long long *ptr = &caller;
    [inv setArgument:&ptr atIndex:2];
    ASOutObject *outObj = [ASBoxer boxedArgumentAtIndex:0 fromInvocation:inv];
    outObj.value = nil;

    BOOL ok = [ASBoxer writeBackObject:outObj atArgumentIndex:0 toInvocation:inv];

    XCTAssertFalse(ok, @"nil has no scalar equivalent (ADR 11)");
    XCTAssertEqual(caller, 1LL);
}

// ---------------------------------------------------------------------------
// Struct boxing, unboxing, and byte-level API tests
// ---------------------------------------------------------------------------

- (void)test_boxedReturnValue_NSRange_returnsASStructValueWithCanonicalNameNSRange {
    ASBridgeSupportStructField *loc = [[ASBridgeSupportStructField alloc] initWithName:@"location" typeEncoding:@"Q"];
    ASBridgeSupportStructField *len = [[ASBridgeSupportStructField alloc] initWithName:@"length" typeEncoding:@"Q"];
    ASBridgeSupportStruct *rangeStruct = [[ASBridgeSupportStruct alloc] initWithCanonicalName:@"NSRange"
                                                                                       fields:@[loc, len]];
    [ASStructValue registerStruct:rangeStruct];

    NSString *str = @"hello world";
    NSMethodSignature *sig = [str methodSignatureForSelector:@selector(rangeOfString:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = str;
    inv.selector = @selector(rangeOfString:);
    NSString *needle = @"world";
    [inv setArgument:&needle atIndex:2];
    [inv invoke];

    id boxed = [ASBoxer boxedReturnValueFromInvocation:inv];
    XCTAssertTrue([boxed isKindOfClass:[ASStructValue class]],
                  @"NSRange return value should be boxed as ASStructValue, got %@", [boxed class]);
    ASStructValue *sv = (ASStructValue *)boxed;
    XCTAssertEqualObjects(sv.canonicalName, @"NSRange");
    NSRange extracted = [[sv asNSValue] rangeValue];
    XCTAssertEqual(extracted.location, (NSUInteger)6);
    XCTAssertEqual(extracted.length, (NSUInteger)5);
}

- (void)test_unboxObject_ASStructValueAndNSValueIntoNSRangeArgument_invokesCorrectly {
    NSString *str = @"hello world";
    NSMethodSignature *sig = [str methodSignatureForSelector:@selector(substringWithRange:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = str;
    inv.selector = @selector(substringWithRange:);

    NSRange range = NSMakeRange(6, 5);
    ASStructValue *sv = [[ASStructValue alloc] initWithBytes:&range
                                                      length:sizeof(NSRange)
                                               canonicalName:@"NSRange"
                                         runtimeTypeEncoding:@(@encode(NSRange))];

    [ASBoxer unboxObject:sv intoArgumentAtIndex:0 ofInvocation:inv];
    [inv invoke];

    __unsafe_unretained NSString *sub1 = nil;
    [inv getReturnValue:&sub1];
    XCTAssertEqualObjects(sub1, @"world");

    // Also verify NSValue unboxing into the same NSRange argument slot.
    NSValue *nsv = [NSValue valueWithRange:NSMakeRange(0, 5)];
    [ASBoxer unboxObject:nsv intoArgumentAtIndex:0 ofInvocation:inv];
    [inv invoke];

    __unsafe_unretained NSString *sub2 = nil;
    [inv getReturnValue:&sub2];
    XCTAssertEqualObjects(sub2, @"hello");
}

- (void)test_boxedObjectFromBytes_and_unboxObjectIntoBytes_structAndSizeMismatch {
    NSRect rect = NSMakeRect(10.0, 20.0, 30.0, 40.0);
    id boxed = [ASBoxer boxedObjectFromBytes:&rect typeEncoding:@encode(NSRect)];
    XCTAssertTrue([boxed isKindOfClass:[ASStructValue class]],
                  @"boxedObjectFromBytes for NSRect should return ASStructValue");
    ASStructValue *sv = (ASStructValue *)boxed;
    XCTAssertEqualObjects(sv.canonicalName, @"CGRect");

    NSRect outRect = NSZeroRect;
    BOOL ok = [ASBoxer unboxObject:sv
                         intoBytes:&outRect
                            ofSize:sizeof(NSRect)
                      typeEncoding:@encode(NSRect)];
    XCTAssertTrue(ok, @"Unboxing CGRect ASStructValue into matching NSRect buffer should succeed");
    XCTAssertTrue(NSEqualRects(rect, outRect));

    // Size mismatch: trying to unbox a CGRect (32 bytes) into an NSRange (16 bytes) buffer must fail safely.
    NSRange outRange = NSMakeRange(1, 2);
    BOOL badOk = [ASBoxer unboxObject:sv
                            intoBytes:&outRange
                               ofSize:sizeof(NSRange)
                         typeEncoding:@encode(NSRange)];
    XCTAssertFalse(badOk, @"Unboxing a 32-byte CGRect into a 16-byte NSRange slot must return NO");
    XCTAssertEqual(outRange.location, (NSUInteger)1, @"Destination buffer must not be overwritten on size mismatch");
}

// ---------------------------------------------------------------------------
// Selector (SEL, ':') boxing tests
// ---------------------------------------------------------------------------

- (void)test_boxedObjectFromBytes_selector_returnsSelectorName {
    SEL sel = @selector(objectAtIndex:);
    id boxed = [ASBoxer boxedObjectFromBytes:&sel typeEncoding:@encode(SEL)];
    XCTAssertEqualObjects(boxed, @"objectAtIndex:",
                          @"A SEL should box to an NSString holding the selector name");
}

- (void)test_boxedObjectFromBytes_nullSelector_returnsNil {
    SEL sel = NULL;
    id boxed = [ASBoxer boxedObjectFromBytes:&sel typeEncoding:@encode(SEL)];
    XCTAssertNil(boxed, @"A NULL SEL should box to nil");
}

- (void)test_unboxObject_stringIntoSelectorBytes_writesSelector {
    SEL out = NULL;
    BOOL ok = [ASBoxer unboxObject:@"objectAtIndex:"
                         intoBytes:&out
                            ofSize:sizeof(SEL)
                      typeEncoding:@encode(SEL)];
    XCTAssertTrue(ok, @"Unboxing an NSString into a SEL slot should succeed");
    XCTAssertEqual(out, @selector(objectAtIndex:),
                   @"The SEL slot should hold the selector named by the string");
}

- (void)test_unboxObject_nilIntoSelectorBytes_writesNULL {
    SEL out = @selector(description);
    BOOL ok = [ASBoxer unboxObject:nil
                         intoBytes:&out
                            ofSize:sizeof(SEL)
                      typeEncoding:@encode(SEL)];
    XCTAssertTrue(ok, @"Unboxing nil into a SEL slot should succeed");
    XCTAssertTrue(out == NULL, @"nil should unbox to a NULL SEL");
}

- (void)test_unboxObject_numberIntoSelectorBytes_returnsNO {
    SEL out = @selector(description);
    BOOL ok = [ASBoxer unboxObject:@42
                         intoBytes:&out
                            ofSize:sizeof(SEL)
                      typeEncoding:@encode(SEL)];
    XCTAssertFalse(ok, @"Only NSString or nil may be unboxed into a SEL slot");
    XCTAssertEqual(out, @selector(description), @"Destination must not be overwritten on failure");
}

- (void)test_unboxObject_stringIntoSelectorArgument_invokesCorrectly {
    // -[NSObject respondsToSelector:(SEL)aSelector]
    NSString *target = @"abc";
    NSMethodSignature *sig = [target methodSignatureForSelector:@selector(respondsToSelector:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = @selector(respondsToSelector:);

    [ASBoxer unboxObject:@"length" intoArgumentAtIndex:0 ofInvocation:inv];
    [inv invoke];

    BOOL responds = NO;
    [inv getReturnValue:&responds];
    XCTAssertTrue(responds, @"respondsToSelector: should receive the SEL named by the string");
}

- (void)test_boxedReturnValue_selectorReturnType_returnsSelectorName {
    // -[NSInvocation selector] returns SEL
    NSMethodSignature *countSig = [@[] methodSignatureForSelector:@selector(count)];
    NSInvocation *subject = [NSInvocation invocationWithMethodSignature:countSig];
    subject.selector = @selector(count);

    NSInvocation *inv = [self invokedInvocationForSelector:@selector(selector) onTarget:subject];
    id result = [ASBoxer boxedReturnValueFromInvocation:inv];

    XCTAssertEqualObjects(result, @"count", @"A SEL return value should box to its name");
}

// ---------------------------------------------------------------------------
// Unboxing failure reporting
// ---------------------------------------------------------------------------

/// Returns an invocation of -[NSObject respondsToSelector:] on a string, ready for its SEL argument.
- (NSInvocation *)respondsToSelectorInvocation {
    NSString *target = @"abc";
    NSMethodSignature *sig = [target methodSignatureForSelector:@selector(respondsToSelector:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = @selector(respondsToSelector:);
    return inv;
}

- (void)test_unboxObjectIntoArgument_convertibleObject_returnsYES {
    NSInvocation *inv = [self respondsToSelectorInvocation];
    BOOL ok = [ASBoxer unboxObject:@"length" intoArgumentAtIndex:0 ofInvocation:inv];
    XCTAssertTrue(ok, @"Unboxing a string into a SEL argument should report success");
}

- (void)test_unboxObjectIntoArgument_unconvertibleObject_returnsNO {
    NSInvocation *inv = [self respondsToSelectorInvocation];
    BOOL ok = [ASBoxer unboxObject:@42 intoArgumentAtIndex:0 ofInvocation:inv];
    XCTAssertFalse(ok, @"Unboxing a number into a SEL argument should report failure");
}

- (void)test_unboxObjectIntoReturnValue_unconvertibleObject_returnsNO {
    // -[NSInvocation selector] returns SEL
    NSMethodSignature *sig = [NSInvocation instanceMethodSignatureForSelector:@selector(selector)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    BOOL ok = [ASBoxer unboxObject:@42 intoReturnValueOfInvocation:inv];
    XCTAssertFalse(ok, @"Unboxing a number into a SEL return value should report failure");
}

- (void)test_unboxObjectIntoReturnValue_convertibleObject_returnsYES {
    NSMethodSignature *sig = [NSInvocation instanceMethodSignatureForSelector:@selector(selector)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    BOOL ok = [ASBoxer unboxObject:@"count" intoReturnValueOfInvocation:inv];
    XCTAssertTrue(ok, @"Unboxing a string into a SEL return value should report success");
}

- (void)test_displayNameForTypeEncoding_selector_returnsSEL {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:@encode(SEL)], @"SEL");
}

- (void)test_displayNameForTypeEncoding_double_returnsDouble {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:@encode(double)], @"double");
}

- (void)test_displayNameForTypeEncoding_underscoredStruct_returnsPublicStructName {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:@encode(NSRange)], @"NSRange");
}

- (void)test_displayNameForTypeEncoding_struct_returnsStructName {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:@encode(CGRect)], @"CGRect");
}

- (void)test_displayNameForTypeEncoding_qualifiedObject_ignoresQualifier {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:"r@"], @"id");
}

- (void)test_displayNameForTypeEncoding_unknownEncoding_returnsEncoding {
    XCTAssertEqualObjects([ASBoxer displayNameForTypeEncoding:"!"], @"!");
}

// ---------------------------------------------------------------------------
// Accepted objects per C type (ARCHITECTURE.md "Conversion failures")
// ---------------------------------------------------------------------------

- (void)test_unboxObject_stringIntoInt_returnsNO {
    int out = 7;
    BOOL ok = [ASBoxer unboxObject:@"42" intoBytes:&out ofSize:sizeof(int) typeEncoding:@encode(int)];
    XCTAssertFalse(ok, @"Only NSNumber may be unboxed into a scalar");
    XCTAssertEqual(out, 7, @"Destination must not be overwritten on failure");
}

- (void)test_unboxObject_nilIntoInt_returnsNO {
    int out = 7;
    BOOL ok = [ASBoxer unboxObject:nil intoBytes:&out ofSize:sizeof(int) typeEncoding:@encode(int)];
    XCTAssertFalse(ok, @"nil must not be unboxed into a scalar as zero");
    XCTAssertEqual(out, 7);
}

- (void)test_unboxObject_nilIntoBOOL_returnsNO {
    BOOL out = YES;
    BOOL ok = [ASBoxer unboxObject:nil intoBytes:&out ofSize:sizeof(BOOL) typeEncoding:@encode(BOOL)];
    XCTAssertFalse(ok, @"nil must not be unboxed into a BOOL as NO");
}

- (void)test_unboxObject_arrayIntoDouble_returnsNO {
    double out = 1.5;
    BOOL ok = [ASBoxer unboxObject:@[@1] intoBytes:&out ofSize:sizeof(double) typeEncoding:@encode(double)];
    XCTAssertFalse(ok, @"An object without numeric accessors must be rejected, not raise");
}

- (void)test_unboxObject_numberIntoDouble_writesValue {
    double out = 0;
    BOOL ok = [ASBoxer unboxObject:@2.5 intoBytes:&out ofSize:sizeof(double) typeEncoding:@encode(double)];
    XCTAssertTrue(ok);
    XCTAssertEqual(out, 2.5);
}

- (void)test_unboxObject_numberIntoCString_returnsNO {
    const char *out = "unchanged";
    BOOL ok = [ASBoxer unboxObject:@42 intoBytes:&out ofSize:sizeof(char *) typeEncoding:@encode(char *)];
    XCTAssertFalse(ok, @"Only NSString may be unboxed into a C string");
}

- (void)test_unboxObject_nilIntoCString_writesNULL {
    const char *out = "unchanged";
    BOOL ok = [ASBoxer unboxObject:nil intoBytes:&out ofSize:sizeof(char *) typeEncoding:@encode(char *)];
    XCTAssertTrue(ok, @"nil is a valid C string (NULL)");
    XCTAssertTrue(out == NULL);
}

- (void)test_unboxObject_stringIntoClass_returnsNO {
    Class out = [NSObject class];
    BOOL ok = [ASBoxer unboxObject:@"NSString" intoBytes:&out ofSize:sizeof(Class) typeEncoding:@encode(Class)];
    XCTAssertFalse(ok, @"A non-class object must not be reinterpreted as a Class");
    XCTAssertEqual(out, [NSObject class]);
}

- (void)test_unboxObject_classIntoClass_writesClass {
    Class out = Nil;
    BOOL ok = [ASBoxer unboxObject:[NSString class] intoBytes:&out ofSize:sizeof(Class) typeEncoding:@encode(Class)];
    XCTAssertTrue(ok);
    XCTAssertEqual(out, [NSString class]);
}

- (void)test_unboxObject_nilIntoClass_writesNil {
    Class out = [NSObject class];
    BOOL ok = [ASBoxer unboxObject:nil intoBytes:&out ofSize:sizeof(Class) typeEncoding:@encode(Class)];
    XCTAssertTrue(ok, @"nil is a valid Class (Nil)");
    XCTAssertTrue(out == Nil);
}

- (void)test_unboxObject_nilIntoStruct_returnsNO {
    NSRange out = NSMakeRange(1, 2);
    BOOL ok = [ASBoxer unboxObject:nil intoBytes:&out ofSize:sizeof(NSRange) typeEncoding:@encode(NSRange)];
    XCTAssertFalse(ok, @"nil must not be unboxed into a struct as all-zero");
    XCTAssertEqual(out.location, (NSUInteger)1);
}

@end
