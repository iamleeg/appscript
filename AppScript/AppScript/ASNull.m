// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASNull.m — Singleton sentinel representing AppScript nil
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

#import <AppScript/ASNull.h>

@implementation ASNull

+ (instancetype)null {
    static ASNull *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:nil];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self null];
}

- (instancetype)copyWithZone:(struct _NSZone *)zone {
    return self;
}

- (NSString *)description {
    return @"<ASNull: nil>";
}

- (NSNumber *)isNil {
    return @YES;
}

@end
