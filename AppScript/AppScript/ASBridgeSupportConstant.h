// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportConstant.h — Model class representing a C constant in a BridgeSupport document
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

/// A C constant described in a BridgeSupport document.
@interface ASBridgeSupportConstant : NSObject

/// The name of the constant as it appears in the BridgeSupport XML.
@property (nonatomic, readonly, copy) NSString *name;

/// The Objective-C type encoding of the constant's value (e.g. @"d" for double, @"q" for NSInteger).
@property (nonatomic, readonly, copy) NSString *typeEncoding;

/// Designated initializer.
- (instancetype)initWithName:(NSString *)name
                typeEncoding:(NSString *)typeEncoding NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
