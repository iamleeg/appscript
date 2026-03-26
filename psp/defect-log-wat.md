# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-25
- Program: wat (asu-wat — NSNumber rounding and clamping)
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| wat | 2026-03-25T18:40:00+00:00 | 1 | 110 | Test | Test | 3 min | — | Ran unit-test script without GNUSTEP_MAKEFILES set; GNUstep make step failed with "No such file or directory". Fixed by setting GNUSTEP_MAKEFILES=$(gnustep-config --variable=GNUSTEP_MAKEFILES) before re-running. |
