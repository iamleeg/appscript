# Requirements: appscript-ewo — Escape Sequences in String Literals

## Problem Statement

The AppScript parser (`ASParser.m`) strips the `@"..."` delimiters from string literals but does not process C-style escape sequences. As a result, the source text `@"\n"` produces a two-character string (`\` + `n`) instead of a newline character. This needs to be fixed so that escape sequences are resolved to their intended characters.

## Scope

The fix is localised to `ASParser.m` around line 810, inside `parseAtExpression:error:` (or its caller), after the raw token text is stripped of its `@"` prefix and `"` suffix.

## Required Escape Sequences

The following escape sequences **must** be handled:

| Sequence | Meaning |
|----------|---------|
| `\n`     | Newline (U+000A) |
| `\t`     | Horizontal tab (U+0009) |
| `\r`     | Carriage return (U+000D) |
| `\\`     | Literal backslash |
| `\"`     | Literal double-quote |

## Resolved: Additional escape sequences

Support **all escape sequences that Objective-C supports**:

| Sequence | Meaning |
|----------|---------|
| `\0`     | Null character (U+0000) |
| `\a`     | Bell (U+0007) |
| `\b`     | Backspace (U+0008) |
| `\f`     | Form feed (U+000C) |
| `\v`     | Vertical tab (U+000B) |
| `\xNN`   | Hex character (1–2 hex digits) |
| `\uNNNN` | Unicode code point (4 hex digits) |
| `\UNNNNNNNN` | Unicode code point (8 hex digits) |
| `\NNN`   | Octal character (1–3 octal digits) |

## Resolved: Invalid / unrecognised escape sequences

A backslash followed by an unrecognised character (e.g. `\q`) is a **parse error**: return `nil` and populate the `NSError` parameter with a descriptive message including the unrecognised sequence and its source location.

## Resolved: Fix location

The fix belongs in **`ASParser.m`**, so that `ASStringLiteralNode` stores the already-unescaped string value — consistent with how the compiled Objective-C language behaves.

## Non-Goals

- No changes to the lexer tokenisation of string literals.
- No changes to other literal types (numbers, booleans, nil).
- No changes to the AppScript runtime or evaluator.

## Acceptance Criteria

1. `@"\n"` evaluates to a single newline character (U+000A).
2. `@"\t"` evaluates to a single tab character (U+0009).
3. `@"\r"` evaluates to a single carriage-return character (U+000D).
4. `@"\\"` evaluates to a single backslash.
5. `@"\""` evaluates to a single double-quote.
6. `@"\0"` evaluates to a null character (U+0000).
7. `@"\a"` evaluates to U+0007 (bell).
8. `@"\b"` evaluates to U+0008 (backspace).
9. `@"\f"` evaluates to U+000C (form feed).
10. `@"\v"` evaluates to U+000B (vertical tab).
11. `@"\x41"` evaluates to `A` (hex escape).
12. `@"\u0041"` evaluates to `A` (4-digit Unicode escape).
13. `@"\U00000041"` evaluates to `A` (8-digit Unicode escape).
14. `@"\101"` evaluates to `A` (octal escape).
15. `@"\q"` (or any unrecognised backslash sequence) causes the parser to return a parse error with a useful message.
16. Strings with no escape sequences are unaffected.
17. All existing AppScript tests continue to pass.
18. New unit tests cover each of the above criteria.
