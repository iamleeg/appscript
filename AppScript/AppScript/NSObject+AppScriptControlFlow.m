// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSObject+AppScriptControlFlow.m — Loop control flow on NSObject
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

#import "NSObject+AppScriptControlFlow.h"
#import "ASNull.h"

static BOOL AppScriptIsFalsy(id _Nullable value) {
    return value == nil || value == [ASNull null] || [value isEqual:@NO];
}

@implementation NSObject (AppScriptControlFlow)

- (nullable id)do:(nullable id (^)(void))aBlock while:(nullable id (^)(void))testBlock {
    id lastResult = nil;
    while (YES) {
        id condition = testBlock ? testBlock() : nil;
        if (AppScriptIsFalsy(condition)) {
            break;
        }
        if (aBlock) {
            lastResult = aBlock();
        }
    }
    return lastResult;
}

- (nullable id)do:(nullable id (^)(void))aBlock until:(nullable id (^)(void))testBlock {
    id lastResult = nil;
    do {
        if (aBlock) {
            lastResult = aBlock();
        }
        id condition = testBlock ? testBlock() : nil;
        if (!AppScriptIsFalsy(condition)) {
            break;
        }
    } while (YES);
    return lastResult;
}

@end
