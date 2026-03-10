# Defining Classes and Categories

Write AppScript class and category definitions and understand how they map to the Objective-C runtime.

## Overview

AppScript supports defining new Objective-C subclasses and categories directly in `.as` script files. ``ASRuntimeInstaller`` translates these definitions into live Objective-C types at load time.

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

``ASRuntimeInstaller`` calls `objc_allocateClassPair` and `objc_registerClassPair` to register `Calculator` as a real Objective-C class whose superclass is `NSObject`.

## Properties

Each `@property` declaration causes ``ASRuntimeInstaller`` to synthesize KVC-compliant accessor methods unless you provide custom implementations with the same names. Supported modifiers are `strong`, `weak`, `copy`, `atomic`, `nonatomic`, `readonly`, and `dynamic`.

## Method installation

For each method defined in an AppScript class, ``ASRuntimeInstaller``:

1. Constructs a trampoline IMP that boxes incoming C parameters to `id` using ``ASBoxer``.
2. Calls ``ASInterpreter`` with the method's AST fragment.
3. Unboxes the return value using ``ASBoxer``.
4. Uses `class_addMethod` for new methods, or `method_setImplementation` to replace inherited ones.

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

### Class registration
- ``ASRuntimeInstaller``

### AST representation
- ``ASClassDefinitionNode``
- ``ASCategoryDefinitionNode``
- ``ASPropertyNode``
- ``ASMethodNode``
