// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptControlFlow.h — Boolean control flow on NSNumber
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

/// Boolean control flow branching on the truthiness of an NSNumber value.
@interface NSNumber (AppScriptControlFlow)

/// Executes trueBlock if the receiver is non-zero and non-nil; executes falseBlock otherwise.
/// Returns the result of whichever block is executed, or nil if the executed block has no return value.
- (nullable id)ifTrue:(nullable id (^)(void))trueBlock ifFalse:(nullable id (^)(void))falseBlock;

@end

NS_ASSUME_NONNULL_END
