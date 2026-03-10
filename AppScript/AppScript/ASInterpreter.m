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
#import <objc/runtime.h>
#import "ASBoxer.h"

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

/// YES once a return statement has been executed.
@property (nonatomic) BOOL didReturn;

/// The value provided by a return statement (may be nil even when didReturn is YES).
@property (nonatomic, strong, nullable) id returnValue;

- (instancetype)initWithScope:(ASScope *)scope
                   scriptPath:(NSString *)scriptPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation ASExecutionContext

- (instancetype)initWithScope:(ASScope *)scope scriptPath:(NSString *)scriptPath {
    self = [super init];
    if (self) {
        _currentScope = scope;
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
- (nullable id)executeBlockBody:(NSArray<ASASTNode *> *)body
                    parentScope:(ASScope *)parentScope
                     scriptPath:(NSString *)scriptPath
                      weakNames:(NSMutableSet<NSString *> *)weakNames
                  constantNames:(NSMutableSet<NSString *> *)constantNames
                      arguments:(NSArray *)arguments
                     paramNames:(NSArray<NSString *> *)paramNames;

/// Reports a runtime error and aborts.
- (void)reportError:(NSString *)message
               node:(nullable ASASTNode *)node
             context:(ASExecutionContext *)ctx NS_SWIFT_UNAVAILABLE("") __attribute__((noreturn));

@end

// ---------------------------------------------------------------------------
// ASInterpreter implementation
// ---------------------------------------------------------------------------

@implementation ASInterpreter

- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath {
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
                                                            scriptPath:scriptPath];

    // Execute body statements in order.
    for (ASASTNode *statement in body) {
        [self executeStatement:statement context:ctx];
        if (ctx.didReturn) {
            break;
        }
    }

    return ctx.returnValue;
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
                         node:node
                      context:ctx];
        }
        id value = [self evaluateExpression:assign.value context:ctx];
        BOOL found = [ctx.currentScope updateValue:value forName:assign.variableName];
        if (!found) {
            [self reportError:[NSString stringWithFormat:
                               @"Undefined variable '%@'", assign.variableName]
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
        if ([name isEqualToString:@"nil"]) return [NSNull null];

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
                     node:node
                  context:ctx];
    }

    // --- Array literal ---
    if ([node isKindOfClass:[ASArrayLiteralNode class]]) {
        ASArrayLiteralNode *arrayNode = (ASArrayLiteralNode *)node;
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:arrayNode.elements.count];
        for (ASASTNode *element in arrayNode.elements) {
            id value = [self evaluateExpression:element context:ctx];
            [result addObject:value ?: [NSNull null]];
        }
        return [result copy];
    }

    // --- Dictionary literal ---
    if ([node isKindOfClass:[ASDictionaryLiteralNode class]]) {
        ASDictionaryLiteralNode *dictNode = (ASDictionaryLiteralNode *)node;
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:dictNode.keys.count];
        for (NSUInteger i = 0; i < dictNode.keys.count; i++) {
            id key   = [self evaluateExpression:dictNode.keys[i]   context:ctx] ?: [NSNull null];
            id value = [self evaluateExpression:dictNode.values[i] context:ctx] ?: [NSNull null];
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
                 node:node
              context:ctx];
    return nil;
}

// ---------------------------------------------------------------------------
// Message send
// ---------------------------------------------------------------------------

- (nullable id)evaluateMessageSend:(ASMessageSendNode *)node context:(ASExecutionContext *)ctx {
    id receiver = [self evaluateExpression:node.receiver context:ctx];

    // Build selector from parts.
    SEL sel = NSSelectorFromString(node.selector);

    // Evaluate argument expressions.
    NSArray<ASASTNode *> *argNodes = node.arguments;
    NSMutableArray *argValues = [NSMutableArray arrayWithCapacity:argNodes.count];
    for (ASASTNode *argNode in argNodes) {
        id argValue = [self evaluateExpression:argNode context:ctx];
        [argValues addObject:argValue ?: [NSNull null]];
    }

    // Obtain the method signature by querying the runtime directly.
    //
    // Using -methodSignatureForSelector: would route through our own
    // ASMethodSignatureForSelectorIMP trampoline (installed on every AppScript
    // class and its metaclass), whose super-call path for non-AppScript
    // selectors like +new is fragile.  Asking the runtime directly is
    // unambiguous: class_getClassMethod for class-object receivers,
    // class_getInstanceMethod for instance receivers.
    NSMethodSignature *sig = nil;
    if (receiver != nil) {
        BOOL receiverIsClass = class_isMetaClass(object_getClass(receiver));
        if (receiverIsClass) {
            Method m = class_getClassMethod((Class)receiver, sel);
            if (m) {
                sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
            }
        } else {
            Method m = class_getInstanceMethod(object_getClass(receiver), sel);
            if (m) {
                sig = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
            }
        }
    }

    if (sig == nil) {
        [self reportError:[NSString stringWithFormat:
                           @"Object of class '%@' does not respond to selector '%@'",
                           NSStringFromClass([receiver class]), node.selector]
                     node:node
                  context:ctx];
    }

    // Build and invoke the NSInvocation.
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = receiver;
    inv.selector = sel;

    for (NSUInteger i = 0; i < argValues.count; i++) {
        id arg = argValues[i];
        // Unwrap NSNull back to nil for id arguments.
        if (arg == [NSNull null]) {
            const char *typeEnc = [sig getArgumentTypeAtIndex:i + 2];
            if (typeEnc && typeEnc[0] == '@') {
                arg = nil;
            }
        }
        [ASBoxer unboxObject:arg intoArgumentAtIndex:i ofInvocation:inv];
    }

    [inv invoke];

    return [ASBoxer boxedReturnValueFromInvocation:inv];
}

// ---------------------------------------------------------------------------
// Block literal
// ---------------------------------------------------------------------------

- (nullable id)executeBlockBody:(NSArray<ASASTNode *> *)body
                    parentScope:(ASScope *)parentScope
                     scriptPath:(NSString *)scriptPath
                      weakNames:(NSMutableSet<NSString *> *)weakNames
                  constantNames:(NSMutableSet<NSString *> *)constantNames
                      arguments:(NSArray *)arguments
                     paramNames:(NSArray<NSString *> *)paramNames {
    ASScope *blockScope = [[ASScope alloc] initWithEnclosingScope:parentScope];
    NSUInteger bindCount = MIN(paramNames.count, arguments.count);
    for (NSUInteger i = 0; i < bindCount; i++) {
        id val = arguments[i];
        [blockScope setValue:(val == [NSNull null] ? nil : val) forName:paramNames[i]];
    }
    ASExecutionContext *blockCtx = [[ASExecutionContext alloc] initWithScope:blockScope
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
}

- (id)evaluateBlockLiteral:(ASBlockLiteralNode *)node context:(ASExecutionContext *)ctx {
    // Capture what we need by value so the block remains valid after this stack frame.
    NSArray<NSString *> *paramNames = node.parameterNames;
    NSArray<ASASTNode *> *body = node.body;
    ASScope *capturedScope = ctx.currentScope;
    NSString *scriptPath = ctx.scriptPath;
    NSMutableSet<NSString *> *capturedWeakNames = [ctx.weakNames mutableCopy];
    NSMutableSet<NSString *> *capturedConstantNames = [ctx.constantNames mutableCopy];
    ASInterpreter *interpreter = self;

    // Create an arity-specific ObjC block so that argument passing works correctly
    // when native Objective-C code invokes the block with the expected number of
    // arguments.  All AppScript block parameters are `id`.
    NSUInteger paramCount = paramNames.count;

    if (paramCount == 0) {
        id (^block)(void) = ^id {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[] paramNames:paramNames];
        };
        return [block copy];
    }

    if (paramCount == 1) {
        NSString *p0 = paramNames[0];
        id (^block)(id) = ^id(id a0) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [NSNull null]]
                                     paramNames:@[p0]];
        };
        return [block copy];
    }

    if (paramCount == 2) {
        NSString *p0 = paramNames[0], *p1 = paramNames[1];
        id (^block)(id, id) = ^id(id a0, id a1) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [NSNull null], a1 ?: [NSNull null]]
                                     paramNames:@[p0, p1]];
        };
        return [block copy];
    }

    if (paramCount == 3) {
        NSString *p0 = paramNames[0], *p1 = paramNames[1], *p2 = paramNames[2];
        id (^block)(id, id, id) = ^id(id a0, id a1, id a2) {
            return [interpreter executeBlockBody:body parentScope:capturedScope
                                      scriptPath:scriptPath weakNames:capturedWeakNames
                                  constantNames:capturedConstantNames
                                      arguments:@[a0 ?: [NSNull null], a1 ?: [NSNull null],
                                                  a2 ?: [NSNull null]]
                                     paramNames:@[p0, p1, p2]];
        };
        return [block copy];
    }

    // Four-parameter blocks cover all common Foundation patterns.
    NSString *p0 = paramNames[0], *p1 = paramNames[1];
    NSString *p2 = paramNames[2], *p3 = paramNames[3];
    id (^block)(id, id, id, id) = ^id(id a0, id a1, id a2, id a3) {
        return [interpreter executeBlockBody:body parentScope:capturedScope
                                  scriptPath:scriptPath weakNames:capturedWeakNames
                              constantNames:capturedConstantNames
                                  arguments:@[a0 ?: [NSNull null], a1 ?: [NSNull null],
                                              a2 ?: [NSNull null], a3 ?: [NSNull null]]
                                 paramNames:@[p0, p1, p2, p3]];
    };
    return [block copy];
}

// ---------------------------------------------------------------------------
// Error reporting
// ---------------------------------------------------------------------------

- (void)reportError:(NSString *)message
               node:(nullable ASASTNode *)node
            context:(ASExecutionContext *)ctx {
    NSString *path = ctx.scriptPath ?: @"<unknown>";
    NSUInteger line = node ? node.lineNumber : 0;
    NSUInteger col  = node ? node.columnNumber : 0;
    fprintf(stderr, "AppScript error at %s:%lu:%lu: %s\n",
            path.UTF8String,
            (unsigned long)line,
            (unsigned long)col,
            message.UTF8String);
    abort();
}

@end
