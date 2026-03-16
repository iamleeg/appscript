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

Number literals (both floating-point and integer), and the BOOL values YES and NO, are automatically boxed into `NSNumber` instances:

```appscript
id flag = NO // Equivalent to Objective-C [NSNumber numberWithBool: NO]
id pi = 3.14 // Equivalent to Objective-C [NSNumber numberWithDouble: 3.14]
```

String literals, array literals, and dictionary literals use the same syntax as Objective-C, including the `@` prefix. Objective-C selectors are represented as string literals.

```appscript
id artist = @"Frank Zappa"
id albums = @[@"Sheik Yerbouti", @"Hot Rats"]
id band_members = @{ @"Bass": @"Roy Estrada", @"Drums" : @"Jimmy Carl Black", @"Harmonica": @"Ray Collins" }
id selector = @"writeToFile:atomically:"
```

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
| `NSString (AppScriptRuntime)` | `-as_class` | `NSClassFromString()` | Returns the `Class` as `id`; returns `nil` for unknown names. |
| `NSURL (AppScriptFileReading)` | `-as_stringContents` | `+[NSString stringWithContentsOfURL:encoding:error:]` | UTF-8; returns `nil` on error instead of using an out-parameter. |

```appscript
id cls = [@"NSMutableArray" as_class]
id instance = [cls new]

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
| struct (registered with `NSValue`) | `NSValue` |
| `void` | `nil` |

Structs that are not registered with `NSValue` produce a runtime error.

#### Limitations

- Functions with variadic arguments (`...`) are not supported and are silently omitted from the generated proxy.
- Function pointer arguments and return values are not supported.
- BridgeSupport metadata is only loaded for frameworks explicitly requested by the host application; it is never loaded automatically.
