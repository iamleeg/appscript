# Defining Classes and Categories

Write AppScript class and category definitions and understand how they map to the Objective-C runtime.

## Overview

AppScript supports defining new Objective-C subclasses and categories directly in `.appscript` script files. `ASRuntimeInstaller` translates these definitions into live Objective-C types at load time.

## Defining a class

Use `@class` to declare a class, specifying its superclass and optional protocol conformances:

```appscript
@class Calculator : NSObject <NSCopying>

@property base
@property accumulator

+ calculatorWithBase: aNumber {
    id calc = [self new]
    [calc setBase: aNumber]
    return calc
}

- add: aNumber {
    [self setAccumulator: [[self accumulator] numberByAdding: aNumber]]
    return self
}

@end
```

`ASRuntimeInstaller` calls `objc_allocateClassPair` and `objc_registerClassPair` to register `Calculator` as a real Objective-C class whose superclass is `NSObject`.

## Properties

Each `@property` declaration causes `ASRuntimeInstaller` to synthesize KVC-compliant accessor methods unless you provide custom implementations with the same names. Supported modifiers are `strong`, `weak`, `copy`, `atomic`, `nonatomic`, `readonly`, and `dynamic`.

## Method installation

For each method defined in an AppScript class, `ASRuntimeInstaller`:

1. Constructs a trampoline IMP that boxes incoming C parameters to `id` using `ASBoxer`.
2. Calls `ASInterpreter` with the method's AST fragment.
3. Unboxes the return value using `ASBoxer`.
4. Uses `class_addMethod` for new methods, or `method_setImplementation` to replace inherited ones.

## Sending messages to the superclass

Inside a method body, `super` is a keyword that can be used as the message receiver. It dispatches the message to the **superclass of the class that statically defines the current method**, while keeping `self` as the actual receiver — matching `objc_msgSendSuper` semantics.

```appscript
@class Dog : Animal

- describe {
    id base = [super describe]
    return [base stringByAppendingString:@" (specifically, a dog)"]
}

@end
```

`self` may be reassigned inside a method body. The canonical initialiser pattern works as in Objective-C:

```appscript
- init {
    self = [super init]
    return self
}
```

`super` is a parse error inside a block literal.

## Defining a category

Use `@category` to add methods to an existing Objective-C or AppScript class without subclassing:

```appscript
@category NSString (Screaming)

- scream {
    return [self uppercaseString]
}

@end
```

The category name is required but unused at runtime.
## Topics

### Class and category definitions

- ``ASClassDefinitionNode``
- ``ASCategoryDefinitionNode``

### Methods and properties

- ``ASMethodNode``
- ``ASPropertyNode``

### Abstract syntax tree

- ``ASASTNode``
- ``ASArrayLiteralNode``
- ``ASAssignmentNode``
- ``ASBlockLiteralNode``
- ``ASDictionaryLiteralNode``
- ``ASIdentifierNode``
- ``ASMessageSendNode``
- ``ASNumberLiteralNode``
- ``ASReturnNode``
- ``ASStringLiteralNode``
- ``ASSuperNode``
- ``ASVariableDeclarationNode``

### Runtime installation

- ``ASRuntimeInstaller``

