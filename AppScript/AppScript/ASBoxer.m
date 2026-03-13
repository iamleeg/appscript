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
        case '{': {
            // Struct — wrap in NSValue using the full type encoding string
            // NSMethodSignature returns the full encoding including size qualifiers, so pass
            // typeEncoding directly as the objCType.
            return [NSValue valueWithBytes:bytes objCType:typeEncoding];
        }
        default: {
            // Unknown type — make a best-effort NSValue wrapping with the given type encoding
            return [NSValue valueWithBytes:bytes objCType:typeEncoding];
        }
    }
}

/// Unboxes `object` into `outBytes` (of size `size`) according to `typeEncoding`.
/// Returns YES if the unboxing succeeded.
static BOOL ASUnboxIntoBytes(id _Nullable object, void *outBytes, const char *typeEncoding) {
    typeEncoding = ASSkipTypeQualifiers(typeEncoding);
    if (!typeEncoding || typeEncoding[0] == '\0') {
        return NO;
    }

    switch (typeEncoding[0]) {
        case '@': {
            // Pass the id through directly
            id __unsafe_unretained obj = object;
            memcpy(outBytes, &obj, sizeof(id));
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
            // NSString → const char *
            const char *ptr = [object UTF8String];
            memcpy(outBytes, &ptr, sizeof(const char *));
            return YES;
        }
        case 'v': {
            // void — nothing to write
            return YES;
        }
        case '{': {
            // NSValue containing a struct
            [object getValue:outBytes];
            return YES;
        }
        default: {
            if ([object isKindOfClass:[NSValue class]]) {
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

+ (nullable id)boxedArgumentAtIndex:(NSUInteger)argumentIndex
                     fromInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    NSUInteger invIndex = argumentIndex + 2; // skip self (0) and _cmd (1)
    const char *typeEncoding = [sig getArgumentTypeAtIndex:invIndex];

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

+ (void)unboxObject:(nullable id)object
intoArgumentAtIndex:(NSUInteger)argumentIndex
       ofInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    NSUInteger invIndex = argumentIndex + 2;
    const char *typeEncoding = [sig getArgumentTypeAtIndex:invIndex];

    NSUInteger argSize = 0;
    NSGetSizeAndAlignment(typeEncoding, &argSize, NULL);
    if (argSize == 0) {
        return;
    }

    void *buffer = alloca(argSize);
    memset(buffer, 0, argSize);

    if (ASUnboxIntoBytes(object, buffer, typeEncoding)) {
        [invocation setArgument:buffer atIndex:(NSInteger)invIndex];
    }
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

+ (void)unboxObject:(nullable id)object
intoReturnValueOfInvocation:(NSInvocation *)invocation {
    NSMethodSignature *sig = invocation.methodSignature;
    const char *typeEncoding = sig.methodReturnType;

    if (!typeEncoding || typeEncoding[0] == 'v') {
        return;
    }

    NSUInteger retSize = sig.methodReturnLength;
    if (retSize == 0) {
        return;
    }

    void *buffer = alloca(retSize);
    memset(buffer, 0, retSize);

    if (ASUnboxIntoBytes(object, buffer, typeEncoding)) {
        [invocation setReturnValue:buffer];
    }
}

@end
