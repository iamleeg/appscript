// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBoxer.m — Automatic boxing and unboxing of Objective-C method arguments and return values
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

#import "ASBoxer.h"
#import "ASNull.h"
#import "ASOutObject.h"
#import "ASStructValue.h"
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Skips past any Objective-C type qualifier characters (const, in, out, etc.)
/// that may prefix a type encoding string, returning a pointer to the base type character.
static const char *ASSkipTypeQualifiers(const char *typeEncoding) {
    // Qualifier characters defined by the ObjC runtime: r=const, n=in, N=inout, o=out, O=bycopy, R=byref, V=oneway
    while (typeEncoding && (*typeEncoding == 'r' || *typeEncoding == 'n' ||
                            *typeEncoding == 'N' || *typeEncoding == 'o' ||
                            *typeEncoding == 'O' || *typeEncoding == 'R' ||
                            *typeEncoding == 'V')) {
        typeEncoding++;
    }
    return typeEncoding;
}

/// Returns YES if `pointee` (the encoding after a `^`, qualifiers already skipped) is a scalar or
/// struct that a pointer out-parameter can carry. `^@` is handled separately as an object
/// out-parameter, and `^v`, `^?`, `^*`, `^^` and unions stay opaque pointers.
static BOOL ASIsBridgedOutPointee(const char *pointee) {
    if (!pointee) {
        return NO;
    }
    switch (pointee[0]) {
        case 'B': case 'c': case 'C': case 's': case 'S': case 'i': case 'I':
        case 'l': case 'L': case 'q': case 'Q': case 'f': case 'd':
        case '{':
            return YES;
        default:
            return NO;
    }
}

/// Returns a boxed id for a raw buffer `bytes` of size `size` described by `typeEncoding`.
/// This function is shared between the argument and return-value boxing paths.
static id _Nullable ASBoxBytes(const void *bytes, const char *typeEncoding) {
    typeEncoding = ASSkipTypeQualifiers(typeEncoding);
    if (!typeEncoding || typeEncoding[0] == '\0') {
        return nil;
    }

    switch (typeEncoding[0]) {
        case '@': {
            // Object pointer — the bytes hold a raw id (not retained here; ARC handles it).
            id __unsafe_unretained obj = nil;
            memcpy(&obj, bytes, sizeof(id));
            return obj;
        }
        case '#': {
            // Class — the bytes hold a Class pointer. Return it as id so AppScript code
            // can send messages to the class object (e.g. [cls description], [cls new]).
            Class __unsafe_unretained cls = Nil;
            memcpy(&cls, bytes, sizeof(Class));
            return cls;
        }
        case ':': {
            // SEL — AppScript represents selectors as strings (e.g. @"objectAtIndex:").
            // A NULL selector boxes to nil.
            SEL sel = NULL;
            memcpy(&sel, bytes, sizeof(SEL));
            return sel ? NSStringFromSelector(sel) : nil;
        }
        case 'B': {
            // BOOL (modern ObjC: _Bool, 1 byte)
            BOOL value = NO;
            memcpy(&value, bytes, sizeof(BOOL));
            return [NSNumber numberWithBool:value];
        }
        case 'c': {
            // char — treat as BOOL for boxing purposes (common usage in ObjC)
            signed char value = 0;
            memcpy(&value, bytes, sizeof(signed char));
            return [NSNumber numberWithBool:(BOOL)value];
        }
        case 'C': {
            unsigned char value = 0;
            memcpy(&value, bytes, sizeof(unsigned char));
            return [NSNumber numberWithUnsignedChar:value];
        }
        case 's': {
            short value = 0;
            memcpy(&value, bytes, sizeof(short));
            return [NSNumber numberWithShort:value];
        }
        case 'S': {
            unsigned short value = 0;
            memcpy(&value, bytes, sizeof(unsigned short));
            return [NSNumber numberWithUnsignedShort:value];
        }
        case 'i': {
            int value = 0;
            memcpy(&value, bytes, sizeof(int));
            return [NSNumber numberWithInt:value];
        }
        case 'l': {
            long value = 0;
            memcpy(&value, bytes, sizeof(long));
            return [NSNumber numberWithLong:value];
        }
        case 'q': {
            long long value = 0;
            memcpy(&value, bytes, sizeof(long long));
            return [NSNumber numberWithLongLong:value];
        }
        case 'I': {
            unsigned int value = 0;
            memcpy(&value, bytes, sizeof(unsigned int));
            return [NSNumber numberWithUnsignedInt:value];
        }
        case 'L': {
            unsigned long value = 0;
            memcpy(&value, bytes, sizeof(unsigned long));
            return [NSNumber numberWithUnsignedLong:value];
        }
        case 'Q': {
            unsigned long long value = 0;
            memcpy(&value, bytes, sizeof(unsigned long long));
            return [NSNumber numberWithUnsignedLongLong:value];
        }
        case 'f': {
            float value = 0.0f;
            memcpy(&value, bytes, sizeof(float));
            return [NSNumber numberWithFloat:value];
        }
        case 'd': {
            double value = 0.0;
            memcpy(&value, bytes, sizeof(double));
            return [NSNumber numberWithDouble:value];
        }
        case '*': {
            // const char * — the bytes hold a pointer to a C string
            const char *ptr = NULL;
            memcpy(&ptr, bytes, sizeof(const char *));
            if (!ptr) {
                return nil;
            }
            return [NSString stringWithUTF8String:ptr];
        }
        case 'v': {
            return [NSNull null];
        }
        case '^': {
            // Pointer type — check if it is a pointer to an Objective-C object (^@, e.g. NSError **).
            // Always return an ASOutObject (even when ptr == NULL) so that AppScript code can
            // unconditionally send `[outError setValue:...]` or forward `outError` to another
            // Cocoa method without needing a nil check. When ptr == NULL, writeBackObject:...
            // simply discards the stored value.
            const char *pointedType = ASSkipTypeQualifiers(typeEncoding + 1);
            if (pointedType && pointedType[0] == '@') {
                id __autoreleasing *ptr = NULL;
                memcpy(&ptr, bytes, sizeof(id *));
                id initialValue = (ptr != NULL) ? *ptr : nil;
                return [[ASOutObject alloc] initWithValue:initialValue];
            }
            return [NSValue valueWithBytes:bytes objCType:typeEncoding];
        }
        case '{': {
            // Struct — always box into ASStructValue using the canonical struct name
            // and resolved runtime type encoding.
            NSString *typeEncodingString = @(typeEncoding);
            NSString *canonicalName = nil;
            const char *p = typeEncoding + 1; // skip '{'
            const char *nameStart = p;
            while (*p && *p != '=' && *p != '}') { p++; }
            if (p > nameStart) {
                NSString *rawName = [[NSString alloc] initWithBytes:nameStart
                                                             length:(NSUInteger)(p - nameStart)
                                                           encoding:NSUTF8StringEncoding];
                canonicalName = [ASStructValue canonicalNameForImportedStructName:rawName];
            }
            NSString *runtimeEnc = [ASStructValue runtimeTypeEncodingForStructTypeEncoding:typeEncodingString];
            if ([runtimeEnc containsString:@"="]) {
                NSUInteger structSize = 0;
                NSGetSizeAndAlignment(runtimeEnc.UTF8String, &structSize, NULL);
                if (structSize > 0) {
                    return [[ASStructValue alloc] initWithBytes:bytes
                                                        length:structSize
                                                  canonicalName:canonicalName ?: runtimeEnc
                                            runtimeTypeEncoding:runtimeEnc];
                }
            }
            return nil;
        }
        default: {
            // Unknown type — make a best-effort NSValue wrapping with the given type encoding
            return [NSValue valueWithBytes:bytes objCType:typeEncoding];
        }
    }
}

/// Unboxes `object` into `outBytes` (of size `outSize`) according to `typeEncoding`.
/// Returns YES if the unboxing succeeded.
static BOOL ASUnboxIntoBytes(id _Nullable object,
                             void *outBytes,
                             NSUInteger outSize,
                             const char *typeEncoding) {
    typeEncoding = ASSkipTypeQualifiers(typeEncoding);
    if (!typeEncoding || typeEncoding[0] == '\0') {
        return NO;
    }

    if ([object isKindOfClass:[ASNull class]] || [object isKindOfClass:[NSNull class]]) {
        object = nil;
    }

    // Reject objects the C type does not accept (ARCHITECTURE.md, "Conversion failures")
    // before any accessor is sent, so nothing is silently zeroed or reinterpreted.
    switch (typeEncoding[0]) {
        case 'B': case 'c': case 'C': case 's': case 'S': case 'i': case 'I':
        case 'l': case 'L': case 'q': case 'Q': case 'f': case 'd':
            // Scalars accept only NSNumber; nil has no scalar equivalent.
            if (![object isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            break;
        case '#':
            // Class accepts class objects (whose class is a metaclass) or nil.
            if (object != nil && !class_isMetaClass(object_getClass(object))) {
                return NO;
            }
            break;
        case '*':
            if (object != nil && ![object isKindOfClass:[NSString class]]) {
                return NO;
            }
            break;
        default:
            break;
    }

    switch (typeEncoding[0]) {
        case '@': {
            // Convert the AppScript nil sentinel ([ASNull null]) to ObjC nil at the boundary.
            id __unsafe_unretained obj = object;
            memcpy(outBytes, &obj, sizeof(id));
            return YES;
        }
        case '#': {
            // Class pointer — same layout as id, pass through directly.
            Class __unsafe_unretained cls = object;
            memcpy(outBytes, &cls, sizeof(Class));
            return YES;
        }
        case ':': {
            // SEL — AppScript passes selectors as strings; nil becomes a NULL selector.
            // Any other object is rejected rather than reinterpreted as SEL bytes.
            SEL sel = NULL;
            if (object != nil) {
                if (![object isKindOfClass:[NSString class]]) {
                    return NO;
                }
                sel = NSSelectorFromString((NSString *)object);
            }
            memcpy(outBytes, &sel, sizeof(SEL));
            return YES;
        }
        case 'B': {
            BOOL value = [object boolValue];
            memcpy(outBytes, &value, sizeof(BOOL));
            return YES;
        }
        case 'c': {
            // Treat char as BOOL
            signed char value = (signed char)[object boolValue];
            memcpy(outBytes, &value, sizeof(signed char));
            return YES;
        }
        case 'C': {
            unsigned char value = [object unsignedCharValue];
            memcpy(outBytes, &value, sizeof(unsigned char));
            return YES;
        }
        case 's': {
            short value = [object shortValue];
            memcpy(outBytes, &value, sizeof(short));
            return YES;
        }
        case 'S': {
            unsigned short value = [object unsignedShortValue];
            memcpy(outBytes, &value, sizeof(unsigned short));
            return YES;
        }
        case 'i': {
            int value = [object intValue];
            memcpy(outBytes, &value, sizeof(int));
            return YES;
        }
        case 'l': {
            long value = [object longValue];
            memcpy(outBytes, &value, sizeof(long));
            return YES;
        }
        case 'q': {
            long long value = [object longLongValue];
            memcpy(outBytes, &value, sizeof(long long));
            return YES;
        }
        case 'I': {
            unsigned int value = [object unsignedIntValue];
            memcpy(outBytes, &value, sizeof(unsigned int));
            return YES;
        }
        case 'L': {
            unsigned long value = [object unsignedLongValue];
            memcpy(outBytes, &value, sizeof(unsigned long));
            return YES;
        }
        case 'Q': {
            unsigned long long value = [object unsignedLongLongValue];
            memcpy(outBytes, &value, sizeof(unsigned long long));
            return YES;
        }
        case 'f': {
            float value = [object floatValue];
            memcpy(outBytes, &value, sizeof(float));
            return YES;
        }
        case 'd': {
            double value = [object doubleValue];
            memcpy(outBytes, &value, sizeof(double));
            return YES;
        }
        case '*': {
            // NSString → const char *; nil → NULL.
            const char *ptr = object ? [(NSString *)object UTF8String] : NULL;
            memcpy(outBytes, &ptr, sizeof(const char *));
            return YES;
        }
        case 'v': {
            // void — nothing to write
            return YES;
        }
        case '^': {
            if (object == nil) {
                void *nullPtr = NULL;
                memcpy(outBytes, &nullPtr, sizeof(void *));
                return YES;
            }
            if ([object isKindOfClass:[NSValue class]]) {
                [object getValue:outBytes];
                return YES;
            }
            return NO;
        }
        case '{': {
            // ASStructValue or NSValue containing a struct — verify the byte length matches outSize.
            if (outSize == 0) {
                return NO;
            }
            if ([object isKindOfClass:[ASStructValue class]]) {
                ASStructValue *sv = (ASStructValue *)object;
                if (sv.bytes.length != outSize) {
                    return NO;
                }
                memcpy(outBytes, sv.bytes.bytes, outSize);
                return YES;
            } else if ([object isKindOfClass:[NSValue class]]) {
                NSValue *nsv = (NSValue *)object;
                const char *valType = nsv.objCType;
                NSUInteger valSize = 0;
                if (valType && strchr(valType, '=') != NULL) {
                    NSGetSizeAndAlignment(valType, &valSize, NULL);
                }
                if (valSize != outSize) {
                    return NO;
                }
                [nsv getValue:outBytes];
                return YES;
            }
            return NO;
        }
        default: {
            if ([object isKindOfClass:[ASStructValue class]]) {
                ASStructValue *sv = (ASStructValue *)object;
                if (outSize > 0 && sv.bytes.length != outSize) {
                    return NO;
                }
                memcpy(outBytes, sv.bytes.bytes, sv.bytes.length);
                return YES;
            } else if ([object isKindOfClass:[NSValue class]]) {
                [object getValue:outBytes];
                return YES;
            }
            return NO;
        }
    }
}

// ---------------------------------------------------------------------------
// ASBoxer
// ---------------------------------------------------------------------------

@implementation ASBoxer

+ (nullable id)boxedObjectFromBytes:(const void *)bytes
                       typeEncoding:(const char *)typeEncoding {
    if (!bytes && typeEncoding && typeEncoding[0] != 'v') {
        return nil;
    }
    return ASBoxBytes(bytes, typeEncoding);
}

+ (BOOL)unboxObject:(nullable id)object
          intoBytes:(void *)outBytes
             ofSize:(NSUInteger)size
       typeEncoding:(const char *)typeEncoding {
    if (!outBytes && typeEncoding && typeEncoding[0] != 'v') {
        return NO;
    }
    return ASUnboxIntoBytes(object, outBytes, size, typeEncoding);
}

+ (nullable id)boxedArgumentAtIndex:(NSUInteger)argumentIndex
                     fromInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    NSUInteger invIndex = argumentIndex + 2; // skip self (0) and _cmd (1)
    const char *typeEncoding = [sig getArgumentTypeAtIndex:invIndex];

    // A pointer to a scalar or struct (`NSInteger *`, `double *`, `NSRange *`) becomes an ASOutObject
    // seeded from the pointee, so a script can read it and write it back. This applies to
    // arguments only: a pointer *returned* by a method stays an opaque NSValue.
    NSString *pointee = [self pointeeTypeEncodingOfOutParameterAtIndex:argumentIndex inSignature:sig];
    if (pointee != nil) {
        void *pointer = NULL;
        [invocation getArgument:&pointer atIndex:(NSInteger)invIndex];
        id initialValue = (pointer != NULL) ? ASBoxBytes(pointer, pointee.UTF8String) : nil;
        return [[ASOutObject alloc] initWithValue:initialValue pointeeTypeEncoding:pointee];
    }

    NSUInteger argSize = 0;
    NSGetSizeAndAlignment(typeEncoding, &argSize, NULL);
    if (argSize == 0) {
        return nil;
    }

    void *buffer = alloca(argSize);
    memset(buffer, 0, argSize);
    [invocation getArgument:buffer atIndex:(NSInteger)invIndex];

    return ASBoxBytes(buffer, typeEncoding);
}

+ (BOOL)isObjectOutParameterAtIndex:(NSUInteger)argumentIndex
                        inSignature:(NSMethodSignature *)signature {
    NSUInteger invIndex = argumentIndex + 2;
    if (invIndex >= signature.numberOfArguments) {
        return NO;
    }
    const char *typeEncoding = ASSkipTypeQualifiers([signature getArgumentTypeAtIndex:invIndex]);
    if (!typeEncoding || typeEncoding[0] != '^') {
        return NO;
    }
    const char *pointedType = ASSkipTypeQualifiers(typeEncoding + 1);
    return (pointedType != NULL && pointedType[0] == '@');
}

+ (BOOL)isOutParameterAtIndex:(NSUInteger)argumentIndex
                  inSignature:(NSMethodSignature *)signature {
    return [self isObjectOutParameterAtIndex:argumentIndex inSignature:signature] ||
           [self pointeeTypeEncodingOfOutParameterAtIndex:argumentIndex inSignature:signature] != nil;
}

+ (nullable NSString *)pointeeTypeEncodingOfOutParameterAtIndex:(NSUInteger)argumentIndex
                                                      inSignature:(NSMethodSignature *)signature {
    NSUInteger invIndex = argumentIndex + 2;
    if (invIndex >= signature.numberOfArguments) {
        return nil;
    }
    const char *typeEncoding = ASSkipTypeQualifiers([signature getArgumentTypeAtIndex:invIndex]);
    if (!typeEncoding || typeEncoding[0] != '^') {
        return nil;
    }
    const char *pointee = ASSkipTypeQualifiers(typeEncoding + 1);
    return ASIsBridgedOutPointee(pointee) ? @(pointee) : nil;
}

+ (BOOL)writeBackObject:(nullable id)object
        atArgumentIndex:(NSUInteger)argumentIndex
           toInvocation:(NSInvocation *)invocation {
    if (![object isKindOfClass:[ASOutObject class]]) {
        return YES;
    }
    NSMethodSignature *sig = invocation.methodSignature;
    NSString *pointee = [self pointeeTypeEncodingOfOutParameterAtIndex:argumentIndex inSignature:sig];
    if (pointee != nil) {
        // Scalar or struct out-parameter: unbox into a scratch buffer with the strict conversion
        // rules (ADR 11), and store it only if that succeeds, so a failure leaves *ptr alone.
        void *pointer = NULL;
        [invocation getArgument:&pointer atIndex:(NSInteger)(argumentIndex + 2)];
        if (pointer == NULL) {
            return YES;
        }
        NSUInteger size = 0;
        NSGetSizeAndAlignment(pointee.UTF8String, &size, NULL);
        if (size == 0) {
            return NO;
        }
        void *buffer = alloca(size);
        memset(buffer, 0, size);
        if (!ASUnboxIntoBytes(((ASOutObject *)object).value, buffer, size, pointee.UTF8String)) {
            return NO;
        }
        memcpy(pointer, buffer, size);
        return YES;
    }
    if (![self isObjectOutParameterAtIndex:argumentIndex inSignature:sig]) {
        return YES;
    }
    NSUInteger invIndex = argumentIndex + 2;
    id __autoreleasing *ptr = NULL;
    [invocation getArgument:&ptr atIndex:(NSInteger)invIndex];
    if (ptr != NULL) {
        ASOutObject *outObj = (ASOutObject *)object;
        id val = outObj.value;
        if ([val isKindOfClass:[ASNull class]]) {
            val = nil;
        }
        *ptr = val;
    }
    return YES;
}

+ (BOOL)unboxObject:(nullable id)object
intoArgumentAtIndex:(NSUInteger)argumentIndex
       ofInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    NSUInteger invIndex = argumentIndex + 2;
    const char *typeEncoding = [sig getArgumentTypeAtIndex:invIndex];

    NSUInteger argSize = 0;
    NSGetSizeAndAlignment(typeEncoding, &argSize, NULL);
    if (argSize == 0) {
        return YES;
    }

    void *buffer = alloca(argSize);
    memset(buffer, 0, argSize);

    if (!ASUnboxIntoBytes(object, buffer, argSize, typeEncoding)) {
        return NO;
    }
    [invocation setArgument:buffer atIndex:(NSInteger)invIndex];
    return YES;
}

+ (nullable id)boxedReturnValueFromInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    const char *typeEncoding = sig.methodReturnType;

    if (!typeEncoding || typeEncoding[0] == 'v') {
        return nil;
    }

    NSUInteger retSize = sig.methodReturnLength;
    if (retSize == 0) {
        return nil;
    }

    void *buffer = alloca(retSize);
    memset(buffer, 0, retSize);
    [invocation getReturnValue:buffer];

    return ASBoxBytes(buffer, typeEncoding);
}

+ (BOOL)unboxObject:(nullable id)object
intoReturnValueOfInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    const char *typeEncoding = sig.methodReturnType;

    if (!typeEncoding || typeEncoding[0] == 'v') {
        return YES;
    }

    NSUInteger retSize = sig.methodReturnLength;
    if (retSize == 0) {
        return YES;
    }

    void *buffer = alloca(retSize);
    memset(buffer, 0, retSize);

    if (!ASUnboxIntoBytes(object, buffer, retSize, typeEncoding)) {
        return NO;
    }
    [invocation setReturnValue:buffer];
    return YES;
}

+ (NSString *)displayNameForTypeEncoding:(const char *)typeEncoding {
    const char *enc = ASSkipTypeQualifiers(typeEncoding);
    if (!enc || enc[0] == '\0') {
        return @"";
    }
    switch (enc[0]) {
        case '@': return @"id";
        case '#': return @"Class";
        case ':': return @"SEL";
        case 'B': return @"BOOL";
        case 'c': return @"char";
        case 'C': return @"unsigned char";
        case 's': return @"short";
        case 'S': return @"unsigned short";
        case 'i': return @"int";
        case 'I': return @"unsigned int";
        case 'l': return @"long";
        case 'L': return @"unsigned long";
        case 'q': return @"long long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case '*': return @"char *";
        case '^': return @"pointer";
        case 'v': return @"void";
        case '{': {
            // {_NSRange=QQ} -> NSRange: the tag runs to '=' or '}'; drop leading underscores.
            const char *start = enc + 1;
            while (*start == '_') {
                start++;
            }
            const char *end = start;
            while (*end && *end != '=' && *end != '}') {
                end++;
            }
            if (end > start) {
                return [[NSString alloc] initWithBytes:start
                                                length:(NSUInteger)(end - start)
                                              encoding:NSUTF8StringEncoding];
            }
            return @(typeEncoding);
        }
        default:
            return @(typeEncoding);
    }
}

@end
