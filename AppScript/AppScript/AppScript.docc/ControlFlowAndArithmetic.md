# Control Flow and Arithmetic

Use the runtime-provided categories on NSNumber and NSObject to implement loops and conditionals in AppScript.

## Overview

AppScript has no built-in control flow keywords or arithmetic operators. Instead, the runtime adds categories to `NSNumber` and `NSObject` that provide these capabilities as ordinary message sends.

## Arithmetic

``NSNumber`` gains four arithmetic methods:

```appscript
id sum = [x numberByAdding: y]
id diff = [x numberBySubtracting: y]
id product = [x numberByMultiplyingBy: y]
id quotient = [x numberByDividingBy: y]
```

All operations use double-precision arithmetic and return a new `NSNumber`.

## Conditionals

Use ``NSNumber/ifTrue:ifFalse:`` to branch on a boolean value:

```appscript
id flag = YES
[flag ifTrue: ^{
    [self doSomething]
} ifFalse: ^{
    [self doSomethingElse]
}]
```

The method executes the matching block and returns its result, or `nil` if the chosen block has no return value.

## Loops

Use ``NSObject/do:while:`` or ``NSObject/do:until:`` for iteration.

`do:while:` checks the condition before each iteration; the body may not run at all:

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

`do:until:` runs the body at least once, then checks the condition:

```appscript
[self do: ^{
    id item = [self nextItem]
    [self process: item]
} until: ^{
    return [self isDone]
}]
```

## Topics

### Arithmetic
- ``NSNumber``

### Control flow
- ``NSObject``
