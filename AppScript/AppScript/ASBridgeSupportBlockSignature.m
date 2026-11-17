// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportBlockSignature.m — The signature of a block parameter of an Objective-C method, from BridgeSupport
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

#import <AppScript/ASBridgeSupportBlockSignature.h>

@implementation ASBridgeSupportBlockSignature

- (instancetype)initWithClassName:(NSString *)className
                     selectorName:(NSString *)selectorName
                    isClassMethod:(BOOL)isClassMethod
                    argumentIndex:(NSUInteger)argumentIndex
           parameterTypeEncodings:(NSArray<NSString *> *)parameterTypeEncodings
               returnTypeEncoding:(NSString *)returnTypeEncoding {
    self = [super init];
    if (self) {
        _className = [className copy];
        _selectorName = [selectorName copy];
        _isClassMethod = isClassMethod;
        _argumentIndex = argumentIndex;
        _parameterTypeEncodings = [parameterTypeEncodings copy];
        _returnTypeEncoding = [returnTypeEncoding copy];
    }
    return self;
}

static BOOL ASIsObjectEncoding(NSString *encoding) {
    return [encoding hasPrefix:@"@"] || [encoding hasPrefix:@"#"];
}

- (BOOL)isObjectOnly {
    for (NSString *encoding in self.parameterTypeEncodings) {
        if (!ASIsObjectEncoding(encoding)) {
            return NO;
        }
    }
    return ASIsObjectEncoding(self.returnTypeEncoding) || [self.returnTypeEncoding isEqualToString:@"v"];
}

@end
