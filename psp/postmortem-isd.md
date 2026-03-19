# PSP Postmortem — appscript-isd

**Date:** 2026-03-19
**Program:** Add GNUmakefile harness app target
**Total actual time:** 52 min (estimate: 60 min — 13% under)

---

## What happened

The task was to add a GNUstep `application.make` target for AppScriptHarness to the
existing GNUmakefile. The makefile edit itself took only **1 minute of coding**. The
remaining **39 minutes** (Compile + Test) were spent discovering and fixing six defects
that all had the same root cause: insufficient up-front knowledge of GNUstep make
conventions and macOS dyld behaviour.

---

## Defect summary

All 6 defects were **injected in the Code phase** and not caught until Compile or Test:

| # | Injected | Removed | Description |
|---|----------|---------|-------------|
| 1 | Code | Compile | `RESOURCE_DIRS` creates empty directories; `RESOURCE_FILES` is needed to copy files |
| 2 | Code | Test | No nib in bundle → `NSMainNibFile` empty → UI never loaded |
| 3 | Code | Test | Framework has relative install name → dyld fails when app launched via `open` |
| 4 | Code | Test | No `-headerpad_max_install_names` → `install_name_tool -change` fails for longer paths |
| 5 | Code | Test | `codesign --preserve-metadata=entitlements` fails on unsigned binary |
| 6 | Code | Test | Scripts in `Resources/Scripts/` → `URLsForResourcesWithExtension:subdirectory:nil` can't find them |

**Defect removal efficiency:** 1 found at Compile, 5 at Test — 83% of defects survived to
the test launch phase.

---

## Time accuracy

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 10 min | 5 min | 0.5× |
| Design | 5 min | 1 min | 0.2× |
| Code | 15 min | 1 min | 0.07× |
| Compile | 15 min | 8 min | 0.5× |
| Test | 10 min | 32 min | **3.2×** |
| Postmortem | 5 min | 5 min | 1.0× |

The Test phase overran by 3.2×. Every other phase underran. The total came in 13%
under estimate by luck: the coding was trivial but the testing was expensive.

---

## Patterns and opportunities for improvement

### 1. All defects came from unknown GNUstep/macOS-specific conventions

Every defect was a "things I didn't know about GNUstep or macOS dyld" failure,
not a logic error. The knowledge now exists in `bd memories` (key:
`building-gnustep-app-target-on-macos-creating-a`). In future GNUstep app-target
tasks, pulling that memory at planning time will eliminate all 6 defect classes
before any code is written.

**Action for user:** When starting a GNUstep task, prompt Claude to search
`bd memories gnustep` before planning. This converts unknown-unknowns into known
requirements.

### 2. The "compile" step should include a launch test, not just `make`

Defects 2–6 were only discovered because you asked "did you check that you can
launch the version of the app you build with the GNUmakefile?" Without that prompt,
they would have been accepted as done. The `run-tests` skill runs the Xcode integration
tests, which test the Xcode-built app — not the GNUstep-built one.

**Action for user:** Add "and launch-test the GNUstep-built binary" explicitly to the
acceptance criteria for GNUstep makefile tasks, or extend the `run-tests` skill with a
`gnustep-launch-test.sh` script.

### 3. Late detection of resource layout error (defect 6)

Defect 6 (wrong resource subdirectory) was the last defect found and the most
consequential — it prevented the app from loading any scripts. It could have been
caught at Compile time by checking `find AppScriptHarness.app -name "*.appscript"` and
comparing the layout against the Xcode-built bundle. A simple structural check after
`make` would surface this in seconds rather than requiring a full launch debug cycle.

**Action for user:** Consider adding a post-build sanity check step to the GNUstep
`check` target that verifies expected resource files are at the right bundle paths.

### 4. Design phase was too short

One minute of design led to 39 minutes of compile+test repair. Had I spent 5–10
minutes studying the GNUstep `application.make` documentation (especially
`RESOURCE_FILES_DIR`, `MAIN_MODEL_FILE`, and the macOS dylib path requirements) before
writing any code, several defects would have been designed out rather than tested out.

**Action for user:** For tasks involving unfamiliar build system features, prompt Claude
to do a "read the make source" design step before coding. Something like: "Before you
code, read the relevant GNUstep Makefiles/Instance/*.make file to understand the
variables you plan to use."
