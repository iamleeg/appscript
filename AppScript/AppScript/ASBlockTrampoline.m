// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockTrampoline.m — Gives a script block the C signature a Cocoa method will call it with
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

#import <AppScript/ASBlockTrampoline.h>
#import <AppScript/ASBoxer.h>
#import "ASFfiSupport.h"
#import <AppScript/ASInterpreter.h>
#import <AppScript/ASNull.h>
#import <AppScript/ASOutObject.h>
#import <AppScript/ASStructValue.h>
#import <objc/runtime.h>
#include <ffi.h>
#include <stdlib.h>

NSString * const ASBlockTrampolineErrorDomain = @"ASBlockTrampolineErrorDomain";
const NSInteger ASBlockTrampolineErrorUnsupportedType = 1;
const NSInteger ASBlockTrampolineErrorWrongArgumentCount = 2;
const NSInteger ASBlockTrampolineErrorNoSignature = 3;
const NSInteger ASBlockTrampolineErrorArgumentConversion = 4;

// The parts of the block ABI used to call a native block (clang's Block_private.h).
enum {
    ASBlockHasCopyDispose = (1 << 25),
    ASBlockHasSignature = (1 << 30),
};
typedef struct {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    void *descriptor;
} ASBlockLayout;

// The Block ABI lays a block out as: isa, flags, reserved, invoke, descriptor, then its captured
// variables. These offsets are for 64-bit platforms; a wrapper isn't built on 32-bit ones.
static const size_t ASBlockInvokeOffset = 16;
static const size_t ASBlockCaptureOffset = 32;

static char ASScriptBlockInfoKey;

// ---------------------------------------------------------------------------
// Script block marker
// ---------------------------------------------------------------------------

@interface ASScriptBlockInfo : NSObject
@property (nonatomic, copy) id _Nullable (^invoker)(NSArray *arguments);
@property (nonatomic) NSUInteger parameterCount;
@end

@implementation ASScriptBlockInfo
@end

// ---------------------------------------------------------------------------
// One libffi closure per distinct signature. The closure reads the per-block context from the block
// it is called with, so every wrapper with the same signature shares it. Entries are cached for
// the life of the process, so the closure memory is never freed.
// ---------------------------------------------------------------------------

@interface ASBlockClosureInfo : NSObject {
@public
    ffi_cif cif;
    ffi_type **argTypes;
    ffi_type *returnFfiType;
    ffi_closure *closure;
    void *code;
}
@property (nonatomic, strong) NSMutableArray<NSValue *> *allocatedStructs;
@property (nonatomic, copy) NSArray<NSString *> *parameterTypes;
@property (nonatomic, copy) NSString *returnType;
@end

@implementation ASBlockClosureInfo
@end

@interface ASBlockWrapperContext : NSObject
@property (nonatomic, strong) ASScriptBlockInfo *script;
@property (nonatomic, strong) ASBlockClosureInfo *closureInfo;
@end

@implementation ASBlockWrapperContext
@end

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns the encoding with a struct's name mapped to the runtime form `ASBoxer` boxes with.
static NSString *ASResolveBlockTypeEncoding(NSString *encoding) {
    const char *skipped = ASFfiSkipQualifiers(encoding.UTF8String);
    if (skipped != NULL && skipped[0] == '{') {
        return [ASStructValue runtimeTypeEncodingForStructTypeEncoding:@(skipped)];
    }
    return encoding;
}

/// The pointee encoding of a pointer to a scalar or struct (`^q`, `^B`, `^{...}`), or `NULL`. These
/// become `ASOutObject`s, as pointer arguments of `NSInvocation` calls do (see `ASBoxer`).
static const char * _Nullable ASBlockOutPointee(const char *encoding) {
    encoding = ASFfiSkipQualifiers(encoding);
    if (encoding == NULL || encoding[0] != '^') {
        return NULL;
    }
    const char *pointee = ASFfiSkipQualifiers(encoding + 1);
    switch (pointee[0]) {
        case 'B': case 'c': case 'C': case 's': case 'S': case 'i': case 'I':
        case 'l': case 'L': case 'q': case 'Q': case 'f': case 'd': case '{':
            return pointee;
        default:
            return NULL;
    }
}

static void ASRaiseBlockConversionFailure(NSString *message) __attribute__((noreturn));
static void ASRaiseBlockConversionFailure(NSString *message) {
    ASRaiseRuntimeError(message, ASErrorCodeValueConversionFailed, nil, 0);
}

/// Stores the script's result in libffi's return slot as the declared C type.
static void ASStoreBlockResult(void *ret, NSString *returnType, id _Nullable result) {
    const char *encoding = ASFfiSkipQualifiers(returnType.UTF8String);
    if (encoding[0] == 'v') {
        return;
    }
    if ([result isKindOfClass:[ASNull class]] || [result isKindOfClass:[NSNull class]]) {
        result = nil;
    }
    if (encoding[0] == '@') {
        // An object result is handed to Cocoa autoreleased (+0), as for forwarded methods (ADR 3).
        __autoreleasing id handedBack = result;
        *(void **)ret = (__bridge void *)handedBack;
        return;
    }
    NSUInteger size = 0;
    NSGetSizeAndAlignment(encoding, &size, NULL);
    void *buffer = alloca(size > 0 ? size : 1);
    memset(buffer, 0, size > 0 ? size : 1);
    if (size == 0 || ![ASBoxer unboxObject:result intoBytes:buffer ofSize:size typeEncoding:encoding]) {
        ASRaiseBlockConversionFailure([NSString stringWithFormat:
            @"Cannot convert the return value of the block from %@ to %@",
            result ? NSStringFromClass([result class]) : @"nil",
            [ASBoxer displayNameForTypeEncoding:encoding]]);
    }
    // libffi requires an integral result narrower than a word to be stored widened.
    switch (encoding[0]) {
        case 'c': *(ffi_sarg *)ret = *(signed char *)buffer; break;
        case 'C': case 'B': *(ffi_arg *)ret = *(unsigned char *)buffer; break;
        case 's': *(ffi_sarg *)ret = *(short *)buffer; break;
        case 'S': *(ffi_arg *)ret = *(unsigned short *)buffer; break;
        case 'i': *(ffi_sarg *)ret = *(int *)buffer; break;
        case 'I': *(ffi_arg *)ret = *(unsigned int *)buffer; break;
        default: memcpy(ret, buffer, size); break;
    }
}

/// Runs when Cocoa calls a wrapper block: boxes the arguments, runs the script, converts the result.
static void ASBlockClosureHandler(ffi_cif *cif, void *ret, void **args, void *userdata) {
    ASBlockClosureInfo *info = (__bridge ASBlockClosureInfo *)userdata;
    void *block = *(void **)args[0];
    ASBlockWrapperContext *context =
        (__bridge ASBlockWrapperContext *)*(void **)((char *)block + ASBlockCaptureOffset);

    NSArray<NSString *> *parameterTypes = info.parameterTypes;
    NSMutableArray *boxed = [NSMutableArray arrayWithCapacity:parameterTypes.count];
    NSMutableArray<NSNumber *> *outIndexes = [NSMutableArray array];
    for (NSUInteger i = 0; i < parameterTypes.count; i++) {
        const char *encoding = parameterTypes[i].UTF8String;
        void *argument = args[i + 1];
        const char *pointee = ASBlockOutPointee(encoding);
        if (pointee != NULL) {
            void *target = *(void **)argument;
            id initial = target ? [ASBoxer boxedObjectFromBytes:target typeEncoding:pointee] : nil;
            [boxed addObject:[[ASOutObject alloc] initWithValue:initial pointeeTypeEncoding:@(pointee)]];
            [outIndexes addObject:@(i)];
        } else {
            id value = [ASBoxer boxedObjectFromBytes:argument typeEncoding:encoding];
            [boxed addObject:value ?: [ASNull null]];
        }
    }

    id result = context.script.invoker(boxed);

    // Store each out-parameter back through its pointer, with the strict conversion rules.
    for (NSNumber *indexNumber in outIndexes) {
        NSUInteger i = indexNumber.unsignedIntegerValue;
        void *target = *(void **)args[i + 1];
        if (target == NULL) {
            continue;
        }
        ASOutObject *out = boxed[i];
        const char *pointee = out.pointeeTypeEncoding.UTF8String;
        NSUInteger size = 0;
        NSGetSizeAndAlignment(pointee, &size, NULL);
        void *buffer = alloca(size > 0 ? size : 1);
        memset(buffer, 0, size > 0 ? size : 1);
        if (size == 0 || ![ASBoxer unboxObject:out.value intoBytes:buffer ofSize:size typeEncoding:pointee]) {
            ASRaiseBlockConversionFailure([NSString stringWithFormat:
                @"Cannot convert out-parameter %lu of the block from %@ to %@", (unsigned long)(i + 1),
                out.value ? NSStringFromClass([out.value class]) : @"nil",
                [ASBoxer displayNameForTypeEncoding:pointee]]);
        }
        memcpy(target, buffer, size);
    }

    ASStoreBlockResult(ret, info.returnType, result);
}

@implementation ASBlockTrampoline

+ (void)attachInvoker:(id _Nullable (^)(NSArray *))invoker
       parameterCount:(NSUInteger)parameterCount
        toScriptBlock:(id)block {
    ASScriptBlockInfo *info = [[ASScriptBlockInfo alloc] init];
    info.invoker = invoker;
    info.parameterCount = parameterCount;
    objc_setAssociatedObject(block, &ASScriptBlockInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (BOOL)isScriptBlock:(nullable id)object {
    return object != nil && objc_getAssociatedObject(object, &ASScriptBlockInfoKey) != nil;
}

+ (BOOL)isBlock:(nullable id)object {
    if (object == nil) {
        return NO;
    }
    if ([self isScriptBlock:object]) {
        return YES;
    }
    for (Class cls = object_getClass(object); cls != Nil; cls = class_getSuperclass(cls)) {
        const char *name = class_getName(cls);
        if (strcmp(name, "NSBlock") == 0 || strcmp(name, "_NSBlock") == 0) {
            return YES;
        }
    }
    return NO;
}

+ (nullable const char *)typeSignatureOfNativeBlock:(id)block {
    ASBlockLayout *layout = (__bridge ASBlockLayout *)block;
    if ((layout->flags & ASBlockHasSignature) == 0 || layout->descriptor == NULL) {
        return NULL;
    }
    // The descriptor is { reserved, size, [copy, dispose,] signature, ... }.
    void **fields = (void **)layout->descriptor;
    NSUInteger index = (layout->flags & ASBlockHasCopyDispose) ? 4 : 2;
    return (const char *)fields[index];
}

static NSError *ASBlockCallError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:ASBlockTrampolineErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static void ASFreeStructFfiTypes(NSArray<NSValue *> *structs) {
    for (NSValue *value in structs) {
        ffi_type *type = (ffi_type *)value.pointerValue;
        if (type) {
            free(type->elements);
            free(type);
        }
    }
}

+ (BOOL)callBlock:(id)block
    withArguments:(NSArray *)arguments
           result:(id _Nullable * _Nonnull)result
            error:(NSError * _Nullable * _Nullable)error {
    *result = nil;
    ASScriptBlockInfo *info = objc_getAssociatedObject(block, &ASScriptBlockInfoKey);
    if (info != nil) {
        if (arguments.count != info.parameterCount) {
            if (error) {
                *error = ASBlockCallError(ASBlockTrampolineErrorWrongArgumentCount, [NSString stringWithFormat:
                    @"The block takes %lu parameters, but was called with %lu",
                    (unsigned long)info.parameterCount, (unsigned long)arguments.count]);
            }
            return NO;
        }
        *result = info.invoker(arguments);
        return YES;
    }

    const char *types = [self typeSignatureOfNativeBlock:block];
    if (types == NULL) {
        if (error) {
            *error = ASBlockCallError(ASBlockTrampolineErrorNoSignature,
                                      @"This block has no type signature, so AppScript can't call it");
        }
        return NO;
    }
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];
    NSUInteger parameterCount = signature.numberOfArguments - 1; // argument 0 is the block itself
    if (arguments.count != parameterCount) {
        if (error) {
            *error = ASBlockCallError(ASBlockTrampolineErrorWrongArgumentCount, [NSString stringWithFormat:
                @"The block takes %lu parameters, but was called with %lu",
                (unsigned long)parameterCount, (unsigned long)arguments.count]);
        }
        return NO;
    }

    NSMutableArray<NSValue *> *structs = [NSMutableArray array];
    NSUInteger count = parameterCount + 1;
    ffi_type **ffiTypes = alloca(count * sizeof(ffi_type *));
    void **values = alloca(count * sizeof(void *));
    void **outBuffers = alloca(count * sizeof(void *));
    void *blockPointer = (__bridge void *)block;
    ffiTypes[0] = &ffi_type_pointer;
    values[0] = &blockPointer;
    outBuffers[0] = NULL;

    for (NSUInteger i = 1; i < count; i++) {
        const char *encoding = [signature getArgumentTypeAtIndex:i];
        const char *cursor = encoding;
        ffi_type *type = ASFfiTypeForEncodingCursor(&cursor, structs);
        NSString *typeName = [ASBoxer displayNameForTypeEncoding:encoding];
        if (type == NULL) {
            ASFreeStructFfiTypes(structs);
            if (error) {
                *error = ASBlockCallError(ASBlockTrampolineErrorUnsupportedType, [NSString stringWithFormat:
                    @"Argument %lu of the block has a type AppScript can't pass (%@)", (unsigned long)i, typeName]);
            }
            return NO;
        }
        ffiTypes[i] = type;
        // A struct ffi_type's size is only set by ffi_prep_cif, so take the size from the encoding.
        NSUInteger argumentSize = 0;
        NSGetSizeAndAlignment(encoding, &argumentSize, NULL);
        NSUInteger size = MAX(argumentSize, sizeof(void *));
        void *buffer = alloca(size);
        memset(buffer, 0, size);
        values[i] = buffer;
        outBuffers[i] = NULL;

        id argument = arguments[i - 1];
        NSString *pointee = [argument isKindOfClass:[ASOutObject class]]
            ? [ASBoxer bridgedPointeeTypeEncodingForPointerEncoding:encoding] : nil;
        BOOL converted;
        if (pointee != nil) {
            NSUInteger pointeeSize = 0;
            NSGetSizeAndAlignment(pointee.UTF8String, &pointeeSize, NULL);
            void *outBuffer = alloca(pointeeSize > 0 ? pointeeSize : 1);
            converted = [ASBoxer prepareOutBuffer:outBuffer size:(pointeeSize > 0 ? pointeeSize : 1)
                                     forOutObject:argument pointee:pointee];
            outBuffers[i] = outBuffer;
            memcpy(buffer, &outBuffer, sizeof(void *));
        } else {
            converted = [ASBoxer unboxObject:argument intoBytes:buffer ofSize:argumentSize
                                typeEncoding:encoding];
        }
        if (!converted) {
            ASFreeStructFfiTypes(structs);
            if (error) {
                id value = [argument isKindOfClass:[ASOutObject class]] ? ((ASOutObject *)argument).value : argument;
                *error = ASBlockCallError(ASBlockTrampolineErrorArgumentConversion, [NSString stringWithFormat:
                    @"Cannot convert argument %lu of the block from %@ to %@", (unsigned long)i,
                    [value isKindOfClass:[ASNull class]] ? @"nil" : NSStringFromClass([value class]), typeName]);
            }
            return NO;
        }
    }

    const char *returnEncoding = signature.methodReturnType;
    const char *returnCursor = returnEncoding;
    ffi_type *returnType = (ASFfiSkipQualifiers(returnEncoding)[0] == 'v')
        ? &ffi_type_void : ASFfiTypeForEncodingCursor(&returnCursor, structs);
    ffi_cif cif;
    if (returnType == NULL ||
        ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)count, returnType, ffiTypes) != FFI_OK) {
        ASFreeStructFfiTypes(structs);
        if (error) {
            *error = ASBlockCallError(ASBlockTrampolineErrorUnsupportedType, [NSString stringWithFormat:
                @"The block returns a type AppScript can't receive (%@)",
                [ASBoxer displayNameForTypeEncoding:returnEncoding]]);
        }
        return NO;
    }
    NSUInteger returnSize = MAX((NSUInteger)returnType->size, sizeof(ffi_arg));
    void *returnBuffer = alloca(returnSize);
    memset(returnBuffer, 0, returnSize);

    ffi_call(&cif, FFI_FN(((__bridge ASBlockLayout *)block)->invoke), returnBuffer, values);

    for (NSUInteger i = 1; i < count; i++) {
        if (outBuffers[i] != NULL) {
            [ASBoxer writeOutBuffer:outBuffers[i] toOutObject:arguments[i - 1]
                            pointee:[ASBoxer bridgedPointeeTypeEncodingForPointerEncoding:
                                     [signature getArgumentTypeAtIndex:i]]];
        }
    }
    if (returnType != &ffi_type_void) {
        *result = [ASBoxer boxedObjectFromBytes:returnBuffer typeEncoding:ASFfiSkipQualifiers(returnEncoding)];
    }
    ASFreeStructFfiTypes(structs);
    return YES;
}

+ (NSUInteger)parameterCountOfScriptBlock:(id)block {
    ASScriptBlockInfo *info = objc_getAssociatedObject(block, &ASScriptBlockInfoKey);
    return info.parameterCount;
}

+ (nullable ASBlockClosureInfo *)closureInfoForSignature:(ASBridgeSupportBlockSignature *)signature
                                                   error:(NSError * _Nullable * _Nullable)error {
    static NSMutableDictionary<NSString *, ASBlockClosureInfo *> *cache;
    static dispatch_queue_t queue;  // owns `cache`
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary dictionary];
        queue = dispatch_queue_create("com.appscript.block-closures", DISPATCH_QUEUE_SERIAL);
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@>%@",
                          [signature.parameterTypeEncodings componentsJoinedByString:@","],
                          signature.returnTypeEncoding];
    __block ASBlockClosureInfo *info = nil;
    __block NSString *failure = nil;
    dispatch_sync(queue, ^{
        info = cache[cacheKey];
        if (info != nil) {
            return;
        }
        ASBlockClosureInfo *built = [[ASBlockClosureInfo alloc] init];
        built.allocatedStructs = [NSMutableArray array];
        NSMutableArray<NSString *> *resolvedParameters = [NSMutableArray array];
        NSUInteger count = signature.parameterTypeEncodings.count;
        built->argTypes = calloc(count + 1, sizeof(ffi_type *));
        built->argTypes[0] = &ffi_type_pointer;   // the block itself
        for (NSUInteger i = 0; i < count; i++) {
            NSString *original = signature.parameterTypeEncodings[i];
            NSString *resolved = ASResolveBlockTypeEncoding(original);
            ffi_type *type = NULL;
            if ([resolved hasPrefix:@"@?"]) {
                type = &ffi_type_pointer;   // a block parameter
            } else {
                const char *cursor = resolved.UTF8String;
                type = ASFfiTypeForEncodingCursor(&cursor, built.allocatedStructs);
                if (type != NULL && *cursor != '\0') {
                    type = NULL;
                }
            }
            if (type == NULL || type == &ffi_type_void) {
                failure = original;
                return;
            }
            built->argTypes[i + 1] = type;
            [resolvedParameters addObject:resolved];
        }
        NSString *resolvedReturn = ASResolveBlockTypeEncoding(signature.returnTypeEncoding);
        const char *returnCursor = resolvedReturn.UTF8String;
        built->returnFfiType = [resolvedReturn hasPrefix:@"@?"] ? &ffi_type_pointer
                                                                  : ASFfiTypeForEncodingCursor(&returnCursor, built.allocatedStructs);
        if (built->returnFfiType == NULL || (![resolvedReturn hasPrefix:@"@?"] && *returnCursor != '\0')) {
            failure = signature.returnTypeEncoding;
            return;
        }
        if (ffi_prep_cif(&built->cif, FFI_DEFAULT_ABI, (unsigned)(count + 1),
                         built->returnFfiType, built->argTypes) != FFI_OK) {
            failure = [NSString stringWithFormat:@"%@ (libffi rejected the signature)", cacheKey];
            return;
        }
        built->closure = ffi_closure_alloc(sizeof(ffi_closure), &built->code);
        if (built->closure == NULL) {
            failure = [NSString stringWithFormat:@"%@ (no memory for a libffi closure)", cacheKey];
            return;
        }
        built.parameterTypes = resolvedParameters;
        built.returnType = resolvedReturn;
        if (ffi_prep_closure_loc(built->closure, &built->cif, ASBlockClosureHandler,
                                 (__bridge void *)built, built->code) != FFI_OK) {
            failure = [NSString stringWithFormat:@"%@ (libffi couldn't prepare the closure)", cacheKey];
            return;
        }
        cache[cacheKey] = built;
        info = built;
    });
    if (info == nil && error != NULL) {
        *error = [NSError errorWithDomain:ASBlockTrampolineErrorDomain
                                     code:ASBlockTrampolineErrorUnsupportedType
                                 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                     @"The block signature has a type the runtime can't pass through a block: %@",
                                     failure ?: @"?"] }];
    }
    return info;
}

+ (nullable id)blockWrappingScriptBlock:(id)scriptBlock
                              signature:(ASBridgeSupportBlockSignature *)signature
                                  error:(NSError * _Nullable * _Nullable)error {
    ASScriptBlockInfo *script = objc_getAssociatedObject(scriptBlock, &ASScriptBlockInfoKey);
    if (script == nil || sizeof(void *) != 8) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:ASBlockTrampolineErrorDomain
                                         code:ASBlockTrampolineErrorUnsupportedType
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                         script == nil ? @"Not a script block"
                                                       : @"Block wrappers are only built on 64-bit platforms" }];
        }
        return nil;
    }
    ASBlockClosureInfo *closureInfo = [self closureInfoForSignature:signature error:error];
    if (closureInfo == nil) {
        return nil;
    }
    ASBlockWrapperContext *context = [[ASBlockWrapperContext alloc] init];
    context.script = script;
    context.closureInfo = closureInfo;
    // A real block whose only captured variable is the context; its invoke function is replaced by the
    // closure's code, which finds the context at the first capture slot (see ASBlockCaptureOffset).
    void (^prototype)(void) = ^{ (void)context; };
    id wrapper = [prototype copy];
    *(void **)((char *)(__bridge void *)wrapper + ASBlockInvokeOffset) = closureInfo->code;
    return wrapper;
}

@end
