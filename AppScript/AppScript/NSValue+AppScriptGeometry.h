// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSValue+AppScriptGeometry.h — Geometry constructors for use from AppScript
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

/// Geometry constructors for AppScript code.
///
/// AppScript cannot call C functions such as `NSMakeRect` or `NSMakeSize` directly.
/// These class methods bridge that gap by returning `NSValue` instances that the
/// AppScript runtime's unboxer can convert to the expected C struct type when the
/// value is passed to an Objective-C method that expects `NSRect`, `NSSize`, or
/// `NSPoint`.
@interface NSValue (AppScriptGeometry)

/// Returns an NSValue wrapping an NSRect constructed from the given components.
+ (NSValue *)rectWithX:(NSNumber *)x y:(NSNumber *)y width:(NSNumber *)width height:(NSNumber *)height;

/// Returns an NSValue wrapping a zero-origin, zero-size NSRect (equivalent to NSZeroRect).
+ (NSValue *)zeroRect;

/// Returns an NSValue wrapping an NSSize constructed from the given width and height.
+ (NSValue *)sizeWithWidth:(NSNumber *)width height:(NSNumber *)height;

/// Returns an NSValue wrapping an NSPoint constructed from the given x and y.
+ (NSValue *)pointWithX:(NSNumber *)x y:(NSNumber *)y;

@end

NS_ASSUME_NONNULL_END
