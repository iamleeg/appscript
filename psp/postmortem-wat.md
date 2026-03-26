# Postmortem — asu-wat: NSNumber Rounding and Clamping

**Date:** 2026-03-25
**Total actual time:** 42 min (estimate: 75 min)
**Defects injected:** 1 (Type 110 — System, test phase)
**Defects removed in development:** 1

---

## What went well

### Significantly under estimate (42 min vs 75 min)

Every phase came in under estimate, especially compile (1 min actual vs 10 min estimated) and design (0 min — design was trivial and merged straight into code). The implementation pattern was a direct extension of existing work: the same `[NSNumber numberWithDouble:fn([self doubleValue])]` idiom repeated four times. When the problem is well-understood and the codebase has clear precedent, estimates based on starting-from-scratch assumptions are overly pessimistic.

**Actionable:** For additive category-method tasks that follow an established pattern in the same file, reduce estimates by roughly 50%. A better planning heuristic for these tasks is: (number of new methods × 3 min for code) + (number of tests × 1 min) + documentation time.

### Zero code defects

The implementation had no logic, syntax, or interface defects. This is consistent with the low cognitive complexity of the task — all four methods are single-expression wrappers over standard C library functions with no branching, no state, and no resource management.

### Requirements ambiguities were caught and resolved before coding

The two ambiguities (return type for `rounded`/`floored`; method naming style for max/min) were surfaced and resolved during planning, not discovered as inconsistencies during implementation. The `ambiguity-resolution` skill workflow is effective for preventing rework.

---

## What could improve

### 1. Missing GNUSTEP_MAKEFILES (Type 110 — System)

The first test run failed because `GNUSTEP_MAKEFILES` was not set. This was caught immediately (in the same test phase), but it still cost ~3 minutes and a second test run.

**Root cause:** The `run-tests` skill's `unit-tests.sh` script requires an environment variable that is not set by default. There is no guard or diagnostic message in the script when it is absent.

**Actionable improvements:**
- Before invoking the test script, always run `gnustep-config --variable=GNUSTEP_MAKEFILES` to get the value and export it. This is now recorded in beads memory.
- The test script itself could be improved to detect a missing `GNUSTEP_MAKEFILES` and emit a clear diagnostic rather than a cascade of makefile errors — but this is a project infrastructure change outside the scope of this task.

### 2. Design phase was recorded as 0 minutes

The design phase exists in the time log but shows 0 minutes because it was absorbed into coding. For this task that was justified — but conflating design and code phases makes it harder to see whether design time is systematically underestimated.

**Actionable:** Even for simple additive tasks, do a brief written design step (even one sentence) before opening the editor, and record it as design time. This preserves process fidelity and makes the logs more useful for future estimation.

### 3. Estimate was accurate in direction but not magnitude

The total estimate of 75 min was nearly 2× the actual 42 min. The overestimate was consistent across every phase. This suggests a systematic bias rather than task-specific uncertainty.

**Actionable:** For "extend an existing category with N methods following the established pattern" tasks, apply a 0.5× correction factor to initial estimates until enough data has accumulated to calibrate more precisely.

---

## Summary

This was a straightforward additive task with no code defects and one process defect (environment configuration). The implementation is complete, tested under xcodebuild, GNUstep, ASan, and TSan, and documented in ARCHITECTURE.md. The only improvement opportunity that matters for future tasks is the `GNUSTEP_MAKEFILES` check before running tests — now recorded in memory.
