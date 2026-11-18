# Handling Exceptions

Intercept failures of message sends in scripts, log them, or recover and retry.

## Overview

When a message send in a script fails — the receiver doesn't respond to the selector, an argument can't be converted, or native code raises — the interpreter asks the installed ``ASExceptionHandler`` what to do before the exception propagates.

Without any handler installed, AppScript uses ``ASLoggingExceptionHandler``. It logs one line with `NSLog`, in the form `AppScript exception <name>: <message> (<path>:<line>)`, and re-raises. Apps that install no handler see the same exceptions as before.

## Installing a handler

```objc
[ASInterpreter setExceptionHandler:myHandler];   // process-wide, any thread
[ASInterpreter setExceptionHandler:nil];         // back to the default
id<ASExceptionHandler> current = [ASInterpreter exceptionHandler];
```

A handler implements `-handleException:context:` and returns an ``ASExceptionDisposition``:

- ``ASExceptionDispositionReraise`` keeps propagating the exception.
- ``ASExceptionDispositionRetry`` dispatches the failed send again, looking the method up afresh so a handler that has just installed a missing method makes the retry succeed.

The ``ASExceptionContext`` describes the send: receiver, selector, script path and line, visible local variables, the hybrid Objective-C and AppScript call stack, and whether the exception originated outside AppScript.

## Rules

- The handler is asked **once per exception**, however many enclosing sends it propagates through.
- A send is retried **at most once**. If the retry fails, the exception is re-raised and the handler isn't asked again.
- A failure raised while the handler itself is running isn't offered to the handler.
- Retrying a send in the `alloc`, `new`, `copy`, `mutableCopy` or `init` family may leak. If such a send fails part-way, the runtime can't tell whether it had already created or retained the object, so it leaves the failed attempt alone. A retried send never over-releases.
- Errors outside a message send, such as an undefined identifier, don't reach the handler.
