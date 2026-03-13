// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSURL+AppScriptFileReading.h — Out-parameter-free file reading for AppScript
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// File-reading helpers callable from AppScript.
///
/// AppScript cannot call methods that take `NSError **` out-parameters, because the language
/// has no pointer-to-pointer types. This category provides wrapper methods that return `nil`
/// on failure so AppScript code can read files without an error out-parameter.
@interface NSURL (AppScriptFileReading)

/// Reads the file at this URL as a UTF-8 string, returning `nil` if the file cannot be read.
///
/// Equivalent to `[NSString stringWithContentsOfURL:self encoding:NSUTF8StringEncoding error:NULL]`.
- (nullable NSString *)as_stringContents;

@end

NS_ASSUME_NONNULL_END
