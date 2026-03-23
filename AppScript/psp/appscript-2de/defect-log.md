# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-23
- Program: appscript-2de
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-2de | 2026-03-23T19:23:51+00:00 | 1 | 40 | Code | Review | 2 min | | ASUncaughtExceptionHandlerTests had no setUp/tearDown; tests mutated global NSUncaughtExceptionHandler without restoring it, risking cross-test pollution |
| appscript-2de | 2026-03-23T19:23:51+00:00 | 2 | 40 | Code | Review | 2 min | | No test verified the chaining path (previous handler called for non-AppScript exceptions); added test_installHandler_nonAppScriptException_invokesPreviousHandler |
