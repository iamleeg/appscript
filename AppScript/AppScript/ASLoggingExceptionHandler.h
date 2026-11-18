// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLoggingExceptionHandler.h — Default exception handler: log one line and re-raise
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
#import <AppScript/ASExceptionHandler.h>

NS_ASSUME_NONNULL_BEGIN

/// The handler used when an app installs none. Logs a one-line summary with
/// `NSLog` and returns ``ASExceptionDispositionReraise``.
@interface ASLoggingExceptionHandler : NSObject <ASExceptionHandler>

/// The line that is logged: `AppScript exception <name>: <message> (<path>:<line>)`.
+ (NSString *)summaryForException:(NSException *)exception
                          context:(ASExceptionContext *)context;

@end

NS_ASSUME_NONNULL_END
