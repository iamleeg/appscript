// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASOwnershipTests.m — Tests that objects returned by native sends are neither leaked nor over-released
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
#import <stdatomic.h>
#import <objc/message.h>
#import <AppScript/ASLoader.h>

// ---------------------------------------------------------------------------
// A Foundation stand-in that counts how many instances have been deallocated.
// ---------------------------------------------------------------------------

static _Atomic NSUInteger gTrackerDeallocCount;

@interface ASTestDeallocTracker : NSObject <NSCopying, NSMutableCopying>
+ (NSUInteger)deallocCount;
/// Not in an owning family: returns an autoreleased tracker.
+ (instancetype)tracker;
/// An init-family method that discards `self` and returns a different object.
- (instancetype)initReplacing;
@end

@implementation ASTestDeallocTracker
+ (NSUInteger)deallocCount {
    return atomic_load(&gTrackerDeallocCount);
}
+ (instancetype)tracker {
    return [[self alloc] init];
}
- (instancetype)initReplacing {
    return [[ASTestDeallocTracker alloc] init];
}
- (id)copyWithZone:(NSZone *)zone {
    return [[ASTestDeallocTracker alloc] init];
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    return [[ASTestDeallocTracker alloc] init];
}
- (void)dealloc {
    atomic_fetch_add(&gTrackerDeallocCount, 1);
}
@end

/// The script methods the tests call from Objective-C.
@protocol ASTestOwnershipScript <NSObject>
- (id)run;
- (id)make;
@end

/// Script methods in the init, copy and new families, declared so ARC callers apply the family
/// conventions to them: init consumes self and returns +1, copy and new return +1 (asu-1y1).
@protocol ASTestFamilyScript <NSObject>
- (instancetype)initKeepingSelf;
- (instancetype)initReplacingSelf;
- (id)copyFresh;
+ (id)newFresh;
/// Not in a family: returns a fresh object at +0.
- (id)makeFresh;
@end

/// What the compiler generates for a call to an init-family method, as a plain function pointer:
/// the receiver is consumed and the result is owned.
typedef id (*ASTestConsumingInitFunction)(id __attribute__((ns_consumed)), SEL)
    __attribute__((ns_returns_retained));

static NSString *uniqueClassName(NSString *prefix) {
    return [NSString stringWithFormat:@"%@_%@", prefix,
            [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
}

@interface ASOwnershipTests : XCTestCase
@end

@implementation ASOwnershipTests

/// Loads `source` and returns the class it defines named `className`.
- (Class)loadSource:(NSString *)source className:(NSString *)className {
    ASLoader *loader = [[ASLoader alloc] init];
    NSError *error = nil;
    XCTAssertTrue([loader loadScriptFromString:source error:&error], @"%@", error);
    return NSClassFromString(className);
}

/// Runs `- run { <body> return nil }` on a fresh script object inside an autorelease pool and
/// returns how many trackers were deallocated by the time the pool drained.
- (NSUInteger)deallocsRunning:(NSString *)body {
    NSString *className = uniqueClassName(@"ASTestOwnershipRunner");
    NSString *source = [NSString stringWithFormat:
                        @"@class %@ : NSObject\n- run {\n%@\n    return nil\n}\n@end\n", className, body];
    Class cls = [self loadSource:source className:className];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestOwnershipScript> runner = [[cls alloc] init];
        (void)[runner run];
    }
    return [ASTestDeallocTracker deallocCount] - before;
}

- (void)test_allocInit_droppedInScript_isDeallocatedOnce {
    XCTAssertEqual([self deallocsRunning:@"    id t = [[ASTestDeallocTracker alloc] init]"], 1u,
                   @"a tracker made by [[X alloc] init] in a script should be freed when the script is done");
}

- (void)test_new_droppedInScript_isDeallocatedOnce {
    XCTAssertEqual([self deallocsRunning:@"    id t = [ASTestDeallocTracker new]"], 1u);
}

- (void)test_copy_droppedInScript_deallocatesOriginalAndCopy {
    XCTAssertEqual([self deallocsRunning:@"    id t = [ASTestDeallocTracker tracker]\n    id c = [t copy]"], 2u);
}

- (void)test_mutableCopy_droppedInScript_deallocatesOriginalAndCopy {
    XCTAssertEqual([self deallocsRunning:@"    id t = [ASTestDeallocTracker tracker]\n    id c = [t mutableCopy]"], 2u);
}

- (void)test_initReturningAnotherObject_deallocatesBothOnce {
    XCTAssertEqual([self deallocsRunning:@"    id t = [[ASTestDeallocTracker alloc] initReplacing]"], 2u,
                   @"the discarded object and its replacement should each be freed once");
}

// Controls: these must keep passing, so a fix can't over-release.

- (void)test_conveniencePlusTracker_droppedInScript_isDeallocatedOnce {
    XCTAssertEqual([self deallocsRunning:@"    id t = [ASTestDeallocTracker tracker]"], 1u,
                   @"an autoreleased result is not balanced by the runtime");
}

- (void)test_scriptSubclassInitCallingSuperInit_isDeallocatedOnce {
    NSString *sub = uniqueClassName(@"ASTestOwnershipSub");
    NSString *runner = uniqueClassName(@"ASTestOwnershipSubRunner");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : ASTestDeallocTracker\n- init {\n    self = [super init]\n    return self\n}\n@end\n"
        @"@class %@ : NSObject\n- run {\n    id t = [[%@ alloc] init]\n    return nil\n}\n@end\n",
        sub, runner, sub];
    Class cls = [self loadSource:source className:runner];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestOwnershipScript> object = [[cls alloc] init];
        (void)[object run];
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u,
                   @"the pattern every ResearchBuddy script uses: alloc, a script init, [super init]");
}

- (void)test_newOnScriptClassWithScriptInit_isDeallocatedOnce {
    NSString *sub = uniqueClassName(@"ASTestOwnershipNewSub");
    NSString *runner = uniqueClassName(@"ASTestOwnershipNewRunner");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : ASTestDeallocTracker\n- init {\n    self = [super init]\n    return self\n}\n@end\n"
        @"@class %@ : NSObject\n- run {\n    id t = [%@ new]\n    return nil\n}\n@end\n",
        sub, runner, sub];
    Class cls = [self loadSource:source className:runner];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestOwnershipScript> object = [[cls alloc] init];
        (void)[object run];
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u,
                   @"+new runs the script's init through native code; the result must still be freed once");
}

- (void)test_scriptMethodInOwningFamily_returnsFreshObjectWithoutOverRelease {
    // -copyOfSomething is in the copy family by name, but a script method's forwarded result is
    // autoreleased (ADR 3), so the runtime must not balance it as if it were +1.
    NSString *className = uniqueClassName(@"ASTestOwnershipFamily");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : NSObject\n"
        @"- copyOfSomething {\n    return [[ASTestDeallocTracker alloc] init]\n}\n"
        @"- run {\n    id t = [self copyOfSomething]\n    return nil\n}\n@end\n", className];
    Class cls = [self loadSource:source className:className];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestOwnershipScript> object = [[cls alloc] init];
        (void)[object run];
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
}

- (void)test_trackerReturnedToObjectiveC_isAliveForCallerThenDeallocatedOnce {
    NSString *className = uniqueClassName(@"ASTestOwnershipMaker");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : NSObject\n- make {\n    return [[ASTestDeallocTracker alloc] init]\n}\n@end\n", className];
    Class cls = [self loadSource:source className:className];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestOwnershipScript> maker = [[cls alloc] init];
        id tracker = [maker make];
        XCTAssertNotNil(tracker);
        XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 0u,
                       @"the caller still holds the tracker, so it must not be freed yet");
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u,
                   @"once the caller lets go, the tracker should be freed exactly once");
}

// ---------------------------------------------------------------------------
// Script-defined family methods called with ARC message syntax (asu-1y1)
// ---------------------------------------------------------------------------

/// A script class that is itself a tracker, so the receiver of an init is counted too.
- (Class)loadFamilyClass {
    NSString *name = uniqueClassName(@"ASTestFamilyScriptClass");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : ASTestDeallocTracker\n"
        @"- initKeepingSelf {\n    self = [super init]\n    return self\n}\n"
        @"- initReplacingSelf {\n    return [[ASTestDeallocTracker alloc] init]\n}\n"
        @"- copyFresh {\n    return [[ASTestDeallocTracker alloc] init]\n}\n"
        @"+ newFresh {\n    return [[ASTestDeallocTracker alloc] init]\n}\n"
        @"- makeFresh {\n    return [[ASTestDeallocTracker alloc] init]\n}\n"
        @"@end\n", name];
    return [self loadSource:source className:name];
}

- (void)test_arcInit_scriptReturnsSelf_isDeallocatedOnce {
    Class cls = [self loadFamilyClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> object = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        XCTAssertNotNil(object);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
}

- (void)test_arcInit_scriptReturnsAnotherObject_deallocatesReceiverAndReplacementOnce {
    Class cls = [self loadFamilyClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> object = [(id<ASTestFamilyScript>)[cls alloc] initReplacingSelf];
        XCTAssertNotNil(object);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u,
                   @"the discarded receiver and its replacement should each be freed once");
}

- (void)test_arcCopyFamily_scriptReturnsFreshObject_isDeallocatedOnce {
    Class cls = [self loadFamilyClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> original = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        id copy = [original copyFresh];
        XCTAssertNotNil(copy);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u, @"the original and the copy");
}

- (void)test_arcNewFamily_scriptClassMethod_isDeallocatedOnce {
    Class cls = [self loadFamilyClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id made = [(Class<ASTestFamilyScript>)cls newFresh];
        XCTAssertNotNil(made);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
}

- (void)test_arcNonFamilyMethod_scriptResultStaysAtPlusZero {
    Class cls = [self loadFamilyClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> original = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        id fresh = [original makeFresh];
        XCTAssertNotNil(fresh);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u, @"the original and the fresh object");
}

- (void)test_consumingTypedPointer_scriptInit_isBalancedInBothCases {
    Class cls = [self loadFamilyClass];
    ASTestConsumingInitFunction send = (ASTestConsumingInitFunction)objc_msgSend;
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id keeping = send([cls alloc], @selector(initKeepingSelf));
        XCTAssertNotNil(keeping);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
    before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id replacing = send([cls alloc], @selector(initReplacingSelf));
        XCTAssertNotNil(replacing);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u);
}

- (void)test_scriptToScriptFamilySends_areBalanced {
    Class family = [self loadFamilyClass];
    NSString *runner = uniqueClassName(@"ASTestFamilyRunner");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : NSObject\n"
        @"- run: familyClass {\n"
        @"    id a = [[familyClass alloc] initKeepingSelf]\n"
        @"    id b = [[familyClass alloc] initReplacingSelf]\n"
        @"    id c = [a copyFresh]\n"
        @"    id d = [familyClass newFresh]\n"
        @"    id e = [a makeFresh]\n"
        @"    return nil\n}\n@end\n", runner];
    Class cls = [self loadSource:source className:runner];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id object = [[cls alloc] init];
        ((id (*)(id, SEL, id))objc_msgSend)(object, NSSelectorFromString(@"run:"), family);
    }
    // a, b's receiver, b's replacement, c, d and e.
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 6u);
}

// ---------------------------------------------------------------------------
// [super ...] sends to script-defined family methods (asu-awy)
// A super send to a script method is evaluated straight from the AST, with no forwarding stub,
// so the interpreter neither balances its result nor consumes self. The enclosing override
// returns through its own stub, which does follow the convention.
// ---------------------------------------------------------------------------

/// A script subclass of the family class whose overrides all send to super.
- (Class)loadSuperForwardingClass {
    Class base = [self loadFamilyClass];
    NSString *name = uniqueClassName(@"ASTestSuperForwarder");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : %@\n"
        @"- initKeepingSelf {\n    self = [super initKeepingSelf]\n    return self\n}\n"
        @"- initReplacingSelf {\n    self = [super initReplacingSelf]\n    return self\n}\n"
        @"- copyFresh {\n    return [super copyFresh]\n}\n"
        @"+ newFresh {\n    return [super newFresh]\n}\n"
        @"- makeFresh {\n    return [super makeFresh]\n}\n"
        @"@end\n", name, NSStringFromClass(base)];
    return [self loadSource:source className:name];
}

- (void)test_superInit_toScriptInit_returningSelf_isDeallocatedOnce {
    Class cls = [self loadSuperForwardingClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> object = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        XCTAssertNotNil(object);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
}

- (void)test_superInit_toScriptInit_returningAnotherObject_deallocatesBothOnce {
    Class cls = [self loadSuperForwardingClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> object = [(id<ASTestFamilyScript>)[cls alloc] initReplacingSelf];
        XCTAssertNotNil(object);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u,
                   @"the discarded receiver and its replacement should each be freed once");
}

- (void)test_superCopy_toScriptCopy_isDeallocatedOnce {
    Class cls = [self loadSuperForwardingClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> original = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        id copy = [original copyFresh];
        XCTAssertNotNil(copy);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u, @"the original and the copy");
}

- (void)test_superNew_toScriptClassMethod_isDeallocatedOnce {
    Class cls = [self loadSuperForwardingClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id made = [(Class<ASTestFamilyScript>)cls newFresh];
        XCTAssertNotNil(made);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 1u);
}

- (void)test_superNonFamily_toScriptMethod_staysAtPlusZero {
    Class cls = [self loadSuperForwardingClass];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id<ASTestFamilyScript> original = [(id<ASTestFamilyScript>)[cls alloc] initKeepingSelf];
        id fresh = [original makeFresh];
        XCTAssertNotNil(fresh);
    }
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 2u, @"the original and the fresh object");
}

- (void)test_superSends_calledFromScript_areBalanced {
    Class forwarder = [self loadSuperForwardingClass];
    NSString *runner = uniqueClassName(@"ASTestSuperRunner");
    NSString *source = [NSString stringWithFormat:
        @"@class %@ : NSObject\n"
        @"- run: aClass {\n"
        @"    id a = [[aClass alloc] initKeepingSelf]\n"
        @"    id b = [[aClass alloc] initReplacingSelf]\n"
        @"    id c = [a copyFresh]\n"
        @"    id d = [aClass newFresh]\n"
        @"    id e = [a makeFresh]\n"
        @"    return nil\n}\n@end\n", runner];
    Class cls = [self loadSource:source className:runner];
    NSUInteger before = [ASTestDeallocTracker deallocCount];
    @autoreleasepool {
        id object = [[cls alloc] init];
        ((id (*)(id, SEL, id))objc_msgSend)(object, NSSelectorFromString(@"run:"), forwarder);
    }
    // a, b's receiver, b's replacement, c, d and e.
    XCTAssertEqual([ASTestDeallocTracker deallocCount] - before, 6u);
}


@end
