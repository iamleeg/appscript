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

#import <AppScript/ASBoxer.h>
#import <AppScript/ASNull.h>
#import <AppScript/ASOutObject.h>
#import <AppScript/ASStructValue.h>
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Skips past any Objective-C type qualifier characters (const, in, out, etc.)
/// that may prefix a type encoding string, returning a pointer to the base type character.
static const char *ASSkipQualifierCharacters(const char *typeEncoding) {
    // Qualifier characters defined by the ObjC runtime: r=const, n=in, N=inout, o=out, O=bycopy, R=byref, V=oneway
    while (typeEncoding && (*typeEncoding == 'r' || *typeEncoding == 'n' ||
                            *typeEncoding == 'N' || *typeEncoding == 'o' ||
                            *typeEncoding == 'O' || *typeEncoding == 'R' ||
                            *typeEncoding == 'V')) {
        typeEncoding++;
    }
    return typeEncoding;
}

/// Skips qualifiers and `_Atomic` (`A`): an atomic scalar is converted like the type it wraps.
static const char *ASSkipTypeQualifiers(const char *typeEncoding) {
    typeEncoding = ASSkipQualifierCharacters(typeEncoding);
    while (typeEncoding && *typeEncoding == 'A') {
        typeEncoding = ASSkipQualifierCharacters(typeEncoding + 1);
    }
    return typeEncoding;
}

/// Returns YES for types that NSInvocation can't carry on Apple platforms: `-setArgument:atIndex:`
/// traps for `__int128`, which would kill the process, so the invocation paths report a conversion
/// failure for it instead.
static BOOL ASInvocationCannotCarry(const char *typeEncoding) {
    typeEncoding = ASSkipTypeQualifiers(typeEncoding);
    return typeEncoding && (typeEncoding[0] == 't' || typeEncoding[0] == 'T');
}

/// Returns the size of a union or other type encoding without letting Foundation's exception
/// escape: NSGetSizeAndAlignment raises for encodings it doesn't know. Returns 0 when unknown.
static NSUInteger ASSizeOfTypeEncoding(const char *typeEncoding) {
    NSUInteger size = 0;
    @try {
        NSGetSizeAndAlignment(typeEncoding, &size, NULL);
    } @catch (NSException *exception) {
        size = 0;
    }
    return size;
}

/// Returns YES if `pointee` (the encoding after a `^`, qualifiers already skipped) is a scalar or
/// struct that a pointer out-parameter can carry. `^@` is handled separately as an object
/// out-parameter, and `^v`, `^?`, `^*`, `^^` and unions stay opaque pointers.
/// Returns whether `object` is a block still on the stack (`__NSStackBlock__` on Apple platforms,
/// `_NSConcreteStackBlock` on GNUstep), which retaining doesn't keep alive.
static BOOL ASIsStackBlock(id object) {
    static Class stackBlockClass = Nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stackBlockClass = objc_lookUpClass("__NSStackBlock__") ?: objc_lookUpClass("_NSConcreteStackBlock");
    });
    return stackBlockClass != Nil && object_getClass(object) == stackBlockClass;
}

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
            // A block on the caller's stack (a native block passed to a script method) must be
            // copied before a script stores it, as ARC does for block parameters (asu-ugk).
            if (obj != nil && ASIsStackBlock(obj)) {
                return [obj copy];
            }
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
            signed char value = 0;
            memcpy(&value, bytes, sizeof(signed char));
#if defined(OBJC_BOOL_IS_BOOL) && OBJC_BOOL_IS_BOOL
            // BOOL is _Bool here (arm64 Apple platforms), so `c` is always a real char.
            return [NSNumber numberWithChar:value];
#else
            // BOOL is a signed char here (x86_64 macOS, GNUstep), so `c` may be a BOOL.
            return [NSNumber numberWithBool:(BOOL)value];
#endif
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
        case 'D': {
            // long double — boxed through double, so the extra precision of x86_64's 80-bit
            // format is lost (arm64's long double already is a double).
            long double value = 0.0L;
            memcpy(&value, bytes, sizeof(long double));
            return [NSNumber numberWithDouble:(double)value];
        }
#ifdef __SIZEOF_INT128__
        case 't': {
            // __int128 — a number when the value fits in a long long, otherwise an NSValue.
            __int128 value = 0;
            memcpy(&value, bytes, sizeof(value));
            if (value >= (__int128)LLONG_MIN && value <= (__int128)LLONG_MAX) {
                return [NSNumber numberWithLongLong:(long long)value];
            }
            return [NSValue valueWithBytes:bytes objCType:"t"];
        }
        case 'T': {
            unsigned __int128 value = 0;
            memcpy(&value, bytes, sizeof(value));
            if (value <= (unsigned __int128)ULLONG_MAX) {
                return [NSNumber numberWithUnsignedLongLong:(unsigned long long)value];
            }
            return [NSValue valueWithBytes:bytes objCType:"T"];
        }
#endif
        case 'j': {
            // _Complex — Foundation can't size it, so NSValue can't wrap it; there is no boxed form.
            return nil;
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
        case 'l': case 'L': case 'q': case 'Q': case 'f': case 'd': case 'D':
            // Scalars accept only NSNumber; nil has no scalar equivalent.
            if (![object isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            break;
        case 'j':
            // _Complex has no boxed form (NSValue can't wrap it), so nothing converts to it.
            return NO;
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
#if defined(OBJC_BOOL_IS_BOOL) && OBJC_BOOL_IS_BOOL
            signed char value = [object charValue];
#else
            // BOOL is a signed char here, so `c` may be a BOOL.
            signed char value = (signed char)[object boolValue];
#endif
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
        case 'D': {
            if (outSize != sizeof(long double)) {
                return NO;
            }
            long double value = (long double)[object doubleValue];
            memcpy(outBytes, &value, sizeof(long double));
            return YES;
        }
#ifdef __SIZEOF_INT128__
        case 't':
        case 'T': {
            // A number widens (signed for `t`, unsigned for `T`); a value that doesn't fit in 64
            // bits comes back as an NSValue of the same encoding. Nothing else converts.
            if (outSize != 16) {
                return NO;
            }
            if ([object isKindOfClass:[NSNumber class]]) {
                if (typeEncoding[0] == 't') {
                    __int128 value = (__int128)[(NSNumber *)object longLongValue];
                    memcpy(outBytes, &value, sizeof(value));
                } else {
                    unsigned __int128 value = (unsigned __int128)[(NSNumber *)object unsignedLongLongValue];
                    memcpy(outBytes, &value, sizeof(value));
                }
                return YES;
            }
            if ([object isKindOfClass:[NSValue class]] &&
                [(NSValue *)object objCType][0] == typeEncoding[0] &&
                ASSizeOfTypeEncoding([(NSValue *)object objCType]) == 16) {
                [object getValue:outBytes];
                return YES;
            }
            return NO;
        }
#endif
        case '(': {
            // Union — only an NSValue of the same encoding, or of another union of the same size.
            // An NSNumber is an NSValue but never a union.
            if (outSize == 0 || ![object isKindOfClass:[NSValue class]] ||
                [object isKindOfClass:[NSNumber class]]) {
                return NO;
            }
            const char *valueType = [(NSValue *)object objCType];
            if (valueType && (strcmp(valueType, typeEncoding) == 0 ||
                              (valueType[0] == '(' && ASSizeOfTypeEncoding(valueType) == outSize))) {
                [object getValue:outBytes];
                return YES;
            }
            return NO;
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
            // An NSNumber is an NSValue, but its bytes are not a pointer.
            if ([object isKindOfClass:[NSValue class]] && ![object isKindOfClass:[NSNumber class]]) {
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
            } else if ([object isKindOfClass:[NSValue class]] && ![object isKindOfClass:[NSNumber class]]) {
                // Any other NSValue, but not an NSNumber: its bytes would be reinterpreted.
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

+ (ASReturnOwnership)returnOwnershipForSelector:(SEL)selector {
    const char *name = sel_getName(selector);
    while (*name == '_') {
        name++;
    }
    static const struct {
        const char *prefix;
        ASReturnOwnership ownership;
    } families[] = {
        { "alloc", ASReturnOwnershipRetained },
        { "new", ASReturnOwnershipRetained },
        { "copy", ASReturnOwnershipRetained },
        { "mutableCopy", ASReturnOwnershipRetained },
        { "init", ASReturnOwnershipInitFamily },
    };
    for (size_t i = 0; i < sizeof(families) / sizeof(families[0]); i++) {
        size_t length = strlen(families[i].prefix);
        if (strncmp(name, families[i].prefix, length) == 0) {
            char next = name[length];
            if (next < 'a' || next > 'z') {
                return families[i].ownership;
            }
        }
    }
    return ASReturnOwnershipNone;
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
    return [self bridgedPointeeTypeEncodingForPointerEncoding:[signature getArgumentTypeAtIndex:invIndex]];
}

+ (nullable NSString *)bridgedPointeeTypeEncodingForPointerEncoding:(const char *)encoding {
    const char *typeEncoding = ASSkipTypeQualifiers(encoding);
    if (!typeEncoding || typeEncoding[0] != '^') {
        return nil;
    }
    const char *pointee = ASSkipTypeQualifiers(typeEncoding + 1);
    return ASIsBridgedOutPointee(pointee) ? @(pointee) : nil;
}

+ (BOOL)prepareOutBuffer:(void *)buffer
                    size:(NSUInteger)size
            forOutObject:(id)outObject
                 pointee:(NSString *)pointee {
    memset(buffer, 0, size);
    id seed = [outObject isKindOfClass:[ASOutObject class]] ? ((ASOutObject *)outObject).value : nil;
    if (seed == nil || [seed isKindOfClass:[ASNull class]]) {
        return YES;
    }
    return ASUnboxIntoBytes(seed, buffer, size, pointee.UTF8String);
}

+ (void)writeOutBuffer:(const void *)buffer
           toOutObject:(id)outObject
               pointee:(NSString *)pointee {
    if (![outObject isKindOfClass:[ASOutObject class]]) {
        return;
    }
    ASOutObject *out = (ASOutObject *)outObject;
    out.value = [self boxedObjectFromBytes:buffer typeEncoding:pointee.UTF8String];
    out.pointeeTypeEncoding = pointee;
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

    if (ASInvocationCannotCarry(typeEncoding)) {
        return NO;
    }

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

    if (ASInvocationCannotCarry(typeEncoding)) {
        return NO;
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
    const char *enc = ASSkipQualifierCharacters(typeEncoding);
    if (!enc || enc[0] == '\0') {
        return @"";
    }
    if (enc[0] == 'A') {
        return [NSString stringWithFormat:@"_Atomic %@", [self displayNameForTypeEncoding:enc + 1]];
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
        case 'D': return @"long double";
        case 't': return @"__int128";
        case 'T': return @"unsigned __int128";
        case 'j': {
            switch (enc[1]) {
                case 'f': return @"float _Complex";
                case 'd': return @"double _Complex";
                case 'D': return @"long double _Complex";
                default: return @(typeEncoding);
            }
        }
        case '(': {
            // (ASBoxerTestUnion=id) -> ASBoxerTestUnion: the tag runs to '=' or ')'.
            const char *start = enc + 1;
            while (*start == '_') {
                start++;
            }
            const char *end = start;
            while (*end && *end != '=' && *end != ')') {
                end++;
            }
            if (end > start && *start != '?') {
                return [[NSString alloc] initWithBytes:start
                                                length:(NSUInteger)(end - start)
                                              encoding:NSUTF8StringEncoding];
            }
            return @"union";
        }
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
