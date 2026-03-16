// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSValue+AppScriptGeometry.m — Geometry constructors for use from AppScript
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

#import "NSValue+AppScriptGeometry.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation NSValue (AppScriptGeometry)

+ (NSValue *)rectWithX:(NSNumber *)x y:(NSNumber *)y width:(NSNumber *)width height:(NSNumber *)height {
    CGRect rect = CGRectMake([x doubleValue], [y doubleValue], [width doubleValue], [height doubleValue]);
    return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
}

+ (NSValue *)zeroRect {
    CGRect zero = CGRectZero;
    return [NSValue valueWithBytes:&zero objCType:@encode(CGRect)];
}

+ (NSValue *)sizeWithWidth:(NSNumber *)width height:(NSNumber *)height {
    CGSize size = CGSizeMake([width doubleValue], [height doubleValue]);
    return [NSValue valueWithBytes:&size objCType:@encode(CGSize)];
}

+ (NSValue *)pointWithX:(NSNumber *)x y:(NSNumber *)y {
    CGPoint point = CGPointMake([x doubleValue], [y doubleValue]);
    return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}

@end
