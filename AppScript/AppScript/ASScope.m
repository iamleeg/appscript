// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASScope.m — Single frame in the AppScript variable scope stack
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

#import <AppScript/ASScope.h>
#import <AppScript/ASNull.h>

@implementation ASScope {
    NSMutableDictionary<NSString *, id> *_bindings;
}

- (instancetype)initWithEnclosingScope:(nullable ASScope *)enclosingScope {
    self = [super init];
    if (self) {
        _enclosingScope = enclosingScope;
        _bindings = [NSMutableDictionary dictionary];
    }
    return self;
}

- (nullable id)valueForName:(NSString *)name {
    id value = _bindings[name];
    if (value != nil) {
        return value;
    }
    // ASNull is the sentinel meaning "nil was explicitly set in this scope frame"
    if ([_bindings objectForKey:name] != nil) {
        return [ASNull null];
    }
    return [_enclosingScope valueForName:name];
}

- (void)setValue:(nullable id)value forName:(NSString *)name {
    if (value == nil || value == [ASNull null]) {
        _bindings[name] = [ASNull null];
    } else {
        _bindings[name] = value;
    }
}

- (BOOL)updateValue:(nullable id)value forName:(NSString *)name {
    if ([self hasNameLocally:name]) {
        [self setValue:value forName:name];
        return YES;
    }
    return [_enclosingScope updateValue:value forName:name];
}

- (BOOL)hasName:(NSString *)name {
    if ([self hasNameLocally:name]) {
        return YES;
    }
    return [_enclosingScope hasName:name];
}

- (BOOL)hasNameLocally:(NSString *)name {
    return [_bindings objectForKey:name] != nil;
}

- (NSDictionary<NSString *, id> *)allVisibleBindings {
    NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary dictionary];
    ASScope *scope = self;
    while (scope != nil) {
        [scope->_bindings enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            if (result[key] == nil) {
                // Inner scope wins; only add a name the first time we see it.
                result[key] = (value == [ASNull null]) ? @"ASNull" : value;
            }
        }];
        scope = scope.enclosingScope;
    }
    return [result copy];
}

@end
