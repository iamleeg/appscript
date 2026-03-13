// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportInstaller.h — Installs BridgeSupport-described C functions as Objective-C class methods
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
#import "ASBridgeSupportDocument.h"

NS_ASSUME_NONNULL_BEGIN

/// Error domain for errors produced by `ASBridgeSupportInstaller`.
extern NSString * const ASBridgeSupportInstallerErrorDomain;

/// Error codes used in `ASBridgeSupportInstallerErrorDomain`.
typedef NS_ENUM(NSInteger, ASBridgeSupportInstallerError) {
    /// BridgeSupport for this framework has already been installed (the `AS<Framework>` proxy class
    /// already exists in the Objective-C runtime).
    ASBridgeSupportInstallerErrorDuplicateFramework = 1,
    /// The Objective-C runtime could not allocate the proxy class pair.
    ASBridgeSupportInstallerErrorAllocationFailure  = 2,
};

/// Installs C functions, constants, and enumeration values from a parsed `ASBridgeSupportDocument`
/// as Objective-C class methods on a dynamically-created proxy class named `AS<FrameworkName>`.
///
/// ## How it works
///
/// For each non-variadic, non-function-pointer function in the document, `ASBridgeSupportInstaller`
/// looks up the C function symbol using `dlsym(RTLD_DEFAULT, ...)` and registers a class method on
/// the proxy class. Arguments passed as `id` values are unboxed to the required C types before the
/// function is called; the return value is boxed back to `id`.
///
/// Functions whose symbols cannot be resolved (e.g. from an unloaded framework) are silently skipped.
/// Variadic functions and functions with function-pointer arguments are always skipped.
/// Constants whose symbols cannot be resolved are also silently skipped.
/// Enumeration values are embedded directly in BridgeSupport and never require a runtime symbol.
///
/// ## Proxy class naming
///
/// The generated class is named `AS<FrameworkName>`. For example, installing BridgeSupport for
/// framework `"Foundation"` creates a class named `ASFoundation`. AppScript code can then send
/// messages directly to `ASFoundation`:
///
/// ```appscript
/// id result = [ASFoundation sin: angle]
/// ```
///
/// ## Boxing and unboxing rules
///
/// The same `ASBoxer` convention applies here. `NSNumber` unboxes to `double`, `float`, `int`,
/// `long long`, or `BOOL` according to the BridgeSupport type encoding. `NSString` unboxes to
/// `const char *`. `id` passes through directly. `void` return values produce `nil`.
///
/// ## Thread safety
///
/// `installDocument:frameworkName:error:` must be called before any AppScript script that uses
/// the proxy class is run. After installation, the proxy class is safe to use from any thread.
@interface ASBridgeSupportInstaller : NSObject

/// Initializes a new `ASBridgeSupportInstaller`.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Registers C functions from `document` as class methods on the `AS<frameworkName>` proxy class.
///
/// Returns `YES` on success. Returns `NO` with an error if the proxy class already exists
/// (duplicate installation) or cannot be allocated.
///
/// - Parameters:
///   - document: The parsed BridgeSupport document.
///   - frameworkName: The framework name used to derive the proxy class name (`AS<frameworkName>`).
///   - error: On failure, set to describe the error.
/// - Returns: `YES` on success; `NO` on failure.
- (BOOL)installDocument:(ASBridgeSupportDocument *)document
          frameworkName:(NSString *)frameworkName
                  error:(NSError **)error;

/// Convenience for AppScript: installs `document` under `frameworkName` without capturing the error.
///
/// Variadic functions and functions with function-pointer arguments are silently omitted.
/// Returns `YES` on success; `NO` if the proxy class already exists or cannot be allocated.
///
/// - Parameters:
///   - document: The parsed BridgeSupport document.
///   - frameworkName: The framework name used to derive the proxy class name (`AS<frameworkName>`).
- (BOOL)installDocument:(ASBridgeSupportDocument *)document
          frameworkName:(NSString *)frameworkName;

@end

NS_ASSUME_NONNULL_END
