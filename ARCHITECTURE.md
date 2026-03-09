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

### Blocks

Block literals are introduced using the `^` character. If the block has arguments, their names are listed next, in a pair of parentheses. Next, the opening brace `{` represents the start of the block's body. Each statement in the block's body must be presented on a separate line, followed by a line that only contains the `}` character to represent the end of the block. Examples:

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

Declare a class with the `@class` keyword, followed by the name of the class, then a colon, then any protocol conformances in angle brackets.

In subsequent lines, define properties, instance methods, and class methods. Complete the class definition with the word `@end` on its own line.

Properties are always Objective-C objects. Use the `@property` keyword, followed by any modifiers in parentheses, then the name of the property. Acceptable modifiers:

- `strong`: The property is a strong reference to an object that's assigned to it.
- `weak`: The property is a weak reference to an object that's assigned to it.
- `copy`: The object makes a copy of an object that's assigned to a property, and keeps a strong reference to that object.
- `nonatomic`: Accesses to the property from different threads aren't atomic.
- `atomic`: Accesses to the property from different threads are atomic.
- `dynamic`: The runtime doesn't synthesize property accessor methods.
- `readonly`: The property can be read but not written to.

If no modifiers are supplied, the property is `strong` and `nonatomic`.

If the property definition doesn't include the `dynamic` modifier, then the AppScript runtime synthesizes Key-Value Coding-compliant accessors (only a method to retrieve the value of a `readonly` property, otherwise also a mutator method). However, the developer can provide custom implementations of methods with the same names, in which case the AppScript runtime doesn't synthesize the accessors.

There isn't any dot syntax for accessing properties in AppScript: use the accessor methods instead.

Method signatures start with a `-` for an instance method or `+` for a class method, followed by the name of the method which includes parameters in infix format, with parameter names separated from the method name by colons. All parameters are Objective-C objects, and the return value is an Objective-C object (return `self` from methods with no return value; return `nil` to indicate the lack of an object). The end of the method signature must be the `{` character denoting the start of the method implementation.

Place the method body on subsequent lines, one line per statement, finishing with the `}` character on its own line.
Here's a complete example of a class:

```appscript
@class Calculator : NSObject <NSCopying>

@property base
@property accumulator

+ calculatorWithBase: aNumber {
    calc = [self new]
    [calc setBase:aNumber]
    return calc
}

- copyWithZone: aZone {
    calc = [[self class] new]
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

AppScript doesn't provide control flow keywords. Iterate through collections of objects using the collection's `-objectEnumerator` and the `NSEnumerator` methods. Implement conditional flow using this category that the AppScript runtime adds to the `NSNumber` class:

```objc
@interface @NSNumber (AppScriptControlFlow)
- (id)ifTrue:(id)(^)trueBlock ifFalse:(id)(^)falseBlock;
@end
```

and this category that the AppScript runtime adds to the `NSObject` class:

```objc
@interface NSObject (AppScriptControlFlow)
/// Executes aBlock in a loop until the testBlock returns `nil` or `[NSNumber numberWithBool: NO]`.
/// Guaranteed to run aBlock at least once.
- (id)do:(id)(^)aBlock until:(id)(^)testBlock;
/// Executes aBlock in a loop which the testBlock returns any object other than `nil` or `[NSNumber numberWithBool: NO]`.
/// Might not run aBlock, if the condition is false on the first test.
- (id)do:(id)(^)aBlock while:(id)(^)testBlock;
@end
```

## Runtime Implementation

An app embeds the AppScript runtime as a dynamic framework, and loads the scripts for a bundle by calling a category method on `NSBundle` that the framework provides:

```objc
@interface NSBundle (AppScriptLoading)
/// Discovers all the AppScript script files in the bundle and loads them into the host application, unless it encounters a syntax error.
/// Returns YES if it succeeded; otherwise, returns NO and sets the error parameter to a description of the error.
- (BOOL)loadAppScriptsInBundle:(NSError **)error;
@end
```

An application must only call this method once for any bundle, but can call it on multiple bundles.

This method searches for `*.as` files in the bundle, searches the files for class definitions, and registers class pairs with those names in the Objective-C runtime. The registered classes supply `-respondsToSelector:`, `-methodSignatureForSelector:`, and `-forwardInvocation:` implementations that invoke the interpreter.

The `-respondsToSelector:` implementation checks whether the superclass implements a method with the supplied selector name, and returns `YES` if it does. Otherwise, it checks if the AppScript script defines a method with that selector name, and returns `YES` if it does. If neither source implements the method, it returns `NO`.

The `-methodSignatureForSelector:` implementation returns the superclass's method signature for the given selector, if it exists. Otherwise, it checks whether the AppScript script defines a method with that selector name. If it does, then the implementation returns a method signature with `@` as the return type, `@:` as the parameter types for `self` and `_cmd`, and `@` as the parameter type for all additional parameters. If neither source defines the method, then it returns `nil`.

The `-forwardInvocation:` implementation finds the AppScript fragment that corresponds to the selector in the invocation, boxes parameters if necessary, then interprets each statement in the script fragment in turn. When it encounters a `return` statement, it unboxes the returned object if necessary, and sets the return value in the supplied invocation.
If the interpreter encounters an error during `-forwardInvocation:`, it must output information about the error including the AppScript file path and line number where the error occurred, then crash the application.

AppScript uses Objective-C ARC to manage memory. The interpreter can be active on multiple threads simultaneously, and can execute code that causes operations on different threads; for example, a script can call `-[NSObject performSelectorOnMainThread:]`.
