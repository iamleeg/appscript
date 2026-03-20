# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-20
- Program: appscript-btc
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-btc | 2026-03-20T08:50:56+00:00 | 1 | 30 | Code | Compile | 1m | | `evaluateExpression:` has no return in all paths — forgot `__builtin_unreachable()` after noreturn reportError call; Clang can't always see through ObjC message-send noreturn attribute |
| appscript-btc | 2026-03-20T08:50:56+00:00 | 2 | 70 | Code | Compile | 2m | | `userInfo` dict built but discarded — `[NSException raise:format:]` has no userInfo: param; should use `exceptionWithName:reason:userInfo:` + `-raise` |
| appscript-btc | 2026-03-20T08:56:03+00:00 | 3 | 60 | Code | Compile | 2m | | Helper class `ASUnknownTestNode` and `runAndCatch` function inserted inside `@implementation ASInterpreterTests` instead of before it — ObjC disallows class defs inside @implementation |
