# Requirements: appscript-isd — Add GNUmakefile harness app target

## Problem Statement

Add a build target for the AppScriptHarness app to the existing `AppScript/GNUmakefile`.
Do **not** create a new makefile; add the target to the existing file.

The AppScriptHarness is the integration test runner: it loads `.appscript` script files from
its bundle, runs them against the full runtime, and exits 0 (all pass) or 1 (any failure).

## Resolved Requirements

1. **Target type**: Use `application.make` — build AppScriptHarness as a GNUstep `.app` bundle.

2. **Cocoa import**: Do not modify `main.m`. GNUstep supplies `<Cocoa/Cocoa.h>`, so the
   existing import is correct as-is.

3. **NEEDS_GUI**: Remove the global `NEEDS_GUI = no` line. Replace with per-target variables:
   - `AppScript_NEEDS_GUI = no` (framework, no GUI dependency)
   - `AppScriptHarness_NEEDS_GUI = yes` (app, links AppKit)

## Scope

### In scope
- Add `APP_NAME`, source files, resource files, and library/framework linkage for
  AppScriptHarness to the existing `AppScript/GNUmakefile`.
- Include `$(GNUSTEP_MAKEFILES)/application.make` after the existing `bundle.make` include.
- Bundle the `AppScriptHarness/Scripts/` directory as a resource directory.
- Link the app against the AppScript framework.

### Out of scope
- Modifying any Objective-C source files.
- Adding a new GNUmakefile.
- Modifying the test bundle target or the framework target (except the NEEDS_GUI change).
