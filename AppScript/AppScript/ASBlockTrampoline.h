// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockTrampoline.h — Gives a script block the C signature a Cocoa method will call it with
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
#import "ASBridgeSupportBlockSignature.h"

NS_ASSUME_NONNULL_BEGIN

/// Error domain for failures building a block wrapper.
extern NSString * const ASBlockTrampolineErrorDomain;

/// Error code: the signature has a type the runtime can't pass through a block.
extern const NSInteger ASBlockTrampolineErrorUnsupportedType;

/// Wraps a script block in a block with the C signature a Cocoa method expects.
///
/// A script block is built as `id (^)(id…)`, so a Cocoa method that calls it with an `NSUInteger`, a
/// `BOOL *` or a `double` hands it values it would misread as objects. A wrapper block has the real
/// signature (built from a libffi closure), boxes each argument for the script, runs the script's
/// block and converts the result to the declared return type with the strict rules of
/// `ASErrorCodeValueConversionFailed`. A pointer to a scalar becomes an `ASOutObject` the script can
/// write, and its value is stored back when the script returns.
///
/// Thread safety: a wrapper may be called from any thread, as the interpreter may.
@interface ASBlockTrampoline : NSObject

/// Unavailable: use the class methods.
- (instancetype)init NS_UNAVAILABLE;

/// Marks `block` as a script block and records how to run it with boxed arguments.
///
/// - Parameters:
///   - invoker: Runs the block's body with the given boxed arguments and returns its result.
///   - parameterCount: The number of parameters the script declared.
///   - block: The block the interpreter built for the script's block literal.
+ (void)attachInvoker:(id _Nullable (^)(NSArray *arguments))invoker
       parameterCount:(NSUInteger)parameterCount
        toScriptBlock:(id)block;

/// Returns whether `object` is a block the interpreter built for a script's block literal.
///
/// - Parameter object: Any object.
/// - Returns: `YES` for a script block.
+ (BOOL)isScriptBlock:(nullable id)object;

/// Returns the number of parameters a script block declared.
///
/// - Parameter block: A script block.
/// - Returns: Its parameter count, or 0 if `block` isn't a script block.
+ (NSUInteger)parameterCountOfScriptBlock:(id)block;

/// Builds a block with the signature's C types that runs `scriptBlock` when called.
///
/// - Parameters:
///   - scriptBlock: A script block (see `+isScriptBlock:`).
///   - signature: The signature the receiving method expects.
///   - error: On failure, set to an error in `ASBlockTrampolineErrorDomain`.
/// - Returns: The wrapper block, or `nil` if the signature has an unsupported type.
+ (nullable id)blockWrappingScriptBlock:(id)scriptBlock
                              signature:(ASBridgeSupportBlockSignature *)signature
                                  error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
