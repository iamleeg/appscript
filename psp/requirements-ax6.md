# Requirements — appscript-ax6

## Problem Statement

`ASTestRunner.appscript` calls `[expectedURL as_stringContents]` (line 64) before checking whether `URLForResource:withExtension:` returned `nil`. When a test class has no companion `.expected` file in the bundle, `URLForResource:withExtension:` returns `nil`, which AppScript represents as `ASNull`. Sending `as_stringContents` to `ASNull` aborts the harness instead of producing a graceful failure.

Additionally, the convention that each `.appscript` file must be paired with a `.expected` file is not documented in `CODING_STANDARDS.md`, leaving future contributors to discover it by accident.

---

## Acceptance Criteria

### AC1 — Guard nil URL before calling `as_stringContents`

In `ASTestRunner.appscript`, add an `isKindOfClass:[NSURL class]` check on `expectedURL` before calling `as_stringContents`. If the URL is not a valid `NSURL` (i.e. `nil` / `ASNull`), skip the `as_stringContents` call entirely and treat `rawContents` as absent.

This is consistent with the existing `hasContents` check pattern already used on `rawContents` (line 65).

### AC2 — Distinct, actionable error messages

When a test class has no `.expected` file and the harness falls back to a failure result, the `expected` field of `ASTestResult` must use the message:

```
missing .expected file for <testName> — create AppScriptHarness/Scripts/<testName>.expected
```

This is distinct from any future case where the URL is valid but the file cannot be read as a string (which would use the existing fallback or a separate message). The message must tell the developer exactly what file to create.

### AC3 — Existing tests continue to pass

All existing `.appscript` test scripts in `AppScriptHarness/Scripts/` (each of which has a companion `.expected` file) must still pass after the fix. The harness must exit 0.

### AC4 — Document the `.appscript` + `.expected` pairing in `CODING_STANDARDS.md`

Expand the existing **Test Harness → Adding a harness test** section in `CODING_STANDARDS.md` to make explicit:

1. Both the `.appscript` and the `.expected` file are **required**. A script without its `.expected` file will not crash the harness (after this fix) but will report a failure with a clear message.
2. The recommended workflow for writing the `.expected` file is **capture-then-assert**: run the harness once with a placeholder `.expected` (or none), observe the actual output in the failure message, then write that output as the final `.expected` content.
3. The naming rule: `<ClassName>.appscript` + `<ClassName>.expected`, where `<ClassName>` is the test class name with the `Test` suffix stripped.

The documentation must not introduce a separate `HOWTO.md` file inside `AppScriptHarness/Scripts/` (that folder's contents are copied into the app bundle; only `.appscript` and `.expected` files belong there).

---

## Out of Scope

- Changes to `ASTestCase.appscript`, `ASTestResult.appscript`, or any `.m` / `.h` file in the framework.
- Unit tests for `ASTestRunner` (the runner is integration-test infrastructure, not a framework class; its behaviour is verified by the harness itself).
- Any change to existing `.expected` file contents.
