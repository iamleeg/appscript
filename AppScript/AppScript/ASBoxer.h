// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBoxer.h — Automatic boxing and unboxing of Objective-C method arguments and return values
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

/// A utility class that boxes C primitive values into Objective-C objects and unboxes them back.
///
/// `ASBoxer` works with `NSInvocation` and `NSMethodSignature` type encoding strings to
/// convert between C primitives and their `NSObject` representations (e.g. `NSNumber`,
/// `NSString`, `NSValue`). All methods are class methods; instances cannot be created.
@interface ASBoxer : NSObject

/// Unavailable.
///
/// You can't instantiate `NSBoxer`; use its class methods only.
- (instancetype)init NS_UNAVAILABLE;

/// Boxes the value in the given NSInvocation argument at the given index into an Objective-C object.
///
/// Uses the argument's type encoding from the invocation's `methodSignature` to determine the
/// correct boxing strategy. Supported type encodings: `@` (id), `^@` (id *, e.g. `NSError **`,
/// boxed as `ASOutObject`), a pointer to a scalar or struct argument (`^q`, `^d`, `^B`, `^{...}`,
/// boxed as an `ASOutObject` seeded from the pointee), `B` (BOOL), `c` (char / BOOL),
/// `i` (int), `l` (long), `q` (long long), `I` (unsigned int), `L` (unsigned long),
/// `Q` (unsigned long long), `f` (float), `d` (double), `*` (C string), `v` (void, returns
/// `NSNull`). For unknown or struct types, returns an `NSValue` wrapping the raw bytes.
///
/// - Parameters:
///   - argumentIndex: Zero-based index into the method's logical argument list (excludes the
///     hidden `self` and `_cmd` arguments). Maps to `NSInvocation` index `argumentIndex + 2`.
///   - invocation: The invocation whose argument should be read and boxed.
/// - Returns: An Objective-C object representing the argument value, or `nil` if boxing is
///   not possible for the given encoding.
+ (nullable id)boxedArgumentAtIndex:(NSUInteger)argumentIndex
                     fromInvocation:(NSInvocation *)invocation;

/// Writes back the value of an `ASOutObject` into an out-parameter of an `NSInvocation` after an
/// AppScript method finishes executing: an object (`^@`, such as `NSError **`), a scalar (`^q`, `^d`, ...)
/// or a struct (`^{...}`).
///
/// If the argument at `argumentIndex` is not a bridged out-parameter, if the caller passed a
/// `NULL` pointer, or if `object` is not an `ASOutObject`, this method does nothing and returns `YES`.
/// For a scalar or struct the value is unboxed with the strict conversion rules (an `NSNumber` for a
/// scalar, an `ASStructValue` or `NSValue` for a struct) and stored only if the conversion succeeds.
///
/// - Parameters:
///   - object: The boxed argument object (expected to be an `ASOutObject` for `^@` arguments).
///   - argumentIndex: Zero-based index into the method's logical argument list. Maps to
///     `NSInvocation` index `argumentIndex + 2`.
///   - invocation: The invocation whose out-parameter pointer should be updated.
/// - Returns: `YES` if nothing needed writing or the write succeeded; `NO` if the value could not be converted to the pointee type, in which case the caller's variable is left unchanged.
+ (BOOL)writeBackObject:(nullable id)object
        atArgumentIndex:(NSUInteger)argumentIndex
           toInvocation:(NSInvocation *)invocation;

/// Returns whether the argument at the given logical index in the signature is an out-parameter
/// the runtime bridges: an object pointer (`^@`), or a pointer to a scalar (`c C s S i I l L q Q f d B`)
/// or to a struct (`^{...}`).
///
/// - Parameters:
///   - argumentIndex: Zero-based index into the method's logical argument list.
///   - signature: The method signature to inspect.
/// - Returns: `YES` for a bridged out-parameter; `NO` for anything else, including `^v`, `^?`, `^*` and pointers to pointers other than `^@`.
+ (BOOL)isOutParameterAtIndex:(NSUInteger)argumentIndex
                  inSignature:(NSMethodSignature *)signature;

/// Returns the type encoding of the scalar or struct a pointer argument points to.
///
/// - Parameters:
///   - argumentIndex: Zero-based index into the method's logical argument list.
///   - signature: The method signature to inspect.
/// - Returns: The pointee's encoding (such as `q` or `{_NSRange=QQ}`) for a scalar or struct out-parameter; `nil` for an object out-parameter (`^@`) or any other argument.
+ (nullable NSString *)pointeeTypeEncodingOfOutParameterAtIndex:(NSUInteger)argumentIndex
                                                      inSignature:(NSMethodSignature *)signature;

/// Returns the pointee encoding of a pointer type the runtime bridges as an out-parameter (a pointer
/// to a scalar or struct, such as `^d` or `^{CGRect=...}`), or `nil` for any other type.
///
/// - Parameter typeEncoding: A type encoding, which may start with qualifiers.
/// - Returns: The pointee's encoding, or `nil`.
+ (nullable NSString *)bridgedPointeeTypeEncodingForPointerEncoding:(const char *)typeEncoding;

/// Prepares the scratch buffer for a scalar or struct out-parameter: zeroes it, then converts the
/// out-object's value into it with the strict rules (ADR 11) if it has one.
///
/// Used for method sends, C function calls and block calls alike.
///
/// - Parameters:
///   - buffer: At least `size` bytes.
///   - size: The pointee's size.
///   - outObject: The `ASOutObject` the script passed (its value seeds the buffer).
///   - pointee: The pointee's type encoding.
/// - Returns: `NO` if the value can't be converted to the pointee type.
+ (BOOL)prepareOutBuffer:(void *)buffer
                    size:(NSUInteger)size
            forOutObject:(id)outObject
                 pointee:(NSString *)pointee;

/// Stores what a callee wrote to an out-parameter buffer back into the script's `ASOutObject`:
/// sets its value to the boxed pointee and its `pointeeTypeEncoding`.
///
/// - Parameters:
///   - buffer: The buffer passed for the out-parameter.
///   - outObject: The `ASOutObject` the script passed.
///   - pointee: The pointee's type encoding.
+ (void)writeOutBuffer:(const void *)buffer
           toOutObject:(id)outObject
               pointee:(NSString *)pointee;

/// Returns whether the argument at the given logical index in the signature is an object
/// out-parameter (`^@`, e.g. `NSError **`).
///
/// - Parameters:
///   - argumentIndex: Zero-based index into the method's logical argument list.
///   - signature: The method signature to inspect.
/// - Returns: `YES` if the argument's stripped type encoding starts with `^@`; `NO` otherwise.
+ (BOOL)isObjectOutParameterAtIndex:(NSUInteger)argumentIndex
                        inSignature:(NSMethodSignature *)signature;

/// Unboxes an Objective-C object into the argument slot at the given index of an NSInvocation.
///
/// Uses the argument's type encoding from the invocation's `methodSignature` to determine how
/// to convert the object. Supported conversions: `id` passes through directly; `NSNumber` is
/// used to extract `BOOL`, `int`, `long`, `long long`, `unsigned int`, `unsigned long`,
/// `unsigned long long`, `float`, or `double`; `NSString` is converted to a C string via
/// `UTF8String`; `NSValue` provides raw bytes for struct types.
///
/// - Parameters:
///   - object: The object to unbox. May be `nil`, which is accepted only for types with a natural
///     null (`id`, `Class`, `SEL`, `char *`, pointers) and rejected for scalars and structs.
///   - argumentIndex: Zero-based index into the method's logical argument list. Maps to
///     `NSInvocation` index `argumentIndex + 2`.
///   - invocation: The invocation whose argument slot should be written.
/// - Returns: `YES` if the object was converted and written; `NO` if it cannot be converted to the
///   argument's type, in which case the argument slot is left unchanged.
+ (BOOL)unboxObject:(nullable id)object
intoArgumentAtIndex:(NSUInteger)argumentIndex
       ofInvocation:(NSInvocation *)invocation;

/// Boxes the return value of an NSInvocation into an Objective-C object.
///
/// If the return type encoding is `v` (void), returns `nil`. For `@` (id), returns the object
/// directly. For primitive types, boxes using the same rules as
/// `boxedArgumentAtIndex:fromInvocation:`.
///
/// - Parameter invocation: An already-invoked `NSInvocation` whose return value should be read.
/// - Returns: An Objective-C object representing the return value, or `nil` for void returns.
+ (nullable id)boxedReturnValueFromInvocation:(NSInvocation *)invocation;

/// Unboxes an Objective-C object and sets it as the return value of an NSInvocation.
///
/// If the return type encoding is `v` (void), does nothing. For `@` (id), sets the object
/// directly. For primitive types, unboxes using the same rules as
/// `unboxObject:intoArgumentAtIndex:ofInvocation:`.
///
/// - Parameters:
///   - object: The object to unbox and set as the invocation's return value. May be `nil`.
///   - invocation: The invocation whose return value slot should be written.
/// - Returns: `YES` if the object was converted and written (or the return type is void); `NO` if
///   it cannot be converted to the return type, in which case the return value is left unchanged.
+ (BOOL)unboxObject:(nullable id)object
intoReturnValueOfInvocation:(NSInvocation *)invocation;

/// How a method hands back the object it returns, by the Objective-C naming convention.
typedef NS_ENUM(NSInteger, ASReturnOwnership) {
    /// The result is not owned by the caller (+0): ordinary selectors, `autorelease`d results.
    ASReturnOwnershipNone = 0,
    /// The selector is in the `alloc`, `new`, `copy` or `mutableCopy` family: the result is owned (+1).
    ASReturnOwnershipRetained,
    /// The selector is in the `init` family: the method consumes `self` and its result is owned (+1).
    ASReturnOwnershipInitFamily,
};

/// Returns the ownership convention for the object a method named `selector` returns.
///
/// This is the rule the Objective-C compiler applies to every method that has no ownership
/// annotation: ignoring leading underscores, a selector is in a family when it begins with
/// `alloc`, `new`, `copy`, `mutableCopy` or `init` and the next character is not a lowercase
/// letter (so `copyWithZone:` and `initWithURL:` qualify, `copying` and `initialize` don't).
///
/// - Parameter selector: The selector of the method that was invoked.
/// - Returns: The ownership convention for the method's returned object.
+ (ASReturnOwnership)returnOwnershipForSelector:(SEL)selector;

/// Returns a human-readable name for an Objective-C type encoding, for use in error messages.
///
/// Type qualifiers are ignored. Common scalar encodings map to their C names (`double`, `BOOL`,
/// `unsigned long long`, …), `@` to `id`, `#` to `Class`, `:` to `SEL`, and `^` to `pointer`.
/// Struct encodings map to the struct's tag with any leading underscores removed
/// (`{_NSRange=QQ}` becomes `NSRange`). Unrecognised encodings are returned unchanged.
///
/// - Parameter typeEncoding: An Objective-C runtime or BridgeSupport type encoding C string.
/// - Returns: The display name.
+ (NSString *)displayNameForTypeEncoding:(const char *)typeEncoding;

/// Returns the size of a type, or 0 when Foundation can't determine it.
///
/// `NSGetSizeAndAlignment` raises `NSInvalidArgumentException` for encodings it doesn't support:
/// unions, and structs with bitfield (`b`), `_Atomic` (`A`) or `_Complex` (`j`) members. Apple's
/// bitfield encoding drops the declared type, so such a size can't be computed by other means
/// either. Every size the runtime takes goes through this method.
///
/// - Parameter typeEncoding: A type encoding.
/// - Returns: The size in bytes, or 0 if it can't be determined.
+ (NSUInteger)sizeOfTypeEncoding:(const char *)typeEncoding;

/// Like `+sizeOfTypeEncoding:`, and also returns the type's alignment (0 when unknown).
///
/// - Parameters:
///   - typeEncoding: A type encoding.
///   - alignment: If not NULL, set to the alignment in bytes, or 0.
/// - Returns: The size in bytes, or 0 if it can't be determined.
+ (NSUInteger)sizeOfTypeEncoding:(const char *)typeEncoding alignment:(nullable NSUInteger *)alignment;

/// Boxes the raw value in `bytes` into an Objective-C object according to `typeEncoding`.
///
/// Struct encodings (`{...}`) are boxed into `ASStructValue` instances.
///
/// - Parameters:
///   - bytes: Pointer to the raw value buffer.
///   - typeEncoding: Objective-C runtime or BridgeSupport type encoding C string.
/// - Returns: The boxed Objective-C object, or `nil` if boxing is not possible.
+ (nullable id)boxedObjectFromBytes:(const void *)bytes
                       typeEncoding:(const char *)typeEncoding;

/// Unboxes `object` into the caller-supplied buffer `outBytes` of `size` bytes according
/// to `typeEncoding`.
///
/// Accepts both `ASStructValue` and `NSValue` when `typeEncoding` is a struct (`{...}`),
/// verifying that the source struct's byte length matches `size`. Scalars accept only
/// `NSNumber`, `char *` and `SEL` only `NSString`, and `Class` only class objects; `nil` is
/// rejected for scalars and structs (see ARCHITECTURE.md, "Conversion failures").
///
/// - Parameters:
///   - object: The Objective-C object to unbox.
///   - outBytes: Destination buffer of at least `size` bytes.
///   - size: Size in bytes of the destination buffer.
///   - typeEncoding: Objective-C runtime or BridgeSupport type encoding C string.
/// - Returns: `YES` if unboxing succeeded; `NO` on type or size mismatch.
+ (BOOL)unboxObject:(nullable id)object
          intoBytes:(void *)outBytes
             ofSize:(NSUInteger)size
       typeEncoding:(const char *)typeEncoding;

@end

NS_ASSUME_NONNULL_END
