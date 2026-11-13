# Control Flow and Arithmetic

Use the runtime-provided categories on NSNumber and NSObject to implement loops and conditionals in AppScript.

## Overview

AppScript has no built-in control flow keywords or arithmetic operators. Instead, the runtime adds categories to `NSNumber` and `NSObject` that provide these capabilities as ordinary message sends.

## Arithmetic

`NSNumber` gains four binary arithmetic methods and one unary method:

```appscript
id sum = [x numberByAdding: y]
id diff = [x numberBySubtracting: y]
id product = [x numberByMultiplyingBy: y]
id quotient = [x numberByDividingBy: y]
id negative = [x negated]
```

All operations use double-precision arithmetic and return a new `NSNumber`. `negated` returns the arithmetic negation of the receiver.

## Logical operators

`NSNumber` also gains three logical operator methods that treat the receiver as a boolean:

```appscript
id both = [a and: b]    // YES iff both a and b are truthy
id either = [a or: b]   // YES iff a, b, or both are truthy
id flipped = [a not]    // YES iff a is falsy
```

Truthiness follows the same rule as ``-[NSNumber ifTrue:ifFalse:]``: any `NSNumber` whose `-boolValue` is `YES` is considered true. All three methods return `@YES` or `@NO`.

Unlike `&&` and `||` in C, `and:` and `or:` evaluate both operands **eagerly** — the second argument is fully evaluated before the method is called. When you need the second operand to be skipped based on the first, use `ifTrue:ifFalse:` with blocks instead.

## Conditionals

Use `-[NSNumber ifTrue:ifFalse:]` to branch on a boolean value:

```appscript
id flag = YES
[flag ifTrue: ^{
    [self doSomething]
} ifFalse: ^{
    [self doSomethingElse]
}]
```

The method executes the matching block and returns its result, or `nil` if the chosen block has no return value.

When only one branch matters, use `-ifTrue:` or `-ifFalse:` instead of supplying an empty block:

```appscript
[flag ifTrue: ^{
    [self doSomething]
}]
[flag ifFalse: ^{
    [self doSomethingElse]
}]
```

`-ifTrue:` is equivalent to `[flag ifTrue: trueBlock ifFalse: nil]`, and `-ifFalse:` to `[flag ifTrue: nil ifFalse: falseBlock]`. Each returns the block's result if it ran, or `nil` otherwise.

## Testing for nil

Send `-isNil` to any value to test whether it is AppScript `nil`. It returns `@YES` for `nil` (the `nil` literal, an uninitialised variable, a `nil` argument, or a `nil` returned from a method) and `@NO` for every other object, including `[NSNull null]`, `NO` and `0`. Combine it with the conditional methods:

```appscript
id album = [albumsByTitle objectForKey: title]
[[album isNil] ifTrue: ^{
    [self reportMissingAlbum: title]
} ifFalse: ^{
    [self playAlbum: album]
}]
```

Sending `-isNil` directly to the result of another message send, such as `[[albumsByTitle objectForKey: title] isNil]`, works the same way as storing the result in a variable first.

## Loops

Use `-[NSObject do:while:]` or `-[NSObject do:until:]` for iteration.

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
