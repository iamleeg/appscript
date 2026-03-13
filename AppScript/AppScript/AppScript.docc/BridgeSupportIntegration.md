# BridgeSupport Integration

Access C functions and constants from Apple's frameworks in AppScript using automatically generated Objective-C proxies.

## Overview

AppScript can only express operations as message sends — it has no syntax for calling C functions or reading C global variables directly. The BridgeSupport integration bridges this gap: the runtime reads Apple's BridgeSupport XML metadata and dynamically registers per-framework proxy classes whose methods wrap the underlying C symbols. All arguments and return values are boxed to and from `id` automatically.

## Loading BridgeSupport for a framework

Before loading any AppScript scripts that use symbols from a framework, call `+[NSBundle loadBridgeSupportForFramework:error:]`:

```objc
NSError *error = nil;
if (![NSBundle loadBridgeSupportForFramework:@"Foundation" error:&error]) {
    NSLog(@"BridgeSupport load failed: %@", error);
}
```

Each framework is loaded at most once; calling this method a second time for the same framework returns `NO` and describes the duplicate load in the error.

## Calling C functions

Each C function becomes a class method on a proxy class named `AS<FrameworkName>`. Functions with multiple parameters are expressed in Objective-C keyword style:

```appscript
// Equivalent to C: sin(1.5708)
id result = [ASFoundation sin: 1.5708]
```

Arguments are unboxed from `id` to the required C type before the call; the return value is boxed back to `id`.

## Accessing constants and enumerations

C constants and BridgeSupport enumeration values become no-argument class methods on the same proxy class:

```appscript
id notFound    = [ASFoundation NSNotFound]
id notification = [ASFoundation NSBundleDidLoadNotification]
```

Numeric values are returned as `NSNumber`; string values as `NSString`.

BridgeSupport distinguishes two kinds of named values:
- **`<constant>`** elements represent genuine C global variables. Their values are read at install time via `dlsym` and cached in the method's block IMP. Symbols that cannot be resolved are silently skipped.
- **`<enum>`** elements represent compile-time constants (macros, `enum` cases). Their values are embedded directly in the BridgeSupport XML and require no runtime symbol lookup. For example, `NSNotFound` is an `<enum>` in Foundation's BridgeSupport with `value64='-1'` (the signed representation of `NSUIntegerMax`).

## Boxing rules

| C type | AppScript (`id`) type |
|---|---|
| `int`, `NSInteger`, unsigned variants | `NSNumber` |
| `float`, `double`, `CGFloat` | `NSNumber` |
| `BOOL` | `NSNumber` |
| `char *` | `NSString` |
| Struct (registered with `NSValue`) | `NSValue` |
| `void` | `nil` |

## Limitations

- Variadic functions (`...`) are not supported and are omitted from the generated proxy.
- Function pointer arguments and return values are not supported.
- BridgeSupport is only loaded for frameworks explicitly requested by the host application.

## How `NSBundle+AppScriptBridgeSupportLoading` works

`+loadBridgeSupportForFramework:error:` is the single entry point for host applications. It:

1. Locates the framework's `.bridgesupport` file — first inside the system framework bundle at
   `/System/Library/Frameworks/<Name>.framework/Resources/BridgeSupport/`, then at the
   system-wide fallback `/System/Library/BridgeSupport/<Name>.bridgesupport`.
2. Parses it with `ASBridgeSupportParser` to produce an `ASBridgeSupportDocument`.
3. Delegates to `ASBridgeSupportInstaller` to register the `AS<FrameworkName>` proxy class.

Each framework can only be loaded once per process. A second call returns `NO` with
`ASBridgeSupportLoadingErrorDuplicateLoad`.

## How `ASBridgeSupportInstaller` works

`ASBridgeSupportInstaller` dynamically allocates an `NSObject` subclass named
`AS<FrameworkName>` using `objc_allocateClassPair`. For each eligible function in the
`ASBridgeSupportDocument` it:

- Resolves the C symbol with `dlsym(RTLD_DEFAULT, ...)`.
- Registers a sentinel method on the proxy metaclass so ObjC message sends flow through the
  forwarding machinery (`forwardInvocation:` / `methodSignatureForSelector:`).
- Stores a `_ASFunctionInfo` record (function pointer + type encodings) in an associated-object
  dictionary keyed to the class object.

When a message is sent to the proxy class at runtime, the custom `forwardInvocation:` IMP
unboxes the `id` arguments to the C types required by the function, calls the C function
pointer, then boxes the return value back to `id`.

For constants, the value is read from the symbol at install time and captured in a direct
`imp_implementationWithBlock` IMP — there is no forwarding overhead on access. Enumerations
are handled identically: their values come from the XML rather than from `dlsym`.

## Topics

### Loading BridgeSupport
- ``NSBundle``

### Generated proxy interface
- ``ASBridgeSupportProxy``

### Internal installer
- ``ASBridgeSupportInstaller``
