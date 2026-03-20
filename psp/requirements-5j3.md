# Requirements — appscript-5j3: Call Stack Backtrace

## Problem Statement

When `reportError:node:context:` fires in `ASInterpreter`, the error currently shows only the immediate error site (path, line, column, locals). Developers need a full AppScript-level call stack to trace the chain of method invocations that led to the error.

## Functional Requirements

### REQ-1 — ASCallFrame class (internal)

Create an internal `ASCallFrame` class in `ASInterpreter.m` with the following properties:

- `receiver` (`id`) — the object receiving the method call
- `selector` (`NSString *`) — the selector being invoked
- `parameterNames` (`NSArray<NSString *> *`) — parameter names in declaration order
- `arguments` (`NSArray *`) — evaluated argument values, parallel to `parameterNames`
- `scriptPath` (`NSString *`) — path of the `.appscript` file containing this method
- `callSiteLine` (`NSUInteger`) — 1-based line number of the call site in the *calling* frame; 0 if called from ObjC (no AppScript call site)
- `frameName` (`NSString *`) — synthesized display name; see REQ-3 and REQ-4

### REQ-2 — Thread-local frame stack

Maintain a mutable array of `ASCallFrame *` objects in `NSThread.currentThread.threadDictionary` under a private static key (e.g. `@"ASInterpreterCallStack"`). The stack represents the chain of active AppScript calls on the current thread, innermost frame last.

### REQ-3 — Push/pop in evaluateMethodBody:

Augment `evaluateMethodBody:withReceiver:definingClass:selector:arguments:parameterNames:scriptPath:` to accept one additional internal parameter:

```
callSiteNode:(nullable ASASTNode *)callSiteNode
```

(This is the `ASMessageSendNode` that triggered the dispatch, or `nil` when called from ObjC.)

At method entry, construct an `ASCallFrame`:
- `frameName` = `-[ClassName selector:]` where `ClassName` is `NSStringFromClass([receiver class])`
- `callSiteLine` = `callSiteNode.lineNumber` (or `0` if `callSiteNode` is `nil`)
- Remaining fields from the method arguments

Push the frame onto the thread-local stack, then execute the body inside `@try { … } @finally { pop frame }`.

### REQ-4 — Push/pop in executeBlockBody:

Augment `executeBlockBody:parentScope:definingClass:scriptPath:weakNames:constantNames:arguments:paramNames:` with:

```
definingMethodSelector:(NSString *)methodSelector
blockIndex:(NSUInteger)blockIndex
callSiteNode:(nullable ASASTNode *)callSiteNode
```

Construct an `ASCallFrame`:
- `frameName` = `[ClassName methodSelector:]__blockN` where `N` is `blockIndex`
- `receiver` = `nil` (blocks have no explicit receiver)
- `callSiteLine` = `callSiteNode.lineNumber` (or `0`)

Push/pop with `@try/@finally` as in REQ-3.

Block callers in `evaluateBlockLiteral:context:` must supply a per-method block counter (starting at 0, incremented each time a block is evaluated within a method frame), the current method selector from scope (`_cmd`), and the current AST node (the `ASBlockLiteralNode`) as `callSiteNode`.

### REQ-5 — Call stack formatting in reportError:

In `reportError:code:node:context:`, after building the existing `baseReason` string:

1. Read the thread-local frame stack.
2. If the stack is non-empty, append a call stack section to the reason string:
   ```
   AppScript call stack (most recent call first):
     at -[MyClass doSomething:] (arg0=<"hello">) /path/to/script.appscript:12
     at -[MyClass run] () /path/to/script.appscript:5
   ```
   Format per frame (innermost first = last element in the array first):
   - `  at <frameName> (<param0>=<arg0 description>, …)` — omit parens content if no params
   - ` <scriptPath>:<callSiteLine>` — omit line number if `callSiteLine == 0`
3. Store the formatted call stack string (the section after the header line, one frame per line) in `userInfo` under `ASErrorCallStackKey`.

### REQ-6 — New public constant: ASErrorCallStackKey

Declare and define:

```objc
FOUNDATION_EXPORT NSString *const ASErrorCallStackKey;
```

Value: `@"ASErrorCallStack"`. Type of value in userInfo: `NSString *` (formatted multi-line string, one frame per line). Add doc comment to `ASInterpreter.h`.

### REQ-7 — Header doc update

Update the `ASInterpreter` class doc comment in `ASInterpreter.h`: the statement "ASInterpreter is stateless and thread-safe" remains true for the *shared interpreter object itself*, but note that it uses thread-local storage to track per-thread call frames during evaluation.

## Non-Functional Requirements

- Thread safety: the thread-local dictionary ensures frames from concurrent evaluations on different threads do not interfere.
- No change to existing `evaluateMethodBody:` public signature in the header — the `callSiteNode:` parameter is added only to the internal private method. The public header method remains the entry point; it calls the private variant with `callSiteNode:nil`.

## Out of Scope

- Displaying ObjC frames (non-AppScript frames) in the backtrace
- Changing the format of the existing error message header line
- Source context for outer frames (only the innermost frame shows source context)
