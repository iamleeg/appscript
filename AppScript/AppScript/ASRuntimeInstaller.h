// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASRuntimeInstaller.h — Registers parsed AppScript class definitions with the Objective-C runtime
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
#import "ASASTNode.h"

NS_ASSUME_NONNULL_BEGIN

/// Error domain for errors produced by `ASRuntimeInstaller`.
extern NSString * const ASRuntimeInstallerErrorDomain;

/// Error codes used in the `ASRuntimeInstallerErrorDomain`.
typedef NS_ENUM(NSInteger, ASRuntimeInstallerErrorCode) {
    /// The named superclass could not be found in the Objective-C runtime.
    ASRuntimeInstallerErrorUnknownSuperclass = 1,
    /// A class with the given name is already registered in the runtime.
    ASRuntimeInstallerErrorDuplicateClass    = 2,
    /// The named class could not be found in the Objective-C runtime (used for categories).
    ASRuntimeInstallerErrorUnknownClass      = 3,
};

/// Registers parsed AppScript class and category definitions as live Objective-C classes.
///
/// `ASRuntimeInstaller` takes the top-level AST nodes produced by `ASParser` and installs them
/// into the Objective-C runtime using `objc_allocateClassPair`, `class_addMethod`, and related
/// runtime APIs. Method bodies are executed via `ASInterpreter` through a `forwardInvocation:`
/// trampoline mechanism.
///
/// ## Thread safety
///
/// `installNodes:scriptPath:error:` should be called from a single thread at a time (typically
/// at application startup). After installation, the registered classes and their methods are safe
/// to use from any thread, because `ASInterpreter` is itself stateless and thread-safe.
///
/// A global property-key dictionary (`ASPropertyKeys`) is used to store the associated-object
/// keys for synthesized property accessors. It is protected for writes by a serial dispatch queue
/// named `_ASPropertyKeysQueue`. Reads of the dictionary during method dispatch happen only after
/// the keys have been inserted (at installation time), so no read-side locking is needed once
/// installation is complete.
@interface ASRuntimeInstaller : NSObject

/// Initializes a new `ASRuntimeInstaller`.
///
/// Each installer holds a strong reference to an `ASInterpreter` instance that it shares across
/// all installed method trampolines.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Registers all class definitions found in the given AST nodes with the Objective-C runtime.
///
/// For each `ASClassDefinitionNode`: allocates a new class pair, registers it, synthesizes
/// KVC-compliant property accessors, and installs trampoline IMPs for every method.
/// For each `ASCategoryDefinitionNode`: installs trampoline IMPs on the existing class.
///
/// - Parameters:
///   - nodes: The top-level AST nodes returned by `ASParser` (`ASClassDefinitionNode` and
///     `ASCategoryDefinitionNode`). Nodes of other types are silently ignored.
///   - scriptPath: The path of the `.appscript` file containing the definitions, used in error messages.
///   - error: On failure, set to describe the error (e.g. unknown superclass, duplicate class).
/// - Returns: `YES` on success; `NO` if registration fails.
- (BOOL)installNodes:(NSArray<ASASTNode *> *)nodes
          scriptPath:(NSString *)scriptPath
               error:(NSError **)error;

/// Returns the Objective-C Class objects for every class registered by any
/// `ASRuntimeInstaller` instance across all loaded bundles.
///
/// The returned array is a snapshot; it does not update if further scripts are loaded.
+ (NSArray<Class> *)registeredClasses;

@end

NS_ASSUME_NONNULL_END
