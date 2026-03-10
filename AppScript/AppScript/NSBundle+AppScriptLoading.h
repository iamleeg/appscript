// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle+AppScriptLoading.h — Top-level entry point for loading .appscript files from a bundle
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

/// Error domain used when bundle loading fails.
extern NSString * const ASBundleLoadingErrorDomain;

/// Error codes used within `ASBundleLoadingErrorDomain`.
typedef NS_ENUM(NSInteger, ASBundleLoadingErrorCode) {
    /// The bundle has already been loaded via a previous call to -loadAppScriptsInBundle:.
    ASBundleLoadingErrorDuplicateLoad  = 1,
    /// A lexer error occurred while processing an .appscript file.
    ASBundleLoadingErrorLexerFailure   = 2,
    /// A parser error occurred while processing an .appscript file.
    ASBundleLoadingErrorParserFailure  = 3,
    /// The runtime installer could not install the parsed definitions.
    ASBundleLoadingErrorInstallFailure = 4,
};

/// NSBundle category providing AppScript source-file discovery and loading.
@interface NSBundle (AppScriptLoading)

/// Discovers all AppScript source files in the bundle and loads them into the host application.
///
/// This method searches for `*.appscript` files in the bundle, lexes and parses each one, and
/// registers the defined classes and categories with the Objective-C runtime.
///
/// Call this method once per bundle. Calling it a second time on the same bundle returns `NO`
/// and sets `error` to describe the duplicate-load attempt. The method may be called on
/// different bundles without restriction.
///
/// If any `.appscript` file contains a lexer or parser error, the method returns `NO` and sets
/// `error` to describe the first error encountered. Classes from successfully parsed files
/// that were already registered before the error occurred remain registered.
///
/// - Parameter error: On failure, set to a description of the error.
/// - Returns: `YES` if all scripts loaded successfully; `NO` otherwise.
- (BOOL)loadAppScriptsInBundle:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
