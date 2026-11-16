// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportBlockSignature.h — The signature of a block parameter of an Objective-C method, from BridgeSupport
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

/// The C signature of a block that a method expects as an argument, as BridgeSupport describes it:
/// `<method selector='enumerateObjectsUsingBlock:'><arg index='0' function_pointer='true' type64='@?'>`
/// followed by one nested `<arg>` per block parameter and a nested `<retval>`.
///
/// The `@?` encoding the Objective-C runtime reports for a block carries no signature, so this is how
/// the runtime learns what a Cocoa API will call a script's block with.
@interface ASBridgeSupportBlockSignature : NSObject

/// The class that declares the method.
@property (nonatomic, readonly, copy) NSString *className;

/// The selector of the method, such as `enumerateObjectsUsingBlock:`.
@property (nonatomic, readonly, copy) NSString *selectorName;

/// `YES` for a class method, `NO` for an instance method.
@property (nonatomic, readonly) BOOL isClassMethod;

/// The zero-based index of the block argument among the method's arguments (not counting `self` and `_cmd`).
@property (nonatomic, readonly) NSUInteger argumentIndex;

/// The type encodings of the block's parameters, in order.
@property (nonatomic, readonly, copy) NSArray<NSString *> *parameterTypeEncodings;

/// The type encoding of the block's return value (`v` for none).
@property (nonatomic, readonly, copy) NSString *returnTypeEncoding;

/// Creates a signature.
///
/// - Parameters:
///   - className: The class that declares the method.
///   - selectorName: The method's selector.
///   - isClassMethod: Whether the method is a class method.
///   - argumentIndex: The index of the block argument.
///   - parameterTypeEncodings: The block's parameter type encodings.
///   - returnTypeEncoding: The block's return type encoding.
- (instancetype)initWithClassName:(NSString *)className
                     selectorName:(NSString *)selectorName
                    isClassMethod:(BOOL)isClassMethod
                    argumentIndex:(NSUInteger)argumentIndex
           parameterTypeEncodings:(NSArray<NSString *> *)parameterTypeEncodings
               returnTypeEncoding:(NSString *)returnTypeEncoding NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Returns whether every parameter is an object (`@` or `#`) and the return is an object or `void`.
///
/// Such a block can be called with the all-`id` block AppScript builds for a script, so it needs no
/// wrapper.
///
/// - Returns: `YES` if the signature is object-only.
- (BOOL)isObjectOnly;

@end

NS_ASSUME_NONNULL_END
