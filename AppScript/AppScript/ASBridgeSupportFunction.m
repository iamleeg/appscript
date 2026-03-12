// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportFunction.m — Model class representing a C function in a BridgeSupport document
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

#import "ASBridgeSupportFunction.h"

@implementation ASBridgeSupportFunction

- (instancetype)initWithName:(NSString *)name
          returnTypeEncoding:(NSString *)returnTypeEncoding
       argumentTypeEncodings:(NSArray<NSString *> *)argumentTypeEncodings
                  isVariadic:(BOOL)isVariadic
                    isInline:(BOOL)isInline
   hasFunctionPointerArguments:(BOOL)hasFunctionPointerArguments {
    self = [super init];
    if (self) {
        _name = [name copy];
        _returnTypeEncoding = [returnTypeEncoding copy];
        _argumentTypeEncodings = [argumentTypeEncodings copy];
        _isVariadic = isVariadic;
        _isInline = isInline;
        _hasFunctionPointerArguments = hasFunctionPointerArguments;
    }
    return self;
}

@end
