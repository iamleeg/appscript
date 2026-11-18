// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASExceptionHandler.h — Interface through which an app intercepts AppScript exceptions
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
#import <AppScript/ASExceptionContext.h>
#import <AppScript/ASExceptionDisposition.h>

NS_ASSUME_NONNULL_BEGIN

/// Implemented by objects that want to see exceptions raised while the interpreter
/// is sending a message. Install one with `+[ASInterpreter setExceptionHandler:]`.
@protocol ASExceptionHandler <NSObject>

/// Called once per exception, on the thread that raised it. Return
/// ``ASExceptionDispositionReraise`` to keep propagating `exception`, or
/// ``ASExceptionDispositionRetry`` to dispatch the failed send again.
- (ASExceptionDisposition)handleException:(NSException *)exception
                                  context:(ASExceptionContext *)context;

@end

NS_ASSUME_NONNULL_END
