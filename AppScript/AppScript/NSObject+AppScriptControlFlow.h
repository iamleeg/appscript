// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSObject+AppScriptControlFlow.h — Loop control flow on NSObject
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

/// Loop control flow driven by block-returning conditions, added to every NSObject.
@interface NSObject (AppScriptControlFlow)

/// Executes aBlock in a loop while testBlock returns any object other than nil or @NO.
/// May not execute aBlock at all if the condition is false on the first check.
/// Returns the result of the last execution of aBlock, or nil if aBlock was never run.
- (nullable id)do:(nullable id (^)(void))aBlock while:(nullable id (^)(void))testBlock;

/// Executes aBlock in a loop until testBlock returns nil or @NO.
/// Guaranteed to run aBlock at least once.
/// Returns the result of the last execution of aBlock.
- (nullable id)do:(nullable id (^)(void))aBlock until:(nullable id (^)(void))testBlock;

@end

NS_ASSUME_NONNULL_END
