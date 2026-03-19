# Requirements: Port Unit Tests to GNUstep XCTest (appscript-z0t)

## Problem Statement

Extend the existing `AppScript/GNUmakefile` to also build a unit test bundle using GNUstep's XCTest framework, and add a `check` pseudo-target that runs all unit tests via GNUstep's `xctest` tool (installed at `/usr/local/bin/xctest`).

## Scope

### Included test files

All 19 `.m` files currently in `AppScript/AppScriptTests/`:

- `ASASTNodeTests.m`
- `ASBoxerTests.m`
- `ASBridgeSupportInstallerTests.m`
- `ASBridgeSupportParserTests.m`
- `ASInterpreterTests.m`
- `ASLexerTests.m`
- `ASLoaderTests.m`
- `ASParserStringEscapeTests.m`
- `ASParserTests.m`
- `ASRuntimeInstallerTests.m`
- `NSBundle_AppScriptBridgeSupportLoadingTests.m`
- `NSBundle_AppScriptLoadingTests.m`
- `NSNumber_AppScriptArithmeticTests.m`
- `NSNumber_AppScriptBitwiseTests.m`
- `NSNumber_AppScriptControlFlowTests.m`
- `NSNumber_AppScriptLogicTests.m`
- `NSObject_AppScriptControlFlowTests.m`
- `NSString_AppScriptRuntimeTests.m`
- `NSURL_AppScriptFileReadingTests.m`

### Excluded

- `AppScriptHarnessUITests` (XCUIAutomation integration tests — not supported by GNUstep XCTest)

## Functional Requirements

1. The existing `AppScript/GNUmakefile` shall be extended (not replaced) to also build a test bundle containing all 19 test files listed above.
2. The test bundle shall link against the `AppScript` framework built in the same makefile.
3. A `check` pseudo-target shall be added that builds the test bundle (if needed) and then runs `xctest` (at `/usr/local/bin/xctest`) against it.
4. The test bundle shall use ARC (`-fobjc-arc`) consistent with the framework target.
5. The 8 test files that currently use project-relative `"Foo.h"` imports shall be updated to use framework-style `<AppScript/Foo.h>` imports, consistent with the other 11 test files. This change must not break the existing Xcode `AppScriptTests` target. (This is safe: the Xcode target depends on the AppScript framework and has no `HEADER_SEARCH_PATHS` override; 11 other test files in the same target already use `<AppScript/Foo.h>` successfully.)
   - `ASBridgeSupportInstallerTests.m`
   - `ASBridgeSupportParserTests.m`
   - `NSBundle_AppScriptBridgeSupportLoadingTests.m`
   - `NSNumber_AppScriptArithmeticTests.m`
   - `NSNumber_AppScriptBitwiseTests.m`
   - `NSNumber_AppScriptControlFlowTests.m`
   - `NSNumber_AppScriptLogicTests.m`
   - `NSObject_AppScriptControlFlowTests.m`

## Non-Functional Requirements

- The solution must work with GNUstep Make on a Linux host.
- The `GNUmakefile` additions shall follow the same conventions and style as the existing content.
- The `GNUmakefile` AGPL-3.0-or-later SPDX licence comment header is already present and shall be retained.
