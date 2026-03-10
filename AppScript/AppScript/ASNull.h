// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASNull.h — Singleton sentinel representing AppScript nil
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

/// A distinct singleton that represents AppScript `nil` inside the interpreter.
///
/// Three nil-like values exist in AppScript's runtime:
/// - ObjC `nil`       — absence of a value; never stored in scope or collections.
/// - `[ASNull null]`  — the AppScript value `nil` (e.g. `id x = nil`, or `return nil`).
///                      Falsy in control-flow tests. Unboxed to ObjC `nil` when passed
///                      as an argument to a native method.
/// - `[NSNull null]`  — a legitimate Objective-C object returned by native APIs
///                      (e.g. as a collection placeholder). Truthy in control-flow tests.
@interface ASNull : NSObject

/// Returns the shared ASNull singleton.
+ (instancetype)null;

/// Unavailable. Use +null.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
