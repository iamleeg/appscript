// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportDocument.m — Aggregated model of a parsed BridgeSupport document
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

#import "ASBridgeSupportDocument.h"

@implementation ASBridgeSupportDocument

- (instancetype)initWithFunctions:(NSArray<ASBridgeSupportFunction *> *)functions
                        constants:(NSArray<ASBridgeSupportConstant *> *)constants
                     enumerations:(NSArray<ASBridgeSupportEnumeration *> *)enumerations
                          structs:(NSArray<ASBridgeSupportStruct *> *)structs {
    self = [super init];
    if (self) {
        _functions    = [functions copy];
        _constants    = [constants copy];
        _enumerations = [enumerations copy];
        _structs      = [structs copy];
    }
    return self;
}

- (nullable ASBridgeSupportFunction *)functionNamed:(NSString *)name {
    for (ASBridgeSupportFunction *function in _functions) {
        if ([function.name isEqualToString:name]) {
            return function;
        }
    }
    return nil;
}

- (nullable ASBridgeSupportConstant *)constantNamed:(NSString *)name {
    for (ASBridgeSupportConstant *constant in _constants) {
        if ([constant.name isEqualToString:name]) {
            return constant;
        }
    }
    return nil;
}

- (nullable ASBridgeSupportEnumeration *)enumerationNamed:(NSString *)name {
    for (ASBridgeSupportEnumeration *enumeration in _enumerations) {
        if ([enumeration.name isEqualToString:name]) {
            return enumeration;
        }
    }
    return nil;
}

- (nullable ASBridgeSupportStruct *)structNamed:(NSString *)canonicalName {
    for (ASBridgeSupportStruct *s in _structs) {
        if ([s.canonicalName isEqualToString:canonicalName]) {
            return s;
        }
    }
    return nil;
}

@end
