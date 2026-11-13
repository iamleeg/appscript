// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASInterpreter.m — AST-walking interpreter for AppScript methods
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

#import "ASInterpreter.h"
#import "ASScope.h"
#import "ASNull.h"
#import "ASOutObject.h"
#import <objc/runtime.h>
#import "ASBoxer.h"
#import "ASRuntimeInstaller.h"
#import "ASMethodNode.h"

// AST node types
#import "ASReturnNode.h"
#import "ASVariableDeclarationNode.h"
#import "ASAssignmentNode.h"
#import "ASMessageSendNode.h"
#import "ASBlockLiteralNode.h"
#import "ASIdentifierNode.h"
#import "ASStringLiteralNode.h"
#import "ASNumberLiteralNode.h"
#import "ASArrayLiteralNode.h"
#import "ASDictionaryLiteralNode.h"
#import "ASSuperNode.h"
#import "NSURL+AppScriptFileReading.h"

// ---------------------------------------------------------------------------
// Internal execution context
// ---------------------------------------------------------------------------

/// Per-invocation execution context. Carries the scope chain, weak/constant
/// variable sets, and a flag + holder for early return.
@interface ASExecutionContext : NSObject

@property (nonatomic, strong) ASScope *currentScope;
@property (nonatomic, strong) NSMutableSet<NSString *> *weakNames;
@property (nonatomic, strong) NSMutableSet<NSString *> *constantNames;
@property (nonatomic, strong, nullable) NSString *scriptPath;

/// The Objective-C class that statically defines the currently-executing method.
/// Used to resolve `super` sends: dispatch starts from [definingClass superclass].
@property (nonatomic, strong, nullable) Class definingClass;

/// YES once a return statement has been executed.
@property (nonatomic) BOOL didReturn;

/// The value provided by a return statement (may be nil even when didReturn is YES).
@property (nonatomic, strong, nullable) id returnValue;

/// Running count of block literals evaluated in this frame (used to synthesise
/// block frame names like `[ClassName method:]__block0`).
@property (nonatomic) NSUInteger blockCount;

- (instancetype)initWithScope:(ASScope *)scope
                 definingClass:(Class)definingClass
                   scriptPath:(NSString *)scriptPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation ASExecutionContext

- (instancetype)initWithScope:(ASScope *)scope
                 definingClass:(Class)definingClass
                   scriptPath:(NSString *)scriptPath {
    self = [super init];
    if (self) {
        _currentScope = scope;
        _definingClass = definingClass;
        _scriptPath = scriptPath;
        _weakNames = [NSMutableSet set];
        _constantNames = [NSMutableSet set];
        _didReturn = NO;
        _returnValue = nil;
    }
    return self;
}

@end

// ---------------------------------------------------------------------------
// ASCallFrame — one entry in the per-thread AppScript call stack
// ---------------------------------------------------------------------------

/// A snapshot of one active AppScript call frame, used to build the call-stack
/// section of an error report.
@interface ASCallFrame : NSObject

/// Synthesised display name: `-[ClassName selector:]` for methods,
/// `[ClassName method:]__blockN` for blocks.
@property (nonatomic, copy) NSString *frameName;

/// Declared parameter names, parallel to `arguments`.
@property (nonatomic, copy) NSArray<NSString *> *parameterNames;

/// Evaluated argument values, parallel to `parameterNames`.
@property (nonatomic, copy) NSArray *arguments;

/// File-system path of the `.appscript` source file containing this method.
@property (nonatomic, copy) NSString *scriptPath;

/// 1-based line number in the *calling* frame where this call was initiated;
/// 0 when called from ObjC (no AppScript call site).
@property (nonatomic) NSUInteger callSiteLine;

@end

@implementation ASCallFrame
@end

// ---------------------------------------------------------------------------
// Thread-local call stack helpers
// ---------------------------------------------------------------------------

/// Key under which the per-thread ASCallFrame mutable array is stored.
static NSString *const ASCallStackThreadKey = @"ASInterpreterCallStack";

/// Returns the ObjC class name suitable for display in a backtrace frame.
/// For class-object receivers (metaclass), returns the class name directly.
/// For instance receivers, returns the name of the instance's class.
static NSString *ASClassNameForObject(id obj) {
    return class_isMetaClass(object_getClass(obj))
        ? NSStringFromClass((Class)obj)
        : NSStringFromClass([obj class]);
}

/// Returns the call stack for the current thread, creating it on first access.
static NSMutableArray<ASCallFrame *> *ASCurrentCallStack(void) {
    NSMutableDictionary *dict = NSThread.currentThread.threadDictionary;
    NSMutableArray *stack = dict[ASCallStackThreadKey];
    if (!stack) {
        stack = [NSMutableArray array];
        dict[ASCallStackThreadKey] = stack;
    }
    return stack;
}

// ---------------------------------------------------------------------------
// Public constants
// ---------------------------------------------------------------------------

NSString *const ASRuntimeErrorException = @"ASRuntimeErrorException";

NSString *const ASErrorMessageKey     = @"ASErrorMessage";
NSString *const ASErrorScriptPathKey  = @"ASErrorScriptPath";
NSString *const ASErrorLineKey        = @"ASErrorLine";
NSString *const ASErrorColumnKey      = @"ASErrorColumn";
NSString *const ASErrorMessageCodeKey = @"ASErrorMessageCode";
NSString *const ASErrorLocalsKey      = @"ASErrorLocals";
NSString *const ASErrorCallStackKey        = @"ASErrorCallStack";
NSString *const ASErrorHybridCallStackKey  = @"ASErrorHybridCallStack";

// ---------------------------------------------------------------------------
// ASInterpreter private interface
// ---------------------------------------------------------------------------

@interface ASInterpreter ()

/// Evaluates a single statement node within `ctx`. If the statement is a return,
/// sets ctx.didReturn and ctx.returnValue.
- (void)executeStatement:(ASASTNode *)node context:(ASExecutionContext *)ctx;

/// Evaluates an expression node and returns its value.
- (nullable id)evaluateExpression:(ASASTNode *)node context:(ASExecutionContext *)ctx;

/// Executes a block body in a child scope with the given arguments bound to paramNames.
/// Returns the block's return value (nil if no return statement was reached).
///
/// `frameName` is the synthesised display name for this block frame
/// (e.g. `[ClassName method:]__block0`). `callSiteNode` is the AST node
/// where the block was defined (used to record line 0 — blocks are invoked
/// from ObjC and have no AppScript call-site line).
- (nullable id)executeBlockBody:(NSArray<ASASTNode *> *)body
                    parentScope:(ASScope *)parentScope
                   definingClass:(nullable Class)definingClass
                     scriptPath:(NSString *)scriptPath
                      weakNames:(NSMutableSet<NSString *> *)weakNames
                  constantNames:(NSMutableSet<NSString *> *)constantNames
                      arguments:(NSArray *)arguments
                     paramNames:(NSArray<NSString *> *)paramNames
                      frameName:(NSString *)frameName;

/// Private variant of the public `evaluateMethodBody:withReceiver:...` entry
/// point. Accepts an additional `callSiteNode` used to record which line in the
/// *calling* AppScript frame triggered this invocation (nil when called from
/// ObjC, giving callSiteLine == 0).
- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                    definingClass:(Class)definingClass
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath
                     callSiteNode:(nullable ASASTNode *)callSiteNode;

/// Reports a runtime error by raising an ``ASRuntimeErrorException``.
- (void)reportError:(NSString *)message
               code:(ASErrorCode)code
               node:(nullable ASASTNode *)node
            context:(ASExecutionContext *)ctx NS_SWIFT_UNAVAILABLE("") __attribute__((noreturn));

@end

// ---------------------------------------------------------------------------
// ASInterpreter implementation
// ---------------------------------------------------------------------------

@implementation ASInterpreter

// Public entry point — called from ObjC (ASRuntimeInstaller forwarding).
// callSiteNode is nil because there is no AppScript AST node at the call site.
- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                     definingClass:(Class)definingClass
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath {
    return [self evaluateMethodBody:body
                       withReceiver:receiver
                      definingClass:definingClass
                           selector:selector
                          arguments:arguments
                     parameterNames:parameterNames
                         scriptPath:scriptPath
                       callSiteNode:nil];
}

// Private implementation — also called from evaluateMessageSend: for super
// dispatches, where the calling ASMessageSendNode is known.
- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                     definingClass:(Class)definingClass
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath
                     callSiteNode:(nullable ASASTNode *)callSiteNode {
    // Build the call frame for this invocation.
    BOOL receiverIsClass = receiver && class_isMetaClass(object_getClass(receiver));
    NSString *className = ASClassNameForObject(receiver);
    NSString *prefix = receiverIsClass ? @"+" : @"-";
    ASCallFrame *frame = [[ASCallFrame alloc] init];
    frame.frameName      = [NSString stringWithFormat:@"%@[%@ %@]", prefix, className, selector];
    frame.parameterNames = parameterNames;
    frame.arguments      = arguments;
    frame.scriptPath     = scriptPath;
    frame.callSiteLine   = callSiteNode ? callSiteNode.lineNumber : 0;

    // Push onto the thread-local call stack.
    NSMutableArray<ASCallFrame *> *callStack = ASCurrentCallStack();
    [callStack addObject:frame];

    @try {
        // Create root scope for this invocation.
        ASScope *rootScope = [[ASScope alloc] initWithEnclosingScope:nil];

        // Bind implicit variables.
        [rootScope setValue:receiver forName:@"self"];
        [rootScope setValue:selector forName:@"_cmd"];

        // Bind parameters.
        NSUInteger paramCount = parameterNames.count;
        for (NSUInteger i = 0; i < paramCount && i < arguments.count; i++) {
            [rootScope setValue:arguments[i] forName:parameterNames[i]];
        }

        // Build execution context.
        ASExecutionContext *ctx = [[ASExecutionContext alloc] initWithScope:rootScope
                                                              definingClass:definingClass
                                                                scriptPath:scriptPath];

        // Execute body statements in order.
        for (ASASTNode *statement in body) {
            [self executeStatement:statement context:ctx];
            if (ctx.didReturn) {
                break;
            }
        }

        return ctx.returnValue;
    } @finally {
        [callStack removeLastObject];
    }
}

// ---------------------------------------------------------------------------
// Statement execution
// ---------------------------------------------------------------------------

- (void)executeStatement:(ASASTNode *)node context:(ASExecutionContext *)ctx {
    if ([node isKindOfClass:[ASReturnNode class]]) {
        ASReturnNode *returnNode = (ASReturnNode *)node;
        id value = nil;
        if (returnNode.value != nil) {
            value = [self evaluateExpression:returnNode.value context:ctx];
        }
        ctx.returnValue = value;
        ctx.didReturn = YES;
        return;
    }

    if ([node isKindOfClass:[ASVariableDeclarationNode class]]) {
        ASVariableDeclarationNode *decl = (ASVariableDeclarationNode *)node;
        id value = nil;
        if (decl.initializer != nil) {
            value = [self evaluateExpression:decl.initializer context:ctx];
        }
        [ctx.currentScope setValue:value forName:decl.variableName];
        if (decl.isWeak) {
            [ctx.weakNames addObject:decl.variableName];
        }
        if (decl.isConstant) {
            [ctx.constantNames addObject:decl.variableName];
        }
        return;
    }

    if ([node isKindOfClass:[ASAssignmentNode class]]) {
        ASAssignmentNode *assign = (ASAssignmentNode *)node;
        if ([ctx.constantNames containsObject:assign.variableName]) {
            [self reportError:[NSString stringWithFormat:
                               @"Cannot reassign constant '%@'", assign.variableName]
                          code:ASErrorCodeCannotReassignConstant
                          node:node
                       context:ctx];
        }
        id value = [self evaluateExpression:assign.value context:ctx];
        BOOL found = [ctx.currentScope updateValue:value forName:assign.variableName];
        if (!found) {
            [self reportError:[NSString stringWithFormat:
                               @"Undefined variable '%@'", assign.variableName]
                          code:ASErrorCodeUndefinedVariable
                          node:node
                       context:ctx];
        }
        return;
    }

    // All other statement-level nodes are expressions whose value is discarded.
    (void)[self evaluateExpression:node context:ctx];
}

// ---------------------------------------------------------------------------
// Expression evaluation
// ---------------------------------------------------------------------------

- (nullable id)evaluateExpression:(ASASTNode *)node context:(ASExecutionContext *)ctx {
    // --- String literal ---
    if ([node isKindOfClass:[ASStringLiteralNode class]]) {
        return ((ASStringLiteralNode *)node).value;
    }

    // --- Number literal ---
    if ([node isKindOfClass:[ASNumberLiteralNode class]]) {
        return ((ASNumberLiteralNode *)node).value;
    }

    // --- Identifier ---
    if ([node isKindOfClass:[ASIdentifierNode class]]) {
        NSString *name = ((ASIdentifierNode *)node).name;

        // Handle built-in literals expressed as identifiers.
        if ([name isEqualToString:@"YES"]) return @YES;
        if ([name isEqualToString:@"NO"])  return @NO;
        if ([name isEqualToString:@"nil"]) return [ASNull null];

        // Look up in scope chain.
        if ([ctx.currentScope hasName:name]) {
            id value = [ctx.currentScope valueForName:name];
            return value;
        }

        // Check if it's a known ObjC class.
        Class cls = NSClassFromString(name);
        if (cls != nil) {
            return cls;
        }

        [self reportError:[NSString stringWithFormat:@"Undefined identifier '%@'", name]
                      code:ASErrorCodeUndefinedIdentifier
                      node:node
                   context:ctx];
    }

    // --- Array literal ---
    if ([node isKindOfClass:[ASArrayLiteralNode class]]) {
        ASArrayLiteralNode *arrayNode = (ASArrayLiteralNode *)node;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:arrayNode.elements.count];
        for (ASASTNode *element in arrayNode.elements) {
            id value = [self evaluateExpression:element context:ctx];
            // evaluateExpression returns [ASNull null] for AppScript nil; ObjC nil cannot
            // be stored in NSArray, so fall back to [ASNull null] as the placeholder.
            [result addObject:value ?: [ASNull null]];
        }
        return [result copy];
    }

    // --- Dictionary literal ---
    if ([node isKindOfClass:[ASDictionaryLiteralNode class]]) {
        ASDictionaryLiteralNode *dictNode = (ASDictionaryLiteralNode *)node;
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:dictNode.keys.count];
        for (NSUInteger i = 0; i < dictNode.keys.count; i++) {
            id key   = [self evaluateExpression:dictNode.keys[i]   context:ctx] ?: [ASNull null];
            id value = [self evaluateExpression:dictNode.values[i] context:ctx] ?: [ASNull null];
            result[key] = value;
        }
        return [result copy];
    }

    // --- Message send ---
    if ([node isKindOfClass:[ASMessageSendNode class]]) {
        return [self evaluateMessageSend:(ASMessageSendNode *)node context:ctx];
    }

    // --- Block literal ---
    if ([node isKindOfClass:[ASBlockLiteralNode class]]) {
        return [self evaluateBlockLiteral:(ASBlockLiteralNode *)node context:ctx];
    }

    // --- Fallback: unrecognised node type ---
    [self reportError:[NSString stringWithFormat:
                       @"Unknown AST node type: %@", NSStringFromClass([node class])]
                  code:ASErrorCodeUnknownASTNodeType
                  node:node
               context:ctx];
    __builtin_unreachable();
}

// ---------------------------------------------------------------------------
// Message send
// ---------------------------------------------------------------------------

- (nullable id)evaluateMessageSend:(ASMessageSendNode *)node context:(ASExecutionContext *)ctx {
    // Detect super sends before evaluating the receiver as an expression.
    // For super: the actual receiver is self; method lookup starts from
    // [definingClass superclass], matching objc_msgSendSuper semantics.
    BOOL isSuperSend = [node.receiver isKindOfClass:[ASSuperNode class]];

    id receiver;
    if (isSuperSend) {
        receiver = [ctx.currentScope valueForName:@"self"];
    } else {
        receiver = [self evaluateExpression:node.receiver context:ctx];
        // A nested send (e.g. [[dict objectForKey:k] isNil]) can yield raw ObjC
        // nil; normalise it to the AppScript nil value so it behaves the same as
        // a nil stored in a variable.
        if (receiver == nil) {
            receiver = [ASNull null];
        }
    }

    // Build selector from parts.
    SEL sel = NSSelectorFromString(node.selector);

    // Evaluate argument expressions.
    NSArray<ASASTNode *> *argNodes = node.arguments;
    NSMutableArray *argValues = [NSMutableArray arrayWithCapacity:argNodes.count];
    for (ASASTNode *argNode in argNodes) {
        id argValue = [self evaluateExpression:argNode context:ctx];
        [argValues addObject:argValue ?: [ASNull null]];
    }

    // Obtain the method and its signature by querying the runtime directly.
    //
    // For super sends, start lookup from [definingClass superclass].
    // For normal sends, use the receiver's dynamic class.
    //
    // Using -methodSignatureForSelector: would route through our own
    // ASMethodSignatureForSelectorIMP trampoline (installed on every AppScript
    // class and its metaclass), whose super-call path for non-AppScript
    // selectors like +new is fragile.  Asking the runtime directly is
    // unambiguous: class_getClassMethod for class-object receivers,
    // class_getInstanceMethod for instance receivers.
    NSMethodSignature *sig = nil;
    Method foundMethod = nil;
    if (receiver != nil) {
        Class lookupClass;
        BOOL receiverIsClass = class_isMetaClass(object_getClass(receiver));
        if (isSuperSend) {
            // Super dispatch: start from the superclass of the defining class.
            Class superClass = [ctx.definingClass superclass];
            if (receiverIsClass) {
                foundMethod = class_getClassMethod(superClass, sel);
            } else {
                foundMethod = class_getInstanceMethod(superClass, sel);
            }
            (void)lookupClass; // suppress unused-variable warning
        } else {
            if (receiverIsClass) {
                foundMethod = class_getClassMethod((Class)receiver, sel);
            } else {
                foundMethod = class_getInstanceMethod(object_getClass(receiver), sel);
            }
        }
        if (foundMethod) {
            const char *typeEncoding = method_getTypeEncoding(foundMethod);
            if (typeEncoding) {
                sig = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
            }
        }
    }

    if (sig == nil) {
        [self reportError:[NSString stringWithFormat:
                           @"Object of class '%@' does not respond to selector '%@'",
                           receiver ? NSStringFromClass([receiver class]) : @"nil", node.selector]
                      code:ASErrorCodeUnrecognisedSelector
                      node:node
                   context:ctx];
        __builtin_unreachable();
    }

    // Build and invoke the NSInvocation.
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = receiver;
    inv.selector = sel;

    // Scratch storage for object out-parameters (`^@`, e.g. `NSError **`).
    // When an AppScript caller passes an ASOutObject to a native method expecting `id *`,
    // we pass the address of the corresponding slot in `outObjectSlots` to the invocation,
    // then copy the resulting object reference back into the ASOutObject after invoke.
    NSUInteger argCount = argValues.count;
    id __unsafe_unretained *outObjectSlots = NULL;
    if (argCount > 0) {
        outObjectSlots = (id __unsafe_unretained *)alloca(sizeof(id) * argCount);
        memset(outObjectSlots, 0, sizeof(id) * argCount);
    }

    for (NSUInteger i = 0; i < argCount; i++) {
        id arg = argValues[i];
        // Unwrap ASNull (AppScript nil) to ObjC nil before native dispatch.
        if (arg == [ASNull null]) {
            arg = nil;
        }
        if ([arg isKindOfClass:[ASOutObject class]] &&
            [ASBoxer isObjectOutParameterAtIndex:i inSignature:sig]) {
            ASOutObject *outObj = (ASOutObject *)arg;
            id initialVal = outObj.value;
            if ([initialVal isKindOfClass:[ASNull class]]) {
                initialVal = nil;
            }
            outObjectSlots[i] = initialVal;
            id __unsafe_unretained *slotPtr = &outObjectSlots[i];
            [inv setArgument:&slotPtr atIndex:(NSInteger)(i + 2)];
        } else {
            [ASBoxer unboxObject:arg intoArgumentAtIndex:i ofInvocation:inv];
        }
    }

    if (isSuperSend) {
        // For super sends, we must bypass dynamic dispatch to avoid infinite recursion.
        //
        // When the target method is defined in an AppScript class, the ObjC runtime has
        // only a forwarding-stub IMP installed (via _objc_msgForward). Calling that stub
        // via invokeUsingIMP: would re-enter ASForwardInvocationIMP, which searches from
        // the receiver's class (not the superclass), finds the same override, and recurses
        // infinitely.
        //
        // Fix: if the super method is an AppScript method, invoke evaluateMethodBody:
        // directly with the superclass's AST body.  Only fall back to invokeUsingIMP:
        // for genuine native ObjC methods (where no AppScript method map entry exists).
        Class superClass = [ctx.definingClass superclass];
        Class appScriptDefiningClass = Nil;
        ASMethodNode *appScriptMethod =
            [ASRuntimeInstaller appScriptMethodNodeForSuperDispatch:superClass
                                                           selector:node.selector
                                                      definingClass:&appScriptDefiningClass];
        if (appScriptMethod != nil) {
            // Direct AST dispatch: bypasses ObjC forwarding entirely.
            // Pass the current ASMessageSendNode as callSiteNode so the callee
            // frame records the line in this script where the super call was made.
            return [self evaluateMethodBody:appScriptMethod.body
                               withReceiver:receiver
                              definingClass:appScriptDefiningClass
                                   selector:node.selector
                                  arguments:argValues
                             parameterNames:appScriptMethod.parameterNames
                                 scriptPath:ctx.scriptPath ?: @"<unknown>"
                               callSiteNode:node];
        }
        // Native ObjC super method: safe to invoke via IMP since there is no
        // AppScript forwarding stub in the superclass chain.
        IMP imp = method_getImplementation(foundMethod);
        [inv invokeUsingIMP:imp];
    } else {
        [inv invoke];
    }

    // Copy any populated object out-parameters back into their ASOutObject wrappers.
    for (NSUInteger i = 0; i < argCount; i++) {
        id arg = argValues[i];
        if ([arg isKindOfClass:[ASOutObject class]] &&
            [ASBoxer isObjectOutParameterAtIndex:i inSignature:sig]) {
            ASOutObject *outObj = (ASOutObject *)arg;
            outObj.value = outObjectSlots[i];
        }
    }

    return [ASBoxer boxedReturnValueFromInvocation:inv];
}

// ---------------------------------------------------------------------------
// Block literal
// ---------------------------------------------------------------------------

- (nullable id)executeBlockBody:(NSArray<ASASTNode *> *)body
                    parentScope:(ASScope *)parentScope
                   definingClass:(nullable Class)definingClass
                     scriptPath:(NSString *)scriptPath
                      weakNames:(NSMutableSet<NSString *> *)weakNames
                  constantNames:(NSMutableSet<NSString *> *)constantNames
                      arguments:(NSArray *)arguments
                     paramNames:(NSArray<NSString *> *)paramNames
                      frameName:(NSString *)frameName {
    // Build and push a call frame for this block invocation.
    // callSiteLine is 0: blocks are invoked from ObjC, not from an AppScript AST node.
    ASCallFrame *frame = [[ASCallFrame alloc] init];
    frame.frameName      = frameName;
    frame.parameterNames = paramNames;
    frame.arguments      = arguments;
    frame.scriptPath     = scriptPath;
    frame.callSiteLine   = 0;

    NSMutableArray<ASCallFrame *> *callStack = ASCurrentCallStack();
    [callStack addObject:frame];

    @try {
        ASScope *blockScope = [[ASScope alloc] initWithEnclosingScope:parentScope];
        NSUInteger bindCount = MIN(paramNames.count, arguments.count);
        for (NSUInteger i = 0; i < bindCount; i++) {
            id val = arguments[i];
            // ASNull means the caller passed AppScript nil; store as-is so the
            // parameter evaluates to [ASNull null] (AppScript nil) in the block body.
            [blockScope setValue:val forName:paramNames[i]];
        }
        ASExecutionContext *blockCtx = [[ASExecutionContext alloc] initWithScope:blockScope
                                                                   definingClass:definingClass
                                                                      scriptPath:scriptPath];
        blockCtx.weakNames = weakNames;
        blockCtx.constantNames = constantNames;
        for (ASASTNode *statement in body) {
            [self executeStatement:statement context:blockCtx];
            if (blockCtx.didReturn) {
                break;
            }
        }
        return blockCtx.returnValue;
    } @finally {
        [callStack removeLastObject];
    }
}

- (id)evaluateBlockLiteral:(ASBlockLiteralNode *)node context:(ASExecutionContext *)ctx {
    // Capture what we need by value so the block remains valid after this stack frame.
    NSArray<NSString *> *paramNames = node.parameterNames;
    NSArray<ASASTNode *> *body = node.body;
    ASScope *capturedScope = ctx.currentScope;
    Class capturedDefiningClass = ctx.definingClass;
    NSString *scriptPath = ctx.scriptPath;
    NSMutableSet<NSString *> *capturedWeakNames = [ctx.weakNames mutableCopy];
    NSMutableSet<NSString *> *capturedConstantNames = [ctx.constantNames mutableCopy];
    ASInterpreter *interpreter = self;

    // Synthesise a stable frame name for this block using the enclosing method's
    // class and selector, plus a per-method block index (e.g. `[MyClass run]__block0`).
    NSUInteger blockIndex = ctx.blockCount++;
    id selfValue = [ctx.currentScope valueForName:@"self"];
    NSString *enclosingClass = selfValue ? ASClassNameForObject(selfValue) : @"<unknown>";
    NSString *enclosingSelector = [ctx.currentScope valueForName:@"_cmd"] ?: @"<unknown>";
    NSString *capturedFrameName = [NSString stringWithFormat:@"[%@ %@]__block%lu",
                                   enclosingClass, enclosingSelector,
                                   (unsigned long)blockIndex];

    // Create an arity-specific ObjC block so that argument passing works correctly
    // when native Objective-C code invokes the block with the expected number of
    // arguments.  All AppScript block parameters are `id`.
    NSUInteger paramCount = paramNames.count;

    if (paramCount == 0) {
        id (^block)(void) = ^id {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                   definingClass:capturedDefiningClass
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[] paramNames:paramNames
                                      frameName:capturedFrameName];
        };
        return [block copy];
    }

    if (paramCount == 1) {
        NSString *p0 = paramNames[0];
        id (^block)(id) = ^id(id a0) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                   definingClass:capturedDefiningClass
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [ASNull null]]
                                     paramNames:@[p0]
                                      frameName:capturedFrameName];
        };
        return [block copy];
    }

    if (paramCount == 2) {
        NSString *p0 = paramNames[0], *p1 = paramNames[1];
        id (^block)(id, id) = ^id(id a0, id a1) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                   definingClass:capturedDefiningClass
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [ASNull null], a1 ?: [ASNull null]]
                                     paramNames:@[p0, p1]
                                      frameName:capturedFrameName];
        };
        return [block copy];
    }

    if (paramCount == 3) {
        NSString *p0 = paramNames[0], *p1 = paramNames[1], *p2 = paramNames[2];
        id (^block)(id, id, id) = ^id(id a0, id a1, id a2) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                   definingClass:capturedDefiningClass
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [ASNull null], a1 ?: [ASNull null],
                                                  a2 ?: [ASNull null]]
                                     paramNames:@[p0, p1, p2]
                                      frameName:capturedFrameName];
        };
        return [block copy];
    }

    // Four-parameter blocks cover all common Foundation patterns.
    NSString *p0 = paramNames[0], *p1 = paramNames[1];
    NSString *p2 = paramNames[2], *p3 = paramNames[3];
    id (^block)(id, id, id, id) = ^id(id a0, id a1, id a2, id a3) {
        return [interpreter executeBlockBody:body parentScope:capturedScope
                               definingClass:capturedDefiningClass
                                  scriptPath:scriptPath weakNames:capturedWeakNames
                              constantNames:capturedConstantNames
                                  arguments:@[a0 ?: [ASNull null], a1 ?: [ASNull null],
                                              a2 ?: [ASNull null], a3 ?: [ASNull null]]
                                 paramNames:@[p0, p1, p2, p3]
                                  frameName:capturedFrameName];
    };
    return [block copy];
}

// ---------------------------------------------------------------------------
// Error reporting
// ---------------------------------------------------------------------------

/// Returns a tab-expanded copy of `s` with each `\t` replaced by 4 spaces.
static NSString *ASExpandTabs(NSString *s) {
    return [s stringByReplacingOccurrencesOfString:@"\t" withString:@"    "];
}

/// Returns source-context lines to append to an error reason string, or `nil`
/// when `line` is 0 (no node available).
///
/// When the source file can be read, the returned string is:
///   tab-expanded source line + newline + (col-1 spaces) + "^"  (caret omitted when col == 0)
///
/// When the file cannot be read (missing, "<unknown>", etc.), the returned
/// string is `(source unavailable)`.
static NSString *ASSourceContext(NSString *path, NSUInteger line, NSUInteger col) {
    // REQ-4: line == 0 means no AST node — omit block entirely.
    if (line == 0) {
        return nil;
    }

    // REQ-5: unreadable file — use the project's established file-reading utility.
    NSString *source = [[NSURL fileURLWithPath:path] as_stringContents];
    if (!source) {
        return @"(source unavailable)";
    }

    NSArray<NSString *> *lines = [source componentsSeparatedByString:@"\n"];
    // line is 1-based; guard against out-of-range values.
    if (line > lines.count) {
        return @"(source unavailable)";
    }

    NSString *rawLine = lines[line - 1];
    NSString *displayLine = ASExpandTabs(rawLine);

    // REQ-4: col == 0 → show source line, omit caret.
    if (col == 0) {
        return displayLine;
    }

    // REQ-2 + REQ-3: caret at column-1 offset in the tab-expanded line.
    // We expand only the prefix (chars before the error column) to get the
    // correct visual offset after tab expansion.
    NSUInteger prefixLen = MIN(col - 1, rawLine.length);
    NSString *expandedPrefix = ASExpandTabs([rawLine substringToIndex:prefixLen]);
    NSString *spaces = [@"" stringByPaddingToLength:expandedPrefix.length
                                         withString:@" "
                                    startingAtIndex:0];

    return [NSString stringWithFormat:@"%@\n%@^", displayLine, spaces];
}

/// Formats one call frame as a single backtrace line.
///
/// Example output:
///   `  at -[MyClass doSomething:] (value=<"hello">) /path/to/script.appscript:12`
static NSString *ASFormatCallFrame(ASCallFrame *frame) {
    // Format arguments as `name=<description>` pairs.
    NSMutableArray<NSString *> *argParts = [NSMutableArray array];
    NSUInteger argCount = MIN(frame.parameterNames.count, frame.arguments.count);
    for (NSUInteger i = 0; i < argCount; i++) {
        NSString *name = frame.parameterNames[i];
        id value = frame.arguments[i];
        NSString *desc = value ? [value description] : @"nil";
        [argParts addObject:[NSString stringWithFormat:@"%@=<%@>", name, desc]];
    }
    NSString *argsStr = [argParts componentsJoinedByString:@", "];

    // Location: path only, or path:line when the call-site line is known.
    NSString *location = frame.callSiteLine > 0
        ? [NSString stringWithFormat:@"%@:%lu", frame.scriptPath, (unsigned long)frame.callSiteLine]
        : frame.scriptPath;

    return [NSString stringWithFormat:@"  at %@ (%@) %@",
            frame.frameName, argsStr, location];
}

/// Returns YES if `symbol` (one line from `[NSThread callStackSymbols]`) belongs
/// to the AppScript runtime execution trampoline and should be filtered out of
/// the hybrid backtrace.
static BOOL ASIsRuntimeFrame(NSString *symbol) {
    static NSArray<NSString *> *kFilters;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kFilters = @[
            @"ASForwardInvocationIMP",
            @"evaluateMethodBody:",
            @"evaluateMessageSend:",
            @"executeStatement:",
            @"reportError:",
            // Must match this function's own name — update if renamed.
            @"ASBuildHybridBacktrace",
        ];
    });
    for (NSString *f in kFilters) {
        if ([symbol containsString:f]) return YES;
    }
    return NO;
}

/// Builds a hybrid backtrace by interleaving `[NSThread callStackSymbols]` with
/// AppScript call frames from `appscriptStack`.
///
/// Consecutive ObjC frames that match the runtime filter are replaced by the
/// next unconsumed AppScript call frame (innermost first). Non-matching ObjC
/// frames pass through verbatim. If AppScript frames are exhausted before all
/// runtime clusters are consumed, the placeholder `  at <AppScript runtime frame>`
/// is emitted for each remaining cluster.
static NSString *ASBuildHybridBacktrace(NSArray<ASCallFrame *> *appscriptStack) {
    NSArray<NSString *> *objcSymbols = [NSThread callStackSymbols];
    // Consume AppScript frames innermost-first (last index = innermost).
    NSInteger asIdx = (NSInteger)appscriptStack.count - 1;
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    BOOL inCluster = NO;

    for (NSString *sym in objcSymbols) {
        if (ASIsRuntimeFrame(sym)) {
            if (!inCluster) {
                // First frame of a new runtime cluster — emit the AppScript frame.
                if (asIdx >= 0) {
                    [lines addObject:ASFormatCallFrame(appscriptStack[(NSUInteger)asIdx])];
                    asIdx--;
                } else {
                    [lines addObject:@"  at <AppScript runtime frame>"];
                }
                inCluster = YES;
            }
            // Remaining frames in the same cluster: skip.
        } else {
            inCluster = NO;
            [lines addObject:sym];
        }
    }

    return [lines componentsJoinedByString:@"\n"];
}

- (void)reportError:(NSString *)message
               code:(ASErrorCode)code
               node:(nullable ASASTNode *)node
            context:(ASExecutionContext *)ctx {
    NSString *path = ctx.scriptPath ?: @"<unknown>";
    NSUInteger line = node ? node.lineNumber : 0;
    NSUInteger col  = node ? node.columnNumber : 0;

    NSString *baseReason = [NSString stringWithFormat:@"AppScript error at %@:%lu:%lu: %@",
                                                       path, (unsigned long)line,
                                                       (unsigned long)col, message];
    NSString *sourceCtx = ASSourceContext(path, line, col);
    NSString *reason = sourceCtx
        ? [NSString stringWithFormat:@"%@\n%@", baseReason, sourceCtx]
        : baseReason;

    // Build the AppScript-level call stack (innermost frame first = last in array).
    // No copy needed: reportError: is noreturn — @finally cleanup runs after the raise,
    // not during this iteration.
    NSMutableArray<NSString *> *frameLines = [NSMutableArray array];
    NSMutableArray<ASCallFrame *> *stack = ASCurrentCallStack();
    for (NSInteger i = (NSInteger)stack.count - 1; i >= 0; i--) {
        [frameLines addObject:ASFormatCallFrame(stack[(NSUInteger)i])];
    }
    NSString *callStackString = [frameLines componentsJoinedByString:@"\n"];

    // Build the hybrid backtrace (ObjC frames interleaved with AppScript frames).
    NSString *hybridCallStackString = ASBuildHybridBacktrace(stack);
    if (hybridCallStackString.length > 0) {
        reason = [NSString stringWithFormat:@"%@\nCall stack (most recent call first):\n%@",
                  reason, hybridCallStackString];
    }

    NSDictionary *locals = [ctx.currentScope allVisibleBindings];
    NSDictionary *userInfo = @{
        ASErrorMessageKey:          message,
        ASErrorScriptPathKey:       path,
        ASErrorLineKey:             @(line),
        ASErrorColumnKey:           @(col),
        ASErrorMessageCodeKey:      @(code),
        ASErrorLocalsKey:           locals,
        ASErrorCallStackKey:        callStackString,
        ASErrorHybridCallStackKey:  hybridCallStackString,
    };

    // Callers are responsible for not swallowing this exception: an
    // ASRuntimeErrorException always represents a programming mistake in the
    // AppScript source under evaluation, and silently catching it will hide
    // that mistake from the developer.
    [[NSException exceptionWithName:ASRuntimeErrorException
                             reason:reason
                           userInfo:userInfo] raise];
    // -[NSException raise] is noreturn; __builtin_unreachable() satisfies
    // the compiler's flow analysis for our __attribute__((noreturn)) declaration.
    __builtin_unreachable();
}

@end
