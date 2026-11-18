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

#import <AppScript/ASInterpreter.h>
#import <AppScript/ASScope.h>
#import <AppScript/ASLoggingExceptionHandler.h>
#import <AppScript/ASNull.h>
#import <AppScript/ASOutObject.h>
#import <objc/runtime.h>
#if __has_include(<objc/objc-arc.h>)
#import <objc/objc-arc.h>   // GNUstep's libobjc2 declares objc_retain here.
#else
// Apple's SDK doesn't declare the ARC runtime entry points in a public header, but libobjc
// exports objc_retain (it is part of the ARC runtime interface the compiler itself calls).
OBJC_EXPORT id _Nullable objc_retain(id _Nullable value);
#endif
#import <AppScript/ASBoxer.h>
#import <AppScript/ASRuntimeInstaller.h>
#import <AppScript/ASBlockRegistry.h>
#import <AppScript/ASBlockTrampoline.h>
#import <AppScript/ASMethodNode.h>

// AST node types
#import <AppScript/ASReturnNode.h>
#import <AppScript/ASVariableDeclarationNode.h>
#import <AppScript/ASAssignmentNode.h>
#import <AppScript/ASMessageSendNode.h>
#import <AppScript/ASBlockLiteralNode.h>
#import <AppScript/ASIdentifierNode.h>
#import <AppScript/ASStringLiteralNode.h>
#import <AppScript/ASNumberLiteralNode.h>
#import <AppScript/ASArrayLiteralNode.h>
#import <AppScript/ASDictionaryLiteralNode.h>
#import <AppScript/ASSuperNode.h>
#import <AppScript/NSURL+AppScriptFileReading.h>

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

/// Private userInfo key marking an ASRuntimeErrorException raised without a script
/// location (see ASRaiseRuntimeError). The interpreter re-raises such errors at the
/// location of the message send during which they occurred.
static NSString *const ASErrorUnlocatedKey = @"ASErrorUnlocated";

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

/// Invokes `inv` (through `imp` when non-NULL), re-raising any ASRuntimeErrorException
/// that has no script location of its own at the location of `node`.
- (void)invokeInvocation:(NSInvocation *)inv
                usingIMP:(nullable IMP)imp
             messageNode:(ASMessageSendNode *)node
                 context:(ASExecutionContext *)ctx;

@end

// ---------------------------------------------------------------------------
// ASInterpreter implementation
// ---------------------------------------------------------------------------

@implementation ASInterpreter

static id<ASExceptionHandler> ASInstalledExceptionHandler = nil;
static ASLoggingExceptionHandler *ASDefaultExceptionHandler = nil;

+ (void)setExceptionHandler:(id<ASExceptionHandler>)handler {
    @synchronized (self) {
        ASInstalledExceptionHandler = handler;
    }
}

+ (id<ASExceptionHandler>)exceptionHandler {
    @synchronized (self) {
        if (ASInstalledExceptionHandler) return ASInstalledExceptionHandler;
        if (!ASDefaultExceptionHandler) ASDefaultExceptionHandler = [[ASLoggingExceptionHandler alloc] init];
        return ASDefaultExceptionHandler;
    }
}

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

static BOOL ASSelectorCallsBlock(NSString *selector, NSUInteger argumentCount);

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

    // [block value], [block value: x value: y]: call the block (asu-ugk).
    if (!isSuperSend && ASSelectorCallsBlock(node.selector, argValues.count) && [ASBlockTrampoline isBlock:receiver]) {
        id result = nil;
        NSError *error = nil;
        if (![ASBlockTrampoline callBlock:receiver withArguments:argValues result:&result error:&error]) {
            [self reportError:error.localizedDescription
                         code:ASErrorCodeValueConversionFailed
                         node:node
                      context:ctx];
        }
        return result;
    }

    return [self dispatchMessageSendConsultingHandler:node
                                             receiver:receiver
                                             selector:sel
                                            arguments:argValues
                                          isSuperSend:isSuperSend
                                              context:ctx];
}

/// Looks up the method for an already-evaluated send, converts the arguments, invokes it
/// and boxes the result. Everything that can fail while delivering the message happens here.
- (nullable id)dispatchMessageSend:(ASMessageSendNode *)node
                          receiver:(id)receiver
                          selector:(SEL)sel
                         arguments:(NSArray *)argValues
                       isSuperSend:(BOOL)isSuperSend
                           context:(ASExecutionContext *)ctx {
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
    // Keeps wrapper blocks alive until after the send (NSInvocation doesn't retain its arguments).
    NSMutableArray *blockArguments = [NSMutableArray array];
    id __unsafe_unretained *outObjectSlots = NULL;
    // Scratch buffers for scalar and struct out-parameters (`NSInteger *`, `NSRange *`), one per argument.
    void **outBuffers = NULL;
    if (argCount > 0) {
        outObjectSlots = (id __unsafe_unretained *)alloca(sizeof(id) * argCount);
        memset(outObjectSlots, 0, sizeof(id) * argCount);
        outBuffers = (void **)alloca(sizeof(void *) * argCount);
        memset(outBuffers, 0, sizeof(void *) * argCount);
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
        } else if ([arg isKindOfClass:[ASOutObject class]] &&
                   [ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:i inSignature:sig] != nil) {
            // Scalar or struct out-parameter: pass the address of a pointee-sized scratch buffer,
            // seeded from the out-object's value (zero if it has none).
            NSString *pointee = [ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:i inSignature:sig];
            NSUInteger pointeeSize = [ASBoxer sizeOfTypeEncoding:pointee.UTF8String];
            void *buffer = alloca(pointeeSize > 0 ? pointeeSize : 1);
            if (![ASBoxer prepareOutBuffer:buffer size:(pointeeSize > 0 ? pointeeSize : 1)
                              forOutObject:arg pointee:pointee]) {
                [self reportError:[NSString stringWithFormat:
                                   @"Cannot convert argument %lu of '%@' from %@ to %@",
                                   (unsigned long)(i + 1), node.selector,
                                   NSStringFromClass([((ASOutObject *)arg).value class]),
                                   [ASBoxer displayNameForTypeEncoding:pointee.UTF8String]]
                              code:ASErrorCodeValueConversionFailed
                              node:node
                           context:ctx];
            }
            outBuffers[i] = buffer;
            [inv setArgument:&buffer atIndex:(NSInteger)(i + 2)];
        } else if ([ASBlockTrampoline isScriptBlock:arg] && ASArgumentIsBlock(sig, i)) {
            // A script block for a block parameter: pass it as is, or wrapped in a block with the C
            // signature the method will call it with.
            id blockArgument = [self blockArgumentForScriptBlock:arg
                                                        receiver:receiver
                                                        selector:sel
                                                   argumentIndex:i
                                                            node:node
                                                         context:ctx];
            [blockArguments addObject:blockArgument];
            [inv setArgument:&blockArgument atIndex:(NSInteger)(i + 2)];
        } else if (![ASBoxer unboxObject:arg intoArgumentAtIndex:i ofInvocation:inv]) {
            const char *expected = [sig getArgumentTypeAtIndex:i + 2];
            [self reportError:[NSString stringWithFormat:
                               @"Cannot convert argument %lu of '%@' from %@ to %@",
                               (unsigned long)(i + 1), node.selector,
                               arg ? NSStringFromClass([arg class]) : @"nil",
                               [ASBoxer displayNameForTypeEncoding:expected]]
                          code:ASErrorCodeValueConversionFailed
                          node:node
                       context:ctx];
        }
    }

    // Ownership of the returned object, by the ARC naming convention. A method in the alloc, new,
    // copy or mutableCopy family returns +1, and an init-family method also consumes self;
    // NSInvocation does neither on our behalf, so balance them here. That holds for
    // methods defined in AppScript too, because their forwarding stub follows the same convention.
    // The one exception is a super send to an AppScript-defined method, which is
    // evaluated directly from the AST below and never goes through the stub.
    ASReturnOwnership ownership = [ASBoxer returnOwnershipForSelector:sel];
    BOOL balanceOwnership = NO;
    if (ownership != ASReturnOwnershipNone && sig.methodReturnType[0] == '@') {
        balanceOwnership = YES;
        if (isSuperSend) {
            balanceOwnership = [ASRuntimeInstaller appScriptMethodNodeForSuperDispatch:[ctx.definingClass superclass]
                                                                              selector:node.selector
                                                                         definingClass:NULL] == nil;
        }
    }
    if (balanceOwnership && ownership == ASReturnOwnershipInitFamily) {
        // The callee releases self (it consumes it), so give it one more retain to release. This is
        // a hand-off of ownership to the callee, which the static analyzer can't see, hence the
        // explicit runtime call; it is balanced by the release of the result below.
        objc_retain(receiver);
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
            id superResult = [self evaluateMethodBody:appScriptMethod.body
                                         withReceiver:receiver
                                        definingClass:appScriptDefiningClass
                                             selector:node.selector
                                            arguments:argValues
                                       parameterNames:appScriptMethod.parameterNames
                                           scriptPath:ctx.scriptPath ?: @"<unknown>"
                                         callSiteNode:node];
            // Apply the method's declared C return type, as a send through the ObjC
            // runtime would, so super and normal sends return the same value.
            return [ASRuntimeInstaller checkedReturnValue:superResult
                                               ofSelector:node.selector
                                            definingClass:appScriptDefiningClass
                                            isClassMethod:class_isMetaClass(object_getClass(receiver))];
        }
        // Native ObjC super method: safe to invoke via IMP since there is no
        // AppScript forwarding stub in the superclass chain.
        IMP imp = method_getImplementation(foundMethod);
        [self invokeInvocation:inv usingIMP:imp messageNode:node context:ctx];
    } else {
        [self invokeInvocation:inv usingIMP:NULL messageNode:node context:ctx];
    }

    // Copy any populated object out-parameters back into their ASOutObject wrappers.
    for (NSUInteger i = 0; i < argCount; i++) {
        id arg = argValues[i];
        if ([arg isKindOfClass:[ASOutObject class]] &&
            [ASBoxer isObjectOutParameterAtIndex:i inSignature:sig]) {
            ASOutObject *outObj = (ASOutObject *)arg;
            outObj.value = outObjectSlots[i];
        } else if ([arg isKindOfClass:[ASOutObject class]] && outBuffers[i] != NULL) {
            // Scalar or struct out-parameter: box what the native method wrote.
            NSString *pointee = [ASBoxer pointeeTypeEncodingOfOutParameterAtIndex:i inSignature:sig];
            [ASBoxer writeOutBuffer:outBuffers[i] toOutObject:arg pointee:pointee];
        }
    }

    (void)blockArguments.count;
    id boxedResult = [ASBoxer boxedReturnValueFromInvocation:inv];
    if (balanceOwnership && boxedResult != nil &&
        ![boxedResult isKindOfClass:[ASNull class]] && ![boxedResult isKindOfClass:[NSNull class]]) {
        // Release the +1 the callee returned. `boxedResult` is a strong reference, so the object
        // stays alive for the script until that is released in turn.
        id owned = (__bridge_transfer id)(__bridge void *)boxedResult;
        (void)owned;
    }
    return boxedResult;
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

    // The arity-specific blocks below take `id` parameters. Cocoa methods that call a block with other
    // C types need a wrapper (ASBlockTrampoline); it runs the script through this generic invoker.
    id _Nullable (^invoker)(NSArray *) = ^id _Nullable(NSArray *arguments) {
        return [interpreter executeBlockBody:body parentScope:capturedScope
                               definingClass:capturedDefiningClass
                                  scriptPath:scriptPath weakNames:capturedWeakNames
                              constantNames:capturedConstantNames
                                  arguments:arguments paramNames:paramNames
                                  frameName:capturedFrameName];
    };
    id (^finish)(id) = ^id(id scriptBlock) {
        [ASBlockTrampoline attachInvoker:invoker parameterCount:paramCount toScriptBlock:scriptBlock];
        return scriptBlock;
    };

    if (paramCount == 0) {
        id (^block)(void) = ^id {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                   definingClass:capturedDefiningClass
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[] paramNames:paramNames
                                      frameName:capturedFrameName];
        };
        return finish([block copy]);
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
        return finish([block copy]);
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
        return finish([block copy]);
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
        return finish([block copy]);
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
    return finish([block copy]);
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

// ---------------------------------------------------------------------------
// Runtime error construction
// ---------------------------------------------------------------------------

/// Builds an ASRuntimeErrorException carrying the location, call stacks and locals.
/// `unlocated` adds ASErrorUnlocatedKey so the interpreter can attach a location.
static NSException *ASMakeRuntimeErrorException(NSString *message,
                                                ASErrorCode code,
                                                NSString * _Nullable scriptPath,
                                                NSUInteger line,
                                                NSUInteger col,
                                                NSDictionary *locals,
                                                BOOL unlocated) {
    NSString *path = scriptPath ?: @"<unknown>";

    NSString *baseReason = [NSString stringWithFormat:@"AppScript error at %@:%lu:%lu: %@",
                                                       path, (unsigned long)line,
                                                       (unsigned long)col, message];
    NSString *sourceCtx = ASSourceContext(path, line, col);
    NSString *reason = sourceCtx
        ? [NSString stringWithFormat:@"%@\n%@", baseReason, sourceCtx]
        : baseReason;

    // Build the AppScript-level call stack (innermost frame first = last in array).
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

    NSMutableDictionary *userInfo = [@{
        ASErrorMessageKey:          message,
        ASErrorScriptPathKey:       path,
        ASErrorLineKey:             @(line),
        ASErrorColumnKey:           @(col),
        ASErrorMessageCodeKey:      @(code),
        ASErrorLocalsKey:           locals,
        ASErrorCallStackKey:        callStackString,
        ASErrorHybridCallStackKey:  hybridCallStackString,
    } mutableCopy];
    if (unlocated) {
        userInfo[ASErrorUnlocatedKey] = @YES;
    }

    return [NSException exceptionWithName:ASRuntimeErrorException
                                   reason:reason
                                 userInfo:userInfo];
}

void ASRaiseRuntimeError(NSString *message, ASErrorCode code,
                         NSString * _Nullable scriptPath, NSUInteger line) {
    [ASMakeRuntimeErrorException(message, code, scriptPath, line, 0, @{}, scriptPath == nil) raise];
    __builtin_unreachable();
}

/// Returns whether `selector` is `value` (no arguments) or `value:` repeated once per argument,
/// the messages a script uses to call a block.
static BOOL ASSelectorCallsBlock(NSString *selector, NSUInteger argumentCount) {
    if (argumentCount == 0) {
        return [selector isEqualToString:@"value"];
    }
    return selector.length == argumentCount * 6 &&
           [[selector stringByReplacingOccurrencesOfString:@"value:" withString:@""] length] == 0;
}

/// Returns whether argument `index` of the method signature is a block (`@?`).
static BOOL ASArgumentIsBlock(NSMethodSignature *signature, NSUInteger index) {
    const char *type = [signature getArgumentTypeAtIndex:index + 2];
    while (*type != '\0' && strchr("rnNoORV", *type) != NULL) {
        type++;
    }
    return type[0] == '@' && type[1] == '?';
}

/// Decides what to pass for a script block given as a block argument: raises if the method's block
/// signature isn't known or the block's parameter count is wrong, passes the block as is if the
/// signature is object-only, and otherwise wraps it with the signature's C types.
- (id)blockArgumentForScriptBlock:(id)scriptBlock
                         receiver:(id)receiver
                         selector:(SEL)selector
                    argumentIndex:(NSUInteger)index
                             node:(ASMessageSendNode *)node
                          context:(ASExecutionContext *)ctx {
    ASBridgeSupportBlockSignature *signature =
        [[ASBlockRegistry sharedRegistry] signatureForReceiver:receiver selector:selector argumentIndex:index];
    if (signature == nil) {
        [self reportError:[NSString stringWithFormat:
                           @"No block signature is registered for argument %lu of '%@'; load BridgeSupport "
                           @"for the framework that declares it",
                           (unsigned long)(index + 1), node.selector]
                     code:ASErrorCodeValueConversionFailed
                     node:node
                  context:ctx];
        __builtin_unreachable();
    }
    NSUInteger given = [ASBlockTrampoline parameterCountOfScriptBlock:scriptBlock];
    NSUInteger expected = signature.parameterTypeEncodings.count;
    if (given != expected) {
        [self reportError:[NSString stringWithFormat:
                           @"The block passed as argument %lu of '%@' takes %lu parameters, but the method "
                           @"calls it with %lu",
                           (unsigned long)(index + 1), node.selector,
                           (unsigned long)given, (unsigned long)expected]
                     code:ASErrorCodeValueConversionFailed
                     node:node
                  context:ctx];
        __builtin_unreachable();
    }
    if ([signature isObjectOnly]) {
        return scriptBlock;
    }
    NSError *error = nil;
    id wrapper = [ASBlockTrampoline blockWrappingScriptBlock:scriptBlock signature:signature error:&error];
    if (wrapper == nil) {
        [self reportError:[NSString stringWithFormat:@"Cannot pass the block as argument %lu of '%@': %@",
                           (unsigned long)(index + 1), node.selector, error.localizedDescription]
                     code:ASErrorCodeValueConversionFailed
                     node:node
                  context:ctx];
        __builtin_unreachable();
    }
    return wrapper;
}

- (void)invokeInvocation:(NSInvocation *)inv
                usingIMP:(nullable IMP)imp
             messageNode:(ASMessageSendNode *)node
                 context:(ASExecutionContext *)ctx {
    @try {
        if (imp) {
            [inv invokeUsingIMP:imp];
        } else {
            [inv invoke];
        }
    } @catch (NSException *ex) {
        // Runtime machinery below this send (e.g. BridgeSupport argument conversion)
        // raises without a location; attach this send's location. Everything else
        // propagates unchanged. Under ARC without -fobjc-arc-exceptions this path may
        // leak objects, which is acceptable: the exception reports a fatal script error.
        if ([ex.name isEqualToString:ASRuntimeErrorException] &&
            [ex.userInfo[ASErrorUnlocatedKey] boolValue]) {
            [self reportError:ex.userInfo[ASErrorMessageKey]
                         code:(ASErrorCode)[ex.userInfo[ASErrorMessageCodeKey] integerValue]
                         node:node
                      context:ctx];
        }
        @throw;
    }
}

- (void)reportError:(NSString *)message
               code:(ASErrorCode)code
               node:(nullable ASASTNode *)node
            context:(ASExecutionContext *)ctx {
    NSUInteger line = node ? node.lineNumber : 0;
    NSUInteger col  = node ? node.columnNumber : 0;
    NSDictionary *locals = [ctx.currentScope allVisibleBindings];

    // Callers are responsible for not swallowing this exception: an
    // ASRuntimeErrorException always represents a programming mistake in the
    // AppScript source under evaluation, and silently catching it will hide
    // that mistake from the developer.
    [ASMakeRuntimeErrorException(message, code, ctx.scriptPath, line, col, locals, NO) raise];
    // -[NSException raise] is noreturn; __builtin_unreachable() satisfies
    // the compiler's flow analysis for our __attribute__((noreturn)) declaration.
    __builtin_unreachable();
}

// ---------------------------------------------------------------------------
// Exception handler boundary
// ---------------------------------------------------------------------------

/// Marks an exception the installed handler has already been asked about, so the sends
/// it propagates through don't ask again.
static const void *ASExceptionHandledKey = &ASExceptionHandledKey;
/// Thread-dictionary key set while a handler runs, so its own failures aren't re-offered to it.
static NSString *const ASInsideExceptionHandlerKey = @"ASInsideExceptionHandler";

static BOOL ASExceptionWasHandled(NSException *ex) {
    return objc_getAssociatedObject(ex, ASExceptionHandledKey) != nil;
}

static void ASMarkExceptionHandled(NSException *ex) {
    objc_setAssociatedObject(ex, ASExceptionHandledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/// Builds the context handed to the handler for a failed send.
static ASExceptionContext *ASExceptionContextFor(NSException *ex, ASMessageSendNode *node, id receiver,
                                                 SEL sel, ASExecutionContext *ctx) {
    BOOL isRuntimeError = [ex.name isEqualToString:ASRuntimeErrorException];
    NSDictionary *userInfo = isRuntimeError ? ex.userInfo : nil;

    NSDictionary *locals = userInfo[ASErrorLocalsKey] ?: [ctx.currentScope allVisibleBindings] ?: @{};
    NSString *hybrid = userInfo[ASErrorHybridCallStackKey] ?: ASBuildHybridBacktrace(ASCurrentCallStack());
    NSMutableArray<NSString *> *frames = [NSMutableArray array];
    [hybrid enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        if (line.length > 0) [frames addObject:line];
    }];
    NSUInteger line = userInfo[ASErrorLineKey] ? [userInfo[ASErrorLineKey] unsignedIntegerValue] : node.lineNumber;
    NSString *path = userInfo[ASErrorScriptPathKey] ?: ctx.scriptPath;

    return [[ASExceptionContext alloc] initWithReceiver:(receiver == [ASNull null] ? nil : receiver)
                                               selector:sel
                                             scriptPath:path
                                                   line:line
                                                 locals:locals
                                        hybridCallStack:frames
                                  crossedScriptBoundary:!isRuntimeError];
}

/// Dispatches a send; if it fails, asks the installed ASExceptionHandler what to do.
/// The handler is consulted once per exception, and a retried send is dispatched afresh
/// (so the method is looked up again) at most once.
- (nullable id)dispatchMessageSendConsultingHandler:(ASMessageSendNode *)node
                                           receiver:(id)receiver
                                           selector:(SEL)sel
                                          arguments:(NSArray *)argValues
                                        isSuperSend:(BOOL)isSuperSend
                                            context:(ASExecutionContext *)ctx {
    @try {
        return [self dispatchMessageSend:node receiver:receiver selector:sel
                               arguments:argValues isSuperSend:isSuperSend context:ctx];
    } @catch (NSException *ex) {
        NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
        if (ASExceptionWasHandled(ex) || threadDictionary[ASInsideExceptionHandlerKey] != nil) {
            @throw;
        }
        ASMarkExceptionHandled(ex);

        ASExceptionDisposition disposition = ASExceptionDispositionReraise;
        threadDictionary[ASInsideExceptionHandlerKey] = @YES;
        @try {
            disposition = [[ASInterpreter exceptionHandler]
                           handleException:ex
                                   context:ASExceptionContextFor(ex, node, receiver, sel, ctx)];
        } @catch (NSException *handlerFailure) {
            // A handler that itself raises replaces the original exception, which
            // enclosing sends must not offer to the handler again.
            ASMarkExceptionHandled(handlerFailure);
            @throw;
        } @finally {
            [threadDictionary removeObjectForKey:ASInsideExceptionHandlerKey];
        }
        if (disposition != ASExceptionDispositionRetry) {
            @throw;
        }
    }

    // Retry once. A failure now is final: ASMarkExceptionHandled stops enclosing sends
    // from offering it to the handler, and nothing here asks again.
    @try {
        return [self dispatchMessageSend:node receiver:receiver selector:sel
                               arguments:argValues isSuperSend:isSuperSend context:ctx];
    } @catch (NSException *retryFailure) {
        ASMarkExceptionHandled(retryFailure);
        @throw;
    }
}

@end
