// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportFunction.h — Model class representing a C function in a BridgeSupport document
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

/// A C function described in a BridgeSupport document.
@interface ASBridgeSupportFunction : NSObject

/// The name of the function as it appears in the BridgeSupport XML.
@property (nonatomic, readonly, copy) NSString *name;

/// The Objective-C type encoding of the function's return value (e.g. @"v" for void, @"d" for double).
@property (nonatomic, readonly, copy) NSString *returnTypeEncoding;

/// The Objective-C type encodings of the function's arguments, in declaration order.
@property (nonatomic, readonly, copy) NSArray<NSString *> *argumentTypeEncodings;

/// Whether the function accepts a variable number of arguments.
@property (nonatomic, readonly) BOOL isVariadic;

/// Whether the function is defined inline (i.e. not available as a symbol in the binary).
@property (nonatomic, readonly) BOOL isInline;

/// Whether any argument is a function pointer, making the function unsafe to call generically.
@property (nonatomic, readonly) BOOL hasFunctionPointerArguments;

/// Designated initializer.
- (instancetype)initWithName:(NSString *)name
          returnTypeEncoding:(NSString *)returnTypeEncoding
       argumentTypeEncodings:(NSArray<NSString *> *)argumentTypeEncodings
                  isVariadic:(BOOL)isVariadic
                    isInline:(BOOL)isInline
   hasFunctionPointerArguments:(BOOL)hasFunctionPointerArguments NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
