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
#import <AppScript/ASASTNode.h>
#import <AppScript/ASMethodNode.h>

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
    /// A protocol named in a class's conformance list is not registered in the Objective-C
    /// runtime: no compiled code references it with a protocol expression, or the library that
    /// defines it has not been loaded yet.
    ASRuntimeInstallerErrorUnknownProtocol   = 4,
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
///   - error: On failure, set to describe the error (e.g. unknown superclass, duplicate class,
///     or a protocol in the conformance list that isn't registered in the runtime). Every
///     protocol a class names must already be registered; otherwise the class is not installed.
/// - Returns: `YES` on success; `NO` if registration fails.
- (BOOL)installNodes:(NSArray<ASASTNode *> *)nodes
          scriptPath:(NSString *)scriptPath
               error:(NSError **)error;

/// Returns the Objective-C Class objects for every class registered by any
/// `ASRuntimeInstaller` instance across all loaded bundles.
///
/// The returned array is a snapshot; it does not update if further scripts are loaded.
+ (NSArray<Class> *)registeredClasses;

/// Looks up the `ASMethodNode` for a given selector in the AppScript method maps
/// installed on `startClass` and its superclasses.
///
/// Used by `ASInterpreter` to detect super sends targeting AppScript-defined methods
/// so that it can dispatch directly via `evaluateMethodBody:` rather than through the
/// ObjC forwarding machinery (which would cause infinite recursion).
///
/// - Parameters:
///   - startClass: The class at which to begin the search (typically `[definingClass superclass]`).
///   - selectorString: The selector string to look up.
///   - outDefiningClass: If non-NULL and a method node is found, set to the class that owns
///     the method map entry. This is the `definingClass` to pass to `evaluateMethodBody:`.
/// - Returns: The `ASMethodNode` for the selector, or `nil` if no AppScript method was found.
+ (nullable ASMethodNode *)appScriptMethodNodeForSuperDispatch:(Class)startClass
                                                      selector:(NSString *)selectorString
                                                 definingClass:(Class _Nullable * _Nullable)outDefiningClass;

/// Passes an AppScript method's result through the C return type declared for it, as
/// Objective-C dispatch would. Used for `[super ...]` sends, which evaluate the
/// superclass's AppScript method directly instead of going through the ObjC runtime.
///
/// The return type comes from the method installed on `definingClass` (from a
/// conforming protocol or a native superclass). `id` returns pass `value` through
/// unchanged; `void` returns yield `nil`; any other type converts `value` to that
/// type and boxes it again, so the caller sees what a normal message send would return.
///
/// - Parameters:
///   - value: The object the AppScript method body returned. May be `nil`.
///   - selectorString: The method's selector.
///   - definingClass: The AppScript class that defines the method.
///   - isClassMethod: `YES` for a class method, `NO` for an instance method.
/// - Returns: The converted value.
/// - Throws: Raises ``ASRuntimeErrorException`` with ``ASErrorCodeValueConversionFailed``
///   at the method's declaration if `value` cannot be converted to the return type.
+ (nullable id)checkedReturnValue:(nullable id)value
                       ofSelector:(NSString *)selectorString
                    definingClass:(Class)definingClass
                    isClassMethod:(BOOL)isClassMethod;

@end

NS_ASSUME_NONNULL_END
