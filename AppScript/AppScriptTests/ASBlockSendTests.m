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

/// A Foundation stand-in for Cocoa APIs that take blocks (ADR 31). Its block signatures are registered
/// from BridgeSupport XML below, as the system's BridgeSupport files do for the real classes.
@interface ASTestBlockHost : NSObject
- (void)enumerate:(NSArray *)items usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;
- (NSArray *)sort:(NSArray *)items usingComparator:(NSInteger (^)(id a, id b))comparator;
- (void)finishWithCompletion:(void (^)(NSInteger code))handler;
- (void)finishLaterWithCompletion:(void (^)(NSInteger code))handler;
- (double)scale:(double)x using:(double (^)(double x))block;
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

@end
