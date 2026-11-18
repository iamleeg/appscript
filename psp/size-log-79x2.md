# PSP Size Recording Log

- Name: Graham Lee
- Date: 2026-11-18
- Program: AppScript-79x2 (exception handler boundary)
- Language: Objective-C

Counts are physical lines in `.h`/`.m` files under `AppScript/AppScript` and `AppScript/AppScriptTests`. Build files (`GNUmakefile`, `project.pbxproj`, 14 lines) and the DocC article (33 lines) are excluded.

- Base Size (Actual) [B]: 24031
- Deleted Size (Actual) [D]: 0
- Modified Size (Actual) [M]: 0
- Added Size (Actual) [A]: 924
- Reused Size (Actual) [R]: 0 (existing helpers such as `ASMakeRuntimeErrorException`, `ASBoxer` ownership helpers and the scope/call-stack code were called unchanged, not copied)
- Added & Modified (Actual) [A+M]: 924
- Total Size (Actual) [B + A - D]: 24955
- New Reused Size (Actual) [R']: 248

Breakdown of Added: new source 238 (six files), new tests 515 (three files), edits to existing files 171 (`ASInterpreter.m` 125, `ASInterpreter.h` 10, `AppScript.h` 4, `ASInterpreterTests.m` 32).
