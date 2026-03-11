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

AppScript supports **only** Objective-C message sends. C functions, C operators, preprocessor macros, and inline expressions are not available. Every operation must be expressed as a message to an object. Where Objective-C programmers would normally reach for a C function (e.g. `NSStringFromClass`), use an equivalent message send instead (e.g. `[[self class] description]`). If no suitable method exists on the target class, the AppScript runtime provides one via a category on the relevant Foundation class.

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

## Runtime Implementation

An app embeds the AppScript runtime as a dynamic framework, and loads the scripts for a bundle by calling a category method on `NSBundle` that the framework provides:

```objc
@interface NSBundle (AppScriptLoading)
/// Discovers all the AppScript script files in the bundle and loads them into the host application, unless it encounters a syntax error.
/// Returns YES if it succeeded; otherwise, returns NO and sets the error parameter to a description of the error.
- (BOOL)loadScriptsWithError:(NSError **)error;
@end
```

An application should call this method once per bundle. If called a second time on the same bundle, it returns `NO` and sets the error parameter to describe the duplicate-load attempt. It can be called on multiple different bundles.

This method searches for `*.appscript` files in the bundle, searches the files for class definitions, and registers class pairs with those names in the Objective-C runtime. For each method defined in an AppScript class, the runtime installs it directly on the registered class: using `class_addMethod` for methods not present in the superclass, and `method_setImplementation` to replace the inherited implementation for methods that override a superclass method. Each installed method IMP is a trampoline that boxes parameters if necessary, invokes the interpreter with the corresponding AppScript fragment, and unboxes the return value if necessary.

If the interpreter encounters an error while executing an AppScript method, it must output information about the error including the AppScript file path and line number where the error occurred, then crash the application.

AppScript uses Objective-C ARC to manage memory. The interpreter can be active on multiple threads simultaneously, and can execute code that causes operations on different threads; for example, a script can call `-[NSObject performSelectorOnMainThread:]`.

### Block implementation

When the interpreter evaluates a block literal such as `^(a b) { return [a compare:b] }`, it creates an Objective-C block whose arity matches the number of declared parameters. The interpreter supports blocks with zero to four parameters; blocks with more parameters produce a runtime error. All parameters and the return value are typed as `id`.

The parameter names, body AST, and captured scope chain are closed over by the block at creation time, so no additional storage (such as associated objects on the block instance) is necessary. When the block is invoked by Objective-C code, the received arguments are bound into a new child scope under the captured scope, and the body is executed.

Because all AppScript blocks return `id`, there is a mismatch when a native Objective-C API expects a block that returns a C primitive type. For example, `sortedArrayUsingComparator:` expects a block returning `NSComparisonResult` (an `NSInteger`), not an `id`. The AppScript runtime provides `as_`-prefixed adaptor methods on Foundation classes to bridge this gap:

```objc
@interface NSArray (AppScriptBlocks)
/// Returns the array sorted using a comparator block that returns NSComparisonResult as an NSNumber.
- (NSArray *)as_sortedArrayUsingBlock:(id (^)(id, id))comparatorBlock;
@end
```

AppScript code calls `as_sortedArrayUsingBlock:` instead of `sortedArrayUsingComparator:` and returns the result of `[a compare:b]` directly — the runtime adaptor unboxes the `NSNumber` return value to `NSComparisonResult` before forwarding to Foundation.
