# PSP Postmortem — appscript-z0t

**Program:** Port unit tests to GNUstep XCTest
**Date:** 2026-03-19
**Total actual time:** 29 min (estimated 80 min — 36% of estimate used)

---

## Summary

The work was completed correctly and all tests pass in both build systems (Xcode and GNUstep Make). One defect was encountered: a GNUstep Make target naming conflict. The change to the 8 test files caused no Xcode regressions.

---

## Time Analysis

Every phase came in well under estimate — the total was 29 min against an 80 min estimate (64% underrun). This is not necessarily a sign of poor estimation; it may reflect that the subagent is fast at mechanical tasks (file edits, makefile additions) compared to a human engineer.

The largest relative underruns were in **Design** (2 min actual vs 10 estimated) and **Code** (7 min actual vs 25 estimated). The design work was quick because the GNUstep xctest package was already installed and its library/header locations were easy to discover. Coding was fast because the changes were straightforward once the design was settled.

**Actionable suggestion:** For future build-system tasks where a prior GNUstep Make installation exists, halve the design and coding estimates — the file-layout discovery and mechanical editing are fast. Reserve more time for the compile/test phase instead, since build system errors like the `check:` vs `check::` conflict are the most likely source of surprises.

---

## Defect Analysis

**1 defect total** — injected in Code, removed in Compile.

- **Type 60** (process/configuration): `check:` single-colon rule conflicted with GNUstep Make's built-in `check::` double-colon rule.
- **Root cause:** The subagent was not prompted to read GNUstep Make's `rules.make` before deciding how to define the `check` target. It assumed standard Make behaviour rather than GNUstep Make's extension pattern.
- **Detection lag:** Injected in Code, found only at first `make check` — one phase later. This is acceptable, but the defect could have been prevented entirely.

**Actionable suggestions:**

1. **Add a design step to the subagent prompt**: explicitly instruct the implementation agent to inspect `$(GNUSTEP_MAKEFILES)/Master/rules.make` for pre-existing target names before defining any new top-level targets. A single `grep "^check"` would have caught this.

2. **Document the GNUstep Make extension convention in the project** (e.g. in `ARCHITECTURE.md` or a GNUstep-specific `CONTRIBUTING` note): *new top-level phony targets should hook into `before-<target>`, `internal-<target>`, or `after-<target>` double-colon rules rather than redefining the top-level target.*

3. **Run `make check` as part of the subagent's work**, not just as a post-coding verification step. The subagent was instructed *not* to run `make`, which is why the defect was only found by the PSP agent. In future, let the implementation agent run the build and catch compile-phase defects itself.

---

## Process Observations

- The **ambiguity-resolution** step caught the import-style inconsistency early, preventing what could have been a harder-to-diagnose GNUstep build failure. This step is worth keeping.
- The user's mid-session correction ("update the existing GNUmakefile, not create a new one") and the follow-up ("ensure Xcode tests still work") were handled smoothly. Having both checks in the requirements before coding started meant neither caused rework.
- The requirement to run `make check` *and* verify it passes before proceeding to postmortem was the right gate: it caught the one defect that slipped through code review.
