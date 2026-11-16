// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockTrampolineTests.m — Unit tests for ASBlockTrampoline
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
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASNull.h>

/// A stand-in for the block the interpreter builds for a script's block literal: tests supply the
/// invoker directly, so the trampoline is exercised without the interpreter.
static id makeScriptBlock(NSUInteger parameterCount, id _Nullable (^invoker)(NSArray *arguments)) {
    id (^plain)(void) = ^id{ return nil; };
    id block = [plain copy];
    [ASBlockTrampoline attachInvoker:invoker parameterCount:parameterCount toScriptBlock:block];
    return block;
}

static ASBridgeSupportBlockSignature *makeSignature(NSArray<NSString *> *params, NSString *ret) {
    return [[ASBridgeSupportBlockSignature alloc] initWithClassName:@"X"
                                                       selectorName:@"x:"
                                                      isClassMethod:NO
                                                      argumentIndex:0
                                             parameterTypeEncodings:params
                                                 returnTypeEncoding:ret];
}

@interface ASBlockTrampolineTests : XCTestCase
@end

@implementation ASBlockTrampolineTests

- (id)wrap:(id)scriptBlock params:(NSArray<NSString *> *)params returning:(NSString *)ret {
    NSError *error = nil;
    id wrapped = [ASBlockTrampoline blockWrappingScriptBlock:scriptBlock
                                                   signature:makeSignature(params, ret)
                                                       error:&error];
    XCTAssertNotNil(wrapped, @"%@", error);
    return wrapped;
}

// ---------------------------------------------------------------------------
// Script block marking
// ---------------------------------------------------------------------------

- (void)test_isScriptBlock_attachedBlock_isYESAndReportsParameterCount {
    id script = makeScriptBlock(3, ^id(NSArray *a) { return nil; });
    XCTAssertTrue([ASBlockTrampoline isScriptBlock:script]);
    XCTAssertEqual([ASBlockTrampoline parameterCountOfScriptBlock:script], 3u);
}

- (void)test_isScriptBlock_plainBlockAndNil_areNO {
    id (^plain)(void) = ^id{ return nil; };
    XCTAssertFalse([ASBlockTrampoline isScriptBlock:[plain copy]]);
    XCTAssertFalse([ASBlockTrampoline isScriptBlock:nil]);
    XCTAssertFalse([ASBlockTrampoline isScriptBlock:@"not a block"]);
}

// ---------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------

- (void)test_wrap_enumerateSignature_boxesArgumentsAndWritesBackStopFlag {
    __block NSArray *received = nil;
    id script = makeScriptBlock(3, ^id(NSArray *args) {
        received = args;
        ((ASOutObject *)args[2]).value = @YES;
        return nil;
    });
    id wrapped = [self wrap:script params:@[@"@", @"Q", @"^B"] returning:@"v"];
    if (!wrapped) { return; }

    BOOL stop = NO;
    ((void (^)(id, NSUInteger, BOOL *))wrapped)(@"item", 3, &stop);

    XCTAssertEqualObjects(received[0], @"item", @"an object argument arrives as the object");
    XCTAssertEqualObjects(received[1], @3, @"an NSUInteger arrives as an NSNumber");
    XCTAssertTrue([received[2] isKindOfClass:[ASOutObject class]], @"BOOL * arrives as an ASOutObject");
    XCTAssertEqualObjects(((ASOutObject *)received[2]).pointeeTypeEncoding, @"B");
    XCTAssertEqualObjects(((ASOutObject *)received[2]).value, @YES);
    XCTAssertTrue(stop, @"the script's write to the out-object must reach the caller's BOOL");
}

- (void)test_wrap_stopFlagLeftAlone_keepsCallersValue {
    id script = makeScriptBlock(3, ^id(NSArray *args) { return nil; });
    id wrapped = [self wrap:script params:@[@"@", @"Q", @"^B"] returning:@"v"];
    if (!wrapped) { return; }
    BOOL stop = NO;
    ((void (^)(id, NSUInteger, BOOL *))wrapped)(@"item", 0, &stop);
    XCTAssertFalse(stop);
}

- (void)test_wrap_doubleParameterAndReturn_roundTripsThroughFloatingPointRegisters {
    id script = makeScriptBlock(1, ^id(NSArray *args) {
        return @([args[0] doubleValue] * 2.0);
    });
    id wrapped = [self wrap:script params:@[@"d"] returning:@"d"];
    if (!wrapped) { return; }
    XCTAssertEqual(((double (^)(double))wrapped)(2.5), 5.0);
}

- (void)test_wrap_structParameter_arrivesAsStructValue {
    __block NSRange seen = NSMakeRange(0, 0);
    id script = makeScriptBlock(1, ^id(NSArray *args) {
        [((ASStructValue *)args[0]).bytes getBytes:&seen length:sizeof(seen)];
        return @(seen.length);
    });
    id wrapped = [self wrap:script params:@[@"{_NSRange=QQ}"] returning:@"q"];
    if (!wrapped) { return; }
    NSInteger length = ((NSInteger (^)(NSRange))wrapped)(NSMakeRange(4, 9));
    XCTAssertEqual(length, 9);
    XCTAssertTrue(NSEqualRanges(seen, NSMakeRange(4, 9)));
}

// ---------------------------------------------------------------------------
// Return values
// ---------------------------------------------------------------------------

- (void)test_wrap_comparatorSignature_convertsNumberToInteger {
    __block NSInteger result = 0;
    id script = makeScriptBlock(2, ^id(NSArray *args) { return @(result); });
    id wrapped = [self wrap:script params:@[@"@", @"@"] returning:@"q"];
    if (!wrapped) { return; }
    for (NSNumber *value in @[@-1, @0, @1, @-9000000000]) {
        result = value.integerValue;
        XCTAssertEqual(((NSInteger (^)(id, id))wrapped)(@"a", @"b"), result);
    }
}

- (void)test_wrap_smallIntegerReturns_areSignAndZeroExtended {
    __block NSNumber *result = @-300;
    id script = makeScriptBlock(1, ^id(NSArray *args) { return result; });
    id wrappedShort = [self wrap:script params:@[@"@"] returning:@"s"];
    if (!wrappedShort) { return; }
    XCTAssertEqual(((short (^)(id))wrappedShort)(@"x"), (short)-300);
    result = @YES;
    id wrappedBool = [self wrap:script params:@[@"@"] returning:@"B"];
    if (!wrappedBool) { return; }
    XCTAssertTrue(((BOOL (^)(id))wrappedBool)(@"x"));
    result = @NO;
    XCTAssertFalse(((BOOL (^)(id))wrappedBool)(@"x"));
}

- (void)test_wrap_objectReturn_isHandedBackAndNilIsNil {
    __block id result = @"result";
    id script = makeScriptBlock(1, ^id(NSArray *args) { return result; });
    id wrapped = [self wrap:script params:@[@"@"] returning:@"@"];
    if (!wrapped) { return; }
    XCTAssertEqualObjects(((id (^)(id))wrapped)(@"x"), @"result");
    result = [ASNull null];
    XCTAssertNil(((id (^)(id))wrapped)(@"x"), @"AppScript nil comes back as nil");
}

- (void)test_wrap_voidReturn_ignoresScriptResult {
    id script = makeScriptBlock(1, ^id(NSArray *args) { return @"ignored"; });
    id wrapped = [self wrap:script params:@[@"@"] returning:@"v"];
    if (!wrapped) { return; }
    XCTAssertNoThrow(((void (^)(id))wrapped)(@"x"));
}

- (void)test_wrap_unconvertibleReturn_raisesValueConversionFailedToTheCaller {
    id script = makeScriptBlock(2, ^id(NSArray *args) { return @"not a number"; });
    id wrapped = [self wrap:script params:@[@"@", @"@"] returning:@"q"];
    if (!wrapped) { return; }
    @try {
        (void)((NSInteger (^)(id, id))wrapped)(@"a", @"b");
        XCTFail(@"an NSString can't be returned as an NSInteger");
    } @catch (NSException *ex) {
        XCTAssertEqualObjects(ex.name, ASRuntimeErrorException);
        XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    }
}

// ---------------------------------------------------------------------------
// Lifetime and threads
// ---------------------------------------------------------------------------

- (void)test_wrap_calledLaterOnAnotherQueue_afterTheScriptBlockIsGone {
    __block NSNumber *received = nil;
    dispatch_semaphore_t called = dispatch_semaphore_create(0);
    void (^handler)(NSInteger) = nil;
    @autoreleasepool {
        id script = makeScriptBlock(1, ^id(NSArray *args) {
            received = args[0];
            dispatch_semaphore_signal(called);
            return nil;
        });
        id wrapped = [self wrap:script params:@[@"q"] returning:@"v"];
        if (!wrapped) { return; }
        handler = (void (^)(NSInteger))[wrapped copy];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handler(9);
    });
    XCTAssertEqual(dispatch_semaphore_wait(called, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0L,
                   @"the completion handler should have run on the other queue");
    XCTAssertEqualObjects(received, @9);
}

// ---------------------------------------------------------------------------
// Unsupported signatures
// ---------------------------------------------------------------------------

- (void)test_wrap_unionParameter_failsWithUnsupportedTypeError {
    id script = makeScriptBlock(1, ^id(NSArray *args) { return nil; });
    NSError *error = nil;
    id wrapped = [ASBlockTrampoline blockWrappingScriptBlock:script
                                                   signature:makeSignature(@[@"(U=iq)"], @"v")
                                                       error:&error];
    XCTAssertNil(wrapped);
    XCTAssertEqualObjects(error.domain, ASBlockTrampolineErrorDomain);
    XCTAssertEqual(error.code, ASBlockTrampolineErrorUnsupportedType);
    XCTAssertTrue([error.localizedDescription containsString:@"(U=iq)"], @"the message names the type: %@", error);
}

@end
