# PSP Postmortem — appscript-ax6

**Project:** Fix nil-URL crash in ASTestRunner + harness conventions documentation
**Date:** 2026-03-18
**Total time:** 9 min (estimated 32 min)

---

## Quantitative summary

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 5 min | 1 min | 0.20× |
| Design | 2 min | 0 min | 0.00× |
| Code | 5 min | 1 min | 0.20× |
| Compile | 5 min | 1 min | 0.20× |
| Test | 10 min | 3 min | 0.30× |
| Postmortem | 5 min | 3 min | 0.60× |
| **Total** | **32 min** | **9 min** | **0.28×** |

0 defects were injected in any development phase.
1 pre-existing defect (wrong scheme in `integration-tests.sh`) was discovered and removed in Compile.

---

## What went well

### 1. Lessons from appscript-ewo were directly applied

The postmortem for appscript-ewo identified four actionable improvements. This project exercised three of them immediately:

- **Integration test checklist**: I ran the integration tests as a matter of course without being asked. This prevented the most common repeat failure mode from ewo.
- **Documentation update**: `CODING_STANDARDS.md` was updated in the same commit as the code change, unprompted.
- **Capture-then-assert workflow**: The documentation I added describes exactly the pattern identified in defect 4 of ewo — I turned the lesson into a written rule.

The postmortem artifacts are directly improving behavior in the next project. This validates the PSP cycle.

### 2. Code was zero-defect

The guard clause in `ASTestRunner.appscript` was correct on the first write, building on the existing `isKindOfClass:` pattern already present in the same method. Following established patterns continues to prevent errors.

### 3. Estimation calibration from ewo held

The appscript-ewo postmortem suggested: "if the fix site is already identified in the issue description, the coding phase is likely under 5 minutes." Code took 1 minute. The estimate was correctly set to 5 min (down from the 45-min default), and reality came in at 1 min — still an overestimate, but the direction of calibration was right.

---

## What went wrong

### 1. Pre-existing infrastructure defect: wrong scheme in integration-tests.sh

**What happened:** The `run-tests` skill's `integration-tests.sh` invoked the scheme `AppScriptHarnessUITests`, which does not exist as a scheme (it exists as a target, but has no scheme). The script had never worked.

**Root cause:** The script was written referencing a scheme that was never created in Xcode. The target exists but was never added to a named scheme; `xcodebuild test` requires a scheme, not a target name.

**How it was resolved:** Investigated the project's available schemes (`xcodebuild -list`), confirmed that `AppScriptHarness` scheme runs the UI test target via the test action, and updated the script.

**Actionable improvement:** The `run-tests` skill should be verified to work end-to-end when first created for a project, not just written and assumed to be correct. A CI run or a single manual invocation at skill-creation time would have caught this. Consider adding a note to the `run-tests` skill template: *"After creating these scripts, run them once to verify they succeed before committing."*

### 2. Postmortem phase timing not recorded in real time

**What happened:** The Postmortem phase start was not recorded in the Time Recording Log before beginning postmortem work. The start time was inferred from the timestamp when I requested the current time at the beginning of the postmortem skill.

**Root cause:** The `psp-develop` skill ends and the `psp-postmortem` skill begins without an explicit time-recording transition step between them.

**Actionable improvement:** The `psp-postmortem` skill's first step should explicitly call `psp-record-time` to start the Postmortem phase in the Time Recording Log before any other work begins.

---

## Estimation accuracy

Total actual was 28% of total estimate — similar to appscript-ewo (35%). Over-estimation persists, driven by:

1. **The coding and design phases are consistently near-zero** for fix-site-identified bugs in well-understood code. The 5 min and 2 min estimates for Code and Design are still too high.
2. **Test phase was most accurately estimated proportionally** (30% of its estimate) — the test phase takes real time because the build tool is slow, not because the test logic is complex.

**Revised heuristic for future planning:** For a "guard-clause fix to existing method + documentation update" issue:
- Design: 0 min
- Code: 1 min
- Compile: 2 min (build is slow regardless of code complexity)
- Test: 3–5 min (test runner warmup dominates)

---

## Summary of actionable improvements

| Priority | Action | Who |
|----------|--------|-----|
| High | Verify `run-tests` scripts end-to-end when first creating them for a project | Update run-tests skill or its README |
| Medium | Add explicit `psp-record-time` start call at the beginning of the `psp-postmortem` skill | Update psp-postmortem skill |
| Low | Further reduce Code and Design estimates for guard-clause fixes: Design=0, Code=1 min | Calibrate for next planning |
