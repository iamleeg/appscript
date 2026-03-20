# PSP Postmortem — appscript-5j3 (Call Stack Backtrace)

Date: 2026-03-20 | Total actual time: 69 min | Estimated: 38 min | Ratio: 1.82×

---

## Time Analysis

| Phase | Est | Actual | Ratio |
|-------|-----|--------|-------|
|Planning| 10 | 12 | 1.2× |
|Design| 3 | 3 | 1.0× |
|Code| 8 | 14 | 1.75× |
|Compile| 3 | 2 | 0.7× |
|Test| 7 | 18 | 2.6× |
|Review| 4 | 15 | 3.75× |
|Postmortem| 3 | 5 | 1.7× |

The overall 1.82× overrun contradicts the established calibration for a "narrowly scoped, 3-4 branches" task (~30 min). The two most anomalous phases were **Test** and **Review**.

### Why Test took 2.6× the estimate

The test phase included running ASan, TSan, the GNUstep unit test suite, and the integration test harness (29 scripts). This multi-suite requirement is a consistent hidden cost not reflected in phase estimates. Each sanitizer run adds ~2 min and integration tests add ~5 min. For this shape of task that is ~9 min of fixed overhead on top of the unit test authoring.

**Action:** The calibration memory should note that Test estimates must include a fixed +9 min overhead for the full AppScript test suite (xcodebuild unit, ASan, TSan, GNUstep, integration tests).

### Why Review took 3.75× the estimate

The simplify skill launched three parallel review agents, which required waiting for all three to complete and then implementing their fixes, verifying them, and re-running tests. The 4-minute estimate assumed a brief scan; the actual simplify cycle involved parallel agent dispatch, synthesis, three code changes, a rebuild, and a targeted test run.

**Action:** The review estimate for tasks with 3+ interacting new components should be 8–10 min, not 4 min.

---

## Defect Analysis

All 3 defects were caught in Review; none by Compile or Test. All are implementation-quality issues rather than correctness bugs:

| # | Type | Inject | Description |
|---|------|--------|-------------|
| 1 | Data (70) | Design | Dead `receiver` field on ASCallFrame — stored but never read |
| 2 | Logic (80) | Code | Duplicated `class_isMetaClass + NSStringFromClass` idiom |
| 3 | Logic (80) | Code | Unnecessary `[stack copy]` in a `noreturn` function |

**Pattern:** Defects 2 and 3 are "first-draft code quality" issues — code that is functionally correct but not clean. The simplify review caught all three. This is the expected outcome: simplify functions as a systematic cleanup pass.

**Defect 1 (dead field)** was a design-phase issue: `receiver` was included in `ASCallFrame` speculatively ("might want to use this for future display"), then never used. The design-phase memory check (`design-phase-file-io-check`) does not currently cover object field design. A design checklist item — "for each field you add, verify it is read at least once in the feature's code path before finishing coding" — would catch this earlier.

---

## Estimation Calibration

Previous calibration was for two shapes:
- Narrowly scoped, 1-2 branches, 4-6 tests → ~20 min
- Narrowly scoped, 3-4 branches, 6-8 tests + review → ~30 min

This task was **wider than the second category**: it touched 5 separate methods across a 700-line file, introduced a new class, a new thread-local mechanism, a public constant, 7 tests, and required full multi-suite validation. The actual time (69 min) suggests a third category is needed:

**Shape 3:** Multi-method cross-cutting feature (≥3 modified methods, new internal class, thread-local state, new public API, 7+ tests) → ~60–70 min. Plan with: Planning=12, Design=3, Code=15, Compile=3, Test=20, Review=10, Postmortem=5.

---

## Process Improvements

1. **Include multi-suite test overhead explicitly.** For every task in this project, add a fixed +9 min to the Test phase estimate (ASan + TSan + GNUstep + integration). Currently this overhead is invisible in estimates.

2. **Add a "field liveness" check to design review.** Before finishing the Code phase for any new class, verify that every field is read somewhere in the feature path. Would have caught the dead `receiver` field before it reached Review.

3. **Bump Review estimate for cross-cutting features.** When a feature modifies ≥3 methods and introduces a new class, estimate Review at 8–10 min rather than 3–4 min to account for the parallel-agent simplify cycle.

4. **Distinguish "medium complexity" from "multi-method" tasks in calibration.** The current two-shape model (20 min / 30 min) does not have a slot for tasks like this one. A third calibration shape at ~65 min prevents the systematic under-estimation seen here.
