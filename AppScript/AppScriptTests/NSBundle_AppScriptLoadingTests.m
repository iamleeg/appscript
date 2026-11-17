// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle_AppScriptLoadingTests.m — Unit tests for NSBundle+AppScriptLoading
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
#import <AppScript/NSBundle+AppScriptLoading.h>

// ---------------------------------------------------------------------------
// Helper: a fake NSBundle subclass backed by a temporary directory.
//
// FakeBundle overrides the two NSBundle methods used by -loadScriptsWithError:
// so we can control exactly which .appscript files it "contains" and give it a
// stable, unique identifier — without touching any real bundle on disk.
// ---------------------------------------------------------------------------

@interface FakeBundle : NSBundle
@property (nonatomic, copy) NSString *fakeIdentifier;
@property (nonatomic, copy) NSArray<NSURL *> *fakeScriptURLs;
@end

@implementation FakeBundle

- (nullable NSString *)bundleIdentifier {
    return self.fakeIdentifier;
}

- (nullable NSArray<NSURL *> *)URLsForResourcesWithExtension:(NSString *)ext
                                                 subdirectory:(nullable NSString *)subpath {
    if ([ext isEqualToString:@"as"]) {
        return self.fakeScriptURLs ?: @[];
    }
    return @[];
}

@end

// ---------------------------------------------------------------------------
// Test class
// ---------------------------------------------------------------------------

/// Tests for the NSBundle+AppScriptLoading category.
@interface NSBundle_AppScriptLoadingTests : XCTestCase
@end

@implementation NSBundle_AppScriptLoadingTests

// ---------------------------------------------------------------------------
// 1. A bundle with no .appscript files returns YES immediately.
// ---------------------------------------------------------------------------

- (void)test_loadScriptsWithError_bundleWithNoScripts_returnsYES {
    // Use a FakeBundle that reports zero .appscript files so we avoid touching any
    // real bundle that may already have been registered by another test run.
    FakeBundle *bundle = [[FakeBundle alloc] init];
    bundle.fakeIdentifier = [NSString stringWithFormat:@"com.appscript.test.noScripts.%@",
                             [NSUUID UUID].UUIDString];
    bundle.fakeScriptURLs = @[];

    NSError *error = nil;
    BOOL result = [bundle loadScriptsWithError:&error];

    XCTAssertTrue(result, @"A bundle with no .appscript files should return YES");
    XCTAssertNil(error, @"No error should be set when there are no scripts to load");
}

// ---------------------------------------------------------------------------
// 2. Calling -loadScriptsWithError: twice on the same bundle returns NO on
//    the second call with ASBundleLoadingErrorDuplicateLoad.
//
//    We use a fresh FakeBundle with a unique identifier for each test
//    invocation so that test ordering does not affect the outcome.
// ---------------------------------------------------------------------------

- (void)test_loadScriptsWithError_calledTwice_returnsNOOnSecondCall {
    FakeBundle *bundle = [[FakeBundle alloc] init];
    bundle.fakeIdentifier = [NSString stringWithFormat:@"com.appscript.test.duplicate.%@",
                             [NSUUID UUID].UUIDString];
    bundle.fakeScriptURLs = @[];   // no scripts → first call succeeds immediately

    // First call: may succeed or may already be duplicate if somehow the same
    // UUID was used before (astronomically unlikely; treat both outcomes as valid).
    NSError *firstError = nil;
    BOOL firstResult = [bundle loadScriptsWithError:&firstError];
    (void)firstResult; // outcome not critical — see comment above

    // Second call: must always return NO with ASBundleLoadingErrorDuplicateLoad.
    NSError *secondError = nil;
    BOOL secondResult = [bundle loadScriptsWithError:&secondError];

    XCTAssertFalse(secondResult,
                   @"The second call to loadScriptsWithError: should return NO");
    XCTAssertNotNil(secondError,
                    @"The second call should set an error");
    XCTAssertEqualObjects(secondError.domain, ASBundleLoadingErrorDomain,
                          @"Error domain should be ASBundleLoadingErrorDomain");
    XCTAssertEqual(secondError.code, ASBundleLoadingErrorDuplicateLoad,
                   @"Error code should be ASBundleLoadingErrorDuplicateLoad");
}

// ---------------------------------------------------------------------------
// 3. Calling -loadScriptsWithError: on [NSBundle mainBundle] does not crash.
//
//    In the XCTest environment the main bundle almost certainly contains no
//    .appscript files, so the method will return YES (or NO with a duplicate-load
//    error if this test runs more than once in a session). Either way there
//    must be no exception.
// ---------------------------------------------------------------------------

- (void)test_loadScriptsWithError_mainBundle_doesNotCrash {
    NSError *error = nil;
    // Discard the return value; we only care that no exception is raised.
    XCTAssertNoThrow((void)[[NSBundle mainBundle] loadScriptsWithError:&error],
                     @"Calling loadScriptsWithError: on [NSBundle mainBundle] must not throw");
}

@end
