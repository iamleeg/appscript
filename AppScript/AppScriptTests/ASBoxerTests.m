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

@end
