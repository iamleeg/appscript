// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASToken.m — Token type enum and token class for the AppScript lexer
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

#import <AppScript/ASToken.h>

@implementation ASToken

- (instancetype)initWithType:(ASTokenType)type
                        text:(NSString *)text
                        line:(NSUInteger)line
                      column:(NSUInteger)column {
    self = [super init];
    if (self) {
        _type = type;
        _text = [text copy];
        _line = line;
        _column = column;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ASToken type=%ld text=%@ line=%lu col=%lu>",
            (long)_type, _text, (unsigned long)_line, (unsigned long)_column];
}

@end
