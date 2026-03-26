// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASStructValue.m — Boxed C struct with named field accessor dispatch
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

#import "ASStructValue.h"
#import "ASBridgeSupportStruct.h"
#import "ASBridgeSupportStructField.h"

#import <objc/runtime.h>
#import <objc/message.h>

// ---------------------------------------------------------------------------
// Process-wide struct registry
// Owned by _ASStructRegistryQueue (a serial dispatch queue).
// ---------------------------------------------------------------------------

static NSMutableDictionary<NSString *, ASBridgeSupportStruct *> *_ASStructRegistry = nil;
static dispatch_queue_t _ASStructRegistryQueue;
static dispatch_once_t  _ASStructRegistryOnce;
static BOOL             _ASStructForwardingInstalled = NO;

// ---------------------------------------------------------------------------
// Helper: extract the canonical struct name from a type encoding.
// e.g. "{CGPoint=dd}" -> "CGPoint", "{_NSRange=QQ}" -> "_NSRange", "{CGPoint}" -> "CGPoint"
// Returns nil if the encoding is not a struct.
// ---------------------------------------------------------------------------

static NSString * _Nullable ASExtractStructName(NSString *typeEncoding) {
    const char *s = typeEncoding.UTF8String;
    if (!s || s[0] != '{') return nil;
    const char *start = s + 1;
    const char *p = start;
    while (*p && *p != '=' && *p != '}') { p++; }
    if (p == start) return nil;
    return [[NSString alloc] initWithBytes:start
                                    length:(NSUInteger)(p - start)
                                  encoding:NSUTF8StringEncoding];
}

// ---------------------------------------------------------------------------
// Helper: compute size and alignment for a field type encoding.
// Handles both well-specified encodings (e.g. "{CGPoint=dd}") and bare struct
// references (e.g. "{CGPoint}") by falling back to a recursive registry lookup.
// Must be called while holding the registry lock (or passing the registry directly).
// ---------------------------------------------------------------------------

static void ASSizeAndAlignForEncoding(NSString *typeEncoding,
                                      NSDictionary<NSString *, ASBridgeSupportStruct *> *registry,
                                      NSUInteger *outSize,
                                      NSUInteger *outAlign) {
    if ([typeEncoding hasPrefix:@"{"]) {
        // IMPORTANT: NSGetSizeAndAlignment throws NSInvalidArgumentException for bare struct
        // references like "{CGPoint}" because it tries to parse the struct name as type
        // encoding characters. Only call it for full encodings that contain '='.
        if ([typeEncoding containsString:@"="]) {
            NSUInteger size = 0, align = 0;
            NSGetSizeAndAlignment(typeEncoding.UTF8String, &size, &align);
            if (size > 0) {
                *outSize  = size;
                *outAlign = (align > 0) ? align : 1;
                return;
            }
        }
        // Bare struct reference (e.g. "{CGPoint}") — compute from registry.
        NSString *name = ASExtractStructName(typeEncoding);
        ASBridgeSupportStruct *s = name ? registry[name] : nil;
        if (s && s.fields.count > 0) {
            NSUInteger totalSize = 0, maxAlign = 1;
            for (ASBridgeSupportStructField *field in s.fields) {
                NSUInteger fs = 0, fa = 0;
                ASSizeAndAlignForEncoding(field.typeEncoding, registry, &fs, &fa);
                if (fa > maxAlign) maxAlign = fa;
                // Align current offset to this field's alignment.
                totalSize = (totalSize + fa - 1) & ~(fa - 1);
                totalSize += fs;
            }
            // Round total size up to the struct's alignment.
            totalSize = (totalSize + maxAlign - 1) & ~(maxAlign - 1);
            *outSize  = totalSize;
            *outAlign = maxAlign;
            return;
        }
    } else {
        // Primitive type — safe to call NSGetSizeAndAlignment directly.
        NSUInteger size = 0, align = 0;
        NSGetSizeAndAlignment(typeEncoding.UTF8String, &size, &align);
        if (size > 0) {
            *outSize  = size;
            *outAlign = (align > 0) ? align : 1;
            return;
        }
    }
    *outSize  = 0;
    *outAlign = 1;
}

// ---------------------------------------------------------------------------
// Helper: build a full runtime type encoding string for a struct from the registry.
// e.g. "CGPoint" + registry -> "{CGPoint=dd}"
// If the struct is unknown or has no fields, returns "{name}".
// ---------------------------------------------------------------------------

static NSString *ASBuildRuntimeEncoding(ASBridgeSupportStruct *s,
                                        NSDictionary<NSString *, ASBridgeSupportStruct *> *registry);

static NSString *ASBuildRuntimeEncodingForFieldType(NSString *fieldTypeEncoding,
                                                    NSDictionary<NSString *, ASBridgeSupportStruct *> *registry) {
    if (![fieldTypeEncoding hasPrefix:@"{"]) {
        return fieldTypeEncoding; // primitive — return as-is
    }
    // Check whether this is already a full encoding (contains '=').
    if ([fieldTypeEncoding containsString:@"="]) {
        return fieldTypeEncoding;
    }
    // Bare struct reference like "{CGPoint}" — resolve from registry.
    NSString *name = ASExtractStructName(fieldTypeEncoding);
    if (!name) return fieldTypeEncoding;
    ASBridgeSupportStruct *nested = registry[name];
    if (!nested) return fieldTypeEncoding;
    return ASBuildRuntimeEncoding(nested, registry);
}

static NSString *ASBuildRuntimeEncoding(ASBridgeSupportStruct *s,
                                        NSDictionary<NSString *, ASBridgeSupportStruct *> *registry) {
    if (s.fields.count == 0) {
        return [NSString stringWithFormat:@"{%@}", s.canonicalName];
    }
    NSMutableString *enc = [NSMutableString stringWithFormat:@"{%@=", s.canonicalName];
    for (ASBridgeSupportStructField *field in s.fields) {
        [enc appendString:ASBuildRuntimeEncodingForFieldType(field.typeEncoding, registry)];
    }
    [enc appendString:@"}"];
    return [enc copy];
}

// ---------------------------------------------------------------------------
// forwardInvocation: / methodSignatureForSelector: — installed once on ASStructValue
// ---------------------------------------------------------------------------

@implementation ASStructValue

+ (void)_ensureRegistryInitialized {
    dispatch_once(&_ASStructRegistryOnce, ^{
        _ASStructRegistry = [NSMutableDictionary dictionary];
        _ASStructRegistryQueue = dispatch_queue_create("com.appscript.structregistry",
                                                       DISPATCH_QUEUE_SERIAL);
    });
}

- (instancetype)initWithBytes:(const void *)bytes
                       length:(NSUInteger)length
                 canonicalName:(NSString *)canonicalName
           runtimeTypeEncoding:(NSString *)runtimeTypeEncoding {
    self = [super init];
    if (self) {
        _canonicalName         = [canonicalName copy];
        _runtimeTypeEncoding   = [runtimeTypeEncoding copy];
        _bytes                 = [NSData dataWithBytes:bytes length:length];
    }
    return self;
}

- (NSValue *)asNSValue {
    return [NSValue valueWithBytes:_bytes.bytes objCType:_runtimeTypeEncoding.UTF8String];
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

+ (void)registerStruct:(ASBridgeSupportStruct *)bridgeSupportStruct {
    [self _ensureRegistryInitialized];

    dispatch_sync(_ASStructRegistryQueue, ^{
        NSString *name = bridgeSupportStruct.canonicalName;
        if (_ASStructRegistry[name] != nil) {
            return; // Already registered — no-op.
        }
        _ASStructRegistry[name] = bridgeSupportStruct;

        // Install a sentinel instance method for each field so the ObjC runtime
        // routes the message through forwardInvocation:.
        //
        // IMPORTANT: class_addMethod only checks the *immediate* class, not superclasses.
        // Foundation BridgeSupport defines structs (e.g. NSHashTableCallBacks) with fields
        // named "retain", "release", and "hash". If we installed _objc_msgForward for those
        // selectors, ARC's retain/release calls on ASStructValue instances would re-enter
        // forwardInvocation: and cause infinite recursion. Guard with instancesRespondToSelector:
        // which checks the full class hierarchy, skipping any selector already handled there.
        for (ASBridgeSupportStructField *field in bridgeSupportStruct.fields) {
            SEL sel = NSSelectorFromString(field.name);
            if (![ASStructValue instancesRespondToSelector:sel]) {
                class_addMethod([ASStructValue class], sel, (IMP)_objc_msgForward, "@@:");
            }
        }

        // Install forwardInvocation: and methodSignatureForSelector: once.
        if (!_ASStructForwardingInstalled) {
            _ASStructForwardingInstalled = YES;

            IMP msfsIMP = imp_implementationWithBlock(^NSMethodSignature *(ASStructValue *blockSelf, SEL sel) {
                // Check if this selector matches any field of the registered struct.
                ASBridgeSupportStruct *__block found = nil;
                dispatch_sync(_ASStructRegistryQueue, ^{
                    found = _ASStructRegistry[blockSelf->_canonicalName];
                });
                if (found) {
                    NSString *selName = NSStringFromSelector(sel);
                    for (ASBridgeSupportStructField *field in found.fields) {
                        if ([field.name isEqualToString:selName]) {
                            return [NSMethodSignature signatureWithObjCTypes:"@@:"];
                        }
                    }
                }
                return [blockSelf methodSignatureForSelectorFallback:sel];
            });
            class_replaceMethod([ASStructValue class],
                                @selector(methodSignatureForSelector:),
                                msfsIMP,
                                "@@::");

            IMP fiIMP = imp_implementationWithBlock(^void(ASStructValue *blockSelf, NSInvocation *inv) {
                // Ensure the invocation retains its return value. Without this, ARC releases
                // the result id at the end of this block scope, producing a dangling pointer
                // when the forwarding machinery reads the return value.
                if (!inv.argumentsRetained) {
                    [inv retainArguments];
                }
                NSString *selName = NSStringFromSelector(inv.selector);

                __block NSDictionary<NSString *, ASBridgeSupportStruct *> *snapshot = nil;
                dispatch_sync(_ASStructRegistryQueue, ^{
                    snapshot = [_ASStructRegistry copy];
                });

                ASBridgeSupportStruct *s = snapshot[blockSelf->_canonicalName];
                if (!s) {
                    [blockSelf forwardInvocationFallback:inv];
                    return;
                }

                // Find the target field and compute its byte offset.
                ASBridgeSupportStructField *targetField = nil;
                NSUInteger offset = 0;

                for (ASBridgeSupportStructField *field in s.fields) {
                    NSUInteger fieldSize = 0, fieldAlign = 0;
                    ASSizeAndAlignForEncoding(field.typeEncoding, snapshot, &fieldSize, &fieldAlign);
                    // Align current offset.
                    if (fieldAlign > 1) {
                        offset = (offset + fieldAlign - 1) & ~(fieldAlign - 1);
                    }
                    if ([field.name isEqualToString:selName]) {
                        targetField = field;
                        break;
                    }
                    offset += fieldSize;
                }

                if (!targetField) {
                    [blockSelf forwardInvocationFallback:inv];
                    return;
                }

                const uint8_t *base = (const uint8_t *)blockSelf->_bytes.bytes;
                const uint8_t *fieldPtr = base + offset;
                NSString *enc = targetField.typeEncoding;
                id result = nil;

                if ([enc isEqualToString:@"d"]) {
                    double v = 0.0;
                    memcpy(&v, fieldPtr, sizeof(double));
                    result = @(v);
                } else if ([enc isEqualToString:@"Q"]) {
                    unsigned long long v = 0;
                    memcpy(&v, fieldPtr, sizeof(unsigned long long));
                    result = @(v);
                } else if ([enc hasPrefix:@"{"]) {
                    // Nested struct — wrap as a new ASStructValue.
                    NSUInteger nestedSize = 0, nestedAlign = 0;
                    ASSizeAndAlignForEncoding(enc, snapshot, &nestedSize, &nestedAlign);
                    if (nestedSize > 0) {
                        NSString *nestedName = ASExtractStructName(enc);
                        ASBridgeSupportStruct *nestedStruct = nestedName ? snapshot[nestedName] : nil;
                        NSString *runtimeEnc = nestedStruct
                            ? ASBuildRuntimeEncoding(nestedStruct, snapshot)
                            : enc;
                        result = [[ASStructValue alloc] initWithBytes:fieldPtr
                                                               length:nestedSize
                                                         canonicalName:nestedName ?: enc
                                                   runtimeTypeEncoding:runtimeEnc];
                    }
                }

                if (result) {
                    [inv setReturnValue:&result];
                } else {
                    [blockSelf forwardInvocationFallback:inv];
                }
            });
            class_replaceMethod([ASStructValue class],
                                @selector(forwardInvocation:),
                                fiIMP,
                                "v@:@");
        }
    });
}

+ (nullable ASBridgeSupportStruct *)registeredStructNamed:(NSString *)canonicalName {
    [self _ensureRegistryInitialized];
    __block ASBridgeSupportStruct *result = nil;
    dispatch_sync(_ASStructRegistryQueue, ^{
        result = _ASStructRegistry[canonicalName];
    });
    return result;
}

// ---------------------------------------------------------------------------
// Fallback helpers (called from the installed IMPs when the selector is unknown)
// ---------------------------------------------------------------------------

- (NSMethodSignature *)methodSignatureForSelectorFallback:(SEL)sel {
    return [super methodSignatureForSelector:sel];
}

- (void)forwardInvocationFallback:(NSInvocation *)inv {
    [super forwardInvocation:inv];
}

// ---------------------------------------------------------------------------
// Description
// ---------------------------------------------------------------------------

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@: %@>",
            NSStringFromClass([self class]),
            _canonicalName,
            [self asNSValue]];
}

@end
