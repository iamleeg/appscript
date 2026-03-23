# Requirements: appscript-2de — Callable Uncaught Exception Handler

## Overview

Add `ASInstallUncaughtExceptionHandler()` to the AppScript framework: a public C
function that installs a custom `NSUncaughtExceptionHandler`. When an
`ASRuntimeErrorException` escapes uncaught, the handler prints a formatted
crash report (including the hybrid call stack) to stderr and calls `abort()`.
For all other exception types it chains to the previously-installed handler.
The framework never installs this handler automatically.
The AppScriptHarness app calls it in `main.m` before `NSApplicationMain`.

## Functional Requirements

### FR-1: New public C function

Declare and define:

```objc
FOUNDATION_EXPORT void ASInstallUncaughtExceptionHandler(void);
```

Calling this function installs the AppScript uncaught-exception handler via
`NSSetUncaughtExceptionHandler`. It saves any previously-installed handler at
call time for use in FR-3.

### FR-2: Handler behaviour for ASRuntimeErrorException

When the installed handler is invoked with an exception whose name equals
`ASRuntimeErrorException`, it must:

1. Print the following to `stderr` (with a trailing newline):

   ```
   Terminating due to uncaught AppScript exception:
   <ex.reason>
   ```

   `ex.reason` already contains the error location, source context, and
   `"Call stack (most recent call first):"` hybrid backtrace section produced
   by `ASBuildHybridBacktrace` (appscript-oot).

2. Call `abort()` to terminate the process and generate a crash report.

### FR-3: Handler behaviour for all other exceptions

When the installed handler is invoked with any exception whose name does **not**
equal `ASRuntimeErrorException`:

- If a previous handler was saved (FR-1), call it with the exception.
- If no previous handler was saved, do nothing (the process will terminate
  after the handler returns, per Cocoa's uncaught-exception contract).

### FR-4: Header placement

Declare `ASInstallUncaughtExceptionHandler` in a new header:

```
AppScript/ASUncaughtExceptionHandler.h
```

Import this header in the umbrella header `AppScript/AppScript.h` so callers
need only `#import <AppScript/AppScript.h>`.

### FR-5: No auto-installation

The framework must never call `ASInstallUncaughtExceptionHandler()` implicitly.
No `+load`, `+initialize`, constructor attribute, or any other automatic
mechanism may install the handler.

### FR-6: Harness app installation

In `AppScriptHarness/main.m`, call `ASInstallUncaughtExceptionHandler()` once,
**before** `NSApplicationMain(argc, argv)`.

## Non-functional Requirements

- The saved previous-handler pointer must not be shared mutable state that
  causes data races when `ASInstallUncaughtExceptionHandler()` is called from
  multiple threads. A `static` local or global written once under `dispatch_once`
  is acceptable (callers are expected to install once at launch).
- `abort()` is preferred over `exit(1)` so the OS generates a crash report.
