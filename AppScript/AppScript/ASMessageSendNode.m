// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASMessageSendNode.m — AST node representing a message send expression
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

#import <AppScript/ASMessageSendNode.h>

@implementation ASMessageSendNode

- (instancetype)initWithReceiver:(ASASTNode *)receiver
                   selectorParts:(NSArray<NSString *> *)selectorParts
                       arguments:(NSArray<ASASTNode *> *)arguments
                            line:(NSUInteger)line
                          column:(NSUInteger)column {
    self = [super initWithLine:line column:column];
    if (self) {
        _receiver = receiver;
        _selectorParts = [selectorParts copy];
        _arguments = [arguments copy];
    }
    return self;
}

- (NSString *)selector {
    if (self.arguments.count == 0) {
        return self.selectorParts.firstObject ?: @"";
    }
    NSMutableString *sel = [NSMutableString string];
    for (NSString *part in self.selectorParts) {
        [sel appendString:part];
        [sel appendString:@":"];
    }
    return [sel copy];
}

@end
