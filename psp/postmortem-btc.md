# PSP Postmortem — appscript-btc

**Date:** 2026-03-20
**Program:** NSException instead of abort() for AppScript runtime errors
**Total time:** 23 minutes (estimated 70 minutes)

---

## What went well

- The requirements phase was very efficient (2 minutes). The ambiguity-resolution process surfaced real design decisions (NSException API shape, error codes, noreturn semantics) before any code was written, preventing rework that would have been much more expensive later.
- All 3 defects were caught at compile time, not at test time. No defects survived to the test phase.
- The new test suite gives direct coverage of all 5 error paths, which was previously untestable because `abort()` crashed the test runner.

---

## Defect analysis

All 3 defects were injected in the coding phase and removed in the compile phase. None required test-phase discovery.

### Defect 1 — Missing `__builtin_unreachable()` (type 30: Documentation/noreturn flow)
**Root cause:** I knew `reportError:` was declared `__attribute__((noreturn))`, but forgot that Clang sometimes cannot trace noreturn through an ObjC message send when the function ends without an explicit `return`. This is a known limitation of Clang's flow analysis.

**Actionable improvement:** When writing a noreturn ObjC method, always follow the call site with `__builtin_unreachable()` *at the call site* — do not rely on Clang to infer it. Add this as a project coding standard.

### Defect 2 — Wrong NSException API (type 70: Interface/API misuse)
**Root cause:** I used `[NSException raise:format:]` from memory, forgetting that the `format:` family method has no `userInfo:` parameter. The correct pattern for exceptions with structured data is `exceptionWithName:reason:userInfo:` + `-raise`. This caused the `userInfo` dict to be built and then silently discarded with a compiler warning.

**Actionable improvement:** The coding standards document should include a snippet showing the correct NSException raise pattern with `userInfo`. A linter rule for `[NSException raise:format:]` in library code (where structured userInfo is nearly always needed) would also catch this.

### Defect 3 — ObjC class definition inside `@implementation` (type 60: Structural)
**Root cause:** When inserting the `ASUnknownTestNode` helper class and `runAndCatch` function, I anchored the insertion to a comment that was inside the `@implementation ASInterpreterTests` block. ObjC does not allow `@interface`/`@implementation` blocks to nest inside another `@implementation`.

**Actionable improvement:** Always place test-local helper classes *above* the test class's `@interface`, matching the pattern already established in this file (where `ASSuperTestBase`/`ASSuperTestSub` are defined before `@interface ASInterpreterTests`). Check placement by reading the target file before inserting new class definitions.

---

## Time estimate accuracy

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 5m | 2m | 0.4× |
| Design | 5m | 1m | 0.2× |
| Code | 30m | 8m | 0.27× |
| Compile | 5m | 6m | 1.2× |
| Test | 15m | 1m | 0.07× |
| Postmortem | 10m | 5m | 0.5× |
| **Total** | **70m** | **23m** | **0.33×** |

Overall I was 3× faster than estimated. The estimates were deliberately conservative for a first attempt. The change was narrowly scoped (one method, one file, one test class), so once the design was clear from the requirements, execution was fast. The compile phase was the only one that slightly overran its estimate (due to 3 defects).

**Actionable improvement:** For narrowly-scoped Objective-C refactoring tasks (changing one method + updating call sites + adding tests), a more accurate baseline estimate is 20–30 minutes total, with compile and code phases roughly equal. The 30-minute code estimate was appropriate, but test (15m estimate) was very high — writing 5 focused XCTest cases takes about 5 minutes for this kind of error-path test.

---

## Process observations

- The ambiguity-resolution step before writing requirements was clearly worth the time. The question about `[NSException raise:format:]` vs `exceptionWithName:reason:userInfo:` was not asked explicitly, but thinking through the API during requirements would have caught defect 2 before coding.
- The compile→fix cycle was tight: all 3 defects were found in a single compile run and fixed within minutes. This is the desired PSP outcome — find defects as early as possible and fix quickly.
- The pre-existing GNUstep `AppScriptHarness` codesigning failure required investigation time (checking via `git stash`) but was quickly ruled out. Worth noting for future sessions: GNUstep `make check` currently fails at the AppScriptHarness codesigning step regardless of code changes.
