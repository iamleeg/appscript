# AppScript Coding Standards

This document defines the engineering practices for implementing the AppScript runtime. All contributors must follow these standards.

## License

Every source file must carry this license header as a comment block at the top of the file, before any other content:

```objc
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// <FileName.m> — <one-line description>
// Copyright (C) <year> <author or organisation>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
```

No source file may be added to the project without this header. Dependencies (third-party libraries) must be licensed under AGPL-compatible terms and their licenses documented in a `LICENSES/` directory at the repository root.

## Implementation Language

All implementation is in Objective-C. Specifically:

- Implementation files use the `.m` extension. Use `.mm` only when a file must interoperate directly with a C++ library; justify this in a comment at the top of the file.
- Header files use the `.h` extension.
- No Swift source files may be added to the framework or test targets. Swift may be used in ancillary tooling (scripts, generators) but not in the runtime itself.
- Target the macOS SDK. Use `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END` in every header to enable nullability checking. Annotate all out-parameters and return types explicitly.
- Use `NS_DESIGNATED_INITIALIZER` and `NS_UNAVAILABLE` to make the intended initialiser surface clear.

## Project Structure

The repository contains three Xcode targets:

| Target | Type | Purpose |
|---|---|---|
| `AppScript` | Framework | The runtime: parser, interpreter, runtime classes |
| `AppScriptTests` | Unit test bundle | XCTest unit tests for every framework class |
| `AppScriptHarness` | macOS application | Integration test harness (see below) |

Source files are organised to mirror this structure:

```
AppScript/           # Framework source
AppScriptTests/      # Unit tests (mirrors AppScript/ layout)
AppScriptHarness/    # Test harness app
LICENSES/            # Third-party licence texts
```

Each source file in `AppScript/` has a corresponding test file in `AppScriptTests/` with the same base name and a `Tests` suffix (e.g. `ASParser.m` → `ASParserTests.m`).

## Memory Management

AppScript uses Objective-C ARC. Manual `retain`/`release`/`autorelease` calls are forbidden.

To avoid memory bugs:

- **Retain cycles**: Use `weak` references for delegates, callbacks, and block captures where the referenced object owns the block. Prefer `weak`–`strong` dance (`__weak`/`__strong`) in blocks rather than `__unsafe_unretained`.
- **Static analysis**: The Xcode build must pass Clang's static analyser (`Analyze` build action) with zero warnings. CI enforces this.
- **Address Sanitizer**: All test targets run with ASan enabled in CI. No ASan errors are acceptable.
- **Instruments**: Before each release, run Leaks and Allocations instruments against the test harness. No leaks may be introduced.

## Thread Safety

The interpreter may be invoked from multiple threads simultaneously (see ARCHITECTURE.md). To avoid thread safety bugs:

- **Thread Sanitizer**: ASan and TSan cannot be active in the same binary simultaneously. CI runs tests in two separate build configurations — one with ASan, one with TSan — and both must pass. No TSan reports are acceptable.
- **Immutability by default**: Prefer immutable data structures. Use mutable variants only within a single-owner scope, then hand off an immutable copy.
- **Explicit queue ownership**: Every class that has internal mutable state must document which dispatch queue owns that state in a header comment. Access that state only from the owning queue.
- **GCD for synchronisation**: Use `dispatch_queue_t` (serial queues) as the primary synchronisation primitive. Avoid `@synchronized` except for trivial one-liner critical sections. Never use `NSLock` on the hot path.
- **`os_unfair_lock`**: Use for low-level, non-recursive locking in performance-sensitive code paths. Document the owning lock at every access site.
- **No `dispatch_get_main_queue()` from the framework**: The framework must not assume it runs on the main thread and must not dispatch back to the main queue internally. The host application controls threading.

## Testing

### Unit Tests

Every `public` or `@package` method on every class in the `AppScript` framework must have at least one corresponding unit test. Private methods are tested indirectly through their public interfaces.

Test files use XCTest. Naming conventions:

- Test class: `<ClassName>Tests` (e.g. `ASInterpreterTests`)
- Test method: `test_<methodUnderTest>_<scenario>_<expectedOutcome>`
  - Example: `test_parseExpression_missingClosingBracket_returnsError`

Each test method tests exactly one behaviour. A test that requires more than ~20 lines of setup is a signal to introduce a helper method or fixture, not to merge test cases.

No production code is written without a failing test that motivates it (test-first). A pull request that adds production code without a corresponding test will not be merged.

### Test Harness

The `AppScriptHarness` app is a macOS application that performs end-to-end integration testing of the full runtime. It is not a unit test bundle; it exists to exercise the complete load → parse → interpret → result pipeline.

**Structure:**

The harness loads `.appscript` script files from a bundle. Each script file has a paired `.expected` file in the same bundle that specifies the expected output. The harness:

1. Calls `loadAppScriptsInBundle:` on the bundle containing the test scripts.
2. For each script, instantiates the class defined in that script and calls `-runTests` on it.
3. Calls `-description` on the returned object and compares the resulting string to the content of the paired `.expected` file.
4. Prints a pass/fail summary to stdout and exits with code 0 (all pass) or 1 (any failure).

Every harness script must define exactly one class whose name ends in `Test` and which implements `-runTests`. Example:

```appscript
@class MyFeatureTest : NSObject

- runTests {
    // exercise the feature and return a result whose -description matches MyFeature.expected
    return self
}

@end
```

This makes the harness usable in CI without a GUI.

**Adding a harness test:**

1. Create `MyFeature.appscript` in `AppScriptHarness/Scripts/`.
2. Create `MyFeature.expected` alongside it with the exact expected output.
3. Verify the harness exits 0 locally before opening a pull request.

Harness tests are required for any behaviour described in ARCHITECTURE.md that cannot be fully exercised by unit tests (e.g. multi-class interactions, the full parse–interpret pipeline, error crash behaviour).

## Documentation

### Method Documentation

Every `public` or `@package` method in the `AppScript` framework must have a documentation comment in the header file. Use DocC-compatible `///` comment syntax:

```objc
/// Loads all AppScript source files found in the given bundle.
///
/// - Parameter error: On failure, set to a description of the error. Pass `nil` if you don't need error information.
/// - Returns: `YES` if all scripts loaded successfully; `NO` otherwise.
- (BOOL)loadAppScriptsInBundle:(NSError **)error;
```

The summary line (first `///` line) must be a complete sentence that stands alone — it appears in quick-help and symbol listings. Parameter and return-value descriptions are required for any method with non-obvious parameters or a non-obvious return value. Omit them only when the method name makes them fully redundant (e.g. a trivial getter).

Private methods in `.m` files do not require documentation comments, but may have them where the logic is non-obvious.

### DocC Articles

Complex end-to-end flows that span multiple classes or methods must be documented as DocC articles in `AppScript/Documentation.docc/`. An article is required whenever:

- A feature involves three or more collaborating types (e.g. the parse → install → invoke pipeline).
- A feature requires the caller to follow a specific sequence of steps (e.g. loading scripts, then instantiating objects).
- A behaviour is described in a section of ARCHITECTURE.md that has no single obvious entry-point method.

Articles must use DocC's `<doc:SymbolName>` link syntax to reference every method and type they describe, so that the documentation graph stays connected. Example article front matter:

```markdown
# Loading and Running AppScript Files

Embed the AppScript framework in your app and execute scripts at runtime.

## Overview

Describe the flow here...

## Topics

### Loading scripts
- <doc:NSBundle/loadAppScriptsInBundle:>

### Defining entry points
- <doc:ASInterpreter>
```

Add a link to each new article from the framework's top-level `AppScript.md` catalog file so it appears in the DocC navigator.

## Bug Reports and the Design Document

When a bug report is received, the first question to answer is: *is this a code bug or a design bug?*

| Situation | Action |
|---|---|
| The code doesn't match ARCHITECTURE.md | Fix the code. No design document change needed. |
| ARCHITECTURE.md is silent on the behaviour | Decide the correct behaviour, update ARCHITECTURE.md to specify it, then fix the code to match. |
| ARCHITECTURE.md specifies the behaviour but the behaviour is wrong | Update ARCHITECTURE.md to specify the corrected behaviour, then fix the code. |

**The design document and the code must always agree.** A commit that fixes a bug by changing observable behaviour must update ARCHITECTURE.md in the same commit. Reviewers must check this before approving.

Run `/ambiguity-resolution` on ARCHITECTURE.md whenever a design change is made to catch new ambiguities before they reach the implementation.

## Code Review Checklist

Before approving a pull request, verify:

- [ ] Every new `.m` file has the AGPL licence header.
- [ ] Every new public method has at least one unit test.
- [ ] Every new public method has a `///` documentation comment in its header.
- [ ] Complex multi-class flows have a DocC article, linked from the catalog.
- [ ] The Clang static analyser reports no new warnings.
- [ ] ASan and TSan report no errors.
- [ ] Any behaviour change is reflected in ARCHITECTURE.md.
- [ ] New end-to-end behaviour is covered by a harness test.
- [ ] Mutable state has a documented owning queue.
