// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLoader.h — API for loading AppScript scripts from arbitrary paths and runtime strings
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
#import <AppScript/ASASTNode.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain used when script loading fails.
extern NSString * const ASLoaderErrorDomain;

/// Error codes used within `ASLoaderErrorDomain`.
typedef NS_ENUM(NSInteger, ASLoaderErrorCode) {
    /// The specified file could not be found.
    ASLoaderErrorFileNotFound          = 1,
    /// The file could not be read (permissions, encoding issues, etc.).
    ASLoaderErrorFileReadFailure       = 2,
    /// A lexer error occurred while processing the script source.
    ASLoaderErrorLexerFailure          = 3,
    /// A parser error occurred while processing the script source.
    ASLoaderErrorParserFailure         = 4,
    /// The runtime installer could not install the parsed definitions.
    ASLoaderErrorInstallFailure        = 5,
    /// The script has already been loaded (based on file path or source hash).
    ASLoaderErrorDuplicateLoad         = 6,
};

/// API for loading AppScript scripts from arbitrary file paths and runtime strings.
///
/// `ASLoader` provides methods to load AppScript scripts from:
/// - Arbitrary file paths (not limited to bundle resources)
/// - Runtime strings containing AppScript source code
///
/// Scripts loaded via `ASLoader` participate fully in the AppScript runtime:
/// they can define new classes, extend existing AppScript classes with new
/// methods/properties, or replace existing class definitions.
///
/// ## Thread Safety
///
/// All methods in this class are thread-safe and can be called from any queue.
///
/// ## Duplicate Load Detection
///
/// Scripts are identified for duplicate detection by:
/// - File path: when loading from a file, the absolute path is used
/// - Source hash: when loading from a string, a hash of the source content is used
///
//  Calling load methods with the same identifier (path or hash) will return NO
/// and set an error with code ASLoaderErrorDuplicateLoad.
@interface ASLoader : NSObject

/// Initializes a new `ASLoader` instance.
///
/// Each loader holds a reference to a shared `ASRuntimeInstaller` for installing
/// parsed definitions into the Objective-C runtime.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Loads an AppScript script from a file path.
///
/// This method reads the specified file, lexes and parses its contents, and
/// installs the resulting definitions into the AppScript runtime.
///
/// - Parameters:
///   - filePath: The absolute path to the .appscript file.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptFromFileAtPath:(NSString *)filePath error:(NSError **)error;

/// Loads an AppScript script from a runtime string.
///
/// This method lexes and parses the provided source code and installs the
/// resulting definitions into the AppScript runtime.
///
/// - Parameters:
///   - source: The AppScript source code as an NSString.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptFromString:(NSString *)source error:(NSError **)error;

/// Loads an AppScript script from a file path with additional options.
///
/// This method provides more control over the loading process, allowing you
/// to specify a custom script name for error reporting.
///
/// - Parameters:
///   - filePath: The absolute path to the .appscript file.
///   - scriptName: A name for the script used in error messages and logging.
///                 If nil, the file path is used.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptFromFileAtPath:(NSString *)filePath
                      scriptName:(nullable NSString *)scriptName
                           error:(NSError **)error;

/// Loads an AppScript script from a runtime string with additional options.
///
/// This method provides more control over the loading process, allowing you
/// to specify a custom script name for error reporting.
///
/// - Parameters:
///   - source: The AppScript source code as an NSString.
///   - scriptName: A name for the script used in error messages and logging.
///                 If nil, a hash of the source is used.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptFromString:(NSString *)source
                  scriptName:(nullable NSString *)scriptName
                       error:(NSError **)error;

/// Loads multiple AppScript scripts from file paths.
///
/// This method loads multiple scripts in dependency order, similar to
/// `NSBundle+AppScriptLoading`. Scripts are sorted by superclass dependencies
/// before installation.
///
/// - Parameters:
///   - filePaths: An array of absolute file paths to .appscript files.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptsFromFilesAtPaths:(NSArray<NSString *> *)filePaths error:(NSError **)error;

/// Loads multiple AppScript scripts from runtime strings.
///
/// This method loads multiple scripts without dependency ordering (since
/// string-based scripts cannot easily determine inter-script dependencies).
///
/// - Parameters:
///   - sources: An array of AppScript source code strings.
///   - error: On failure, set to describe the error. May be NULL.
/// - Returns: `YES` if loading succeeded; `NO` otherwise.
- (BOOL)loadScriptsFromStrings:(NSArray<NSString *> *)sources error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
