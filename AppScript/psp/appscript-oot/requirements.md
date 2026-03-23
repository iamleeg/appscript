# Requirements: appscript-oot — Hybrid Spliced AppScript+ObjC Backtrace

## Overview

Extend `ASInterpreter -reportError:code:node:context:` to produce a hybrid backtrace
that interleaves the native ObjC call stack (`[NSThread callStackSymbols]`) with the
AppScript thread-local frame stack, replacing clusters of AppScript runtime frames
with the corresponding AppScript call frame description.

## Functional Requirements

### FR-1: Hybrid backtrace algorithm

When `reportError:` fires, build a hybrid trace by walking `[NSThread callStackSymbols]`
(innermost frame = index 0) as follows:

1. Scan each ObjC symbol string for any of the **runtime filter substrings** (see FR-2).
2. A *runtime cluster* is one or more consecutive ObjC frames that each match at least
   one filter substring.
3. Replace each runtime cluster with the **next unconsumed AppScript call frame**
   (consuming innermost-first: last entry in `ASCurrentCallStack()`, working toward index 0).
4. Consecutive non-matching ObjC frames pass through **verbatim**.
5. If a runtime cluster is encountered but the AppScript frame stack has been exhausted,
   emit the literal placeholder string:
   `  at <AppScript runtime frame>`
6. Any remaining AppScript frames after the ObjC stack is exhausted are **not** appended
   (they are already included via the clusters).

### FR-2: Runtime filter substrings

An ObjC frame is classified as an AppScript runtime frame if its symbol string contains
any of the following substrings (checked with `-[NSString containsString:]`):

- `ASForwardInvocationIMP`
- `evaluateMethodBody:`
- `evaluateMessageSend:`
- `executeStatement:`
- `reportError:`
- `ASBuildHybridBacktrace` (the new function itself)

### FR-3: AppScript call frame format

Each AppScript call frame is formatted using the existing `ASFormatCallFrame()` static
function, producing lines of the form:
```
  at -[ClassName selector:] (param=<value>) /path/to/script.appscript:12
```

### FR-4: New public userInfo key

Declare and define a new public constant:
```objc
FOUNDATION_EXPORT NSString *const ASErrorHybridCallStackKey;
```
The hybrid trace string (multi-line, one entry per output line, joined with `\n`) is
stored under this key in the exception's `userInfo` dictionary.

### FR-5: Integration into exception reason string

Replace the existing `"AppScript call stack (most recent call first):\n<frames>"` section
in the exception `reason` string with:
```
Call stack (most recent call first):
<hybrid trace lines>
```
The section header and trace block appear after the source context line (same position as
the old AppScript-only block).

### FR-6: Backwards compatibility

`ASErrorCallStackKey` continues to carry the **AppScript-only** formatted call stack,
unchanged. Existing callers that read this key are unaffected.

## Non-functional Requirements

- No new allocations on the critical path beyond what `[NSThread callStackSymbols]`
  already allocates.
- Thread-safe: the hybrid builder reads only thread-local state and immutable ObjC
  symbols — no synchronisation needed.

## Out of Scope

- Demangling C++ or Swift symbol names in ObjC frames.
- Filtering frames from frameworks other than AppScript.
- Modifying the GNUstep build (hybrid backtrace uses `NSThread` which is available on
  GNUstep, but `[NSThread callStackSymbols]` behaviour may vary — acceptable).
