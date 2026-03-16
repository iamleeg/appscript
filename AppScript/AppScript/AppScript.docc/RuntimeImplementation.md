# Runtime Implementation

How the AppScript framework integrates with the Objective-C runtime to load scripts, install classes, and execute methods.

## Overview

AppScript scripts are loaded once, compiled to an AST, and installed as live Objective-C classes. From that point on, the host application interacts with AppScript-defined classes entirely through the normal Objective-C messaging system — no interpreter involvement until a method is actually called.

See <doc:LoadingAndRunningAppScriptFiles> for the host-application API and <doc:DefiningClassesAndCategories> for how classes and categories are installed.

## Method forwarding machinery

For each method defined in an AppScript class, ``ASRuntimeInstaller`` installs a sentinel IMP (`_objc_msgForward`) on the registered class using `class_addMethod` (new methods) or `class_replaceMethod` (category overrides). When the sentinel is triggered, the Objective-C forwarding machinery calls `methodSignatureForSelector:` — overridden on every AppScript class — which returns the correct `NSMethodSignature` for the selector, then calls `forwardInvocation:` — also overridden — which boxes the invocation's parameters to `id`, calls ``ASInterpreter``, and unboxes the return value.

### Protocol-aware type encoding

When choosing the type encoding for a sentinel IMP, ``ASRuntimeInstaller`` first searches the protocols adopted by the class and its superclass chain for a matching method description. If a protocol declares the selector, its encoding is used, preserving primitive return types such as `BOOL` or `NSInteger`. If no protocol declares the selector, the runtime falls back to an all-`id` encoding derived from the parameter count.

This ensures that an AppScript method implementing a protocol requirement — for example, `applicationShouldTerminateAfterLastWindowClosed:` from `NSApplicationDelegate` — carries the correct type encoding on its sentinel IMP, so the Objective-C runtime dispatches it correctly.

## Memory management and threading

AppScript uses Objective-C ARC for all memory management; manual `retain`/`release`/`autorelease` calls do not appear in the framework. The interpreter can be active on multiple threads simultaneously. Scripts may call Objective-C APIs that dispatch work to other threads — for example, `-[NSObject performSelectorOnMainThread:withObject:waitUntilDone:]` — and the framework places no restrictions on this. The host application is responsible for ensuring that any shared state accessed from AppScript scripts is appropriately synchronized.

## Block implementation

When ``ASInterpreter`` evaluates a block literal such as `^(a b) { return [a compare:b] }`, it creates an Objective-C block whose arity matches the number of declared parameters. The interpreter supports blocks with zero to four parameters; blocks with more parameters produce a runtime error. All parameters and the return value are typed as `id`.

The parameter names, body AST, and captured scope chain are closed over by the block at creation time. No additional storage — such as associated objects on the block instance — is required. When the block is invoked by Objective-C code, the received arguments are bound into a new child scope under the captured scope, and the body is executed by the interpreter.

### Block adaptor methods

Because all AppScript blocks return `id`, there is a type mismatch when a native Objective-C API expects a block returning a C primitive type. For example, `-[NSArray sortedArrayUsingComparator:]` expects a block returning `NSComparisonResult` (an `NSInteger`), not an `id`.

The AppScript runtime provides `as_`-prefixed adaptor methods on Foundation classes to bridge this gap:

```objc
@interface NSArray (AppScriptBlocks)
/// Returns the array sorted using a comparator block that returns NSComparisonResult as an NSNumber.
- (NSArray *)as_sortedArrayUsingBlock:(id (^)(id, id))comparatorBlock;
@end
```

```appscript
id sorted = [array as_sortedArrayUsingBlock: ^(a b) {
    return [a compare: b]
}]
```

The adaptor unboxes the `NSNumber` return value to `NSComparisonResult` before forwarding to Foundation. AppScript code calls `as_sortedArrayUsingBlock:` instead of `sortedArrayUsingComparator:` and returns the comparison result directly.

## Topics

### Installation

- ``ASRuntimeInstaller``
- ``ASInterpreter``
- ``ASBoxer``

### Blocks

- ``NSArray``
