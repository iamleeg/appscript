# PSP Postmortem — appscript-ewo

**Project:** AppScript escape sequence support
**Date:** 2026-03-18
**Total time:** 44 min (estimated 125 min)

---

## Quantitative summary

| Phase | Estimate | Actual | Ratio |
|-------|----------|--------|-------|
| Planning | 15 min | 4 min | 0.27× |
| Design | 15 min | 1 min | 0.07× |
| Code | 45 min | 1 min | 0.02× |
| Compile | 10 min | 3 min | 0.30× |
| Test | 30 min | 30 min | 1.00× |
| Postmortem | 10 min | 5 min | 0.50× |
| **Total** | **125 min** | **44 min** | **0.35×** |

All 4 defects were injected in the Test phase and removed in the Test phase.
0 defects were injected in Planning, Design, Code, or Compile.

---

## What went well

- **Coding phase was extremely fast (1 min actual vs 45 min estimated).** The fix was well-scoped — one private helper method plus a small call-site change — and the existing error-handling patterns in `ASParser.m` made it straightforward to follow.
- **First compile succeeded with no errors.** Building on the existing code style and following established patterns avoided any type or API errors.
- **Unit tests were comprehensive on first write.** All 17 unit test cases passed immediately without needing corrections, covering every acceptance criterion.
- **Zero defects in code or compile.** The implementation was correct on the first attempt.

---

## What went wrong

### 1. Integration tests omitted from initial scope (defect 1)

**What happened:** I declared "Done" after unit tests passed and did not include integration tests in the Test phase plan. You had to explicitly ask for them.

**Root cause:** The requirements document mentioned "existing AppScript tests continue to pass" but did not explicitly call out integration tests as a required deliverable. I interpreted this narrowly as "unit tests."

**Actionable improvement:** Add a standard checklist item to the psp-develop skill or the requirements template: *"Have you added or updated integration/harness tests?"* This should be prompted before the developer signs off. Alternatively, the requirements document template could include a dedicated "Integration test" acceptance criterion for any project with an existing integration harness.

---

### 2. Documentation updates omitted from scope (defect 2)

**What happened:** `README.md` ("Upcoming features") and `ARCHITECTURE.md` (string literal description) were not updated as part of the fix. Again you had to ask.

**Root cause:** The issue description focused entirely on the parser fix. Documentation updates were not listed as acceptance criteria in the requirements document.

**Actionable improvement:** Add a standard non-functional requirement to the requirements template: *"Update all user-facing documentation affected by this change (README, ARCHITECTURE, etc.)."* A checklist at the end of psp-develop could remind: *"Have you updated README and ARCHITECTURE where relevant?"*

---

### 3. Integration test crash — missing `.expected` file (defect 3, caused by defect 1)

**What happened:** Adding `StringEscapes.appscript` without a companion `.expected` file caused `URLForResource:withExtension:` to return `nil` (AppScript `ASNull`), which then caused `[ASNull as_stringContents]` to abort the harness. This was a latent bug in the test runner that only manifests for new tests added without their expected file.

**Root cause:** Downstream consequence of defect 1 (no integration test experience with this project). I was unfamiliar with the harness convention that `.expected` files are mandatory.

**Actionable improvement:** The `ASTestRunner.appscript` has a latent bug: it calls `as_stringContents` on a URL that may be `nil` before checking whether it got back a string. This could be fixed defensively in the runner itself. Separately, a brief note in the test harness `README` or in the harness `Scripts/` directory (e.g. a `HOWTO.md`) explaining the `.appscript` + `.expected` file pairing convention would prevent this mistake for any future developer.

---

### 4. Wrong `.expected` content (defect 4, caused by defect 1)

**What happened:** The first version of `StringEscapes.expected` included a backslash+quote item (`@"\\\""`) without knowing how Foundation's `NSArray -description` escapes special characters in that context. This caused a mismatch.

**Root cause:** I guessed the NSArray description format for strings containing `\` and `"` rather than verifying it empirically first.

**Actionable improvement:** When writing a new integration test, always run the harness once with a placeholder `.expected` file and look at the actual output before committing to the final `.expected` content. This is the standard "capture then assert" pattern used in snapshot testing. Alternatively, add a helper script or harness mode that prints the actual output for a named test to stdout so it can be captured directly.

---

## Estimation accuracy

Every phase was dramatically over-estimated (35% of total estimate used). The coding phase was estimated at 45 minutes but took 1 minute. This suggests:

1. **The issue was small and well-localised.** The beads issue correctly identified the fix site (`ASParser.m ~line 810`), which made exploration fast.
2. **Estimates from the prior project (appscript-7ew) anchored too high.** That project involved a new class (`ASLoader`); this one only required a new private method.

**Actionable improvement:** For "add feature to existing well-understood file" issues, reduce Code estimates by 80% compared to "new file" estimates. A rough heuristic: if the fix site is already identified in the issue description, the coding phase is likely under 5 minutes.

---

## Summary of actionable improvements

| Priority | Action | Who |
|----------|--------|-----|
| High | Add integration test checklist item to psp-develop sign-off | Update psp-develop skill |
| High | Add documentation update requirement to requirements template | Update psp-plan skill or requirements template |
| Medium | Fix latent nil-URL crash in `ASTestRunner.appscript` | File as a new beads issue |
| Medium | Add `HOWTO.md` to `AppScriptHarness/Scripts/` explaining `.appscript`+`.expected` pairing | File as a new beads issue |
| Low | Add "capture-then-assert" guidance for new integration tests | Add to harness HOWTO |
| Low | Calibrate Code phase estimates: identified fix-site issues ≈ 5 min, not 45 min | Remember for next planning |
