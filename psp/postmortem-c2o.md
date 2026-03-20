# Postmortem: appscript-c2o — Source context display at AppScript error (clang-style)

Date: 2026-03-20

## Summary

| Metric | Estimate | Actual | Ratio |
|--------|----------|--------|-------|
| Total time | 26 min | 30 min | 1.15x |
| Defects injected | — | 2 | — |
| Defects removed in development | — | 2 | — |
| Defects escaped | — | 0 | — |

## Time Analysis

Estimates were very close overall (1.15x vs. the prior calibrated ~0.3x ratio for "narrowly scoped" tasks). This task was slightly larger than the canonical single-method narrowly-scoped shape — it involved a new static helper with non-trivial logic, 7 tests (vs. the 4-6 baseline), and the simplify review. The estimate held up well.

**Test phase overran by 2x (5 min estimated, 10 actual).** The main contributor was the simplify review (3 agents + one additional compile/test cycle to apply the fix). The simplify review is valuable — it caught a real consistency issue — but it is not accounted for in the PSP estimate template.

**Actionable suggestion:** Add a "Review" phase row to the project plan estimate, distinct from Test, to account for the simplify skill's compile+retest cycle. Budget 3–5 min for narrowly scoped tasks.

## Defect Analysis

Both defects were injected in the **Code** phase:

1. **Doc comment syntax** (Type 10 — Documentation): A `<tab-expanded...>` string in the doc comment was parsed as malformed HTML by the documentation warning pass. Removed immediately in Compile (1 min fix). This class of defect is trivially avoided by writing doc comments in plain prose rather than pseudo-HTML angle-bracket syntax. Low cost.

2. **Wrong file-reading API** (Type 50 — Interface): Used `stringWithContentsOfFile:encoding:error:` instead of the project's `NSURL+AppScriptFileReading` (`-as_stringContents`). Removed in Test via the simplify review (2 min fix). This defect was not caught at design time — the design phase did not explicitly check for existing project utilities covering this operation.

**Actionable suggestion:** During the Design phase for any feature that reads files, explicitly grep for existing file-reading utilities (`grep -r "stringContents\|fileReading"`) before writing the implementation. This is a 30-second step that would have prevented defect #2 entirely.

## Process Observations

### What worked well
- **Ambiguity resolution up front** (5 questions, all resolved in one exchange) meant zero requirement-driven rework during coding.
- **First build was clean** (only a doc comment warning). The design was straightforward enough that no structural compile errors occurred.
- **All tests passed on first run.** The 7 tests were written to match the specification directly (one test per REQ), making them easy to reason about.
- **Simplify review caught a real issue.** The three-agent review paid for itself by surfacing the API inconsistency.

### What could be improved
1. **Design phase should include a "check for existing utilities" step** for any I/O operation. Would have caught defect #2.
2. **Estimate the simplify/review cycle explicitly** — it is a consistent 3–5 min overhead that makes the Test phase appear to overrun.
3. **Tab-width is a magic literal** (`@"    "`) in `ASExpandTabs`. Although only one occurrence, a `#define AS_TAB_WIDTH 4` or similar constant would make intent clearer. Filed as a low-priority cleanup note — not a defect but a style improvement for future contributors.

## Calibration Update

This task shape: "add a static helper function with conditional logic, 7 unit tests, no public API changes" → **30 min actual** with good estimates (26 min). Slightly larger than the canonical 20-min narrowly-scoped ObjC task. The sizing factor that drove extra time was: (a) helper logic was ~15 lines with 4 distinct branches, and (b) simplify review overhead.

Suggest updating the calibration memory to distinguish:
- "Narrowly scoped, 1-2 branches, 4-6 tests" → ~20 min
- "Narrowly scoped, 3-4 branches, 6-8 tests + review" → ~30 min
