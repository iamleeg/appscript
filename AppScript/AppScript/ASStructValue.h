// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASStructValue.h — Boxed C struct with named field accessor dispatch
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
#import "ASBridgeSupportStruct.h"

NS_ASSUME_NONNULL_BEGIN

/// An AppScript-boxed C struct that supports named field access via message sends.
///
/// `ASStructValue` holds the raw bytes of a C struct together with the metadata needed to
/// dispatch field-accessor messages (e.g. `.width`, `.height`) and to produce a standard
/// `NSValue` for interop with Objective-C APIs.
///
/// Field accessor methods are installed lazily on first call to `+registerStruct:` and
/// dispatched through `forwardInvocation:`. Supported field type encodings: `d` (double),
/// `Q` (unsigned long long), and nested struct references (`{…}`).
///
/// ## Thread Safety
/// The process-wide struct registry is protected by a lock; `+registerStruct:` and
/// `+registeredStructNamed:` may be called from any thread.
@interface ASStructValue : NSObject

/// The canonical struct name used to look up the registered `ASBridgeSupportStruct`, e.g. @"CGSize".
@property (nonatomic, readonly, copy) NSString *canonicalName;

/// The runtime Objective-C type encoding of the struct, without field names,
/// e.g. @"{CGSize=dd}". Used by `-asNSValue`.
@property (nonatomic, readonly, copy) NSString *runtimeTypeEncoding;

/// The raw bytes of the struct.
@property (nonatomic, readonly) NSData *bytes;

/// Designated initializer.
///
/// @param bytes          Pointer to the raw struct bytes. Copied immediately.
/// @param length         Number of bytes to copy.
/// @param canonicalName  The canonical struct name, e.g. @"CGSize".
/// @param runtimeTypeEncoding  Stripped ObjC type encoding, e.g. @"{CGSize=dd}".
- (instancetype)initWithBytes:(const void *)bytes
                       length:(NSUInteger)length
                 canonicalName:(NSString *)canonicalName
           runtimeTypeEncoding:(NSString *)runtimeTypeEncoding NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Returns an `NSValue` wrapping the same bytes with the `runtimeTypeEncoding` as `objCType`.
- (NSValue *)asNSValue;

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

/// Registers `bridgeSupportStruct` in the process-wide struct registry and installs
/// a sentinel instance method on `ASStructValue` for each of its named fields.
///
/// If a struct with the same `canonicalName` is already registered, this call is a no-op.
/// Safe to call from any thread.
+ (void)registerStruct:(ASBridgeSupportStruct *)bridgeSupportStruct;

/// Returns the registered `ASBridgeSupportStruct` for `canonicalName`, or nil if none.
+ (nullable ASBridgeSupportStruct *)registeredStructNamed:(NSString *)canonicalName;

/// Maps an imported Objective-C or BridgeSupport struct tag name (e.g. @"_NSRange")
/// to its canonical AppScript struct name (e.g. @"NSRange").
///
/// If no mapping exists for `importedName`, returns `importedName` unchanged.
///
/// - Parameter importedName: The raw struct tag name extracted from a type encoding.
/// - Returns: The canonical AppScript struct name.
+ (NSString *)canonicalNameForImportedStructName:(NSString *)importedName;

/// Resolves a struct type encoding (including bare struct references such as @"{CGSize}"
/// or @"{CGRect={CGPoint}{CGSize}}") into a complete Objective-C runtime type encoding
/// string suitable for `NSGetSizeAndAlignment` and `NSValue` (e.g. @"{CGSize=dd}").
///
/// - Parameter typeEncoding: A struct type encoding string beginning with `{`.
/// - Returns: The resolved runtime type encoding string.
+ (NSString *)runtimeTypeEncodingForStructTypeEncoding:(NSString *)typeEncoding;

@end

NS_ASSUME_NONNULL_END
