// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASUncaughtExceptionHandler.m — Callable uncaught-exception handler for AppScript
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

#import <AppScript/ASUncaughtExceptionHandler.h>
#import <AppScript/ASInterpreter.h>
#import <stdio.h>

/// The previously-installed uncaught-exception handler, saved at install time
/// so that non-AppScript exceptions are forwarded rather than swallowed.
static NSUncaughtExceptionHandler *sPreviousHandler = NULL;

/// The AppScript uncaught-exception handler implementation.
///
/// For ``ASRuntimeErrorException`` exceptions the handler writes an augmented
/// crash report to `stderr` (the exception's `reason` already contains the
/// hybrid ObjC+AppScript call stack) then calls `abort()`.
///
/// For all other exception types the previously-saved handler is invoked,
/// preserving existing Cocoa crash-reporting behaviour.
static void ASUncaughtExceptionHandlerImpl(NSException *exception) {
    if ([[exception name] isEqualToString:ASRuntimeErrorException]) {
        const char *reason = [[exception reason] UTF8String] ?: "(no reason)";
        fprintf(stderr, "Terminating due to uncaught AppScript exception:\n%s\n", reason);
        abort();
    } else {
        if (sPreviousHandler) {
            sPreviousHandler(exception);
        }
    }
}

void ASInstallUncaughtExceptionHandler(void) {
    // Guard against recording our own handler as "previous" if called more than
    // once — that would create an infinite forwarding loop for non-AppScript
    // exceptions on the second (and subsequent) invocations.
    NSUncaughtExceptionHandler *current = NSGetUncaughtExceptionHandler();
    if (current != &ASUncaughtExceptionHandlerImpl) {
        sPreviousHandler = current;
    }
    NSSetUncaughtExceptionHandler(&ASUncaughtExceptionHandlerImpl);
}
