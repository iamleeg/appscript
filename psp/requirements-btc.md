# Requirements: appscript-btc — NSException instead of abort() for AppScript runtime errors

## Summary

Replace the `abort()` call in `-[ASInterpreter reportError:node:context:]` with `[NSException raise:ASRuntimeErrorException ...]`, carrying a structured `userInfo` dictionary. Remove the existing `fprintf(stderr, ...)` print. This makes runtime errors catchable by test code and enables structured error handling by callers.

## Functional Requirements

### FR-1: Exception name constant
Define a public `NSString *const ASRuntimeErrorException` in `ASInterpreter.h` (or a dedicated public header). This constant is the name passed to `[NSException raise:...]`.

### FR-2: userInfo key constants
Define the following public `NSString *const` key constants, to be used in the `userInfo` dictionary of the raised exception:

| Constant | Type of value | Description |
|---|---|---|
| `ASErrorMessageKey` | `NSString *` | Human-readable description of the error |
| `ASErrorScriptPathKey` | `NSString *` | Path of the `.appscript` file where the error occurred, or `"<unknown>"` |
| `ASErrorLineKey` | `NSNumber *` (NSUInteger) | Line number of the error node (0 if no node) |
| `ASErrorColumnKey` | `NSNumber *` (NSUInteger) | Column number of the error node (0 if no node) |
| `ASErrorMessageCodeKey` | `NSNumber *` (ASErrorCode) | Numeric code uniquely identifying the type of error |

### FR-3: Error code enumeration
Define a public `NS_ENUM(NSInteger, ASErrorCode)` with one value per distinct runtime error currently raised by the interpreter. Each enumerator must have a DocC `///` documentation comment describing exactly when it is raised. Initial values:

| Enumerator | Description |
|---|---|
| `ASErrorCodeCannotReassignConstant` | Attempt to assign a new value to a variable that was declared as a constant. |
| `ASErrorCodeUndefinedVariable` | Assignment to a variable name that is not declared in any enclosing scope. |
| `ASErrorCodeUndefinedIdentifier` | An identifier expression could not be resolved to a variable, parameter, `self`, `super`, `nil`, or a known Objective-C class. |
| `ASErrorCodeUnknownASTNodeType` | The interpreter encountered an AST node of an unrecognised class during evaluation. |
| `ASErrorCodeUnrecognisedSelector` | A message send targeted an object whose class does not respond to the requested selector. |

### FR-4: Replace abort() with NSException raise
In `-[ASInterpreter reportError:node:context:]`:
- Remove the `fprintf(stderr, ...)` call.
- Remove the `abort()` call.
- Construct a `userInfo` dictionary with `ASErrorMessageKey`, `ASErrorScriptPathKey`, `ASErrorLineKey`, `ASErrorColumnKey`, and `ASErrorMessageCodeKey` populated from the method's arguments and the error type.
- Call `[NSException raise:ASRuntimeErrorException format:@"%@", message]` (or equivalent) with the populated `userInfo`.

### FR-5: noreturn attribute
Keep `__attribute__((noreturn))` on the declaration, unless doing so produces a compiler error or warning. `[NSException raise:...]` does not return, so the attribute is accurate; remove only if the compiler rejects it.

### FR-6: Error code passed through call sites
Each of the five call sites in `ASInterpreter.m` that currently invoke `reportError:node:context:` must supply the appropriate `ASErrorCode`. The signature of the private helper method must be updated to accept a `code:(ASErrorCode)` parameter.

### FR-7: No safeguard mechanism
No `NSUncaughtExceptionHandler` or other catch-all is added. A comment in the code notes that callers are responsible for not swallowing `ASRuntimeErrorException`.

### FR-8: Tests
Add XCTest cases to `ASInterpreterTests.m` that exercise each of the five error paths, asserting:
- An `NSException` named `ASRuntimeErrorException` is raised (use `XCTAssertThrowsSpecificNamed`).
- The `userInfo` dictionary contains the correct `ASErrorMessageCodeKey` value for the path under test.

## Non-functional Requirements

- No public API changes other than the new constants, exception name, and enum defined above.
- All existing `ASInterpreterTests` must continue to pass.
