# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-20
- Program: appscript-5j3 (Call Stack Backtrace)
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-5j3 | 2026-03-20T16:25 | 1 | 70 | Design | Review | 2 | — | Dead `receiver` field on ASCallFrame: written during design and set at frame-push time, but never read by ASFormatCallFrame or any backtrace path. Removed in simplify review. |
| appscript-5j3 | 2026-03-20T16:25 | 2 | 80 | Code | Review | 3 | — | Duplicated class-name derivation logic: `class_isMetaClass + NSStringFromClass` idiom written twice (evaluateMethodBody: private and evaluateBlockLiteral:). Extracted into ASClassNameForObject() helper in simplify review. |
| appscript-5j3 | 2026-03-20T16:25 | 3 | 80 | Code | Review | 2 | — | Unnecessary `[ASCurrentCallStack() copy]` in reportError:: reportError: is noreturn so @finally pops run after the raise, not during iteration. Direct iteration of the mutable array is safe. Removed copy in simplify review. |
