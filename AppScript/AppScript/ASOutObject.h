// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASOutObject.h — Mutable container boxing an Objective-C object out-parameter (id *)
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

/// A mutable container that represents an Objective-C out-parameter: an object (`NSError **`, encoded `^@`),
/// a scalar (`NSInteger *`, `double *`, `BOOL *`) or a struct (`NSRange *`).
///
/// For a scalar or struct out-parameter `value` is an `NSNumber` or `ASStructValue`, and
/// `pointeeTypeEncoding` holds the pointed-to type's encoding (for example `q` or `{_NSRange=QQ}`).
/// For an object out-parameter `pointeeTypeEncoding` is `nil`.
///
/// When an Objective-C caller passes a non-NULL `NSError **` (or any `id *`, encoded as `^@`) into an
/// AppScript method, `ASBoxer` boxes the pointer into an `ASOutObject` instance. Inside the AppScript
/// method body, code can assign an object to the out-parameter via `[outError setValue:myError]` or
/// forward `outError` directly to another Objective-C method expecting an `NSError **`. When the
/// AppScript method returns, the runtime writes `value` back to the caller's `id *` pointer.
///
/// AppScript code can also instantiate `ASOutObject` via `+outObject` and pass it to Objective-C
/// methods that populate an `NSError **` out-parameter, then inspect `-value` after the call.
///
/// Thread safety: An `ASOutObject` instance is confined to the single method invocation frame that
/// created it and must not be shared across threads without external synchronisation.
@interface ASOutObject : NSObject

/// The object, `NSNumber` or `ASStructValue` stored in or written to the out-parameter slot. Defaults to `nil`.
@property (nonatomic, strong, nullable) id value;

/// The Objective-C type encoding of the value the out-parameter points to, such as `q`, `d`,
/// `B` or `{_NSRange=QQ}`, or `nil` for an object out-parameter and for an out-object a script
/// created that has not yet been passed to a native method. The runtime sets it when it boxes a
/// pointer argument and when a native method fills the out-object.
@property (nonatomic, copy, nullable) NSString *pointeeTypeEncoding;

/// Creates and returns a new `ASOutObject` with a `nil` initial value.
///
/// - Returns: A newly allocated `ASOutObject` instance with `value` set to `nil`.
+ (instancetype)outObject;

/// Initialises an `ASOutObject` with the given initial value and pointee type.
///
/// - Parameters:
///   - value: The initial object, `NSNumber` or `ASStructValue` pointed to by the out-parameter, or `nil`.
///   - pointeeTypeEncoding: The encoding of the pointed-to scalar or struct type, or `nil` for an object.
/// - Returns: An initialised `ASOutObject` instance.
- (instancetype)initWithValue:(nullable id)value
          pointeeTypeEncoding:(nullable NSString *)pointeeTypeEncoding NS_DESIGNATED_INITIALIZER;

/// Initialises an `ASOutObject` with the given initial object value and no pointee type.
///
/// - Parameter value: The initial object pointed to by the out-parameter, or `nil`.
/// - Returns: An initialised `ASOutObject` instance.
- (instancetype)initWithValue:(nullable id)value;

/// Initialises an `ASOutObject` with a `nil` initial value.
///
/// - Returns: An initialised `ASOutObject` instance.
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
