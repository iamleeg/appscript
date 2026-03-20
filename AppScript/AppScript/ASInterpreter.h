// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASInterpreter.h — AST-walking interpreter for AppScript methods
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

// ---------------------------------------------------------------------------
// Runtime error exception name
// ---------------------------------------------------------------------------

/// The name of the ``NSException`` raised by ``ASInterpreter`` when a runtime
/// error is detected in an AppScript method body.
///
/// Callers that need to distinguish AppScript runtime errors from other
/// exceptions should match against this constant. The exception's `userInfo`
/// dictionary carries structured information via the `ASError*Key` constants
/// below.
///
/// > Warning: Do not swallow this exception silently — unhandled AppScript
/// > runtime errors represent a programming mistake in the script under
/// > evaluation, and suppressing them will hide those mistakes from the
/// > developer.
FOUNDATION_EXPORT NSString *const ASRuntimeErrorException;

// ---------------------------------------------------------------------------
// userInfo keys for ASRuntimeErrorException
// ---------------------------------------------------------------------------

/// The human-readable error message describing what went wrong.
/// Value type: `NSString *`.
FOUNDATION_EXPORT NSString *const ASErrorMessageKey;

/// The file-system path of the `.appscript` source file in which the error
/// occurred, or the string `"<unknown>"` when the path is unavailable.
/// Value type: `NSString *`.
FOUNDATION_EXPORT NSString *const ASErrorScriptPathKey;

/// The 1-based line number of the AST node that triggered the error, or `0`
/// when no node is available.
/// Value type: `NSNumber *` (`NSUInteger`).
FOUNDATION_EXPORT NSString *const ASErrorLineKey;

/// The 1-based column number of the AST node that triggered the error, or `0`
/// when no node is available.
/// Value type: `NSNumber *` (`NSUInteger`).
FOUNDATION_EXPORT NSString *const ASErrorColumnKey;

/// A numeric code that uniquely identifies the *type* of runtime error.
/// Value type: `NSNumber *` wrapping an ``ASErrorCode`` enumerator.
///
/// Use this key to programmatically distinguish error kinds without parsing
/// the human-readable ``ASErrorMessageKey`` string.
FOUNDATION_EXPORT NSString *const ASErrorMessageCodeKey;

/// A snapshot of all variable bindings visible in the scope at the error site.
/// Value type: `NSDictionary<NSString *, id> *`.
/// Keys are variable names (including `self` and `_cmd`); values are their
/// runtime values. AppScript nil values are represented as the `NSString`
/// `@"ASNull"` to distinguish them from ObjC `nil` and `NSNull`.
FOUNDATION_EXPORT NSString *const ASErrorLocalsKey;

// ---------------------------------------------------------------------------
// Error code enumeration
// ---------------------------------------------------------------------------

/// Identifies the kind of AppScript runtime error that caused an
/// ``ASRuntimeErrorException`` to be raised.
///
/// Retrieve the code from the exception's `userInfo` via ``ASErrorMessageCodeKey``.
typedef NS_ENUM(NSInteger, ASErrorCode) {
    /// An attempt was made to assign a new value to a variable that was
    /// declared with `const`. Reassigning a constant is always a programming
    /// error in AppScript.
    ASErrorCodeCannotReassignConstant = 1,

    /// An assignment expression targeted a variable name that does not appear
    /// in any enclosing scope. Declare the variable with `id` before assigning
    /// to it.
    ASErrorCodeUndefinedVariable = 2,

    /// An identifier expression could not be resolved: the name was not found
    /// in any enclosing scope, is not `self`, `super`, `nil`, `YES`, or `NO`,
    /// and does not match any known Objective-C class name.
    ASErrorCodeUndefinedIdentifier = 3,

    /// The interpreter encountered an AST node whose class is not handled by
    /// ``ASInterpreter``. This indicates a mismatch between the parser and the
    /// interpreter and should be treated as an interpreter bug.
    ASErrorCodeUnknownASTNodeType = 4,

    /// A message send targeted an object whose class does not respond to the
    /// requested selector. Check that the selector is spelled correctly and
    /// that the receiver is of the expected type.
    ASErrorCodeUnrecognisedSelector = 5,
};

// ---------------------------------------------------------------------------

/// An AST-walking interpreter that evaluates AppScript method bodies.
///
/// `ASInterpreter` is stateless and thread-safe. All mutable execution state
/// (scope stack, return-value holder) is stack-allocated per call to
/// `evaluateMethodBody:withReceiver:selector:arguments:parameterNames:scriptPath:`.
/// Multiple threads may therefore share a single `ASInterpreter` instance and
/// invoke it concurrently without synchronisation.
@interface ASInterpreter : NSObject

/// Evaluates the body statements of a method, and returns the result.
///
/// - Parameters:
///   - body: The array of ASASTNode statement nodes making up the method body.
///   - receiver: The object receiving the method call (`self` inside the method).
///   - definingClass: The Objective-C class that statically defines this method. Used to
///     resolve `super` sends: the message is dispatched starting from `[definingClass superclass]`
///     while `self` remains the actual receiver.
///   - selector: The selector being invoked (available as `_cmd` inside the method).
///   - arguments: The (already-boxed) argument objects, parallel to the method's parameter names.
///   - parameterNames: The parameter variable names declared in the method signature.
///   - scriptPath: The path of the `.appscript` file containing this method, for error messages.
/// - Returns: The value returned by a `return` statement, or `nil` if the body completes without returning.
- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                     definingClass:(Class)definingClass
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath;

@end

NS_ASSUME_NONNULL_END
