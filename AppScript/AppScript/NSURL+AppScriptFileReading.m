// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSURL+AppScriptFileReading.m — Out-parameter-free file reading for AppScript
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

#import <AppScript/NSURL+AppScriptFileReading.h>

@implementation NSURL (AppScriptFileReading)

- (nullable NSString *)as_stringContents {
    return [NSString stringWithContentsOfURL:self
                                    encoding:NSUTF8StringEncoding
                                       error:NULL];
}

@end
