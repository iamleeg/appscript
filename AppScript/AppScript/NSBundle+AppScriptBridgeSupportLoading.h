// SPDX-License-Identifier: AGPL-3.0-or-later
//
// NSBundle+AppScriptBridgeSupportLoading.h — Entry point for loading BridgeSupport metadata
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

/// Error domain for errors produced by `NSBundle (AppScriptBridgeSupportLoading)`.
extern NSString * const ASBridgeSupportLoadingErrorDomain;

/// Error codes used in `ASBridgeSupportLoadingErrorDomain`.
typedef NS_ENUM(NSInteger, ASBridgeSupportLoadingError) {
    /// The named framework could not be found on the system.
    ASBridgeSupportLoadingErrorFrameworkNotFound    = 1,
    /// No BridgeSupport file could be found for the named framework.
    ASBridgeSupportLoadingErrorBridgeSupportNotFound = 2,
    /// The BridgeSupport file was found but could not be parsed.
    ASBridgeSupportLoadingErrorParseFailed          = 3,
    /// BridgeSupport for this framework has already been loaded.
    ASBridgeSupportLoadingErrorDuplicateLoad        = 4,
};

/// `NSBundle` category providing the host-app entry point for loading BridgeSupport metadata.
///
/// Call `+loadBridgeSupportForFramework:error:` once per framework before running any AppScript
/// scripts that reference that framework's C functions or constants. The method parses the Apple
/// BridgeSupport XML file for the named framework and registers the `AS<FrameworkName>` proxy
/// class in the Objective-C runtime via `ASBridgeSupportInstaller`.
@interface NSBundle (AppScriptBridgeSupportLoading)

/// Loads BridgeSupport metadata for the named framework and registers the `AS<FrameworkName>`
/// proxy class in the Objective-C runtime.
///
/// The method searches for the framework's BridgeSupport file in two locations:
/// 1. Inside the system framework bundle at
///    `/System/Library/Frameworks/<frameworkName>.framework/Resources/BridgeSupport/`
/// 2. At the system-wide path `/System/Library/BridgeSupport/<frameworkName>.bridgesupport`
///
/// Returns `YES` on success; sets `error` and returns `NO` if the BridgeSupport file cannot
/// be found, cannot be parsed, or has already been loaded.
///
/// - Parameters:
///   - frameworkName: The short framework name, e.g. `"Foundation"` or `"AppKit"`.
///   - error: On failure, set to describe the error.
/// - Returns: `YES` on success; `NO` on failure.
+ (BOOL)loadBridgeSupportForFramework:(NSString *)frameworkName error:(NSError **)error;

/// AppScript-friendly convenience variant that omits the error out-parameter.
///
/// Returns `YES` on success; `NO` if the BridgeSupport file cannot be found, parsed, or was
/// already loaded. Use `+loadBridgeSupportForFramework:error:` when you need diagnostic detail.
///
/// - Parameter frameworkName: The short framework name, e.g. `"Foundation"`.
/// - Returns: `YES` on success; `NO` on failure.
+ (BOOL)loadBridgeSupportForFramework:(NSString *)frameworkName;

@end

NS_ASSUME_NONNULL_END
