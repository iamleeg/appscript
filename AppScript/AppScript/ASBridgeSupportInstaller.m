// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportInstaller.m — Installs BridgeSupport-described C functions as Objective-C class methods
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

#import "ASBridgeSupportInstaller.h"
#import "ASBridgeSupportDocument.h"
#import "ASBridgeSupportFunction.h"
#import "ASBridgeSupportConstant.h"
#import "ASBridgeSupportEnumeration.h"
#import "ASBridgeSupportStruct.h"
#import "ASStructValue.h"
#import "ASBoxer.h"
#import "ASNull.h"
#import "ASOutObject.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <ffi.h>

// ---------------------------------------------------------------------------
// Error domain
// ---------------------------------------------------------------------------

NSString * const ASBridgeSupportInstallerErrorDomain = @"ASBridgeSupportInstallerErrorDomain";

// ---------------------------------------------------------------------------
// Associated-object key for the per-class method map
// ---------------------------------------------------------------------------

static char ASBridgeSupportMethodMapKey;

// ---------------------------------------------------------------------------
// Helper: map an Objective-C / BridgeSupport type encoding string to ffi_type *
// ---------------------------------------------------------------------------

static const char *ASSkipQualifiers(const char *p) {
    while (p && (*p == 'r' || *p == 'n' || *p == 'N' || *p == 'o' ||
                 *p == 'O' || *p == 'R' || *p == 'V')) {
        p++;
    }
    return p;
}

static ffi_type * _Nullable ASFfiTypeForEncodingCursor(const char **pPtr,
                                                       NSMutableArray<NSValue *> *allocatedStructs) {
    const char *p = ASSkipQualifiers(*pPtr);
    if (!p || *p == '\0') {
        return NULL;
    }

    char c = *p;
    p++;
    *pPtr = p;

    switch (c) {
        case 'v': return &ffi_type_void;
        case 'c': return &ffi_type_schar;
        case 'C': return &ffi_type_uchar;
        case 'B': return &ffi_type_uint8;
        case 's': return &ffi_type_sshort;
        case 'S': return &ffi_type_ushort;
        case 'i': return &ffi_type_sint32;
        case 'I': return &ffi_type_uint32;
        case 'l': return (sizeof(long) == 8) ? &ffi_type_sint64 : &ffi_type_sint32;
        case 'L': return (sizeof(unsigned long) == 8) ? &ffi_type_uint64 : &ffi_type_uint32;
        case 'q': return &ffi_type_sint64;
        case 'Q': return &ffi_type_uint64;
        case 'f': return &ffi_type_float;
        case 'd': return &ffi_type_double;
        case '@':
        case '#':
        case ':':
        case '*': return &ffi_type_pointer;
        case '^': {
            // Advance past the pointed-to type encoding.
            const char *sub = ASSkipQualifiers(*pPtr);
            while (sub && *sub == '^') {
                sub = ASSkipQualifiers(sub + 1);
            }
            if (sub && *sub == '{') {
                int depth = 0;
                while (*sub) {
                    if (*sub == '{') depth++;
                    else if (*sub == '}') {
                        depth--;
                        if (depth == 0) { sub++; break; }
                    }
                    sub++;
                }
            } else if (sub && *sub != '\0' && *sub != '}') {
                sub++;
            }
            *pPtr = sub;
            return &ffi_type_pointer;
        }
        case '{': {
            // Skip struct tag name up to '=' or '}'
            while (**pPtr && **pPtr != '=' && **pPtr != '}') {
                (*pPtr)++;
            }
            if (**pPtr != '=') {
                return NULL;
            }
            (*pPtr)++; // skip '='

            NSMutableArray<NSValue *> *elements = [NSMutableArray array];
            while (**pPtr && **pPtr != '}') {
                // Skip optional quoted field name: "fieldName"
                if (**pPtr == '"') {
                    (*pPtr)++;
                    while (**pPtr && **pPtr != '"') {
                        (*pPtr)++;
                    }
                    if (**pPtr == '"') {
                        (*pPtr)++;
                    }
                }
                if (**pPtr == '}' || **pPtr == '\0') {
                    break;
                }
                ffi_type *fieldType = ASFfiTypeForEncodingCursor(pPtr, allocatedStructs);
                if (!fieldType) {
                    return NULL;
                }
                [elements addObject:[NSValue valueWithPointer:fieldType]];
            }
            if (**pPtr != '}' || elements.count == 0) {
                return NULL;
            }
            (*pPtr)++; // skip '}'

            ffi_type *structType = calloc(1, sizeof(ffi_type));
            ffi_type **elemsArray = calloc(elements.count + 1, sizeof(ffi_type *));
            if (!structType || !elemsArray) {
                free(structType);
                free(elemsArray);
                return NULL;
            }
            for (NSUInteger i = 0; i < elements.count; i++) {
                elemsArray[i] = (ffi_type *)[elements[i] pointerValue];
            }
            elemsArray[elements.count] = NULL;

            structType->size = 0;
            structType->alignment = 0;
            structType->type = FFI_TYPE_STRUCT;
            structType->elements = elemsArray;

            [allocatedStructs addObject:[NSValue valueWithPointer:structType]];
            return structType;
        }
        default:
            return NULL;
    }
}

static NSString *ASResolveBridgeSupportTypeEncoding(NSString *rawEncoding) {
    const char *skipped = ASSkipQualifiers(rawEncoding.UTF8String);
    if (skipped && skipped[0] == '{') {
        return [ASStructValue runtimeTypeEncodingForStructTypeEncoding:@(skipped)];
    }
    return rawEncoding;
}

// ---------------------------------------------------------------------------
// Private container for per-function libffi dispatch info
// ---------------------------------------------------------------------------

@interface _ASFunctionInfo : NSObject {
    ffi_cif _cif;
    ffi_type *_returnFfiType;
    ffi_type **_argFfiTypes;
    NSMutableArray<NSValue *> *_allocatedStructFfiTypes;
}
@property (nonatomic, readonly) void *funcPtr;
@property (nonatomic, copy, readonly) NSString *returnTypeEncoding;
@property (nonatomic, copy, readonly) NSArray<NSString *> *argTypeEncodings;
- (nullable instancetype)initWithFuncPtr:(void *)funcPtr
                      returnTypeEncoding:(NSString *)returnTypeEncoding
                        argTypeEncodings:(NSArray<NSString *> *)argTypeEncodings NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable id)invokeWithBoxedArguments:(NSArray<id> *)boxedArgs;
@end

@implementation _ASFunctionInfo

- (nullable instancetype)initWithFuncPtr:(void *)funcPtr
                      returnTypeEncoding:(NSString *)returnTypeEncoding
                        argTypeEncodings:(NSArray<NSString *> *)argTypeEncodings {
    self = [super init];
    if (self) {
        _funcPtr = funcPtr;
        _allocatedStructFfiTypes = [NSMutableArray array];

        NSString *resolvedRet = ASResolveBridgeSupportTypeEncoding(returnTypeEncoding);
        _returnTypeEncoding = [resolvedRet copy];

        const char *retCursor = _returnTypeEncoding.UTF8String;
        _returnFfiType = ASFfiTypeForEncodingCursor(&retCursor, _allocatedStructFfiTypes);
        if (!_returnFfiType) {
            return nil;
        }

        NSUInteger argCount = argTypeEncodings.count;
        NSMutableArray<NSString *> *resolvedArgs = [NSMutableArray arrayWithCapacity:argCount];
        if (argCount > 0) {
            _argFfiTypes = calloc(argCount, sizeof(ffi_type *));
            if (!_argFfiTypes) {
                return nil;
            }
        }

        for (NSUInteger i = 0; i < argCount; i++) {
            NSString *resolvedArg = ASResolveBridgeSupportTypeEncoding(argTypeEncodings[i]);
            [resolvedArgs addObject:resolvedArg];
            const char *argCursor = resolvedArg.UTF8String;
            ffi_type *argFfi = ASFfiTypeForEncodingCursor(&argCursor, _allocatedStructFfiTypes);
            if (!argFfi) {
                return nil;
            }
            _argFfiTypes[i] = argFfi;
        }
        _argTypeEncodings = [resolvedArgs copy];

        ffi_status status = ffi_prep_cif(&_cif,
                                         FFI_DEFAULT_ABI,
                                         (unsigned int)argCount,
                                         _returnFfiType,
                                         _argFfiTypes);
        if (status != FFI_OK) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    for (NSValue *val in _allocatedStructFfiTypes) {
        ffi_type *st = (ffi_type *)[val pointerValue];
        if (st) {
            free(st->elements);
            free(st);
        }
    }
    free(_argFfiTypes);
}

- (nullable id)invokeWithBoxedArguments:(NSArray<id> *)boxedArgs {
    NSUInteger argCount = _argTypeEncodings.count;
    void **argValues = (argCount > 0) ? alloca(argCount * sizeof(void *)) : NULL;

    for (NSUInteger i = 0; i < argCount; i++) {
        NSUInteger argSize = MAX((NSUInteger)_argFfiTypes[i]->size, sizeof(void *));
        void *argBuf = alloca(argSize);
        memset(argBuf, 0, argSize);
        argValues[i] = argBuf;

        id boxedArg = (i < boxedArgs.count) ? boxedArgs[i] : nil;
        const char *enc = _argTypeEncodings[i].UTF8String;
        if (![ASBoxer unboxObject:boxedArg
                        intoBytes:argBuf
                           ofSize:(NSUInteger)_argFfiTypes[i]->size
                     typeEncoding:enc]) {
            return nil;
        }
    }

    NSUInteger retBufSize = MAX((NSUInteger)_returnFfiType->size, sizeof(ffi_arg));
    void *retBuffer = alloca(retBufSize);
    memset(retBuffer, 0, retBufSize);

    ffi_call(&_cif, FFI_FN(_funcPtr), retBuffer, argValues);

    const char *retEnc = ASSkipQualifiers(_returnTypeEncoding.UTF8String);
    if (!retEnc || retEnc[0] == 'v') {
        return nil;
    }
    return [ASBoxer boxedObjectFromBytes:retBuffer typeEncoding:retEnc];
}

@end

// ---------------------------------------------------------------------------
// All-id type encodings for class methods (return @ + class self @ + cmd : + N @ args)
// ---------------------------------------------------------------------------

static const char * const ASBridgeSupportTypeEncodings[] = {
    "@@:",              // 0 args
    "@@:@",             // 1 arg
    "@@:@@",            // 2 args
    "@@:@@@",           // 3 args
    "@@:@@@@",          // 4 args
    "@@:@@@@@",         // 5 args
    "@@:@@@@@@",        // 6 args
    "@@:@@@@@@@",       // 7 args
    "@@:@@@@@@@@",      // 8 args
};

// ---------------------------------------------------------------------------
// Helper: read a C constant from a dlsym pointer and box it to an ObjC object.
// Returns nil for unsupported type encodings or NULL pointers.
// ---------------------------------------------------------------------------

static id ASBoxConstantSymbol(void *symPtr, NSString *typeEncoding) {
    if (symPtr == NULL || typeEncoding.length == 0) return nil;
    NSString *resolvedEncoding = ASResolveBridgeSupportTypeEncoding(typeEncoding);
    const char *enc = ASSkipQualifiers(resolvedEncoding.UTF8String);
    if (!enc || enc[0] == '\0' || enc[0] == 'v' || enc[0] == '^') {
        return nil;
    }
    return [ASBoxer boxedObjectFromBytes:symPtr typeEncoding:enc];
}

// ---------------------------------------------------------------------------
// forwardInvocation: IMP — installed on the proxy class metaclass.
// Receives class-method invocations routed through the forwarding machinery.
// ---------------------------------------------------------------------------

static void ASBridgeSupportForwardInvocationIMP(id self, SEL _cmd, NSInvocation *invocation) {
    // `self` is the class object (e.g. ASTestMath), installed on its metaclass.
    Class cls = (Class)self;
    NSString *selectorString = NSStringFromSelector(invocation.selector);

    NSDictionary<NSString *, _ASFunctionInfo *> *methodMap =
        objc_getAssociatedObject(cls, &ASBridgeSupportMethodMapKey);
    _ASFunctionInfo *info = methodMap[selectorString];

    if (info == nil) {
        // Not one of ours — call super's forwardInvocation:.
        Class metaclass = object_getClass(cls);
        Class superMetaclass = class_getSuperclass(metaclass);
        struct objc_super superInfo = { .receiver = self, .super_class = superMetaclass };
        ((void (*)(struct objc_super *, SEL, NSInvocation *))objc_msgSendSuper)(
            &superInfo, @selector(forwardInvocation:), invocation);
        return;
    }

    // Ensure the invocation retains its return value so ARC-managed objects returned by
    // invokeWithBoxedArguments: stay alive until the caller reads the invocation result.
    if (!invocation.argumentsRetained) {
        [invocation retainArguments];
    }

    // Extract the boxed id arguments (the method signature uses all-@ encoding).
    NSUInteger argCount = info.argTypeEncodings.count;
    NSMutableArray<id> *boxedArgs = [NSMutableArray arrayWithCapacity:argCount];
    for (NSUInteger i = 0; i < argCount; i++) {
        __unsafe_unretained id boxedArg = nil;
        [invocation getArgument:&boxedArg atIndex:(NSInteger)(i + 2)];
        [boxedArgs addObject:boxedArg ?: [NSNull null]];
    }

    // Call the C function via libffi and set the boxed result as the return value.
    id result = [info invokeWithBoxedArguments:boxedArgs];
    [invocation setReturnValue:&result];
}

// ---------------------------------------------------------------------------
// methodSignatureForSelector: IMP — installed on the proxy class metaclass.
// ---------------------------------------------------------------------------

static NSMethodSignature *ASBridgeSupportMethodSignatureIMP(id self, SEL _cmd, SEL selector) {
    Class cls = (Class)self;
    NSString *selectorString = NSStringFromSelector(selector);

    NSDictionary<NSString *, _ASFunctionInfo *> *methodMap =
        objc_getAssociatedObject(cls, &ASBridgeSupportMethodMapKey);
    _ASFunctionInfo *info = methodMap[selectorString];

    if (info == nil) {
        // Fall back to NSObject's metaclass implementation.
        Class metaclass = object_getClass(cls);
        Class superMetaclass = class_getSuperclass(metaclass);
        struct objc_super superInfo = { .receiver = self, .super_class = superMetaclass };
        return ((NSMethodSignature *(*)(struct objc_super *, SEL, SEL))objc_msgSendSuper)(
            &superInfo, @selector(methodSignatureForSelector:), selector);
    }

    NSUInteger argCount = info.argTypeEncodings.count;
    NSCAssert(argCount < (sizeof(ASBridgeSupportTypeEncodings) / sizeof(ASBridgeSupportTypeEncodings[0])),
              @"ASBridgeSupportInstaller: more than 4 arguments are not supported");
    return [NSMethodSignature signatureWithObjCTypes:ASBridgeSupportTypeEncodings[argCount]];
}

// ---------------------------------------------------------------------------
// ASBridgeSupportInstaller implementation
// ---------------------------------------------------------------------------

@implementation ASBridgeSupportInstaller

- (instancetype)init {
    return [super init];
}

- (BOOL)installDocument:(ASBridgeSupportDocument *)document
          frameworkName:(NSString *)frameworkName
                  error:(NSError **)error {
    NSString *proxyClassName = [@"AS" stringByAppendingString:frameworkName];

    // Guard against duplicate installation.
    if (NSClassFromString(proxyClassName) != Nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASBridgeSupportInstallerErrorDomain
                                         code:ASBridgeSupportInstallerErrorDuplicateFramework
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"BridgeSupport for framework '%@' is already installed (class %@ exists)",
                    frameworkName, proxyClassName],
            }];
        }
        return NO;
    }

    // Allocate the proxy class as a plain NSObject subclass.
    Class proxyClass = objc_allocateClassPair([NSObject class], proxyClassName.UTF8String, 0);
    if (proxyClass == Nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASBridgeSupportInstallerErrorDomain
                                         code:ASBridgeSupportInstallerErrorAllocationFailure
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Failed to allocate proxy class %@", proxyClassName],
            }];
        }
        return NO;
    }

    // Register struct definitions first so ASStructValue can resolve bare struct
    // type encodings when installing functions and constants below.
    for (ASBridgeSupportStruct *s in document.structs) {
        [ASStructValue registerStruct:s];
    }

    // Build the method map: selector string → _ASFunctionInfo.
    NSMutableDictionary<NSString *, _ASFunctionInfo *> *methodMap = [NSMutableDictionary dictionary];
    Class metaclass = object_getClass(proxyClass);

    for (ASBridgeSupportFunction *function in document.functions) {
        // Skip unsupported function kinds.
        if (function.isVariadic || function.hasFunctionPointerArguments) {
            continue;
        }

        NSUInteger argCount = function.argumentTypeEncodings.count;
        if (argCount >= (sizeof(ASBridgeSupportTypeEncodings) / sizeof(ASBridgeSupportTypeEncodings[0]))) {
            // More than 8 arguments — not currently supported.
            continue;
        }

        // Resolve the C function symbol at install time.
        void *funcPtr = dlsym(RTLD_DEFAULT, function.name.UTF8String);
        if (funcPtr == NULL) {
            // Symbol not available in the current process — skip silently.
            continue;
        }

        _ASFunctionInfo *info = [[_ASFunctionInfo alloc]
            initWithFuncPtr:funcPtr
         returnTypeEncoding:function.returnTypeEncoding
           argTypeEncodings:function.argumentTypeEncodings];
        if (info == nil) {
            // Unsupported type encoding in signature — skip silently.
            continue;
        }

        // Build the ObjC selector: "funcName" (0 args), "funcName:" (1 arg), "funcName::" (2), etc.
        NSMutableString *selectorString = [NSMutableString stringWithString:function.name];
        for (NSUInteger i = 0; i < argCount; i++) {
            [selectorString appendString:@":"];
        }

        methodMap[selectorString] = info;

        // Register a sentinel method on the metaclass so the ObjC runtime routes
        // the message send through the forwarding machinery.
        SEL sel = NSSelectorFromString(selectorString);
        const char *encoding = ASBridgeSupportTypeEncodings[argCount];
        class_addMethod(metaclass, sel, (IMP)_objc_msgForward, encoding);
    }

    // Install constants as direct IMP blocks: the value is boxed once at install time
    // and captured in the block, so there is no per-call overhead.
    for (ASBridgeSupportConstant *constant in document.constants) {
        void *symPtr = dlsym(RTLD_DEFAULT, constant.name.UTF8String);
        if (symPtr == NULL) {
            // Symbol not available in the current process — skip silently.
            continue;
        }
        id boxedValue = ASBoxConstantSymbol(symPtr, constant.typeEncoding);
        if (boxedValue == nil) {
            continue;
        }
        SEL sel = NSSelectorFromString(constant.name);
        IMP imp = imp_implementationWithBlock(^id(id blockSelf) {
            return boxedValue;
        });
        class_addMethod(metaclass, sel, imp, "@@:");
    }

    // Install enumerations as direct IMP blocks: the integer value is available
    // directly from the parsed document (no dlsym needed).
    for (ASBridgeSupportEnumeration *enumeration in document.enumerations) {
        NSNumber *boxedValue = @(enumeration.value);
        SEL sel = NSSelectorFromString(enumeration.name);
        IMP imp = imp_implementationWithBlock(^id(id blockSelf) {
            return boxedValue;
        });
        class_addMethod(metaclass, sel, imp, "@@:");
    }

    // Store the method map on the class object itself.
    objc_setAssociatedObject(proxyClass,
                             &ASBridgeSupportMethodMapKey,
                             [methodMap copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Install forwardInvocation: and methodSignatureForSelector: on the metaclass.
    IMP msfsIMP = imp_implementationWithBlock(^NSMethodSignature *(id blockSelf, SEL selector) {
        return ASBridgeSupportMethodSignatureIMP(blockSelf, NULL, selector);
    });
    class_replaceMethod(metaclass, @selector(methodSignatureForSelector:), msfsIMP, "@@::");

    IMP fiIMP = imp_implementationWithBlock(^void(id blockSelf, NSInvocation *inv) {
        ASBridgeSupportForwardInvocationIMP(blockSelf, NULL, inv);
    });
    class_replaceMethod(metaclass, @selector(forwardInvocation:), fiIMP, "v@:@");

    // Register the class pair with the runtime.
    objc_registerClassPair(proxyClass);

    return YES;
}

- (BOOL)installDocument:(ASBridgeSupportDocument *)document
          frameworkName:(NSString *)frameworkName {
    return [self installDocument:document frameworkName:frameworkName error:nil];
}

@end
