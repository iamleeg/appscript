# Requirements — appscript-xjo: Local variable dump at AppScript error site

**Date:** 2026-03-20
**Author:** Claude (PSP0)

---

## Problem Statement

When `reportError:node:context:` fires in `ASInterpreter`, the raised `NSException` includes
the error message, script path, line, and column — but no information about what variables
were in scope at the error site. A developer debugging a runtime error must mentally reconstruct
the variable state from the source, which is error-prone and time-consuming.

---

## Requirements

### R1 — New `ASScope` method: `allVisibleBindings`

Add a new public instance method to `ASScope`:

```objc
- (NSDictionary<NSString *, id> *)allVisibleBindings;
```

**Behaviour:**
- Walk the scope chain starting at the receiver, ascending through `enclosingScope` links.
- Collect all name→value pairs visible from this scope (inner scopes shadow outer scopes:
  if the same name exists in multiple frames, the innermost binding wins).
- Return an immutable `NSDictionary<NSString *, id>`.
- All bindings are included — including `self` and `_cmd`.
- When a variable holds `[ASNull null]` (AppScript nil), represent it in the returned
  dictionary as the `NSString` value `@"ASNull"` (clearly distinct from ObjC `nil`
  and `NSNull`). All other values are stored as-is.

**Declaration:** Add to `ASScope.h`.
**Implementation:** Add to `ASScope.m`.
**Framework header:** Update `AppScript.framework/Versions/0/Headers/ASScope.h` to match.

---

### R2 — New `ASErrorLocalsKey` constant

Add a new public constant to `ASInterpreter.h`:

```objc
/// The local variables visible at the AppScript error site.
/// Value type: NSDictionary<NSString *, id> *
/// Keys are variable names; values are their runtime values.
/// AppScript nil values are represented as the NSString "ASNull".
FOUNDATION_EXPORT NSString *const ASErrorLocalsKey;
```

Define the constant in `ASInterpreter.m`:

```objc
NSString *const ASErrorLocalsKey = @"ASErrorLocals";
```

---

### R3 — Populate locals in `reportError:node:context:`

In `reportError:node:context:` (in `ASInterpreter.m`), add the local variable dump
to the `userInfo` dictionary:

```objc
NSDictionary *locals = [ctx.currentScope allVisibleBindings];
NSDictionary *userInfo = @{
    ASErrorMessageKey:     message,
    ASErrorScriptPathKey:  path,
    ASErrorLineKey:        @(line),
    ASErrorColumnKey:      @(col),
    ASErrorMessageCodeKey: @(code),
    ASErrorLocalsKey:      locals,
};
```

The `reason` string is **not** changed — only `userInfo` is augmented.

---

### R4 — Tests

Add XCTest cases in `ASInterpreterTests.m` covering:

1. **Happy path**: after a runtime error, `userInfo[ASErrorLocalsKey]` is an `NSDictionary`.
2. **Variable in scope appears**: a declared variable and its value appear in the locals dict.
3. **ASNull representation**: a variable set to AppScript nil appears as `@"ASNull"` in the dict.
4. **Implicit variables**: `self` and `_cmd` appear in the locals dict.
5. **Weak binding**: a variable declared `weak` appears in the locals dict with either its current value (if the referent is still alive) or `@"ASNull"` (if it has been deallocated and the slot holds nil/ASNull).

---

## Out of scope

- Formatting the locals dump into the `reason` string (possible future task).
- Filtering specific variable names from the dump.
- Per-scope-frame breakdown (all bindings are flattened into one dict, inner wins).
