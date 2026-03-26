# PSP Postmortem — asu-2pl

- Name: Claude Code
- Date: 2026-03-26
- Program: NSValue BridgeSupport Struct Field Accessors (asu-2pl)
- Language: Objective-C

---

## Time Summary

| Phase | Estimate | Actual | Accuracy |
|-------|----------|--------|----------|
| Planning | 20 min | 21 min | 105% (on target) |
| Design | 10 min | 5 min | 50% (overestimated) |
| Code | 68 min | 6 min | 9% (wildly overestimated) |
| Compile | 8 min | 14 min | 175% (underestimated) |
| Test | 15 min | 48 min | 320% (badly underestimated) |
| Postmortem | 10 min | ~10 min | on target |
| **Total** | **131 min** | **~104 min** | **79%** |

## Defect Summary

| # | Type | Injected | Removed | Fix Time | Description |
|---|------|----------|---------|----------|-------------|
| 1 | 60 (Data) | Code | Compile | 3 min | `NSGetSizeAndAlignment` throws on bare struct refs |
| 2 | 90 (Build/Package) | Code | Compile | 5 min | ARC releases forwardInvocation: return value before forwarding reads it |
| 3 | 50 (Interface) | Code | Test | 15 min | Property accessors on blockSelf inside forwarding block trigger sentinel selectors |
| 4 | 50 (Interface) | Code | Test | 33 min | `class_addMethod` installs sentinel for `retain`/`release`, overriding NSObject |

All defects injected in Code phase. 2 caught in Compile (cheap), 2 caught in Test (expensive).

---

## Key Observations

### 1. Code Phase Was Massively Overestimated

The estimate for Code was 68 minutes; actual was 6 minutes. This is characteristic of the "multi-branch cross-cutting feature" shape (see psp-estimation-calibration memory), but the codebase patterns (value objects, parser extension, installer) are now deeply familiar. The code itself was fast; the problems were all in the ObjC runtime interaction, which showed up later.

**Actionable improvement**: For tasks that primarily extend existing patterns in a familiar codebase, cut Code estimates by 50–75% and reallocate that budget to Compile and Test. The hard work on `forwardInvocation:` dispatch is not in writing the code — it's in validating the runtime behaviour.

### 2. Test Phase Was Badly Underestimated (3.2× overrun)

Estimated 15 min; actual 48 min. The four defects consumed 56 minutes of fix time, with the two Test-phase defects alone taking 48 minutes. Both of those were subtle ObjC runtime problems that could only be observed by running tests in a process that had already loaded Foundation's BridgeSupport.

**Root cause of the time loss**: The test environment exposed interactions with Foundation's real BridgeSupport that could not have been predicted from unit tests run in isolation. Specifically:
- Defect 3: Property accessors inside a `forwardInvocation:` block are unsafe if those selectors are registered as sentinels by other code running in the same process.
- Defect 4: `class_addMethod` silently succeeds at overriding inherited NSObject methods (`retain`, `release`) if they aren't already directly on the subclass — because `class_addMethod` only checks the immediate class.

### 3. Both Expensive Defects Share a Root Cause

Defects 3 and 4 are both variations on the same theme: **the forwardInvocation: implementation interacted badly with the ObjC runtime in ways that only manifested when many unrelated selectors were installed on the same class by an external caller (Foundation BridgeSupport).**

This suggests a design-time checklist item was missing:

> **When implementing `forwardInvocation:`-based dispatch on a class, explicitly enumerate every ObjC message send that occurs *inside* the forwarding block and ask: "If this selector is also registered as a sentinel on this class, what happens?"**

If that question had been asked during Design, both defects would have been caught before Code:
- `blockSelf.canonicalName` inside the block → use `blockSelf->_canonicalName` (direct ivar)
- `class_addMethod` for `retain`/`release` → guard with `instancesRespondToSelector:`

**Actionable improvement**: Add this checklist item to the design skill or to a project-specific `forwardInvocation:` design template.

### 4. Parallelism Made Test Failures Flaky and Hard to Diagnose

Defect 4 was intermittent: it only manifested in XCTest parallel workers that had run `NSBundle_AppScriptBridgeSupportLoadingTests` first. Diagnosing which test class was polluting which worker, and what exactly `retain`/`release` being sentinels meant for ARC, took the bulk of the 33-minute fix time.

**Actionable improvement for this project**: When adding a new test class that registers global runtime state (class methods, sentinel IMPs), explicitly check whether the test produces different results when run:
- In isolation (`-only-testing:`)
- Together with the BridgeSupport loading tests (`-only-testing:A -only-testing:B`)

This is cheap to verify at the end of the Code phase and would have exposed Defect 4 before it was submitted for test.

### 5. Estimation Accuracy Was Good Overall Despite Phase Imbalance

The total came in at 104 min vs 131 min estimated (79%) — within the plausible range. But the phase distribution was very different from the estimate. This is a pattern: for `forwardInvocation:`-style runtime programming, the difficulty is not in writing the code but in debugging the interactions. Future tasks of this shape should use this distribution:

| Phase | Suggested allocation |
|-------|---------------------|
| Planning | 15% |
| Design | 8% |
| Code | 8% |
| Compile | 15% |
| Test | 45% |
| Postmortem | 9% |

---

## Specific Actionable Recommendations

1. **Add `forwardInvocation:` design checklist** to the design skill or CLAUDE.md: when writing code that installs `_objc_msgForward` as a sentinel IMP and a corresponding `forwardInvocation:` handler, require explicit enumeration of every ObjC message send inside the block body and verify none of those selectors could be installed as sentinels.

2. **Use direct ivar access by default inside forwarding blocks**: any `self.property` access inside `forwardInvocation:` should be replaced with `self->_ivar` at design time, not discovered as a crash during testing. This could be a code-review checklist item.

3. **Guard `class_addMethod` sentinel installations with `instancesRespondToSelector:`**: this should be a standing rule for all future sentinel-based dispatch installations. The comment explaining the `retain`/`release` hazard is now in the code; the principle should also be documented in ARCHITECTURE.md.

4. **Add a parallel-isolation smoke test** at end of Code phase: run the new test class together with `NSBundle_AppScriptBridgeSupportLoadingTests` (two `-only-testing:` flags) before calling Code complete. If that passes, Defect 4 would have been caught 40+ minutes earlier.

5. **Re-calibrate Test phase estimates for `forwardInvocation:` tasks**: 15 min was based on the standard calibration. For ObjC runtime dispatch tasks, use 45 min as the baseline for the Test phase.
