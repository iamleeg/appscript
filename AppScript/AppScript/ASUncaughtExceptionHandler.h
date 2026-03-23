// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASUncaughtExceptionHandler.h — Callable uncaught-exception handler for AppScript
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs the AppScript uncaught-exception handler.
///
/// When an ``ASRuntimeErrorException`` propagates out of all exception handlers,
/// the installed handler prints an augmented crash report to `stderr` — including
/// the hybrid ObjC+AppScript call stack produced by ``ASErrorHybridCallStackKey``
/// — then calls `abort()`. For all other exception types the previously-installed
/// handler (if any) is invoked, preserving existing handler chains.
///
/// Call this function **once**, before `NSApplicationMain`, to enable augmented
/// AppScript crash reports. The AppScript framework never calls it automatically.
///
/// > Note: Calling this function more than once is safe — the handler is only
/// > registered once and a loop-safe guard prevents the function from recording
/// > its own handler as the "previous" handler.
FOUNDATION_EXPORT void ASInstallUncaughtExceptionHandler(void);

NS_ASSUME_NONNULL_END
