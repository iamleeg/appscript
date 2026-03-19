# Requirements: GNUmakefile for AppScript Framework (appscript-ddh)

## Summary

Create a `GNUmakefile` in `AppScript/AppScript/` that builds the AppScript framework as a GNUstep framework using `framework.make`.

## Requirements

### R1 — File location
The `GNUmakefile` must be placed at `AppScript/GNUmakefile`.

### R2 — Build system
The makefile must use GNUstep's `framework.make` (not `library.make`), producing a `.framework` bundle suitable for linking by the harness and tests.

### R3 — Framework name
The framework must be named `AppScript`, producing `AppScript.framework`.

### R4 — No GUI dependency
The makefile must set `NEEDS_GUI = no`, because AppScript depends only on Foundation and does not require any GUI library.

### R5 — Source files
All 41 `.m` files in `AppScript/AppScript/` must be listed in `AppScript_OBJC_FILES`:

- ASArrayLiteralNode.m
- ASAssignmentNode.m
- ASASTNode.m
- ASBlockLiteralNode.m
- ASBoxer.m
- ASBridgeSupportConstant.m
- ASBridgeSupportDocument.m
- ASBridgeSupportEnumeration.m
- ASBridgeSupportFunction.m
- ASBridgeSupportInstaller.m
- ASBridgeSupportParser.m
- ASCategoryDefinitionNode.m
- ASClassDefinitionNode.m
- ASDictionaryLiteralNode.m
- ASIdentifierNode.m
- ASInterpreter.m
- ASLexer.m
- ASLoader.m
- ASMessageSendNode.m
- ASMethodNode.m
- ASNull.m
- ASNumberLiteralNode.m
- ASParser.m
- ASPropertyNode.m
- ASReturnNode.m
- ASRuntimeInstaller.m
- ASScope.m
- ASStringLiteralNode.m
- ASSuperNode.m
- ASToken.m
- ASVariableDeclarationNode.m
- NSArray+AppScriptBlocks.m
- NSBundle+AppScriptBridgeSupportLoading.m
- NSBundle+AppScriptLoading.m
- NSNumber+AppScriptArithmetic.m
- NSNumber+AppScriptBitwise.m
- NSNumber+AppScriptControlFlow.m
- NSNumber+AppScriptLogic.m
- NSObject+AppScriptControlFlow.m
- NSString+AppScriptRuntime.m
- NSURL+AppScriptFileReading.m

### R6 — Header files
All public `.h` files in `AppScript/AppScript/` must be listed in `AppScript_HEADER_FILES`. Headers will be installed into the `AppScript/` subdirectory inside the framework (handled automatically by `framework.make`), making them importable as `#import <AppScript/Header.h>`.

### R7 — Standard GNUstep makefile structure
The file must follow the standard GNUstep pattern:
1. `include $(GNUSTEP_MAKEFILES)/common.make`
2. Variable assignments (`FRAMEWORK_NAME`, `NEEDS_GUI`, `AppScript_OBJC_FILES`, `AppScript_HEADER_FILES`)
3. `include $(GNUSTEP_MAKEFILES)/framework.make`

### R8 — SPDX licence header
The file must begin with the project's standard SPDX licence header (AGPL-3.0-or-later), matching other source files in the project.
