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

## Accessing constants

C constants and enum values become no-argument class methods on the same proxy class:

```appscript
id notFound = [ASFoundation NSNotFound]
id pi       = [ASFoundation M_PI]
```

Numeric values are returned as `NSNumber`; string values as `NSString`.

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

## Topics

### Loading BridgeSupport
- ``NSBundle``

### Generated proxy interface
- ``ASBridgeSupportProxy``
