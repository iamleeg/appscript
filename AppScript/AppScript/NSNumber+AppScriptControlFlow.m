// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSNumber+AppScriptControlFlow.m — Boolean control flow on NSNumber
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

#import <AppScript/NSNumber+AppScriptControlFlow.h>

@implementation NSNumber (AppScriptControlFlow)

- (nullable id)ifTrue:(nullable id (^)(void))trueBlock ifFalse:(nullable id (^)(void))falseBlock {
    if ([self boolValue]) {
        if (trueBlock) {
            return trueBlock();
        }
        return nil;
    } else {
        if (falseBlock) {
            return falseBlock();
        }
        return nil;
    }
}

- (nullable id)ifTrue:(nullable id (^)(void))trueBlock {
    return [self ifTrue:trueBlock ifFalse:nil];
}

- (nullable id)ifFalse:(nullable id (^)(void))falseBlock {
    return [self ifTrue:nil ifFalse:falseBlock];
}

@end
