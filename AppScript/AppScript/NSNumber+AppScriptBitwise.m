// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptBitwise.m — Bitwise operators on NSNumber
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

#import "NSNumber+AppScriptBitwise.h"

@implementation NSNumber (AppScriptBitwise)

- (NSNumber *)bitwiseOr:(NSNumber *)other {
    NSUInteger result = [self unsignedIntegerValue] | [other unsignedIntegerValue];
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)bitwiseAnd:(NSNumber *)other {
    NSUInteger result = [self unsignedIntegerValue] & [other unsignedIntegerValue];
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)bitwiseXor:(NSNumber *)other {
    NSUInteger result = [self unsignedIntegerValue] ^ [other unsignedIntegerValue];
    return [NSNumber numberWithUnsignedInteger:result];
}

- (NSNumber *)bitwiseNot {
    NSUInteger result = ~[self unsignedIntegerValue];
    return [NSNumber numberWithUnsignedInteger:result];
}

@end
