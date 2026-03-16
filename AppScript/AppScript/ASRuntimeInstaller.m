// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASRuntimeInstaller.m — Registers parsed AppScript class definitions with the Objective-C runtime
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

#import "ASRuntimeInstaller.h"
#import "ASClassDefinitionNode.h"
#import "ASCategoryDefinitionNode.h"
#import "ASMethodNode.h"
#import "ASPropertyNode.h"
#import "ASInterpreter.h"
#import "ASBoxer.h"

#import <objc/runtime.h>
#import <objc/message.h>

// ---------------------------------------------------------------------------
// Error domain constant
// ---------------------------------------------------------------------------

NSString * const ASRuntimeInstallerErrorDomain = @"ASRuntimeInstallerErrorDomain";

// ---------------------------------------------------------------------------
// Associated-object keys
// ---------------------------------------------------------------------------

// Key for the per-class NSDictionary<NSString *, ASMethodNode *> mapping selector string → method node.
static char ASMethodMapKey;

// Key for the per-class NSString → script path, so forwardInvocation: can report errors correctly.
static char ASScriptPathKey;

// Key for the per-class ASInterpreter reference.
static char ASInterpreterKey;

// ---------------------------------------------------------------------------
// Global property-key store
// Guarded by ASPropertyKeysQueue for writes; safe to read after installation.
// ---------------------------------------------------------------------------

static dispatch_queue_t ASPropertyKeysQueue;
// Maps "ClassName.propertyName" → NSString key object (used as pointer key for associated objects).
static NSMutableDictionary<NSString *, NSString *> *ASPropertyKeys;

// ---------------------------------------------------------------------------
// Global registry of AppScript-installed classes.
// Guarded by ASRegisteredClassesQueue for all accesses.
// ---------------------------------------------------------------------------

static dispatch_queue_t ASRegisteredClassesQueue;
static NSMutableArray<NSValue *> *ASRegisteredClassValues; // NSValue wrapping Class

// ---------------------------------------------------------------------------
// Helper: build an ObjC type encoding for a method returning id with N id params.
// Result is like "@@:" (0 params), "@@:@" (1 param), "@@:@@" (2 params), etc.
//
// Returns a pointer to a static C string (safe to use with runtime APIs).
// Supports 0–16 parameters; asserts on larger counts.
// ---------------------------------------------------------------------------

static const char * const ASTypeEncodings[] = {
    "@@:",          // 0 params
    "@@:@",         // 1 param
    "@@:@@",        // 2 params
    "@@:@@@",       // 3 params
    "@@:@@@@",      // 4 params
    "@@:@@@@@",     // 5 params
    "@@:@@@@@@",    // 6 params
    "@@:@@@@@@@",   // 7 params
    "@@:@@@@@@@@",  // 8 params
    "@@:@@@@@@@@@", // 9 params
    "@@:@@@@@@@@@@",            // 10 params
    "@@:@@@@@@@@@@@",           // 11 params
    "@@:@@@@@@@@@@@@",          // 12 params
    "@@:@@@@@@@@@@@@@",         // 13 params
    "@@:@@@@@@@@@@@@@@",        // 14 params
    "@@:@@@@@@@@@@@@@@@",       // 15 params
    "@@:@@@@@@@@@@@@@@@@",      // 16 params
};

static const char *ASTypeEncodingForParamCount(NSUInteger paramCount) {
    NSCAssert(paramCount <= 16, @"ASRuntimeInstaller: methods with more than 16 parameters are not supported");
    return ASTypeEncodings[paramCount];
}

// ---------------------------------------------------------------------------
// forwardInvocation: IMP — shared by all AppScript-installed classes.
// Looks up the method node from the per-class map, boxes arguments, calls
// the interpreter, then unboxes the return value back into the invocation.
// ---------------------------------------------------------------------------

/// Walk the class hierarchy from `startClass` upward to find the class whose associated
/// ASMethodMapKey contains an entry for `selectorString`. Returns Nil if not found.
static Class ASFindMethodMapClassForSelector(Class startClass, NSString *selectorString) {
    Class cls = startClass;
    while (cls != Nil) {
        NSDictionary<NSString *, ASMethodNode *> *map = objc_getAssociatedObject(cls, &ASMethodMapKey);
        if (map[selectorString] != nil) {
            return cls;
        }
        cls = class_getSuperclass(cls);
    }
    return Nil;
}

/// Walk the class hierarchy from `startClass` upward to find the first class that has
/// an AppScript method map installed (i.e., the class where our forwarding overrides live).
/// Returns Nil if not found. Used to determine the correct super_class for objc_msgSendSuper
/// fallbacks, so that we don't recurse back into our own override.
static Class ASFindLowestInstalledOverrideClass(Class startClass) {
    Class cls = startClass;
    while (cls != Nil) {
        if (objc_getAssociatedObject(cls, &ASMethodMapKey) != nil) {
            return cls;
        }
        cls = class_getSuperclass(cls);
    }
    return Nil;
}

static void ASForwardInvocationIMP(id self, SEL _cmd, NSInvocation *invocation) {
    // When self is a class object (class-method dispatch), object_getClass(self) is the
    // metaclass — but the method map is stored on the class object itself, so use self
    // directly as the lookup start.
    BOOL isClassDispatch = class_isMetaClass(object_getClass(self));
    Class cls = isClassDispatch ? (Class)self : object_getClass(self);
    NSString *selectorString = NSStringFromSelector(invocation.selector);

    // Walk the class hierarchy to find which class installed this method.
    Class methodClass = ASFindMethodMapClassForSelector(cls, selectorString);

    if (methodClass == Nil) {
        // Not an AppScript method — call super's forwardInvocation:.
        // Use the superclass of the class where our override is actually installed, not
        // class_getSuperclass(cls), to avoid re-entering our own IMP when cls is a subclass
        // of the class that has the override (e.g., a class cluster concrete class).
        Class overrideClass = ASFindLowestInstalledOverrideClass(cls);
        Class superClass = overrideClass ? class_getSuperclass(overrideClass) : class_getSuperclass(cls);
        struct objc_super superInfo = { .receiver = self, .super_class = superClass };
        ((void (*)(struct objc_super *, SEL, NSInvocation *))objc_msgSendSuper)(&superInfo,
                                                                                  @selector(forwardInvocation:),
                                                                                  invocation);
        return;
    }

    NSDictionary<NSString *, ASMethodNode *> *methodMap =
        objc_getAssociatedObject(methodClass, &ASMethodMapKey);
    NSString *scriptPath = objc_getAssociatedObject(methodClass, &ASScriptPathKey);
    ASInterpreter *interpreter = objc_getAssociatedObject(methodClass, &ASInterpreterKey);
    ASMethodNode *methodNode = methodMap[selectorString];
    // methodNode is guaranteed non-nil: ASFindMethodMapClassForSelector found it.

    // Box all arguments.
    NSUInteger paramCount = methodNode.parameterNames.count;
    NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:paramCount];
    for (NSUInteger i = 0; i < paramCount; i++) {
        id boxed = [ASBoxer boxedArgumentAtIndex:i fromInvocation:invocation];
        [arguments addObject:boxed ?: [NSNull null]];
    }

    // Evaluate the method body via the interpreter.
    // Pass methodClass as the defining class so that [super ...] sends dispatch
    // starting from [methodClass superclass], matching objc_msgSendSuper semantics.
    id result = [interpreter evaluateMethodBody:methodNode.body
                                   withReceiver:self
                                  definingClass:methodClass
                                       selector:selectorString
                                      arguments:arguments
                                 parameterNames:methodNode.parameterNames
                                     scriptPath:scriptPath ?: @"<unknown>"];

    // Unbox the result back into the invocation if the return type is non-void.
    const char *returnType = invocation.methodSignature.methodReturnType;
    if (returnType[0] != 'v') {
        [ASBoxer unboxObject:result intoReturnValueOfInvocation:invocation];
    }
}

// ---------------------------------------------------------------------------
// methodSignatureForSelector: IMP — shared by all AppScript-installed classes.
// Prefers the real protocol/superclass signature so that primitive parameters
// (e.g., NSInteger row in NSTableViewDelegate) are boxed correctly by ASBoxer.
// Falls back to an all-id encoding when no real signature is available.
// ---------------------------------------------------------------------------

/// Walk cls and its superclass chain, checking all adopted protocols for a method
/// description matching `selector`. Returns the raw ObjC type encoding string
/// (from protocol data — valid for the lifetime of the process) or NULL if not found.
/// Checks both required and optional instance methods.
static const char *ASProtocolTypeEncodingForSelector(Class cls, SEL selector) {
    while (cls != Nil) {
        unsigned int protocolCount = 0;
        Protocol * __unsafe_unretained *protocols = class_copyProtocolList(cls, &protocolCount);
        for (unsigned int i = 0; i < protocolCount; i++) {
            struct objc_method_description desc =
                protocol_getMethodDescription(protocols[i], selector, YES, YES);
            if (desc.name != NULL && desc.types != NULL) {
                free(protocols);
                return desc.types;
            }
            desc = protocol_getMethodDescription(protocols[i], selector, NO, YES);
            if (desc.name != NULL && desc.types != NULL) {
                free(protocols);
                return desc.types;
            }
        }
        if (protocols) free(protocols);
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

/// Search the protocols adopted by `cls` (and its superclasses) for a method description
/// matching `selector`. Returns nil if not found.
static NSMethodSignature *ASProtocolMethodSignatureForSelector(Class cls, SEL selector) {
    const char *types = ASProtocolTypeEncodingForSelector(cls, selector);
    return types ? [NSMethodSignature signatureWithObjCTypes:types] : nil;
}

static NSMethodSignature *ASMethodSignatureForSelectorIMP(id self, SEL _cmd, SEL selector) {
    BOOL isClassDispatch = class_isMetaClass(object_getClass(self));
    Class cls = isClassDispatch ? (Class)self : object_getClass(self);
    NSString *selectorString = NSStringFromSelector(selector);

    // Walk the class hierarchy to find which class installed this method.
    Class methodClass = ASFindMethodMapClassForSelector(cls, selectorString);

    if (methodClass == Nil) {
        // Fall back to super's methodSignatureForSelector:.
        // Use the superclass of the class where our override is actually installed, not
        // class_getSuperclass(cls), to avoid re-entering our own IMP when cls is a subclass
        // of the class that has the override (e.g., a class cluster concrete class).
        Class overrideClass = ASFindLowestInstalledOverrideClass(cls);
        Class superClass = overrideClass ? class_getSuperclass(overrideClass) : class_getSuperclass(cls);
        struct objc_super superInfo = { .receiver = self, .super_class = superClass };
        return ((NSMethodSignature *(*)(struct objc_super *, SEL, SEL))objc_msgSendSuper)(&superInfo,
                                                                                            @selector(methodSignatureForSelector:),
                                                                                            selector);
    }

    // Prefer the real signature from a protocol the class conforms to (e.g.
    // NSTableViewDelegate declares tableView:viewForTableColumn:row: with an
    // NSInteger row parameter). Using the real signature ensures ASBoxer correctly
    // boxes/unboxes primitive parameters rather than misreading them as object pointers.
    NSMethodSignature *protocolSig = ASProtocolMethodSignatureForSelector(cls, selector);
    if (protocolSig != nil) {
        return protocolSig;
    }

    NSDictionary<NSString *, ASMethodNode *> *methodMap =
        objc_getAssociatedObject(methodClass, &ASMethodMapKey);
    ASMethodNode *methodNode = methodMap[selectorString];

    NSUInteger paramCount = methodNode.parameterNames.count;
    const char *encoding = ASTypeEncodingForParamCount(paramCount);
    return [NSMethodSignature signatureWithObjCTypes:encoding];
}

// ---------------------------------------------------------------------------
// Property getter/setter block helpers
// ---------------------------------------------------------------------------

// Returns the NSString * that serves as the associated-object key for a given property
// on a given class. The strings are stored in the global ASPropertyKeys dict under
// "ClassName.propertyName". The returned NSString * pointer is used as the key itself.
static NSString * ASPropertyKeyForClassAndName(NSString *className, NSString *propertyName) {
    NSString *compositeKey = [NSString stringWithFormat:@"%@.%@", className, propertyName];
    __block NSString *keyObject = nil;
    dispatch_sync(ASPropertyKeysQueue, ^{
        keyObject = ASPropertyKeys[compositeKey];
        if (keyObject == nil) {
            // Store the composite key string in the dict; its pointer identity is the assoc key.
            ASPropertyKeys[compositeKey] = compositeKey;
            keyObject = compositeKey;
        }
    });
    return keyObject;
}

// ---------------------------------------------------------------------------
// Private implementation
// ---------------------------------------------------------------------------

@interface ASRuntimeInstaller ()
@property (nonatomic, strong) ASInterpreter *interpreter;
@end

@implementation ASRuntimeInstaller

// ---------------------------------------------------------------------------
// Class setup
// ---------------------------------------------------------------------------

+ (void)initialize {
    if (self == [ASRuntimeInstaller class]) {
        ASPropertyKeysQueue = dispatch_queue_create("_ASPropertyKeysQueue", DISPATCH_QUEUE_SERIAL);
        ASPropertyKeys = [NSMutableDictionary dictionary];
        ASRegisteredClassesQueue = dispatch_queue_create("_ASRegisteredClassesQueue", DISPATCH_QUEUE_SERIAL);
        ASRegisteredClassValues = [NSMutableArray array];
    }
}

+ (nullable ASMethodNode *)appScriptMethodNodeForSuperDispatch:(Class)startClass
                                                      selector:(NSString *)selectorString
                                                 definingClass:(Class _Nullable * _Nullable)outDefiningClass {
    Class methodClass = ASFindMethodMapClassForSelector(startClass, selectorString);
    if (methodClass == Nil) {
        return nil;
    }
    NSDictionary<NSString *, ASMethodNode *> *map = objc_getAssociatedObject(methodClass, &ASMethodMapKey);
    ASMethodNode *methodNode = map[selectorString];
    if (outDefiningClass != NULL) {
        *outDefiningClass = methodClass;
    }
    return methodNode;
}

+ (NSArray<Class> *)registeredClasses {
    __block NSArray<NSValue *> *snapshot;
    dispatch_sync(ASRegisteredClassesQueue, ^{
        snapshot = [ASRegisteredClassValues copy];
    });
    NSMutableArray<Class> *result = [NSMutableArray arrayWithCapacity:snapshot.count];
    for (NSValue *v in snapshot) {
        [result addObject:v.nonretainedObjectValue];
    }
    return [result copy];
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

- (instancetype)init {
    self = [super init];
    if (self) {
        _interpreter = [[ASInterpreter alloc] init];
    }
    return self;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

- (BOOL)installNodes:(NSArray<ASASTNode *> *)nodes
          scriptPath:(NSString *)scriptPath
               error:(NSError **)error {
    for (ASASTNode *node in nodes) {
        if ([node isKindOfClass:[ASClassDefinitionNode class]]) {
            ASClassDefinitionNode *classDef = (ASClassDefinitionNode *)node;
            if (![self installClassDefinition:classDef scriptPath:scriptPath error:error]) {
                return NO;
            }
        } else if ([node isKindOfClass:[ASCategoryDefinitionNode class]]) {
            ASCategoryDefinitionNode *categoryDef = (ASCategoryDefinitionNode *)node;
            if (![self installCategoryDefinition:categoryDef scriptPath:scriptPath error:error]) {
                return NO;
            }
        }
        // Other node types are silently ignored.
    }
    return YES;
}

// ---------------------------------------------------------------------------
// Class definition installation
// ---------------------------------------------------------------------------

- (BOOL)installClassDefinition:(ASClassDefinitionNode *)classDef
                    scriptPath:(NSString *)scriptPath
                         error:(NSError **)error {
    NSString *className = classDef.className;
    NSString *superclassName = classDef.superclassName ?: @"NSObject";

    // 1. Look up the superclass.
    Class superclass = NSClassFromString(superclassName);
    if (superclass == Nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASRuntimeInstallerErrorDomain
                                         code:ASRuntimeInstallerErrorUnknownSuperclass
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Unknown superclass '%@' for class '%@' in %@",
                    superclassName, className, scriptPath],
            }];
        }
        return NO;
    }

    // 2. Check for duplicate class.
    if (NSClassFromString(className) != Nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASRuntimeInstallerErrorDomain
                                         code:ASRuntimeInstallerErrorDuplicateClass
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Class '%@' is already registered in %@",
                    className, scriptPath],
            }];
        }
        return NO;
    }

    // 3. Allocate the class pair.
    Class newClass = objc_allocateClassPair(superclass, className.UTF8String, 0);
    if (newClass == Nil) {
        // objc_allocateClassPair can return nil if the name is taken (race condition).
        if (error) {
            *error = [NSError errorWithDomain:ASRuntimeInstallerErrorDomain
                                         code:ASRuntimeInstallerErrorDuplicateClass
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Failed to allocate class pair for '%@' in %@",
                    className, scriptPath],
            }];
        }
        return NO;
    }

    // 4. Add protocol conformances.
    for (NSString *protocolName in classDef.protocolNames) {
        Protocol *proto = objc_getProtocol(protocolName.UTF8String);
        if (proto != NULL) {
            class_addProtocol(newClass, proto);
        }
    }

    // 5. Install forwardInvocation: and methodSignatureForSelector: overrides on both
    //    the class (for instance methods) and its metaclass (for class methods).
    [self installForwardingOverridesOnClass:newClass];
    [self installForwardingOverridesOnClass:object_getClass(newClass)];

    // 6. Build the per-class method map (selector string → ASMethodNode).
    NSMutableDictionary<NSString *, ASMethodNode *> *methodMap = [NSMutableDictionary dictionary];
    for (ASMethodNode *methodNode in classDef.methods) {
        methodMap[methodNode.selector] = methodNode;
    }

    // Store the method map and supporting data as associated objects on the *class object*.
    objc_setAssociatedObject(newClass, &ASMethodMapKey,
                             [methodMap copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(newClass, &ASScriptPathKey,
                             scriptPath,
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(newClass, &ASInterpreterKey,
                             self.interpreter,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 7. Add properties and synthesize KVC accessors.
    for (ASPropertyNode *propertyNode in classDef.properties) {
        [self addProperty:propertyNode toClass:newClass className:className];
    }

    // 8. Register the class pair before installing sentinels so that
    //    class_copyProtocolList returns the protocols added in step 4.
    objc_registerClassPair(newClass);

    // 9. Install sentinel IMP for each method selector (routes through forwarding).
    //    Done after registration so ASProtocolTypeEncodingForSelector can walk the
    //    protocol list and return the correct encoding (e.g., BOOL instead of id).
    for (ASMethodNode *methodNode in classDef.methods) {
        [self installSentinelForMethodNode:methodNode onClass:newClass];
    }

    // 10. Record in the global AppScript class registry.
    NSValue *classValue = [NSValue valueWithNonretainedObject:newClass];
    dispatch_sync(ASRegisteredClassesQueue, ^{
        [ASRegisteredClassValues addObject:classValue];
    });

    return YES;
}

// ---------------------------------------------------------------------------
// Category definition installation
// ---------------------------------------------------------------------------

- (BOOL)installCategoryDefinition:(ASCategoryDefinitionNode *)categoryDef
                        scriptPath:(NSString *)scriptPath
                             error:(NSError **)error {
    NSString *className = categoryDef.className;

    // 1. Look up the existing class.
    Class existingClass = NSClassFromString(className);
    if (existingClass == Nil) {
        if (error) {
            *error = [NSError errorWithDomain:ASRuntimeInstallerErrorDomain
                                         code:ASRuntimeInstallerErrorUnknownClass
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Unknown class '%@' for category '%@' in %@",
                    className, categoryDef.categoryName, scriptPath],
            }];
        }
        return NO;
    }

    // Retrieve or create the per-class method map.
    NSMutableDictionary<NSString *, ASMethodNode *> *methodMap =
        [(NSDictionary *)objc_getAssociatedObject(existingClass, &ASMethodMapKey) mutableCopy];
    if (methodMap == nil) {
        methodMap = [NSMutableDictionary dictionary];
    }

    // Install forwardInvocation:/methodSignatureForSelector: if not already present
    // (the class may be a plain NSObject subclass, not previously installed by us).
    [self installForwardingOverridesOnClass:existingClass];

    // Ensure interpreter and script path are set.
    if (objc_getAssociatedObject(existingClass, &ASInterpreterKey) == nil) {
        objc_setAssociatedObject(existingClass, &ASInterpreterKey,
                                 self.interpreter,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (objc_getAssociatedObject(existingClass, &ASScriptPathKey) == nil) {
        objc_setAssociatedObject(existingClass, &ASScriptPathKey,
                                 scriptPath,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
    }

    // 2. For each method node, install a sentinel IMP using class_replaceMethod (category semantics).
    for (ASMethodNode *methodNode in categoryDef.methods) {
        methodMap[methodNode.selector] = methodNode;
        SEL sel = NSSelectorFromString(methodNode.selector);
        const char *encoding = ASProtocolTypeEncodingForSelector(existingClass, sel);
        if (encoding == NULL) {
            encoding = ASTypeEncodingForParamCount(methodNode.parameterNames.count);
        }
        // Categories replace existing implementations.
        class_replaceMethod(existingClass, sel, (IMP)_objc_msgForward, encoding);
    }

    // Update the method map associated object.
    objc_setAssociatedObject(existingClass, &ASMethodMapKey,
                             [methodMap copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return YES;
}

// ---------------------------------------------------------------------------
// Install forwardInvocation: and methodSignatureForSelector: on a class
// (idempotent — checks for existing override before installing).
// ---------------------------------------------------------------------------

- (void)installForwardingOverridesOnClass:(Class)cls {
    // imp_implementationWithBlock: the block's first arg is `self`; subsequent args are the
    // method's explicit parameters (self and _cmd are NOT in the block signature).

    // methodSignatureForSelector: — type encoding "@@::" (returns id, takes id self + SEL _cmd + SEL sel)
    SEL msfsSel = @selector(methodSignatureForSelector:);
    IMP msfsIMP = imp_implementationWithBlock(^NSMethodSignature *(id blockSelf, SEL selector) {
        return ASMethodSignatureForSelectorIMP(blockSelf, NULL, selector);
    });
    class_replaceMethod(cls, msfsSel, msfsIMP, "@@::");

    // forwardInvocation: — type encoding "v@:@" (returns void, takes id self + SEL _cmd + id inv)
    SEL fiSel = @selector(forwardInvocation:);
    IMP fiIMP = imp_implementationWithBlock(^void(id blockSelf, NSInvocation *inv) {
        ASForwardInvocationIMP(blockSelf, NULL, inv);
    });
    class_replaceMethod(cls, fiSel, fiIMP, "v@:@");
}

// ---------------------------------------------------------------------------
// Install sentinel IMP (routes through _objc_msgForward) for a method node.
// ---------------------------------------------------------------------------

- (void)installSentinelForMethodNode:(ASMethodNode *)methodNode onClass:(Class)cls {
    SEL sel = NSSelectorFromString(methodNode.selector);
    // Class methods must be installed on the metaclass so the ObjC runtime finds them
    // when the selector is sent to the class object itself.
    Class targetClass = methodNode.isClassMethod ? object_getClass(cls) : cls;
    const char *encoding = ASProtocolTypeEncodingForSelector(targetClass, sel);
    if (encoding == NULL) {
        encoding = ASTypeEncodingForParamCount(methodNode.parameterNames.count);
    }
    class_addMethod(targetClass, sel, (IMP)_objc_msgForward, encoding);
}

// ---------------------------------------------------------------------------
// Property synthesis
// ---------------------------------------------------------------------------

- (void)addProperty:(ASPropertyNode *)propertyNode
            toClass:(Class)cls
          className:(NSString *)className {
    NSString *propertyName = propertyNode.propertyName;
    NSArray<NSString *> *modifiers = propertyNode.modifiers;

    // Check dynamic modifier — skip synthesis entirely.
    if ([modifiers containsObject:@"dynamic"]) {
        return;
    }

    BOOL isReadonly = [modifiers containsObject:@"readonly"];
    BOOL isCopy = [modifiers containsObject:@"copy"];
    BOOL isWeak = [modifiers containsObject:@"weak"];
    objc_AssociationPolicy policy = isWeak
        ? OBJC_ASSOCIATION_ASSIGN
        : (isCopy ? OBJC_ASSOCIATION_COPY_NONATOMIC : OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Register the property with ObjC runtime metadata.
    // Each objc_property_attribute_t has a single-character `name` (the attribute code)
    // and a `value` (the type encoding or empty string for flag attributes).
    //   T@ → object type
    //   & → strong retain
    //   C → copy
    //   W → weak
    //   R → readonly
    // We build a small attribute list on the stack.
    objc_property_attribute_t propAttrs[4];
    unsigned int attrCount = 0;
    propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "T", .value = "@" };
    if (isCopy) {
        propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "C", .value = "" };
        propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "&", .value = "" };
    } else if (isWeak) {
        propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "W", .value = "" };
    } else {
        // strong (default)
        propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "&", .value = "" };
    }
    if (isReadonly) {
        propAttrs[attrCount++] = (objc_property_attribute_t){ .name = "R", .value = "" };
    }
    class_addProperty(cls, propertyName.UTF8String, propAttrs, attrCount);

    // Retrieve/create the key string for this property's associated object.
    NSString *keyObject = ASPropertyKeyForClassAndName(className, propertyName);

    // The method map was stored as an associated object in the step before property synthesis.
    // Skip synthesizing any accessor whose selector is already covered by an AppScript method
    // definition — the custom method takes priority, matching Objective-C @synthesize semantics.
    NSDictionary<NSString *, ASMethodNode *> *methodMap =
        objc_getAssociatedObject(cls, &ASMethodMapKey);

    // --- Getter ---
    SEL getterSel = NSSelectorFromString(propertyName);
    if (methodMap[propertyName] == nil) {
        IMP getterIMP = imp_implementationWithBlock(^id(id blockSelf) {
            return objc_getAssociatedObject(blockSelf, (__bridge const void *)keyObject);
        });
        class_addMethod(cls, getterSel, getterIMP, "@@:");
    }

    if (isReadonly) {
        return;
    }

    // --- Setter ---
    // Build setFoo: selector from property name.
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:",
                            [[propertyName substringToIndex:1] uppercaseString],
                            [propertyName substringFromIndex:1]];
    if (methodMap[setterName] == nil) {
        SEL setterSel = NSSelectorFromString(setterName);

        // Capture policy and keyObject in a block; capture by value.
        objc_AssociationPolicy capturedPolicy = policy;
        IMP setterIMP = imp_implementationWithBlock(^void(id blockSelf, id value) {
            objc_setAssociatedObject(blockSelf, (__bridge const void *)keyObject, value, capturedPolicy);
        });
        class_addMethod(cls, setterSel, setterIMP, "v@:@");
    }
}

@end
