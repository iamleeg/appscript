// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASInterpreterExceptionHandlingTests.m — Tests for the interpreter's exception handler boundary
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
#import <objc/runtime.h>
#import <stdatomic.h>
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASExceptionHandler.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASReturnNode.h>

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Raises from -flaky for its first `failuresRemaining` calls, then returns @"ok".
@interface ASFlakyTarget : NSObject
@property (nonatomic) NSInteger failuresRemaining;
@property (nonatomic) NSInteger callCount;
- (NSString *)flaky;
@end

@implementation ASFlakyTarget
- (NSString *)flaky {
    self.callCount++;
    if (self.failuresRemaining > 0) {
        self.failuresRemaining--;
        [NSException raise:@"ASFlakyFailure" format:@"flaky failed"];
    }
    return @"ok";
}
@end

/// Runs a script body when sent -runInner, as the runtime's forwarding stub does for an
/// AppScript-defined method: the inner send happens below this native frame.
@interface ASInnerRunner : NSObject
@property (nonatomic) ASInterpreter *interpreter;
@property (nonatomic) NSArray<ASASTNode *> *body;
@property (nonatomic) id innerReceiver;
- (id)runInner;
@end

@implementation ASInnerRunner
- (id)runInner {
    return [self.interpreter evaluateMethodBody:self.body
                                   withReceiver:self.innerReceiver
                                  definingClass:[NSObject class]
                                       selector:@"inner"
                                      arguments:@[]
                                 parameterNames:@[]
                                     scriptPath:@"inner.appscript"];
}
@end

/// Counts deallocations, and fails its owning-family factory methods a set number of times,
/// so retries of alloc-, new-, copy- and init-family sends can be checked for leaks and
/// over-releases. A failing attempt follows the ARC contract: it returns nothing, and an
/// init-family method releases the self it consumed before raising.
static _Atomic NSUInteger gRetryTrackerDeallocs;
static NSInteger gRetryTrackerFailures;

@interface ASRetryTracker : NSObject <NSCopying>
+ (NSUInteger)deallocCount;
+ (void)failNext:(NSInteger)count;
/// alloc family: returns +1.
+ (instancetype)allocFlaky;
/// new family: returns +1.
+ (instancetype)newFlaky;
/// copy family: returns +1.
- (instancetype)copyFlaky;
/// init family: consumes self, returns +1.
- (instancetype)initFlaky;
@end

@implementation ASRetryTracker
+ (NSUInteger)deallocCount { return atomic_load(&gRetryTrackerDeallocs); }
+ (void)failNext:(NSInteger)count { gRetryTrackerFailures = count; }
+ (void)raiseIfFailing {
    if (gRetryTrackerFailures > 0) {
        gRetryTrackerFailures--;
        [NSException raise:@"ASRetryTrackerFailure" format:@"tracker failed"];
    }
}
+ (instancetype)allocFlaky { [self raiseIfFailing]; return [[self alloc] init]; }
+ (instancetype)newFlaky { [self raiseIfFailing]; return [[self alloc] init]; }
- (instancetype)copyFlaky { [[self class] raiseIfFailing]; return [[[self class] alloc] init]; }
- (id)copyWithZone:(NSZone *)zone { return [[[self class] alloc] init]; }
- (instancetype)initFlaky {
    if (gRetryTrackerFailures > 0) {
        self = nil;    // release the self this method consumed, as a failing init should
        [[ASRetryTracker class] raiseIfFailing];
    }
    return self;
}
- (void)dealloc { atomic_fetch_add(&gRetryTrackerDeallocs, 1); }
@end

@interface ASRecordingHandler : NSObject <ASExceptionHandler>
@property (nonatomic) ASExceptionDisposition disposition;
@property (nonatomic) NSMutableArray<NSException *> *exceptions;
@property (nonatomic) NSMutableArray<ASExceptionContext *> *contexts;
@property (nonatomic, copy, nullable) void (^onHandle)(NSException *exception);
@end

@implementation ASRecordingHandler
- (instancetype)init {
    self = [super init];
    if (self) {
        _exceptions = [NSMutableArray array];
        _contexts = [NSMutableArray array];
    }
    return self;
}
- (ASExceptionDisposition)handleException:(NSException *)exception context:(ASExceptionContext *)context {
    [self.exceptions addObject:exception];
    [self.contexts addObject:context];
    if (self.onHandle) self.onHandle(exception);
    return self.disposition;
}
@end

static ASASTNode *ASSendTo(NSString *identifier, NSString *selector) {
    return [[ASMessageSendNode alloc] initWithReceiver:[[ASIdentifierNode alloc] initWithName:identifier line:3 column:5]
                                         selectorParts:@[selector]
                                             arguments:@[]
                                                  line:3
                                                column:5];
}

static ASASTNode *ASSend(ASASTNode *receiver, NSString *selector) {
    return [[ASMessageSendNode alloc] initWithReceiver:receiver
                                         selectorParts:@[selector]
                                             arguments:@[]
                                                  line:3
                                                column:5];
}

static ASASTNode *ASReturn(ASASTNode *value) {
    return [[ASReturnNode alloc] initWithValue:value line:3 column:1];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@interface ASInterpreterExceptionHandlingTests : XCTestCase
@property (nonatomic) ASInterpreter *interpreter;
@property (nonatomic) ASRecordingHandler *handler;
@end

@implementation ASInterpreterExceptionHandlingTests

- (void)setUp {
    [super setUp];
    self.interpreter = [[ASInterpreter alloc] init];
    self.handler = [[ASRecordingHandler alloc] init];
    [ASInterpreter setExceptionHandler:self.handler];
}

- (void)tearDown {
    [ASInterpreter setExceptionHandler:nil];
    [super tearDown];
}

- (id)run:(NSArray<ASASTNode *> *)body receiver:(id)receiver exception:(NSException **)caught {
    @try {
        return [self.interpreter evaluateMethodBody:body
                                       withReceiver:receiver
                                      definingClass:[NSObject class]
                                           selector:@"test"
                                          arguments:@[]
                                     parameterNames:@[]
                                         scriptPath:@"test.appscript"];
    } @catch (NSException *ex) {
        if (caught) *caught = ex;
        return nil;
    }
}

- (void)test_noHandlerInstalled_failurePropagatesUnchanged {
    [ASInterpreter setExceptionHandler:nil];
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 1;
    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"self", @"flaky"))] receiver:target exception:&caught];
    XCTAssertEqualObjects(caught.name, @"ASFlakyFailure");
    XCTAssertEqual(target.callCount, 1);
}

- (void)test_reraise_propagatesAndHandlerSeesContext {
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 1;
    self.handler.disposition = ASExceptionDispositionReraise;
    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"self", @"flaky"))] receiver:target exception:&caught];

    XCTAssertEqualObjects(caught.name, @"ASFlakyFailure");
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1);
    XCTAssertEqual(self.handler.exceptions.firstObject, caught);
    ASExceptionContext *ctx = self.handler.contexts.firstObject;
    XCTAssertEqual(ctx.receiver, target);
    XCTAssertEqual(ctx.selector, @selector(flaky));
    XCTAssertEqualObjects(ctx.scriptPath, @"test.appscript");
    XCTAssertEqual(ctx.line, (NSUInteger)3);
    XCTAssertTrue(ctx.crossedScriptBoundary, @"A native exception originates outside AppScript");
}

- (void)test_retry_succeedsOnSecondDispatch {
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 1;
    self.handler.disposition = ASExceptionDispositionRetry;
    NSException *caught = nil;
    id result = [self run:@[ASReturn(ASSendTo(@"self", @"flaky"))] receiver:target exception:&caught];

    XCTAssertNil(caught);
    XCTAssertEqualObjects(result, @"ok");
    XCTAssertEqual(target.callCount, 2);
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1);
}

- (void)test_retry_secondFailureIsReraisedWithoutAskingAgain {
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 5;
    self.handler.disposition = ASExceptionDispositionRetry;
    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"self", @"flaky"))] receiver:target exception:&caught];

    XCTAssertEqualObjects(caught.name, @"ASFlakyFailure");
    XCTAssertEqual(target.callCount, 2, @"One retry per send");
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1);
}

- (void)test_nestedFailure_handlerInvokedOncePerException {
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 1;
    ASInnerRunner *runner = [[ASInnerRunner alloc] init];
    runner.interpreter = self.interpreter;
    runner.body = @[ASReturn(ASSendTo(@"self", @"flaky"))];
    runner.innerReceiver = target;
    self.handler.disposition = ASExceptionDispositionReraise;

    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"self", @"runInner"))] receiver:runner exception:&caught];

    XCTAssertEqualObjects(caught.name, @"ASFlakyFailure");
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1,
                   @"The enclosing send must not ask the handler about the same exception again");
    XCTAssertEqualObjects([self.handler.contexts.firstObject scriptPath], @"inner.appscript");
}

- (void)test_unrecognisedSelector_reachesHandlerAsRuntimeError {
    self.handler.disposition = ASExceptionDispositionReraise;
    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"NSObject", @"noSuchMethodAnywhere"))] receiver:[NSObject new] exception:&caught];

    XCTAssertEqualObjects(caught.name, ASRuntimeErrorException);
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1);
    XCTAssertEqualObjects(self.handler.exceptions.firstObject.userInfo[ASErrorMessageCodeKey],
                          @(ASErrorCodeUnrecognisedSelector));
    ASExceptionContext *ctx = self.handler.contexts.firstObject;
    XCTAssertFalse(ctx.crossedScriptBoundary);
    XCTAssertEqual(ctx.selector, NSSelectorFromString(@"noSuchMethodAnywhere"));
}

- (void)test_retry_afterHandlerAddsMissingMethod_succeeds {
    Class target = [ASFlakyTarget class];
    SEL missing = NSSelectorFromString(@"asPatchedLater");
    XCTAssertFalse([target instancesRespondToSelector:missing]);
    self.handler.disposition = ASExceptionDispositionRetry;
    self.handler.onHandle = ^(NSException *exception) {
        class_addMethod(target, missing, imp_implementationWithBlock(^id(id _self) { return @"patched"; }), "@@:");
    };
    NSException *caught = nil;
    id result = [self run:@[ASReturn(ASSendTo(@"self", @"asPatchedLater"))]
                 receiver:[[ASFlakyTarget alloc] init] exception:&caught];
    XCTAssertNil(caught);
    XCTAssertEqualObjects(result, @"patched");
}

- (void)test_failureInsideHandler_doesNotReenterHandler {
    ASFlakyTarget *target = [[ASFlakyTarget alloc] init];
    target.failuresRemaining = 1;
    self.handler.disposition = ASExceptionDispositionReraise;
    ASFlakyTarget *other = [[ASFlakyTarget alloc] init];
    other.failuresRemaining = 1;
    ASInterpreter *interpreter = self.interpreter;
    __block NSException *innerCaught = nil;
    self.handler.onHandle = ^(NSException *exception) {
        @try {
            [interpreter evaluateMethodBody:@[ASReturn(ASSendTo(@"self", @"flaky"))]
                               withReceiver:other
                              definingClass:[NSObject class]
                                   selector:@"fromHandler"
                                  arguments:@[]
                             parameterNames:@[]
                                 scriptPath:@"handler.appscript"];
        } @catch (NSException *ex) {
            innerCaught = ex;
        }
    };
    NSException *caught = nil;
    [self run:@[ASReturn(ASSendTo(@"self", @"flaky"))] receiver:target exception:&caught];

    XCTAssertEqualObjects(caught.name, @"ASFlakyFailure");
    XCTAssertEqualObjects(innerCaught.name, @"ASFlakyFailure", @"The handler's own failure is re-raised");
    XCTAssertEqual(self.handler.exceptions.count, (NSUInteger)1);
}

// ---------------------------------------------------------------------------
// Ownership across a retry (alloc, new, copy and init families)
//
// A send in an owning family that fails part-way may or may not already have created or
// retained its result, and the runtime can't tell which. So a retried send of that kind
// is allowed to leak. What it must never do is over-release: the result of the retry has
// to be valid and usable, and a send that succeeds first time is freed exactly once.
// ---------------------------------------------------------------------------

/// Runs `body` with `failures` initial failures and a retrying handler, inside an autorelease
/// pool, and returns how many trackers were deallocated by the time the pool drained.
- (NSUInteger)deallocsRunning:(NSArray<ASASTNode *> *)body failures:(NSInteger)failures
                       result:(id *)result {
    self.handler.disposition = ASExceptionDispositionRetry;
    NSUInteger before = [ASRetryTracker deallocCount];
    [ASRetryTracker failNext:failures];
    @autoreleasepool {
        NSException *caught = nil;
        id value = [self run:body receiver:[[NSObject alloc] init] exception:&caught];
        XCTAssertNil(caught);
        if (result) *result = value;
    }
    [ASRetryTracker failNext:0];
    return [ASRetryTracker deallocCount] - before;
}

- (ASASTNode *)trackerClass {
    return [[ASIdentifierNode alloc] initWithName:@"ASRetryTracker" line:3 column:5];
}

- (void)test_noFailure_owningFamilySends_areFreedOnce {
    NSArray *newBody = @[ASReturn(ASSend([self trackerClass], @"newFlaky"))];
    XCTAssertEqual([self deallocsRunning:newBody failures:0 result:NULL], 1u);
    NSArray *allocBody = @[ASReturn(ASSend([self trackerClass], @"allocFlaky"))];
    XCTAssertEqual([self deallocsRunning:allocBody failures:0 result:NULL], 1u);
    NSArray *initBody = @[ASReturn(ASSend(ASSend([self trackerClass], @"alloc"), @"initFlaky"))];
    XCTAssertEqual([self deallocsRunning:initBody failures:0 result:NULL], 1u);
}

- (void)test_retry_newFamily_resultIsValidAndNotOverReleased {
    id result = nil;
    NSArray *body = @[ASReturn(ASSend([self trackerClass], @"newFlaky"))];
    [self deallocsRunning:body failures:1 result:&result];
    XCTAssertTrue([result isKindOfClass:[ASRetryTracker class]]);
    XCTAssertNotNil([result description], @"the retried result must still be alive");
}

- (void)test_retry_allocFamily_resultIsValidAndNotOverReleased {
    id result = nil;
    NSArray *body = @[ASReturn(ASSend([self trackerClass], @"allocFlaky"))];
    [self deallocsRunning:body failures:1 result:&result];
    XCTAssertTrue([result isKindOfClass:[ASRetryTracker class]]);
    XCTAssertNotNil([result description]);
}

- (void)test_retry_copyFamily_resultIsValidAndOriginalNotOverReleased {
    ASRetryTracker *original = [ASRetryTracker new];
    self.handler.disposition = ASExceptionDispositionRetry;
    [ASRetryTracker failNext:1];
    NSException *caught = nil;
    id copy = [self run:@[ASReturn(ASSendTo(@"self", @"copyFlaky"))] receiver:original exception:&caught];
    [ASRetryTracker failNext:0];
    XCTAssertNil(caught);
    XCTAssertTrue([copy isKindOfClass:[ASRetryTracker class]]);
    XCTAssertNotEqual(copy, original);
    XCTAssertNotNil([copy description]);
    XCTAssertNotNil([original description], @"the receiver must not have been released by the retry");
}

- (void)test_retry_initFamily_resultIsValidAndNotOverReleased {
    id result = nil;
    NSArray *body = @[ASReturn(ASSend(ASSend([self trackerClass], @"alloc"), @"initFlaky"))];
    [self deallocsRunning:body failures:1 result:&result];
    XCTAssertTrue([result isKindOfClass:[ASRetryTracker class]]);
    XCTAssertNotNil([result description], @"the retried init must not have released the object it returned");
}

@end
