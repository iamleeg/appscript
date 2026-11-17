// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockSendTests.m — Script blocks passed to Cocoa methods that call them with C types
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
#import <AppScript/ASBridgeSupportParser.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportInstaller.h>
#import <AppScript/ASStructValue.h>
#import <AppScript/ASBridgeSupportFunction.h>

/// A Foundation stand-in for Cocoa APIs that take blocks (ADR 31). Its block signatures are registered
/// from BridgeSupport XML below, as the system's BridgeSupport files do for the real classes.
@interface ASTestBlockHost : NSObject
- (void)enumerate:(NSArray *)items usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;
- (NSArray *)sort:(NSArray *)items usingComparator:(NSInteger (^)(id a, id b))comparator;
- (void)finishWithCompletion:(void (^)(NSInteger code))handler;
- (void)finishLaterWithCompletion:(void (^)(NSInteger code))handler;
- (double)scale:(double)x using:(double (^)(double x))block;
- (long double)scaleLong:(long double)x using:(long double (^)(long double x))block;
- (NSInteger)lengthOf:(NSRange)range using:(NSInteger (^)(NSRange range))block;
- (id)transform:(id)value usingBlock:(id (^)(id value))block;
- (void)noMetadata:(void (^)(NSInteger code))block;
@end

@implementation ASTestBlockHost
- (void)enumerate:(NSArray *)items usingBlock:(void (^)(id, NSUInteger, BOOL *))block {
    BOOL stop = NO;
    for (NSUInteger i = 0; i < items.count && !stop; i++) {
        block(items[i], i, &stop);
    }
}
- (NSArray *)sort:(NSArray *)items usingComparator:(NSInteger (^)(id, id))comparator {
    NSMutableArray *result = [items mutableCopy];
    for (NSUInteger i = 0; i < result.count; i++) {
        for (NSUInteger j = 0; j + 1 < result.count - i; j++) {
            if (comparator(result[j], result[j + 1]) > 0) {
                [result exchangeObjectAtIndex:j withObjectAtIndex:j + 1];
            }
        }
    }
    return result;
}
- (void)finishWithCompletion:(void (^)(NSInteger))handler {
    handler(7);
}
- (void)finishLaterWithCompletion:(void (^)(NSInteger))handler {
    void (^kept)(NSInteger) = [handler copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        kept(9);
    });
}
- (double)scale:(double)x using:(double (^)(double))block {
    return block(x);
}
- (long double)scaleLong:(long double)x using:(long double (^)(long double))block {
    return block(x);
}
- (NSInteger)lengthOf:(NSRange)range using:(NSInteger (^)(NSRange))block {
    return block(range);
}
- (id)transform:(id)value usingBlock:(id (^)(id))block {
    return block(value);
}
- (void)noMetadata:(void (^)(NSInteger))block {
    block(1);
}
@end

@protocol ASTestBlockScript <NSObject>
- (id)run;
- (id)runWithResults:(NSMutableArray *)results semaphore:(id)semaphore;
- (id)runWithRange:(NSRange)range;
- (id)runWith:(id)value;
- (id)runWith:(id)value and:(id)other;
- (void)finishTask:(id)task completionHandler:(void (^)(BOOL success, NSError *error))handler;
@end

/// An object a script can send `-signal` to, running a block (stands in for a dispatch semaphore).
@interface ASTestBlockHostSignaller : NSObject
- (instancetype)initWithBlock:(void (^)(void))block;
- (void)signal;
@end

@implementation ASTestBlockHostSignaller {
    void (^_block)(void);
}
- (instancetype)initWithBlock:(void (^)(void))block {
    self = [super init];
    if (self) {
        _block = [block copy];
    }
    return self;
}
- (void)signal {
    _block();
}
@end

static NSString *uniqueClassName(NSString *prefix) {
    return [NSString stringWithFormat:@"%@_%@", prefix,
            [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

@interface ASBlockSendTests : XCTestCase
@end

@implementation ASBlockSendTests

- (void)setUp {
    [super setUp];
    // GNUstep's XCTest has no +setUp, so register the stand-in's signatures once from here.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [ASBlockSendTests registerHostSignatures];
    });
}

+ (void)registerHostSignatures {
    __attribute__((unused)) Protocol *ensure = @protocol(ASTestBlockScript);
    NSString *xml =
        @"<?xml version='1.0'?><signatures version='1.0'><class name='ASTestBlockHost'>"
        @"<method selector='enumerate:usingBlock:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='@'/><arg type64='Q'/><arg type64='^B' type_modifier='o'/><retval type64='v'/></arg></method>"
        @"<method selector='sort:usingComparator:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='@'/><arg type64='@'/><retval type64='q'/></arg></method>"
        @"<method selector='finishWithCompletion:'><arg index='0' function_pointer='true' type64='@?'>"
        @"<arg type64='q'/><retval type64='v'/></arg></method>"
        @"<method selector='finishLaterWithCompletion:'><arg index='0' function_pointer='true' type64='@?'>"
        @"<arg type64='q'/><retval type64='v'/></arg></method>"
        @"<method selector='scale:using:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='d'/><retval type64='d'/></arg></method>"
        @"<method selector='scaleLong:using:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='D'/><retval type64='D'/></arg></method>"
        @"<method selector='lengthOf:using:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='{_NSRange=QQ}'/><retval type64='q'/></arg></method>"
        @"<method selector='transform:usingBlock:'><arg index='1' function_pointer='true' type64='@?'>"
        @"<arg type64='@'/><retval type64='@'/></arg></method>"
        @"</class></signatures>";
    ASBridgeSupportDocument *document = [[[ASBridgeSupportParser alloc] init]
        parseData:[xml dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    [[ASBlockRegistry sharedRegistry] registerSignatures:document.blockSignatures];
}

/// Loads a script class whose methods are `methods`, and returns an instance.
- (id<ASTestBlockScript>)scriptWithMethods:(NSString *)methods conformingToProtocol:(BOOL)conforms {
    NSString *className = uniqueClassName(@"ASTestBlockScriptClass");
    NSString *source = [NSString stringWithFormat:@"@class %@ : NSObject%@\n%@\n@end\n",
                        className, conforms ? @" <ASTestBlockScript>" : @"", methods];
    NSError *error = nil;
    XCTAssertTrue([[[ASLoader alloc] init] loadScriptFromString:source error:&error], @"%@", error);
    return [[NSClassFromString(className) alloc] init];
}

- (id)resultOfRunning:(NSString *)body {
    id<ASTestBlockScript> script =
        [self scriptWithMethods:[NSString stringWithFormat:@"- run {\n%@\n}", body] conformingToProtocol:NO];
    return [script run];
}

- (NSException *)exceptionRunning:(NSString *)body {
    @try {
        (void)[self resultOfRunning:body];
    } @catch (NSException *ex) {
        return ex;
    }
    return nil;
}

- (void)test_enumerateBlock_receivesObjectsAndNumbers {
    id result = [self resultOfRunning:
        @"    id seen = [NSMutableArray array]\n"
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host enumerate:@[@\"b\", @\"a\", @\"c\"] usingBlock:^(obj idx stop) {\n"
        @"        [seen addObject:@[obj, idx]]\n"
        @"    }]\n"
        @"    return seen"];
    NSArray *expected = @[@[@"b", @0], @[@"a", @1], @[@"c", @2]];
    XCTAssertEqualObjects(result, expected, @"the index arrives as an NSNumber");
}

- (void)test_enumerateBlock_settingStopFlag_stopsTheLoop {
    id result = [self resultOfRunning:
        @"    id seen = [NSMutableArray array]\n"
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host enumerate:@[@\"b\", @\"a\", @\"c\"] usingBlock:^(obj idx stop) {\n"
        @"        [seen addObject:obj]\n"
        @"        [[idx isEqualToNumber:1] ifTrue:^{\n"
        @"            [stop setValue:YES]\n"
        @"        }]\n"
        @"    }]\n"
        @"    return seen"];
    NSArray *expected = @[@"b", @"a"];
    XCTAssertEqualObjects(result, expected, @"setting the stop flag at index 1 should end the loop there");
}

- (void)test_comparatorBlock_resultIsConvertedToInteger {
    id ascending = [self resultOfRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host sort:@[@\"b\", @\"a\", @\"c\"] usingComparator:^(a b) {\n"
        @"        return [a compare:b]\n"
        @"    }]"];
    NSArray *expectedAscending = @[@"a", @"b", @"c"];
    XCTAssertEqualObjects(ascending, expectedAscending);
    id descending = [self resultOfRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host sort:@[@\"b\", @\"a\", @\"c\"] usingComparator:^(a b) {\n"
        @"        return [b compare:a]\n"
        @"    }]"];
    NSArray *expectedDescending = @[@"c", @"b", @"a"];
    XCTAssertEqualObjects(descending, expectedDescending);
}

- (void)test_completionBlock_receivesIntegerAsNumber {
    id result = [self resultOfRunning:
        @"    id seen = [NSMutableArray array]\n"
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host finishWithCompletion:^(code) {\n"
        @"        [seen addObject:code]\n"
        @"    }]\n"
        @"    return seen"];
    NSArray *expected = @[@7];
    XCTAssertEqualObjects(result, expected);
}

- (void)test_completionBlock_calledLaterOnAnotherQueue_afterTheScriptMethodReturned {
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- runWithResults: results semaphore: semaphore {\n"
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host finishLaterWithCompletion:^(code) {\n"
        @"        [results addObject:code]\n"
        @"        [semaphore signal]\n"
        @"    }]\n"
        @"    return nil\n"
        @"}" conformingToProtocol:YES];
    NSMutableArray *results = [NSMutableArray array];
    NSCondition *condition = [[NSCondition alloc] init];
    __block BOOL signalled = NO;
    // A stand-in for a semaphore the script can message: signals the condition when told to.
    id semaphore = [[ASTestBlockHostSignaller alloc] initWithBlock:^{
        [condition lock]; signalled = YES; [condition signal]; [condition unlock];
    }];
    (void)[script runWithResults:results semaphore:semaphore];
    [condition lock];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!signalled && [condition waitUntilDate:deadline]) {}
    [condition unlock];
    XCTAssertTrue(signalled, @"the completion handler should run on another queue after the method returned");
    @synchronized (results) {
        NSArray *expected = @[@9];
        XCTAssertEqualObjects(results, expected);
    }
}

- (void)test_doubleBlock_roundTripsAsNumbers {
    id result = [self resultOfRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host scale:2.5 using:^(x) {\n"
        @"        return [x numberByMultiplyingBy:2.0]\n"
        @"    }]"];
    XCTAssertEqualObjects(result, @5.0);
}

- (void)test_longDoubleBlock_roundTripsAsNumbers {
    id result = [self resultOfRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host scaleLong:2.5 using:^(x) {\n"
        @"        return [x numberByMultiplyingBy:2.0]\n"
        @"    }]"];
    XCTAssertEqualObjects(result, @5.0);
}

- (void)test_structBlock_receivesStructAndReturnsInteger {
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- runWithRange: range {\n"
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host lengthOf:range using:^(r) {\n"
        @"        return 42\n"
        @"    }]\n"
        @"}" conformingToProtocol:YES];
    XCTAssertEqualObjects([script runWithRange:NSMakeRange(3, 5)], @42);
}

- (void)test_objectOnlyBlock_isPassedThroughAndWorks {
    id result = [self resultOfRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host transform:@\"x\" usingBlock:^(v) {\n"
        @"        return [v stringByAppendingString:@\"!\"]\n"
        @"    }]"];
    XCTAssertEqualObjects(result, @"x!");
}

- (void)test_nativeNSArraySortedArrayUsingComparator_acceptsAScriptBlock {
    id ascending = [self resultOfRunning:
        @"    return [@[@\"b\", @\"a\", @\"c\"] sortedArrayUsingComparator:^(a b) {\n"
        @"        return [a compare:b]\n"
        @"    }]"];
    NSArray *expectedAscending = @[@"a", @"b", @"c"];
    XCTAssertEqualObjects(ascending, expectedAscending);
    id descending = [self resultOfRunning:
        @"    return [@[@\"b\", @\"a\", @\"c\"] sortedArrayUsingComparator:^(a b) {\n"
        @"        return [b compare:a]\n"
        @"    }]"];
    NSArray *expectedDescending = @[@"c", @"b", @"a"];
    XCTAssertEqualObjects(descending, expectedDescending);
}

- (void)test_nativeNSArrayEnumerateObjectsUsingBlock_hasIndexAndWritableStopFlag {
    id result = [self resultOfRunning:
        @"    id seen = [NSMutableArray array]\n"
        @"    [@[@\"b\", @\"a\", @\"c\"] enumerateObjectsUsingBlock:^(obj idx stop) {\n"
        @"        [seen addObject:@[obj, idx]]\n"
        @"        [[idx isEqualToNumber:1] ifTrue:^{\n"
        @"            [stop setValue:YES]\n"
        @"        }]\n"
        @"    }]\n"
        @"    return seen"];
    NSArray *expected = @[@[@"b", @0], @[@"a", @1]];
    XCTAssertEqualObjects(result, expected, @"the index is an NSNumber and the loop stops after the flag is set");
}

- (void)test_blockWithWrongParameterCount_raisesValueConversionFailed {
    NSException *ex = [self exceptionRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host enumerate:@[@\"a\"] usingBlock:^(obj idx) {\n"
        @"    }]\n"
        @"    return nil"];
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException);
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    XCTAssertTrue([ex.reason containsString:@"takes 2 parameters"], @"%@", ex.reason);
}

- (void)test_blockForMethodWithNoSignature_raisesValueConversionFailed {
    NSException *ex = [self exceptionRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    [host noMetadata:^(code) {\n"
        @"    }]\n"
        @"    return nil"];
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException);
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
    XCTAssertTrue([ex.reason containsString:@"No block signature"], @"%@", ex.reason);
}

- (void)test_comparatorReturningAString_raisesValueConversionFailed {
    NSException *ex = [self exceptionRunning:
        @"    id host = [ASTestBlockHost new]\n"
        @"    return [host sort:@[@\"b\", @\"a\"] usingComparator:^(a b) {\n"
        @"        return @\"not a number\"\n"
        @"    }]"];
    XCTAssertEqualObjects(ex.name, ASRuntimeErrorException);
    XCTAssertEqualObjects(ex.userInfo[ASErrorMessageCodeKey], @(ASErrorCodeValueConversionFailed));
}

// ---------------------------------------------------------------------------
// Block arguments to C functions (asu-ugk). libdispatch and qsort_b have no
// BridgeSupport, so these use real functions with metadata written here.
// ---------------------------------------------------------------------------

/// Installs the functions in `functionsXML` under a new proxy class and returns its name.
- (NSString *)installFunctions:(NSString *)functionsXML {
    static NSUInteger counter = 0;
    NSString *frameworkName = [NSString stringWithFormat:@"BlockFunctions%lu_%@", (unsigned long)++counter,
                               [[[NSUUID UUID] UUIDString] substringToIndex:8]];
    NSString *xml = [NSString stringWithFormat:@"<?xml version='1.0'?><signatures version='1.0'>%@</signatures>",
                     functionsXML];
    ASBridgeSupportDocument *document = [[[ASBridgeSupportParser alloc] init]
        parseData:[xml dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    NSError *error = nil;
    XCTAssertTrue([[[ASBridgeSupportInstaller alloc] init] installDocument:document
                                                             frameworkName:frameworkName
                                                                     error:&error], @"%@", error);
    return [@"AS" stringByAppendingString:frameworkName];
}

static NSString * const ASTestDispatchXML =
    @"<function name='dispatch_get_global_queue'><arg type64='q'/><arg type64='Q'/><retval type64='@'/></function>"
    @"<function name='dispatch_sync'><arg type64='@'/>"
    @"<arg function_pointer='true' type64='@?'><retval type64='v'/></arg><retval type64='v'/></function>";

- (void)test_cFunctionBlock_dispatchSync_runsScriptBlockBeforeReturning {
    NSString *proxy = [self installFunctions:ASTestDispatchXML];
    id result = [self resultOfRunning:[NSString stringWithFormat:
        @"    id seen = [NSMutableArray array]\n"
        @"    id queue = [%@ dispatch_get_global_queue: 0 : 0]\n"
        @"    [%@ dispatch_sync: queue : ^{\n"
        @"        [seen addObject:@\"ran\"]\n"
        @"    }]\n"
        @"    [seen addObject:@\"after\"]\n"
        @"    return seen", proxy, proxy]];
    XCTAssertEqualObjects(result, (@[@"ran", @"after"]));
}

- (void)test_cFunctionBlock_qsortB_sortsWithScriptComparator {
    // qsort_b's comparator really takes (const void *, const void *); declaring the elements as
    // int * gives the script each element as an ASOutObject holding its value.
    NSString *proxy = [self installFunctions:
        @"<function name='qsort_b'><arg type64='^v'/><arg type64='Q'/><arg type64='Q'/>"
        @"<arg function_pointer='true' type64='@?'><arg type64='^i'/><arg type64='^i'/><retval type64='i'/></arg>"
        @"<retval type64='v'/></function>"];
    int numbers[] = { 5, -2, 9, 0, 3 };
    id<ASTestBlockScript> script = [self scriptWithMethods:[NSString stringWithFormat:
        @"- runWith:base {\n"
        @"    [%@ qsort_b: base : 5 : 4 : ^(a b) {\n"
        @"        return [[a value] compare: [b value]]\n"
        @"    }]\n"
        @"    return nil\n"
        @"}", proxy] conformingToProtocol:YES];

    [script runWith:[NSValue valueWithPointer:numbers]];

    XCTAssertEqual(numbers[0], -2);
    XCTAssertEqual(numbers[1], 0);
    XCTAssertEqual(numbers[2], 3);
    XCTAssertEqual(numbers[3], 5);
    XCTAssertEqual(numbers[4], 9);
}

- (void)test_cFunctionBlock_wrongParameterCount_raises {
    NSString *proxy = [self installFunctions:ASTestDispatchXML];
    NSException *ex = [self exceptionRunning:[NSString stringWithFormat:
        @"    id queue = [%@ dispatch_get_global_queue: 0 : 0]\n"
        @"    [%@ dispatch_sync: queue : ^(unexpected) {\n"
        @"        return nil\n"
        @"    }]\n"
        @"    return nil", proxy, proxy]];
    XCTAssertNotNil(ex);
    XCTAssertTrue([ex.reason containsString:@"dispatch_sync"], @"%@", ex.reason);
    XCTAssertTrue([ex.reason containsString:@"takes 1 parameters"], @"%@", ex.reason);
}

- (void)test_cFunctionBlock_realLibSystemMetadata_installsNotifyRegisterDispatch {
    // The one block-taking function in libSystem.bridgesupport. It's installed, not called,
    // so the test doesn't register a system notification.
    NSString *path = @"/System/Library/BridgeSupport/libSystem.bridgesupport";
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        return; // No system BridgeSupport (GNUstep).
    }
    ASBridgeSupportDocument *document = [[[ASBridgeSupportParser alloc] init] parseData:data error:nil];
    ASBridgeSupportFunction *function = nil;
    for (ASBridgeSupportFunction *candidate in document.functions) {
        if ([candidate.name isEqualToString:@"notify_register_dispatch"]) {
            function = candidate;
        }
    }
    XCTAssertEqual(function.argumentTypeEncodings.count, 4u);
    XCTAssertEqualObjects(function.blockSignatures[@3].parameterTypeEncodings, @[@"i"]);

    NSString *frameworkName = [NSString stringWithFormat:@"libSystemCopy%@", [[[NSUUID UUID] UUIDString] substringToIndex:8]];
    XCTAssertTrue([[[ASBridgeSupportInstaller alloc] init] installDocument:document frameworkName:frameworkName error:nil]);
    Class proxy = NSClassFromString([@"AS" stringByAppendingString:frameworkName]);
    XCTAssertTrue([proxy respondsToSelector:NSSelectorFromString(@"notify_register_dispatch::::")]);
}

// ---------------------------------------------------------------------------
// Scripts calling blocks with value/value: (asu-ugk). A native block is called
// with the type signature from its own descriptor.
// ---------------------------------------------------------------------------

- (void)test_scriptCallsNativeBlock_scalarArgument {
    __block NSInteger received = 0;
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- runWith:handler {\n    [handler value: 41]\n    return nil\n}" conformingToProtocol:YES];

    [script runWith:^(NSInteger code) { received = code; }];

    XCTAssertEqual(received, 41);
}

- (void)test_scriptCallsNativeBlock_structAndOutArguments {
    NSRange range = NSMakeRange(2, 3);
    ASStructValue *rangeValue = [[ASStructValue alloc] initWithBytes:&range length:sizeof(NSRange)
                                                       canonicalName:@"_NSRange"
                                                 runtimeTypeEncoding:@(@encode(NSRange))];
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- runWith:handler and:range {\n"
        @"    id stop = [ASOutObject outObject]\n"
        @"    id matched = [handler value: @\"x\" value: range value: stop]\n"
        @"    return @[matched, [stop value]]\n"
        @"}" conformingToProtocol:YES];

    id result = [script runWith:^BOOL(id object, NSRange r, BOOL *stop) {
        *stop = YES;
        return [object isEqual:@"x"] && r.location == 2 && r.length == 3;
    } and:rangeValue];

    XCTAssertEqualObjects(result, (@[@YES, @YES]), @"BOOL result and the out-parameter both come back");
}

- (void)test_scriptCallsNativeBlock_objectResult {
    NSString *greeting = [@"hel" stringByAppendingString:@"lo"];
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- runWith:handler {\n    return [handler value]\n}" conformingToProtocol:YES];

    XCTAssertEqualObjects([script runWith:^id { return greeting; }], @"hello");
}

- (void)test_scriptCallsOwnBlock {
    id result = [self resultOfRunning:
        @"    id join = ^(a b) {\n"
        @"        return [a stringByAppendingString: b]\n"
        @"    }\n"
        @"    id hello = ^{\n"
        @"        return @\"hi\"\n"
        @"    }\n"
        @"    return @[[join value: @\"a\" value: @\"b\"], [hello value]]"];
    XCTAssertEqualObjects(result, (@[@"ab", @"hi"]));
}

- (void)test_delegateCompletionHandler_calledByScript {
    // An Objective-C caller passes a completion handler to a script's delegate method, as Cocoa
    // does for delegate callbacks; no BridgeSupport describes it.
    __block BOOL succeeded = NO;
    __block BOOL called = NO;
    id<ASTestBlockScript> script = [self scriptWithMethods:
        @"- finishTask:task completionHandler:handler {\n"
        @"    [handler value: YES value: nil]\n"
        @"}" conformingToProtocol:YES];

    [script finishTask:@"task" completionHandler:^(BOOL success, NSError *error) {
        called = YES;
        succeeded = success && error == nil;
    }];

    XCTAssertTrue(called);
    XCTAssertTrue(succeeded);
}

- (void)test_callBlock_wrongArgumentCount_raises {
    id<ASTestBlockScript> nativeCaller = [self scriptWithMethods:
        @"- runWith:handler {\n    return [handler value]\n}" conformingToProtocol:YES];
    NSException *nativeEx = nil;
    @try {
        [nativeCaller runWith:^(NSInteger code) { (void)code; }];
    } @catch (NSException *ex) {
        nativeEx = ex;
    }
    XCTAssertTrue([nativeEx.reason containsString:@"takes 1 parameters, but was called with 0"], @"%@", nativeEx.reason);

    NSException *scriptEx = [self exceptionRunning:
        @"    id one = ^(a) {\n        return a\n    }\n"
        @"    return [one value: 1 value: 2]"];
    XCTAssertTrue([scriptEx.reason containsString:@"takes 1 parameters, but was called with 2"], @"%@", scriptEx.reason);
}

@end
