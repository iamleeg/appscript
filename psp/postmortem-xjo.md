# PSP Postmortem — appscript-xjo

**Date:** 2026-03-20
**Program:** Local variable dump at AppScript error site
**Total time:** 13 minutes (estimated 43 minutes)

---

## What went well

- **Zero defects, first time.** All code compiled and passed unit tests (default, ASan, TSan) and
  integration tests on the first attempt. This is the second consecutive zero-defect task following
  `btc` (also zero defects). The prior postmortem lessons about helper-class placement, noreturn
  semantics, and NSException API were not needed — this task didn't touch those areas — but the habit
  of reading existing code and tests before writing new code appears to be paying off.

- **The ambiguity-resolution step was productive.** Four genuine design decisions were surfaced
  before writing any code: where to put the dump (userInfo only vs. reason), whether to include
  `self`/`_cmd`, how to represent `ASNull`, and the value type. The user added a fifth requirement
  (weak bindings test) during sign-off. All of these were resolved in ~2 minutes of planning and
  avoided potential rework in coding.

- **The integration tests caught nothing extra** — all 29 harness script tests continued to pass
  without change. This confirms the feature is additive and doesn't alter existing interpreter
  behaviour.

---

## Defect analysis

No defects were recorded. The defect log is empty.

---

## Time estimate accuracy

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 5 min | 3 min | 0.6× |
| Design | 3 min | 1 min | 0.3× |
| Code | 15 min | 2 min | 0.13× |
| Compile | 5 min | 1 min | 0.2× |
| Test | 10 min | 3 min | 0.3× |
| Postmortem | 5 min | 3 min | 0.6× |
| **Total** | **43 min** | **13 min** | **0.30×** |

Overall I ran at **0.30×** the estimate — i.e., about 3× faster than predicted. This is
consistent with the `btc` postmortem (also 0.33×). There is a stable pattern: for narrowly-scoped
Objective-C tasks (add one method, add one constant, one-line call-site change, ~5 test cases),
actual time is roughly 10–15 minutes regardless of the estimated total.

**Actionable improvement:** For tasks of this shape (one new method on an existing class,
propagate through one or two call sites, 4–6 tests), the calibrated estimate should be:
- Planning: 3 min
- Design: 1 min
- Code: 5 min
- Compile: 2 min
- Test: 5 min
- Postmortem: 3 min
- **Total: ~20 min**

The current estimate template is still generating 40+ minute totals for tasks that resolve in
under 15 minutes. The user should nudge estimates down by 3× for "low effort" tasks like this one.

---

## Process observations

### The "read before edit" requirement prevented at least one defect

The framework header sync edit (`AppScript.framework/Versions/0/Headers/ASScope.h`) failed on the
first tool call because I hadn't read it first. The tool returned an error immediately; I read it,
then retried successfully. This is a good example of the tool guardrail working as intended:
a silent failure here would have left the framework header out of sync with the implementation
header, which would manifest as a runtime ABI mismatch only visible to external framework
consumers — hard to diagnose. The guardrail turned a potential post-shipping defect into a
0-second inconvenience.

**This is not recorded as a defect** (the tool prevented the write from happening at all), but it's
worth noting: always read framework headers before editing them, even when the source header was
already read.

### Integration tests should be explicitly in the plan

I ran integration tests only after the user prompted me. The unit test + sanitizer run was already
in my mental checklist, but integration tests were not. The skill instructions say "ensure all
tests pass including existing tests", but in practice I stopped at unit tests until reminded.

**Actionable improvement for user:** Add an explicit line to the `psp-develop` skill instructions:
"After all unit tests pass, run the integration test suite (`integration-tests.sh`) before
declaring the development phase complete." Alternatively, add a step to the `run-tests` skill
that always runs both suites together.

### Estimation remains systematically high

Three tasks in a row (`btc`, `isd`, `xjo`) have all come in at roughly 0.3× the estimate. This
is no longer a fluke — it's a process calibration problem. The estimates are anchored to a model
of "cautious first attempt" that no longer reflects actual execution speed for narrowly-scoped ObjC
tasks.

**Actionable improvement for user:** Ask Claude to apply a 3× downward calibration factor to
estimates for tasks tagged "low effort" or "narrowly scoped". Or, maintain a running calibration
table in `bd memories` and reference it during planning.
