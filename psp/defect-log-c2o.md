# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-20
- Program: appscript-c2o — Source context display at AppScript error (clang-style)
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-c2o | 2026-03-20 10:17 | 1 | 10 | Code | Compile | 1 | | Doc comment used `<tab-expanded...>` HTML-like syntax, triggering -Wdocumentation warning; rewrote as plain prose |
| appscript-c2o | 2026-03-20 10:47 | 2 | 50 | Code | Test | 2 | | Used `stringWithContentsOfFile:encoding:error:` instead of the project's established `NSURL+AppScriptFileReading` `-as_stringContents` utility; found by simplify review and fixed |
