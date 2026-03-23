// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASUncaughtExceptionHandlerTests.m — Tests for ASUncaughtExceptionHandler
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
#import <AppScript/ASUncaughtExceptionHandler.h>

// ---------------------------------------------------------------------------
// Dummy handlers used by tests that need pre-existing handlers installed.
// ASDummyCalled is set to YES by ASDummyCalledHandler so tests can verify
// the previous handler is invoked for non-AppScript exceptions.
// ---------------------------------------------------------------------------

static void ASDummyUncaughtHandler(NSException *e) { (void)e; }

static BOOL ASDummyCalled = NO;
static void ASDummyCalledHandler(NSException *e) { (void)e; ASDummyCalled = YES; }

// ---------------------------------------------------------------------------

@interface ASUncaughtExceptionHandlerTests : XCTestCase {
    NSUncaughtExceptionHandler *_savedHandler;
}
@end

@implementation ASUncaughtExceptionHandlerTests

- (void)setUp {
    [super setUp];
    // Save the current handler so tearDown can restore it, preventing test pollution.
    _savedHandler = NSGetUncaughtExceptionHandler();
    ASDummyCalled = NO;
}

- (void)tearDown {
    // Restore the handler that was in place before this test ran.
    NSSetUncaughtExceptionHandler(_savedHandler);
    [super tearDown];
}

// ---------------------------------------------------------------------------
// 1. Installing registers a non-NULL handler
// ---------------------------------------------------------------------------

- (void)test_installHandler_registersNonNullHandler {
    ASInstallUncaughtExceptionHandler();

    XCTAssertTrue(NSGetUncaughtExceptionHandler() != NULL,
                  @"ASInstallUncaughtExceptionHandler should register a non-NULL handler");
}

// ---------------------------------------------------------------------------
// 2. Installing replaces a pre-existing handler
// ---------------------------------------------------------------------------

- (void)test_installHandler_replacesExistingHandler {
    NSSetUncaughtExceptionHandler(&ASDummyUncaughtHandler);

    ASInstallUncaughtExceptionHandler();

    XCTAssertNotEqual(NSGetUncaughtExceptionHandler(), &ASDummyUncaughtHandler,
                      @"After ASInstallUncaughtExceptionHandler the dummy handler must not be current");
    XCTAssertTrue(NSGetUncaughtExceptionHandler() != NULL,
                  @"A handler must be installed after ASInstallUncaughtExceptionHandler");
}

// ---------------------------------------------------------------------------
// 3. Calling twice does not record the handler as its own previous handler
//    (infinite-loop guard)
// ---------------------------------------------------------------------------

- (void)test_installHandler_calledTwice_keepsSameHandler {
    ASInstallUncaughtExceptionHandler();
    NSUncaughtExceptionHandler *afterFirst = NSGetUncaughtExceptionHandler();

    ASInstallUncaughtExceptionHandler();
    NSUncaughtExceptionHandler *afterSecond = NSGetUncaughtExceptionHandler();

    XCTAssertEqual(afterFirst, afterSecond,
                   @"Calling ASInstallUncaughtExceptionHandler twice should install the same "
                   @"handler function both times, not create a chain with itself");
}

// ---------------------------------------------------------------------------
// 4. Previous handler is invoked for non-AppScript exceptions
// ---------------------------------------------------------------------------

- (void)test_installHandler_nonAppScriptException_invokesPreviousHandler {
    // Arrange: pre-install a handler that records it was called.
    NSSetUncaughtExceptionHandler(&ASDummyCalledHandler);
    ASInstallUncaughtExceptionHandler();

    // Act: invoke the installed handler with a non-AppScript exception directly.
    // (We call it via NSGetUncaughtExceptionHandler() to avoid coupling to the
    // internal function name.)
    NSException *nonAppScriptEx = [NSException exceptionWithName:@"NSGenericException"
                                                          reason:@"test"
                                                        userInfo:nil];
    NSGetUncaughtExceptionHandler()(nonAppScriptEx);

    // Assert: the previously-installed handler must have been forwarded to.
    XCTAssertTrue(ASDummyCalled,
                  @"The previous handler should be called for non-AppScript exceptions");
}

@end
