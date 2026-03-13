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

#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

// ---------------------------------------------------------------------------
// Error domain
// ---------------------------------------------------------------------------

NSString * const ASBridgeSupportInstallerErrorDomain = @"ASBridgeSupportInstallerErrorDomain";

// ---------------------------------------------------------------------------
// Associated-object key for the per-class method map
// ---------------------------------------------------------------------------

static char ASBridgeSupportMethodMapKey;

// ---------------------------------------------------------------------------
// Private container for per-function dispatch info
// ---------------------------------------------------------------------------

@interface _ASFunctionInfo : NSObject
@property (nonatomic, readonly) void *funcPtr;
@property (nonatomic, copy, readonly) NSString *returnTypeEncoding;
@property (nonatomic, copy, readonly) NSArray<NSString *> *argTypeEncodings;
- (instancetype)initWithFuncPtr:(void *)funcPtr
             returnTypeEncoding:(NSString *)returnTypeEncoding
                argTypeEncodings:(NSArray<NSString *> *)argTypeEncodings NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation _ASFunctionInfo

- (instancetype)initWithFuncPtr:(void *)funcPtr
             returnTypeEncoding:(NSString *)returnTypeEncoding
                argTypeEncodings:(NSArray<NSString *> *)argTypeEncodings {
    self = [super init];
    if (self) {
        _funcPtr = funcPtr;
        _returnTypeEncoding = [returnTypeEncoding copy];
        _argTypeEncodings   = [argTypeEncodings copy];
    }
    return self;
}

@end

// ---------------------------------------------------------------------------
// All-id type encodings for class methods (return @ + class self @ + cmd : + N @ args)
// ---------------------------------------------------------------------------

static const char * const ASBridgeSupportTypeEncodings[] = {
    "@@:",          // 0 args
    "@@:@",         // 1 arg
    "@@:@@",        // 2 args
    "@@:@@@",       // 3 args
    "@@:@@@@",      // 4 args
};

// ---------------------------------------------------------------------------
// Helper: unbox a single NSNumber/NSString/id argument to a typed C value.
// The caller passes the expected BridgeSupport type encoding character.
// ---------------------------------------------------------------------------

static double    ASUnboxDouble(id obj)  { return [(NSNumber *)obj doubleValue]; }
static float     ASUnboxFloat(id obj)   { return [(NSNumber *)obj floatValue]; }
static int       ASUnboxInt(id obj)     { return [(NSNumber *)obj intValue]; }
static long long ASUnboxLongLong(id obj){ return [(NSNumber *)obj longLongValue]; }
static BOOL      ASUnboxBool(id obj)    { return [(NSNumber *)obj boolValue]; }
static const char *ASUnboxCString(id obj) {
    return (obj == nil || obj == [NSNull null]) ? NULL : [(NSString *)obj UTF8String];
}

// ---------------------------------------------------------------------------
// Helper: read a C constant from a dlsym pointer and box it to an ObjC object.
// Returns nil for unsupported type encodings or NULL pointers.
// ---------------------------------------------------------------------------

static id ASBoxConstantSymbol(void *symPtr, NSString *typeEncoding) {
    if (symPtr == NULL || typeEncoding.length == 0) return nil;
    char enc = (char)[typeEncoding characterAtIndex:0];
    switch (enc) {
        case 'd': return @(*(double *)symPtr);
        case 'f': return @(*(float *)symPtr);
        case 'i': return @(*(int *)symPtr);
        case 'I': return @(*(unsigned int *)symPtr);
        case 'l': return @(*(long *)symPtr);
        case 'L': return @(*(unsigned long *)symPtr);
        case 'q': return @(*(long long *)symPtr);
        case 'Q': return @(*(unsigned long long *)symPtr);
        case 's': return @(*(short *)symPtr);
        case 'S': return @(*(unsigned short *)symPtr);
        case 'c':
        case 'B': return @((BOOL)(*(char *)symPtr));
        case '@': return *((__unsafe_unretained id *)symPtr);
        case '*': {
            const char *s = *(const char **)symPtr;
            return s ? @(s) : nil;
        }
        default: return nil;
    }
}

// ---------------------------------------------------------------------------
// Helper: call a C function pointer with the given boxed arguments.
// Handles the common signatures needed for BridgeSupport-wrapped functions.
// Returns the boxed result, or nil for void returns.
// ---------------------------------------------------------------------------

NS_INLINE BOOL ASTypeIsIntLike(NSString *t) {
    return [t isEqualToString:@"i"] || [t isEqualToString:@"I"] ||
           [t isEqualToString:@"l"] || [t isEqualToString:@"L"] ||
           [t isEqualToString:@"s"] || [t isEqualToString:@"S"] ||
           [t isEqualToString:@"c"] || [t isEqualToString:@"B"];
}

static id ASCallCFunction(void *funcPtr,
                          NSString *ret,
                          NSArray<NSString *> *argTypes,
                          NSArray<id> *boxed) {
    NSUInteger n = argTypes.count;

    // ---- void return ----
    if ([ret isEqualToString:@"v"]) {
        if (n == 0) {
            ((void (*)(void))funcPtr)();
            return nil;
        }
        if (n == 1) {
            NSString *a0 = argTypes[0];
            if ([a0 isEqualToString:@"d"])  { ((void (*)(double))funcPtr)(ASUnboxDouble(boxed[0])); return nil; }
            if ([a0 isEqualToString:@"f"])  { ((void (*)(float))funcPtr)(ASUnboxFloat(boxed[0])); return nil; }
            if (ASTypeIsIntLike(a0))         { ((void (*)(int))funcPtr)(ASUnboxInt(boxed[0])); return nil; }
            if ([a0 isEqualToString:@"q"] || [a0 isEqualToString:@"Q"]) {
                ((void (*)(long long))funcPtr)(ASUnboxLongLong(boxed[0])); return nil;
            }
            if ([a0 isEqualToString:@"@"])  { ((void (*)(id))funcPtr)(boxed[0]); return nil; }
            if ([a0 isEqualToString:@"*"])  { ((void (*)(const char *))funcPtr)(ASUnboxCString(boxed[0])); return nil; }
            // Pointer types (^): pass as nil/NULL
            if ([a0 hasPrefix:@"^"]) { ((void (*)(void *))funcPtr)(NULL); return nil; }
        }
    }

    // ---- double return ----
    if ([ret isEqualToString:@"d"]) {
        if (n == 0) return @(((double (*)(void))funcPtr)());
        if (n == 1) {
            NSString *a0 = argTypes[0];
            if ([a0 isEqualToString:@"d"]) return @(((double (*)(double))funcPtr)(ASUnboxDouble(boxed[0])));
            if ([a0 isEqualToString:@"f"]) return @(((double (*)(float))funcPtr)(ASUnboxFloat(boxed[0])));
            if (ASTypeIsIntLike(a0))        return @(((double (*)(int))funcPtr)(ASUnboxInt(boxed[0])));
        }
        if (n == 2) {
            NSString *a0 = argTypes[0], *a1 = argTypes[1];
            if ([a0 isEqualToString:@"d"] && [a1 isEqualToString:@"d"])
                return @(((double (*)(double, double))funcPtr)(ASUnboxDouble(boxed[0]), ASUnboxDouble(boxed[1])));
        }
        if (n == 3) {
            NSString *a0 = argTypes[0], *a1 = argTypes[1], *a2 = argTypes[2];
            if ([a0 isEqualToString:@"d"] && [a1 isEqualToString:@"d"] && [a2 isEqualToString:@"d"])
                return @(((double (*)(double, double, double))funcPtr)(
                    ASUnboxDouble(boxed[0]), ASUnboxDouble(boxed[1]), ASUnboxDouble(boxed[2])));
        }
    }

    // ---- float return ----
    if ([ret isEqualToString:@"f"]) {
        if (n == 0) return @(((float (*)(void))funcPtr)());
        if (n == 1) {
            NSString *a0 = argTypes[0];
            if ([a0 isEqualToString:@"f"]) return @(((float (*)(float))funcPtr)(ASUnboxFloat(boxed[0])));
            if ([a0 isEqualToString:@"d"]) return @((float)((float (*)(double))funcPtr)(ASUnboxDouble(boxed[0])));
        }
    }

    // ---- int / long return (treat as int-width) ----
    if (ASTypeIsIntLike(ret)) {
        if (n == 0) return @(((int (*)(void))funcPtr)());
        if (n == 1) {
            NSString *a0 = argTypes[0];
            if (ASTypeIsIntLike(a0)) return @(((int (*)(int))funcPtr)(ASUnboxInt(boxed[0])));
            if ([a0 isEqualToString:@"d"]) return @((int)((int (*)(double))funcPtr)(ASUnboxDouble(boxed[0])));
        }
        if (n == 2) {
            NSString *a0 = argTypes[0], *a1 = argTypes[1];
            if (ASTypeIsIntLike(a0) && ASTypeIsIntLike(a1))
                return @(((int (*)(int, int))funcPtr)(ASUnboxInt(boxed[0]), ASUnboxInt(boxed[1])));
        }
    }

    // ---- long long / unsigned long long return ----
    if ([ret isEqualToString:@"q"] || [ret isEqualToString:@"Q"]) {
        if (n == 0) return @(((long long (*)(void))funcPtr)());
        if (n == 1) {
            NSString *a0 = argTypes[0];
            if ([a0 isEqualToString:@"q"] || [a0 isEqualToString:@"Q"])
                return @(((long long (*)(long long))funcPtr)(ASUnboxLongLong(boxed[0])));
            if (ASTypeIsIntLike(a0))
                return @(((long long (*)(int))funcPtr)(ASUnboxInt(boxed[0])));
        }
    }

    // ---- id return ----
    if ([ret isEqualToString:@"@"]) {
        if (n == 0) return ((id (*)(void))funcPtr)();
        if (n == 1 && [argTypes[0] isEqualToString:@"@"])
            return ((id (*)(id))funcPtr)(boxed[0]);
        if (n == 2 && [argTypes[0] isEqualToString:@"@"] && [argTypes[1] isEqualToString:@"@"])
            return ((id (*)(id, id))funcPtr)(boxed[0], boxed[1]);
    }

    // ---- C string return ----
    if ([ret isEqualToString:@"*"]) {
        if (n == 0) {
            const char *r = ((const char *(*)(void))funcPtr)();
            return r ? @(r) : nil;
        }
        if (n == 1 && [argTypes[0] isEqualToString:@"*"]) {
            const char *r = ((const char *(*)(const char *))funcPtr)(ASUnboxCString(boxed[0]));
            return r ? @(r) : nil;
        }
    }

    NSLog(@"ASBridgeSupportInstaller: unsupported C function signature ret=%@ args=%@", ret, argTypes);
    return nil;
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

    // Extract the boxed id arguments (the method signature uses all-@ encoding).
    NSUInteger argCount = info.argTypeEncodings.count;
    NSMutableArray<id> *boxedArgs = [NSMutableArray arrayWithCapacity:argCount];
    for (NSUInteger i = 0; i < argCount; i++) {
        __unsafe_unretained id boxedArg = nil;
        [invocation getArgument:&boxedArg atIndex:(NSInteger)(i + 2)];
        [boxedArgs addObject:boxedArg ?: [NSNull null]];
    }

    // Call the C function and set the boxed result as the return value.
    id result = ASCallCFunction(info.funcPtr,
                                info.returnTypeEncoding,
                                info.argTypeEncodings,
                                boxedArgs);
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
            // More than 4 arguments — not currently supported.
            continue;
        }

        // Resolve the C function symbol at install time.
        void *funcPtr = dlsym(RTLD_DEFAULT, function.name.UTF8String);
        if (funcPtr == NULL) {
            // Symbol not available in the current process — skip silently.
            continue;
        }

        // Build the ObjC selector: "funcName" (0 args), "funcName:" (1 arg), "funcName::" (2), etc.
        NSMutableString *selectorString = [NSMutableString stringWithString:function.name];
        for (NSUInteger i = 0; i < argCount; i++) {
            [selectorString appendString:@":"];
        }

        _ASFunctionInfo *info = [[_ASFunctionInfo alloc]
            initWithFuncPtr:funcPtr
         returnTypeEncoding:function.returnTypeEncoding
            argTypeEncodings:function.argumentTypeEncodings];
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
