// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockRegistry.h — Registry of the block signatures Cocoa methods expect
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
#import <AppScript/ASBridgeSupportBlockSignature.h>

NS_ASSUME_NONNULL_BEGIN

/// The block signatures the runtime knows for methods that take a block argument.
///
/// BridgeSupport loading registers every method block signature it reads. The registry also holds
/// built-in signatures for the framework's own block-taking helpers (`ifTrue:`, `do:while:`) and for
/// `-[NSArray sortedArrayUsingComparator:]` and `-[NSArray enumerateObjectsUsingBlock:]`, so they work
/// where BridgeSupport isn't available.
///
/// Thread safety: the table is owned by a private serial dispatch queue; every method may be called
/// from any thread.
@interface ASBlockRegistry : NSObject

/// The shared registry.
+ (ASBlockRegistry *)sharedRegistry;

/// Registers a signature, replacing any earlier one for the same class, selector and argument.
///
/// - Parameter signature: The signature to register.
- (void)registerSignature:(ASBridgeSupportBlockSignature *)signature;

/// Registers several signatures.
///
/// - Parameter signatures: The signatures to register.
- (void)registerSignatures:(NSArray<ASBridgeSupportBlockSignature *> *)signatures;

/// Finds the signature of the block a method expects at an argument.
///
/// Looks for the receiver's class first and then each superclass, for an instance method or, when
/// `receiver` is a class, a class method.
///
/// - Parameters:
///   - receiver: The object (or class) the message is sent to.
///   - selector: The selector being sent.
///   - argumentIndex: The zero-based index of the block argument, not counting `self` and `_cmd`.
/// - Returns: The registered signature, or `nil` if none is known.
- (nullable ASBridgeSupportBlockSignature *)signatureForReceiver:(id)receiver
                                                         selector:(SEL)selector
                                                    argumentIndex:(NSUInteger)argumentIndex;

@end

NS_ASSUME_NONNULL_END
