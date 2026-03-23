# Postmortem: appscript-oot — Hybrid Spliced AppScript+ObjC Backtrace

- Date: 2026-03-23
- Actual total time: 21 min (estimated 33 min; 0.64× estimate)

## What Went Well

**Algorithm clarity.** The interleaved backtrace algorithm — walk ObjC symbols, replace
runtime clusters with AppScript frames — was easy to reason about once the requirements
resolved the key ambiguities (direction of AppScript frame consumption, placeholder
behaviour). Design took only 1 minute as a result.

**Code efficiency.** Implementation was fast (2 min) with no compile errors and no
functional defects. The `dispatch_once` filter list and `inCluster` flag are clean and
obvious.

**Test suite.** Six new tests (including two updated for the changed header string)
covered all meaningful cases: key presence, header in reason, old header absent,
AppScript frame content, ObjC frame passthrough, and backwards-compat for the old key.
All passed first time.

## Issues Found

### Defect #1 — GNUstep env var dismissed (Type 60 — Checking)
**Inject:** Test | **Remove:** Test | **Fix time:** 3 min

During the Compile/Test phase, `unit-tests.sh` reported a GNUstep make failure. This was
misclassified as "GNUstep not installed (pre-existing)" and logged as a non-issue.
The user had to intervene to point out that GNUstep IS installed and `GNUSTEP_MAKEFILES`
needs to be set.

**Root cause:** Over-reliance on the error message surface ("No such file or directory"
for a make include) without investigating further.

**Actionable fix:** When a GNUstep build step fails, always check whether
`GNUSTEP_MAKEFILES` is set before concluding GNUstep is absent. The run-tests skill
should be enhanced to set `GNUSTEP_MAKEFILES=/Library/GNUstep/Makefiles` automatically
(or the unit-tests.sh script should source the GNUstep environment file).

### Defect #2 — Requirements gap: callable exception handler omitted (Type 120 — Support)
**Inject:** Planning | **Remove:** Review | **Fix time:** addressed as appscript-2de

The initial problem statement (appscript-oot) described the hybrid backtrace but did not
explicitly require a public API to install an uncaught exception handler. This was only
noticed during post-task review, prompting appscript-2de as a follow-on.

**Root cause:** The requirements only asked for building the hybrid trace and storing it
in `userInfo`; the logical next step — "how does an app surface this on crash?" — was
left implicit.

**Actionable fix:** During planning of runtime-error features, explicitly ask: "How does
a host application observe this in production (crash reports, logging, etc.)?" Add this
as a standard review checklist item for the planning phase.

## Time Estimation Analysis

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 3 min | 4 min | 1.3× |
| Design | 2 min | 1 min | 0.5× |
| Code | 8 min | 2 min | 0.25× |
| Compile | 2 min | 2 min | 1.0× |
| Test | 12 min | 6 min | 0.5× |
| Review | 3 min | 2 min | 0.7× |
| Postmortem | 3 min | 4 min | 1.3× |
| **Total** | **33 min** | **21 min** | **0.64×** |

The Code phase estimate (8 min) was 4× too high. This continues the trend identified in
previous PSP tasks: narrowly-scoped Objective-C features run at ~0.25–0.33× of estimates
for the Code phase. The calibrated baseline for this shape (add one algorithm + helper +
public key, 6–8 tests) is Code ≈ 2–3 min, not 8 min.

The Test phase (12 min estimated, 6 min actual) was also 2× over. The full multi-suite
run (Xcode unit + ASan + TSan + GNUstep + integration) is approximately 6–8 min when
everything passes first time — consistent with what was observed here.
