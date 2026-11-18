// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASExceptionContext.m — Description of a failed message send passed to an exception handler
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

#import <AppScript/ASExceptionContext.h>

@implementation ASExceptionContext

- (instancetype)initWithReceiver:(id)receiver
                        selector:(SEL)selector
                      scriptPath:(NSString *)scriptPath
                            line:(NSUInteger)line
                          locals:(NSDictionary<NSString *, id> *)locals
                 hybridCallStack:(NSArray<NSString *> *)hybridCallStack
           crossedScriptBoundary:(BOOL)crossedScriptBoundary {
    self = [super init];
    if (self) {
        _receiver = receiver;
        _selector = selector;
        _scriptPath = [scriptPath copy];
        _line = line;
        _locals = [locals copy];
        _hybridCallStack = [hybridCallStack copy];
        _crossedScriptBoundary = crossedScriptBoundary;
    }
    return self;
}

@end
