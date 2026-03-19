# PSP Postmortem — appscript-ddh

- Date: 2026-03-19
- Program: GNUmakefile for AppScript framework (GNUstep)
- Total time: 34 minutes (estimated 80 minutes)

## Summary

This task was straightforward: create a single GNUmakefile to build the AppScript framework under GNUstep. The build succeeded on the second attempt after one compile-time defect was fixed. Total actual time was 34 minutes against an estimate of 80 minutes — less than half the estimate.

---

## Time Analysis

| Phase | Estimate | Actual | Variance |
|-------|----------|--------|---------|
| Planning | 20 min | 27 min | +7 min (+35%) |
| Design | 5 min | 1 min | −4 min |
| Code | 15 min | 1 min | −14 min |
| Compile | 20 min | 1 min | −19 min |
| Test | 10 min | 0 min | −10 min |
| Postmortem | 10 min | 4 min | −6 min |
| **Total** | **80 min** | **34 min** | **−46 min** |

**Planning was the only phase that exceeded its estimate.** The main driver was the two-step ambiguity resolution: I needed to fetch and read the GNUstep tutorial, explore the codebase, and then engage the user to settle three design questions. The planning estimate of 20 minutes was too aggressive given the research required.

**All other phases were dramatically under-estimated** — or more accurately, dramatically *over-estimated*. Writing a GNUmakefile is mechanical once the design questions are answered: it's a list of filenames plus three lines of boilerplate. I budgeted for iteration and complexity that did not materialise.

### Actionable improvement — Estimation

For configuration/build-file tasks (GNUmakefile, CMakeLists.txt, Xcode project settings), break the estimate into two explicit sub-tasks:

1. **Research** (reading docs, fetching tutorials, asking ambiguity questions): budget based on how novel the build system is. This was the first GNUstep makefile in the project, so 20–30 minutes was appropriate.
2. **Mechanical authoring** (listing files, writing boilerplate): budget ~1 minute per 10 source files, plus ~5 minutes for the boilerplate and header config. For 41 files that would be ~9 minutes — far closer to the 3 minutes actually spent.

---

## Defect Analysis

| # | Type | Injected | Removed | Fix Time |
|---|------|---------|---------|---------|
| 1 | Build (30) | Code | Compile | 1 min |
| 2 | Build (30) | Postmortem | Postmortem (after dev) | 1 min |

**Defect 1:** The GNUmakefile omitted `-fobjc-arc`, causing a compile failure on `ASScope.m`'s `weak` property.

**Why it was injected:** GNUstep makefiles default to MRC. The source code was written under Xcode/Clang where ARC is the default. This implicit platform difference was not surfaced during requirements gathering or design.

**Why it was caught in Compile (good):** The build system caught it immediately on the first `make` run. No additional test infrastructure was needed.

### Actionable improvement — Preventing defect 1

Add a standing rule to the requirements or design checklist for GNUstep build files:

> **Always set `ADDITIONAL_OBJCFLAGS = -fobjc-arc` when porting code from an Xcode project that uses ARC** (which is the default for all modern Xcode projects).

Alternatively, this could be encoded in a project-level `GNUmakefile.preamble` so it applies to all sub-projects automatically — worth considering when the harness and test makefiles are added.

**Defect 2:** Attempted to edit `.gitignore` without reading it first during the postmortem, causing a tool error.

**Why it was injected:** The Read-before-Edit rule is a process discipline that must be applied consistently. It was overlooked in the context-switching moment of moving from implementation to postmortem housekeeping.

### Actionable improvement — Preventing defect 2

> **Always read a file before editing it**, without exception, even for short or familiar files like `.gitignore`. Consider this a hard rule, not a guideline. If you find yourself skipping the Read step, treat it as a process violation to log.

---

## Process Observations

1. **The ambiguity-resolution step was the most valuable part of planning.** Three design questions were resolved before a line was written: `framework.make` vs `library.make`, `NEEDS_GUI`, and header install path. Without that step, at least one of those decisions would likely have been wrong and required rework.

2. **The "Test" phase was vacuous for this task.** A GNUmakefile is verified by compiling — there is no separate unit/integration test suite for a makefile. Future build-file tasks should not budget time for a formal test phase; the Compile phase subsumes it.

3. **The framework structure was correct on the first attempt** — headers, versioned symlinks, dylib, `Info.plist` — because `framework.make` handles all of that automatically once `FRAMEWORK_NAME`, `_HEADER_FILES_DIR`, and `_HEADER_FILES` are set correctly.
