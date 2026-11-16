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

@end
