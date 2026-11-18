// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASExceptionDisposition.h — What an exception handler wants the interpreter to do
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

/// The decision an ``ASExceptionHandler`` returns to the interpreter.
typedef NS_ENUM(NSInteger, ASExceptionDisposition) {
    /// Continue propagating the exception to the caller.
    ASExceptionDispositionReraise = 0,
    /// Dispatch the failed message send again. The send is retried at most once;
    /// a second failure is re-raised without consulting the handler.
    /// Retrying an alloc-, new-, copy- or init-family send may leak the object the failed
    /// attempt had begun to create, but never over-releases.
    ASExceptionDispositionRetry = 1,
};

NS_ASSUME_NONNULL_END
