// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSString+AppScriptRuntime.h — ObjC runtime helpers callable from AppScript
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

/// Objective-C runtime helpers for AppScript.
///
/// AppScript cannot call C functions directly. This category bridges the gap for
/// the most commonly needed runtime introspection functions so AppScript code can
/// look up classes and selectors by name without BridgeSupport.
@interface NSString (AppScriptRuntime)

/// Returns the Objective-C class with this string as its name, or `nil` if no
/// such class exists. Equivalent to `NSClassFromString(self)`.
///
/// The return value is typed as `id` so AppScript's all-objects-are-`id` invariant
/// is preserved — the caller receives a Class object and can send class-level
/// messages to it directly.
- (nullable id)as_class;

@end

NS_ASSUME_NONNULL_END
