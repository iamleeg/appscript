// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportStruct.h — Model class representing a C struct in a BridgeSupport document
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
#import "ASBridgeSupportStructField.h"

NS_ASSUME_NONNULL_BEGIN

/// A C struct described in a BridgeSupport document, with its named fields.
///
/// The `canonicalName` is the public-facing lookup key used at runtime, e.g. @"CGSize".
/// This may differ from the imported name in the BridgeSupport encoding (e.g. @"_NSRange"
/// is mapped to @"NSRange" via the parser's name-mapping table).
///
/// Structs with zero fields (opaque structs) are valid and have an empty `fields` array.
@interface ASBridgeSupportStruct : NSObject

/// The canonical name used as a lookup key at runtime, e.g. @"CGSize", @"NSRange".
@property (nonatomic, readonly, copy) NSString *canonicalName;

/// The fields of this struct, in declaration order. May be empty for opaque structs.
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportStructField *> *fields;

/// Designated initializer.
- (instancetype)initWithCanonicalName:(NSString *)canonicalName
                               fields:(NSArray<ASBridgeSupportStructField *> *)fields NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
