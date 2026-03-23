# Postmortem: appscript-2de — Callable Uncaught Exception Handler

- Date: 2026-03-23
- Actual total time: 13 min (estimated 28 min; 0.46× estimate)

## What Went Well

**Design clarity.** The double-install infinite-loop guard (pointer comparison before
saving the previous handler) was identified during design in 1 minute and implemented
correctly first time — no compile or runtime defects in the core logic.

**Rapid implementation.** The entire Code + Compile cycle was 3 minutes combined. The
structure was simple: one static C function with a branch on exception name, one
public installer with a guard.

**Chain-correctness.** The non-AppScript chaining path was sound by design; it just
needed a test to prove it — which the simplify review correctly identified.

## Issues Found

### Defect #1 — Missing test isolation via setUp/tearDown (Type 40 — Assignment)
**Inject:** Code | **Remove:** Review | **Fix time:** 2 min

Tests in `ASUncaughtExceptionHandlerTests` modified the global
`NSGetUncaughtExceptionHandler()` state without saving and restoring it. Any test that
failed mid-run could leave a stale handler that would interfere with subsequent tests.

**Root cause:** When writing the first test (`registersNonNullHandler`), the need for
restoration was not immediately obvious because the test just installs and reads. The
global state side effect only becomes a concern when there are multiple tests — a pattern
I should have anticipated from the start.

**Actionable fix:** For any XCTestCase that writes to global process state (signal
handlers, NSUncaughtExceptionHandler, NSNotification observers, etc.), always add
setUp/tearDown boilerplate as the *first* thing written — before any test methods. Add
this to a mental checklist when creating test files that interact with system-level APIs.

### Defect #2 — Missing chaining test for non-AppScript exceptions (Type 40 — Assignment)
**Inject:** Code | **Remove:** Review | **Fix time:** 2 min

No test verified that the previously-installed handler is actually called for
non-AppScript exceptions. This is the second critical code path (FR-3) and was
untested.

**Root cause:** The test for `ASRuntimeErrorException` termination cannot be written
(it calls `abort()`), so attention naturally focused on what *could* be tested.
The chaining path was implemented but not verified.

**Actionable fix:** When a code path cannot be tested directly (because it terminates
the process), explicitly ask: "Is there an observable *side effect* of the other branch
that I can test instead?" In this case: install a flag-setting handler, then invoke the
installed handler with a non-matching exception and check the flag. Make this the
standard approach for any handler/callback that has a fallthrough branch.

## Time Estimation Analysis

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 3 min | 2 min | 0.7× |
| Design | 1 min | 1 min | 1.0× |
| Code | 6 min | 2 min | 0.3× |
| Compile | 2 min | 1 min | 0.5× |
| Test | 10 min | 0 min | — |
| Review | 3 min | 4 min | 1.3× |
| Postmortem | 3 min | 3 min | 1.0× |
| **Total** | **28 min** | **13 min** | **0.46×** |

**Test phase:** Testing was folded into the Compile phase because all 870 unit tests,
29 integration tests, and 3 new GNUstep tests passed on the first run. No separate
Test phase was needed. The 10-minute Test estimate was over-budgeted.

**Review over-ran estimate (1.3×):** The simplify review found two genuine defects that
required fixing, which explains the 4 min actual vs 3 min estimate. This is acceptable
and expected when review finds real issues.

**Overall:** This is a shape-1 task (narrowly scoped, 1-2 branches, 4 tests) that ran
at ~0.46× estimate, consistent with the calibrated ~0.3–0.5× for this shape. Code phase
at 0.3× continues the pattern. The Test estimate for future shape-1 tasks should be 0
or folded into Compile when the implementation is straightforward.
