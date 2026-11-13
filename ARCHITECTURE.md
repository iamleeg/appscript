# AppScript — scripting for Cocoa

"Objective-C without the C"

AppScript is an interpreted language that represents a simplified subset of Objective-C. It supports human developers and AI agents by enabling quick, and memory-safe, iteration on implementations. The interpreter is deployed as a framework, so it can be embedded in apps and command-line tools.

## Language design

The syntax of AppScript is familiar to Objective-C developers, but removes some of the complexity of that language.
All code statements in AppScript must be part of a method definition, or a block variable declaration; there is no "top level" or immediate execution. A developer could run a script by defining its entry point in the initializer of an object, loading the script, then instantiating that object; or by creating an app where the app delegate object is defined in AppScript.

### Objects

All variables and constants are Objective-C objects, declared with the `id` type: no bare pointers, C strings, primitive types, structs, or unions. Here's an example:

```appscript
id null = [NSNull null]
```

Single-line comments begin with `//` and extend to the end of the line. Block comments are not supported.

Each statement must be presented on its own line, there are no semicolon statement separators and no continuation characters. It's an error to split a statement across multiple lines, or to put multiple statements on the same line. The only exception occurs when a statement includes a block literal, discussed in Blocks below.

Number literals (both floating-point and integer), and the BOOL values YES and NO, are automatically boxed into `NSNumber` instances. The `@` prefix may optionally be used on number literals to match Objective-C syntax, though they are boxed automatically regardless:

```appscript
id flag = NO // Equivalent to Objective-C [NSNumber numberWithBool: NO]
id pi = 3.14 // Equivalent to Objective-C [NSNumber numberWithDouble: 3.14]
id boxed = @42 // Equivalent to Objective-C @42
```

The `nil` literal is supported and represents the absence of an object, exactly as in Objective-C.

String literals, array literals, and dictionary literals use the same syntax as Objective-C, including the `@` prefix. Objective-C selectors are represented as string literals.

```appscript
id artist = @"Frank Zappa"
id albums = @[@"Sheik Yerbouti", @"Hot Rats"]
id band_members = @{ @"Bass": @"Roy Estrada", @"Drums" : @"Jimmy Carl Black", @"Harmonica": @"Ray Collins" }
id selector = @"writeToFile:atomically:"
```

String literals support the same backslash escape sequences as Objective-C:

| Sequence | Meaning |
|----------|---------|
| `\\`     | Literal backslash |
| `\"`     | Literal double-quote |
| `\n`     | Newline (U+000A) |
| `\t`     | Horizontal tab (U+0009) |
| `\r`     | Carriage return (U+000D) |
| `\0`     | Null character (U+0000) |
| `\a`     | Bell (U+0007) |
| `\b`     | Backspace (U+0008) |
| `\f`     | Form feed (U+000C) |
| `\v`     | Vertical tab (U+000B) |
| `\xNN`   | Hex character (1–2 hex digits) |
| `\uNNNN` | Unicode code point (4 hex digits) |
| `\UNNNNNNNN` | Unicode code point (8 hex digits) |
| `\NNN`   | Octal character (1–3 octal digits, first digit 1–7) |

An unrecognised backslash sequence (e.g. `@"\q"`) is a parse error.

Two modifiers are acceptable before `id` when declaring a variable:

- `weak id`: Indicates that the variable is a weak reference. Variables are strong references by default.
- `constant id`: Indicates that the variable can't be reassigned. It's an error to try to reassign a different value after the declaration.

### Sending messages to objects

Send messages using the familiar Objective-C square bracket syntax. All arguments are treated as objects, and the return value is an object. However, if the script sends a message to an Objective-C object with a different signature, the runtime automatically converts objects into primitive types by sending the appropriate `NSValue` message to the arguments, and "boxes" a primitive return value into an `NSString`, `NSValue` or `NSNumber`:

```appscript
id n = 8
id array = [NSMutableArray mutableArrayWithCapacity: n] // Runtime calls [n integerValue]
id count = [array count] // Runtime converts return value into a NSNumber
```

AppScript supports **only** Objective-C message sends. C functions, C operators, preprocessor macros, and inline expressions are not available. Every operation must be expressed as a message to an object. Where Objective-C programmers would normally reach for a C function, the AppScript runtime provides an equivalent message via a category on the relevant Foundation class. If no suitable method exists and the symbol is part of a BridgeSupport-covered framework, use the BridgeSupport proxy class instead (see below).

#### AppScript runtime categories

The following categories are included in the AppScript framework to bridge common C-function patterns:

| Category | Method | Equivalent C function | Notes |
|---|---|---|---|
| `NSArray (AppScriptBlocks)` | `-as_sortedArrayUsingBlock:` | N/A | Bridges block-based sorting. The block must return an `NSNumber` wrapping an `NSComparisonResult`. |
| `NSString (AppScriptRuntime)` | `-as_class` | `NSClassFromString()` | Returns the `Class` as `id`; returns `nil` for unknown names. |
| `NSString (AppScriptRuntime)` | `-as_protocol` | `NSProtocolFromString()` | Returns the `Protocol *` as `id`; returns `nil` for unknown names. |
| `NSURL (AppScriptFileReading)` | `-as_stringContents` | `+[NSString stringWithContentsOfURL:encoding:error:]` | UTF-8; returns `nil` on error instead of using an out-parameter. |

```appscript
id cls = [@"NSMutableArray" as_class]
id instance = [cls new]

id proto = [@"NSCopying" as_protocol]
id conforms = [instance conformsToProtocol: proto]

id url = [NSURL fileURLWithPath: @"/path/to/file.txt"]
id contents = [url as_stringContents]
```

### Blocks

Blocks must always be declared inside a method body. `self` inside a block refers to the enclosing method's receiver, not the block itself.

Block literals are introduced using the `^` character. If the block has arguments, their names are listed next, in a pair of parentheses, as bare identifiers (implicitly `id` — no type annotation). Next, the opening brace `{` represents the start of the block's body. Each statement in the block's body must be presented on a separate line, followed by a line that only contains the `}` character to represent the end of the block. Examples:

```appscript
id noArgsBlock = ^{
    weak id weakSelf = self
    id myself = weakSelf
    [myself reticulateSplines]
    return [myself countOfSplines]
}

id limitSplines = ^(splineCount) {
    array = [array subarrayToIndex:splineCount]
}
```

If a block has a return statement, it returns an Objective-C object, otherwise it returns `nil`.

Blocks can capture values from their surrounding context, using same variable names. It's an error to "shadow" a captured variable by declaring a local variable with the same name. Only values in surrounding AppScript code are captured, not any Objective-C variables that happen to be active:

```appscript
id name = @"Graham Lee"
id capitalize = ^{
    return [name uppercaseString] // captures name from the enclosing scope
}
```

Variables that aren't marked `constant` are automatically mutable by blocks that can capture them, as if they had the Objective-C `__block` annotation.

### Defining classes

Declare a class with the `@class` keyword, followed by the name of the class, then a colon, then the name of the superclass, then optionally any protocol conformances in angle brackets. A superclass is always required. A class with no explicit protocols omits the angle-bracket section entirely.

In subsequent lines, define properties, instance methods, and class methods. Complete the class definition with the word `@end` on its own line.

Properties are always Objective-C objects. Use the `@property` keyword, followed by any modifiers in parentheses, then the name of the property. Acceptable modifiers:

- `strong`: The property is a strong reference to an object that's assigned to it.
- `weak`: The property is a weak reference to an object that's assigned to it.
- `copy`: The object makes a copy of an object that's assigned to a property, and keeps a strong reference to that object.
- `nonatomic`: Accesses to the property from different threads aren't atomic.
- `atomic`: Accesses to the property from different threads are atomic.
- `dynamic`: The runtime doesn't synthesize property accessor methods.
- `readonly`: The property can be read but not written to.

Multiple modifiers can be combined inside the parentheses, comma-separated (e.g. `@property (strong, readonly) name`). If no modifiers are supplied, the property is `strong` and `nonatomic`.

If the property definition doesn't include the `dynamic` modifier, then the AppScript runtime synthesizes Key-Value Coding-compliant accessors (only a method to retrieve the value of a `readonly` property, otherwise also a mutator method). However, the developer can provide custom implementations of methods with the same names, in which case the AppScript runtime doesn't synthesize the accessors.

There isn't any dot syntax for accessing properties in AppScript: use the accessor methods instead.

Method signatures start with a `-` for an instance method or `+` for a class method, followed by the name of the method which includes parameters in infix format, with parameter names separated from the method name by colons. Parameters are always Objective-C objects; they are declared as bare identifiers after each colon, with no type annotation. The return value is an Objective-C object (return `self` from methods with no return value; return `nil` to indicate the lack of an object). Returning `self` from void-like methods enables message chaining. The end of the method signature must be the `{` character denoting the start of the method implementation.

Both `self` (the receiver) and `_cmd` (the current selector as a string) are implicitly in scope inside every method body. In instance methods, `self` is the instance; in class methods, `self` is the class object. Blocks declared inside a method body capture `self` from that method — inside a block, `self` always refers to the enclosing method's receiver, never to the block itself.

Place the method body on subsequent lines, one line per statement, finishing with the `}` character on its own line.

For methods with multiple parameters, use the same infix style as Objective-C: each keyword and its parameter appear in sequence, all on the same line as the opening `{`:

```appscript
- writeToFile: aPath atomically: aFlag {
    // aPath and aFlag are both available here
}
```

Here's a complete example of a class:

```appscript
@class Calculator : NSObject <NSCopying>

@property base
@property accumulator

+ calculatorWithBase: aNumber {
    id calc = [self new]
    [calc setBase:aNumber]
    return calc
}

- copyWithZone: aZone {
    id calc = [[self class] new]
    [calc setBase: [self base]]
    [calc setAccumulator: [self accumulator]]
    return calc
}

- add: aNumber {
    [self setAccumulator: [[self accumulator] numberByAdding: aNumber]]
    return self
}

@end
```

If the class defines a subclass of an Objective-C class, and overrides an existing method, the appscript runtime uses automatic boxing and unboxing to convert parameters between the types defined in the method signature and Objective-C objects.

### Sending messages to the superclass

Inside a method body, `super` is a reserved keyword that can be used as the receiver of a message-send expression. It dispatches the message to the **superclass of the class that statically defines the current method**, not the dynamic type of `self`. The actual receiver (the object that `self` refers to) is unchanged — only the method lookup starting point shifts up the class hierarchy. This matches the semantics of `objc_msgSendSuper` in Objective-C.

```appscript
@class Animal : NSObject

- describe {
    return @"I am an animal"
}

@end

@class Dog : Animal

- describe {
    id base = [super describe]
    return [base stringByAppendingString:@" (specifically, a dog)"]
}

@end
```

`super` is valid as a receiver in both instance methods and class methods. In a class method, the message is dispatched to the superclass's class method, with `self` remaining the class object.

`super` is a reserved keyword and not a variable. It cannot appear on the left-hand side of an assignment, and it cannot be passed as an argument or stored in a variable.

`self` may be reassigned inside a method body, matching Objective-C. The canonical initialiser pattern is therefore valid in AppScript:

```appscript
- init {
    self = [super init]
    // self may now be a different object, or nil
    return self
}
```

`super` is not valid inside a block literal — it is a parse error, matching Objective-C. AppScript blocks capture `self` from the enclosing method (see Blocks above); if access to a superclass method is needed from within a block, call it before the block and capture the result.

It is a parse error to use `super` as a receiver anywhere outside a method body (including at top-level variable declarations and free-standing block literals not enclosed by a method).

In a category method, `super` refers to the superclass of the class on which the category is defined, matching Objective-C category semantics.

### Categories

To add AppScript methods to an existing Objective-C or AppScript class (rather than defining a new subclass), use the `@category` keyword, followed by the class name, and then the name of a category in parentheses:

```appscript
@category NSString (MyExtensions)

- scream {
    return [self uppercaseString]
}

@end
```

The category name is required but unused at runtime. You can't use a category to change a class's superclass, and it's an error to implement two categories on the same class with the same name within a single bundle, or to implement the same method override on the same class in two different categories in the same bundle, even if the two categories have different names. If multiple bundles implement categories on the same class that override the same method, it's up to the host application to load the bundles in the order that gets the desired implementation.

### Basic arithmetic

AppScript doesn't provide the arithmetic operators. Instead, the AppScript runtime adds a category of methods to `NSNumber` to provide arithmetic functions:

```objc
@interface NSNumber (AppScriptArithmetic)
- (NSNumber *)numberByAdding:(NSNumber *)other;
- (NSNumber *)numberBySubtracting:(NSNumber *)other;
- (NSNumber *)numberByMultiplyingBy:(NSNumber *)other;
- (NSNumber *)numberByDividingBy:(NSNumber *)other;
- (NSNumber *)negated;
- (NSNumber *)rounded;
- (NSNumber *)floored;
- (NSNumber *)numberMaximumOfSelfAnd:(NSNumber *)other;
- (NSNumber *)numberMinimumOfSelfAnd:(NSNumber *)other;
@end
```

### Control flow

AppScript doesn't provide control flow keywords. Iterate through collections of objects using the collection's `-objectEnumerator` and the `NSEnumerator` methods combined with `do:while:`:

```appscript
id enumerator = [albums objectEnumerator]
id album = [enumerator nextObject]
[self do: ^{
    [self processAlbum: album]
    album = [enumerator nextObject]
} while: ^{
    return album
}]
```

Implement conditional flow using this category that the AppScript runtime adds to the `NSNumber` class:

```objc
@interface NSNumber (AppScriptControlFlow)
/// Returns the result of whichever block is executed, or nil if the executed block has no return value.
- (id)ifTrue:(id)(^)trueBlock ifFalse:(id)(^)falseBlock;
@end
```

and this category that the AppScript runtime adds to the `NSObject` class:

```objc
@interface NSObject (AppScriptControlFlow)
/// Executes aBlock in a loop until the testBlock returns `nil` or `[NSNumber numberWithBool: NO]`.
/// Guaranteed to run aBlock at least once.
/// Returns the result of the last execution of aBlock, or nil if aBlock has no return value.
- (id)do:(id)(^)aBlock until:(id)(^)testBlock;
/// Executes aBlock in a loop while the testBlock returns any object other than `nil` or `[NSNumber numberWithBool: NO]`.
/// Might not run aBlock, if the condition is false on the first test.
/// Returns the result of the last execution of aBlock, or nil if aBlock was never run or has no return value.
- (id)do:(id)(^)aBlock while:(id)(^)testBlock;
@end
```

### Unary minus

AppScript does not provide C-style unary minus. To negate a number, send the `negated` message to an `NSNumber`:

```appscript
id temperature = 37
id belowFreezing = [temperature negated] // -37
```

The `NSNumber (AppScriptArithmetic)` category provides:

```objc
@interface NSNumber (AppScriptArithmetic)
- (NSNumber *)negated;
@end
```

### Rounding and clamping

AppScript does not provide the `round()`, `floor()`, `MAX()`, or `MIN()` C functions/macros. These are unavailable via BridgeSupport (they are compiler intrinsics or macros, absent from `libSystem.bridgesupport`). The `NSNumber (AppScriptArithmetic)` category provides equivalents:

```objc
@interface NSNumber (AppScriptArithmetic)
/// Rounds to nearest integer; half-values round away from zero (round() semantics).
- (NSNumber *)rounded;
/// Rounds toward -infinity (floor() semantics).
- (NSNumber *)floored;
/// Returns the larger of the receiver and other (fmax() semantics).
- (NSNumber *)numberMaximumOfSelfAnd:(NSNumber *)other;
/// Returns the smaller of the receiver and other (fmin() semantics).
- (NSNumber *)numberMinimumOfSelfAnd:(NSNumber *)other;
@end
```

All four methods operate on the `double` representation of each operand and return a `double`-typed `NSNumber`.

```appscript
id pixelX = [rawX rounded]                          // round to nearest pixel
id safeHeight = [height numberMinimumOfSelfAnd: @800] // clamp to max 800pt
id paneSize = [requestedSize numberMaximumOfSelfAnd: @100] // clamp to min 100pt
```

### Logical operators

AppScript does not provide the `&&`, `||`, and `!` C operators. Instead, `NSNumber (AppScriptLogic)` provides:

```objc
@interface NSNumber (AppScriptLogic)
- (NSNumber *)and:(NSNumber *)other;
- (NSNumber *)or:(NSNumber *)other;
- (NSNumber *)not;
@end
```

All three methods evaluate both operands eagerly — unlike `&&` and `||` in C, there is no short-circuit behaviour. Use `-[NSNumber ifTrue:ifFalse:]` when you need a lazy second operand. All methods return `@YES` or `@NO`. Truthiness follows the same rule used throughout the runtime: any `NSNumber` whose `-boolValue` is `YES` is true; any whose `-boolValue` is `NO` is false.

```appscript
id a = YES
id b = NO
id both = [a and:b]   // NO
id either = [a or:b]  // YES
id flipped = [a not]  // NO
```

### Bitwise operators

AppScript does not provide the `&`, `|`, `^`, and `~` C bitwise operators. Instead, `NSNumber (AppScriptBitwise)` provides:

```objc
@interface NSNumber (AppScriptBitwise)
/// Bitwise OR of the receiver and other (both treated as unsigned long long).
- (NSNumber *)bitwiseOr:(NSNumber *)other;
/// Bitwise AND of the receiver and other.
- (NSNumber *)bitwiseAnd:(NSNumber *)other;
/// Bitwise XOR of the receiver and other.
- (NSNumber *)bitwiseXor:(NSNumber *)other;
/// Bitwise NOT of the receiver (one's complement).
- (NSNumber *)bitwiseNot;
@end
```

All four methods operate on the `unsigned long long` representation of each operand and return an `unsigned long long`-typed `NSNumber`. This makes them suitable for composing bitmasks such as `NSViewAutoresizingMask` or `NSWindowStyleMask`:

```appscript
id widthSizable  = 2   // NSViewWidthSizable
id heightSizable = 16  // NSViewHeightSizable
id mask = [widthSizable bitwiseOr:heightSizable]  // 18
[view setAutoresizingMask:mask]

// Multi-level chaining for window style masks:
id titled      = @1
id closable    = @2
id resizable   = @8
id styleMask   = [[titled bitwiseOr:closable] bitwiseOr:resizable]
```

### C struct values and BridgeSupport

AppScript preserves the all-objects invariant for C structs by boxing them into `ASStructValue` objects. Once BridgeSupport has been loaded for the relevant framework, struct field access works via ordinary message sends.

#### Loading BridgeSupport for struct access

Before using any method that receives or returns a C struct (e.g. `NSRect`, `NSSize`, `CGPoint`), the host application must load BridgeSupport for the relevant framework. This is mandatory — without it the runtime cannot box struct arguments correctly and will crash:

```objc
// In AppDelegate.applicationDidFinishLaunching: — call BEFORE loadScriptsWithError:
NSError *error = nil;
[NSBundle loadBridgeSupportForFramework:@"Foundation" error:&error];
[NSBundle loadBridgeSupportForFramework:@"AppKit"     error:&error];
```

#### Accessing struct fields

Once BridgeSupport is loaded, methods that return a struct produce an `ASStructValue`. Field access is via message sends whose selector matches the C field name:

```appscript
// NSRect → origin (CGPoint) and size (CGSize) fields
id bounds = [self bounds]               // returns ASStructValue for CGRect
id sz     = [bounds size]               // returns ASStructValue for CGSize
id w      = [sz width]                  // returns NSNumber (double)
id h      = [sz height]                 // returns NSNumber (double)

// Chained:
id width = [[[self bounds] size] width]
```

Field names match the names in the C struct definition: `origin`, `size` for `CGRect`; `x`, `y` for `CGPoint`; `width`, `height` for `CGSize`; `location`, `length` for `NSRange`.

#### Passing structs from ObjC into AppScript methods

When ObjC code calls a method on an AppScript class that takes a struct argument (e.g. `initWithFrame:(NSRect)frame`), AppScript must know the correct method signature to box the argument correctly. AppScript looks for the signature in the protocols the class conforms to. If the method is not declared in a protocol, AppScript falls back to a synthetic all-`id` signature, which misboxes struct arguments and causes a crash.

**Rule**: every method on an AppScript class that accepts or returns a C struct must be declared in the class's ObjC interop protocol with the correct types:

```objc
// LibrarySidebarViewProtocol.h — protocol must include initWithFrame:
@protocol LibrarySidebarViewProtocol <NSObject>
- (instancetype)initWithFrame:(NSRect)frameRect;  // declares NSRect so AppScript boxes it correctly
@property (nonatomic, strong, readonly) NSOutlineView *outlineView;
@end
```

Without this declaration the `methodSignatureForSelector:` override returns `@:@` (all-id) and the NSRect bytes are misread as an object pointer, causing an `EXC_BAD_ACCESS` crash in `objc_retain`.

### Object out-parameters (`NSError **`)

Objective-C methods frequently report errors via an `NSError **` out-parameter (encoded in the Objective-C runtime as `^@` or `o^@`). Because AppScript has no bare pointers or address-of (`&`) / dereference (`*`) operators, the runtime bridges object out-parameters using the `ASOutObject` container class.

#### Implementing a method with an `NSError **` parameter in AppScript

When an Objective-C caller invokes an AppScript method whose signature declares an `NSError **` (or any `id *`) parameter, `ASBoxer` boxes the argument into an `ASOutObject` instance (even when the caller passes `NULL`).

Inside the AppScript method body:
- Send `-setValue:` to the `ASOutObject` parameter to assign an `NSError` that will be written back to the caller's `NSError **` pointer when the method returns (if the caller passed `NULL`, the write-back is safely ignored).
- Or pass the `ASOutObject` parameter directly to another Cocoa method that expects an `NSError **`; any error populated by that inner call is automatically stored in the `ASOutObject` and written back to the outer caller.

**Rule**: just like C struct parameters, every method on an AppScript class that accepts an `NSError **` (or `id *`) out-parameter must be declared in a protocol the class conforms to so the runtime installs the method with the `^@` parameter encoding rather than the synthetic all-`id` (`@`) fallback:

```objc
@protocol NotesStorageProtocol <NSObject>
- (BOOL)saveNotes:(NSAttributedString *)notes forPaperURL:(NSURL *)paperURL error:(NSError **)error;
@end
```

```appscript
@class NotesStorage : NSObject <NotesStorageProtocol>

- saveNotes: notes forPaperURL: paperURL error: outError {
    id rtfURL = [self rtfFileURLForPaperURL: paperURL]
    id options = @{ @"DocumentType": @"NSRTF" }
    id range = [ASFoundation NSMakeRange: 0 : [notes length]]
    id rtfData = [notes dataFromRange: range documentAttributes: options error: outError]
    return [rtfData writeToURL: rtfURL atomically: YES error: outError]
}

@end
```

#### Capturing an `NSError **` when calling Cocoa methods from AppScript

When calling an Objective-C method that takes an `NSError **` parameter from AppScript:
- Pass `nil` if you want to ignore the error (unboxed as a `NULL` `NSError **` pointer).
- Or create an `ASOutObject` via `[ASOutObject outObject]`, pass it as the `error:` argument, and read `[errBox value]` after the call:

```appscript
id errBox = [ASOutObject outObject]
id fm = [NSFileManager defaultManager]
id items = [fm contentsOfDirectoryAtPath: @"/nonexistent" error: errBox]
id err = [errBox value] // holds the NSError instance on failure, or nil on success
```

### BridgeSupport integration

AppScript provides access to C functions and constants declared in Apple's BridgeSupport metadata, while preserving the language's all-objects-are-`id` invariant.

#### What BridgeSupport is

BridgeSupport is an XML format Apple ships alongside its frameworks (in `<Framework.framework>/Resources/BridgeSupport/` and `/System/Library/BridgeSupport/`) that describes each framework's C-level API surface: functions, constants, enums, and structs. The AppScript runtime reads these files to generate Objective-C message-send interfaces automatically, so AppScript code never needs to call a C function directly.

#### How functions are exposed

Each C function described in BridgeSupport is made callable from AppScript as a class method on a generated per-framework proxy class named `AS<FrameworkName>` (e.g., `ASFoundation`, `ASAppKit`). The method name is the original C function name, converted to Objective-C keyword syntax when the function has multiple parameters. For example:

```objc
// C: double sin(double x)
// BridgeSupport proxy:
@interface ASFoundation (AppScriptBridgeSupport)
+ (NSNumber *)sin:(NSNumber *)x;
@end
```

```appscript
id angle = 1.5708
id result = [ASFoundation sin:angle]
```

The runtime automatically unboxes `id` arguments to the required C types before calling the underlying symbol, and boxes the C return value back to `id`.

Functions with no return value (`void`) return `nil`.

#### How constants and enumerations are exposed

BridgeSupport distinguishes two kinds of named values, both exposed as no-argument class methods on the same per-framework proxy class:

**`<constant>` elements** represent genuine C global variables (e.g. notification-name strings, version numbers). Their values are read from the process image at install time via `dlsym` and cached in the method IMP. Symbols that cannot be resolved are silently skipped.

**`<enum>` elements** represent compile-time constants — preprocessor macros and C enum cases whose values are embedded directly in the BridgeSupport XML. They require no runtime symbol lookup. For example, `NSNotFound` is declared in Foundation headers as a macro but is exposed in Foundation's BridgeSupport as `<enum name='NSNotFound' value64='-1'/>` (the BridgeSupport generator uses `-1` as the signed representation of `NSUIntegerMax`).

```objc
@interface ASFoundation (AppScriptBridgeSupport)
+ (NSNumber *)NSNotFound;                   // enum, value -1
+ (NSString *)NSBundleDidLoadNotification;  // constant, resolved via dlsym
+ (NSNumber *)NSFoundationVersionNumber;    // constant, resolved via dlsym
@end
```

```appscript
id sentinel      = [ASFoundation NSNotFound]
id notification  = [ASFoundation NSBundleDidLoadNotification]
id version       = [ASFoundation NSFoundationVersionNumber]
```

Numeric values are boxed into `NSNumber`. String (`@`-typed) constants are returned as-is (typically `NSString`). Enum values are always boxed into `NSNumber`.

#### Framework loading

The host application requests BridgeSupport loading by calling a category method on the proxy class for the desired framework **before** loading any AppScript scripts that depend on those symbols:

```objc
@interface NSBundle (AppScriptBridgeSupportLoading)
/// Loads BridgeSupport metadata for the named framework and registers the AS<FrameworkName>
/// proxy class in the Objective-C runtime.
/// Returns YES on success; sets error and returns NO if the BridgeSupport file cannot be found or parsed.
+ (BOOL)loadBridgeSupportForFramework:(NSString *)frameworkName error:(NSError **)error;
@end
```

An application should call this once per framework. Calling it a second time for the same framework returns `NO` with an error describing the duplicate-load attempt.

#### Boxing and unboxing rules

The same `ASBoxer` rules that govern AppScript method parameters apply to BridgeSupport function arguments and return values. Specifically:

| C type | Boxed type |
|---|---|
| `int`, `long`, `NSInteger`, and unsigned variants | `NSNumber` |
| `float`, `double`, `CGFloat` | `NSNumber` |
| `BOOL` | `NSNumber` |
| `char *` | `NSString` |
| `id *` (e.g. `NSError **`) | `ASOutObject` |
| struct (e.g. `NSRange`, `CGRect`, `CGSize`, `CGPoint`) | `ASStructValue` (unboxes `ASStructValue` or `NSValue` on input) |
| `void` | `nil` |

Structs whose type encodings cannot be resolved (for example, an unexpanded bare struct reference not registered in BridgeSupport) are omitted or return `nil`.

#### Limitations

- Functions with variadic arguments (`...`) are not supported and are silently omitted from the generated proxy.
- Function pointer arguments and return values are not supported.
- BridgeSupport metadata is only loaded for frameworks explicitly requested by the host application; it is never loaded automatically.

## Loading scripts

AppScript provides two mechanisms for loading scripts into the runtime, suited to different use cases.

### Loading from a bundle

The standard production path: call `-loadScriptsWithError:` on an `NSBundle` to discover and load all `.appscript` files in that bundle. This is the approach described in [README.md](README.md).

```objc
#import <AppScript/AppScript.h>

NSError *error = nil;
if (![[NSBundle mainBundle] loadScriptsWithError:&error]) {
    NSLog(@"Script load failed: %@", error);
    abort();
}
```

Each bundle may only be loaded once. A second call on the same bundle returns `NO` with error code `ASBundleLoadingErrorDuplicateLoad`.

### Loading from arbitrary paths or strings

`ASLoader` supports loading scripts from arbitrary file paths or source strings at runtime. This is useful during development (e.g. loading scripts from a project directory rather than the app bundle), in tools and tests, or for evaluating dynamically generated scripts.

```objc
#import <AppScript/AppScript.h>

ASLoader *loader = [[ASLoader alloc] init];
NSError *error = nil;

// Load from a file path
if (![loader loadScriptFromFileAtPath:@"/path/to/MyScript.appscript" error:&error]) {
    NSLog(@"Failed: %@", error);
}

// Load from a source string
NSString *source = @"@class Greeter : NSObject\n- greet { return @\"Hello\" }\n@end";
if (![loader loadScriptFromString:source error:&error]) {
    NSLog(@"Failed: %@", error);
}
```

You can also supply a `scriptName:` for clearer error messages:

```objc
[loader loadScriptFromFileAtPath:path scriptName:@"MyFeature" error:&error];
[loader loadScriptFromString:source scriptName:@"generated-script" error:&error];
```

To load multiple files in dependency order (superclass relationships are resolved automatically using topological sort):

```objc
NSArray *paths = @[@"/scripts/Base.appscript", @"/scripts/Derived.appscript"];
[loader loadScriptsFromFilesAtPaths:paths error:&error];
```

Multiple strings can also be loaded in one call, though dependency ordering is not applied for string-based batches:

```objc
[loader loadScriptsFromStrings:@[sourceA, sourceB] error:&error];
```

#### Duplicate-load detection

`ASLoader` tracks loaded scripts to prevent double-loading:
- File-based scripts are identified by their absolute path.
- String-based scripts are identified by a hash of their source content.

A duplicate load returns `NO` with error code `ASLoaderErrorDuplicateLoad`.

#### Error codes

| Code | Meaning |
|---|---|
| `ASLoaderErrorFileNotFound` | The specified file does not exist. |
| `ASLoaderErrorFileReadFailure` | The file could not be read (permissions, encoding). |
| `ASLoaderErrorLexerFailure` | The source failed lexing. |
| `ASLoaderErrorParserFailure` | The source failed parsing. |
| `ASLoaderErrorInstallFailure` | The runtime could not install the parsed definitions. |
| `ASLoaderErrorDuplicateLoad` | The script has already been loaded. |

All errors are in the `ASLoaderErrorDomain` error domain.
