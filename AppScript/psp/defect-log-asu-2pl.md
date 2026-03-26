# PSP Defect Recording Log

- Name: Claude Code
- Date: 2026-03-25
- Program: NSValue BridgeSupport Struct Field Accessors (asu-2pl)
- Language: Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| asu-2pl | 2026-03-25T22:39:51+00:00 | 1 | 60 | Code | Compile | 3 min | | `NSGetSizeAndAlignment("{CGPoint}", ...)` throws `NSInvalidArgumentException` for bare struct references. Assumed it returned 0 for unknowns. Fixed: check for `=` in encoding before calling NSGetSizeAndAlignment; use registry fallback directly for bare refs. |
| asu-2pl | 2026-03-25T22:55:00+00:00 | 2 | 90 | Code | Compile | 5 min | | `forwardInvocation:` return value (ASStructValue) released by ARC at block-scope end before `_objc_msgForward` reads it — segfault. Fixed: call `[inv retainArguments]` so NSInvocation retains the return value object. |
| asu-2pl | 2026-03-26T08:55:12+00:00 | 3 | 50 | Code | Test | 15 min | | Infinite recursion in `forwardInvocation:` block when Foundation BridgeSupport loaded first: property accesses `blockSelf.canonicalName` and `blockSelf.bytes` inside the block triggered sentinel selectors (installed for Foundation struct fields), causing re-entry. Fixed: use direct ivar access `blockSelf->_canonicalName` and `blockSelf->_bytes` to bypass ObjC message dispatch. |
| asu-2pl | 2026-03-26T09:28:22+00:00 | 4 | 50 | Code | Test | 33 min | | ARC retain/release infinite recursion: Foundation BridgeSupport structs (NSHashTableCallBacks etc.) have fields named `retain` and `release`. `class_addMethod` only checks the immediate class, not superclasses — so these override the NSObject implementations on ASStructValue. ARC's retain/release of any ASStructValue then re-enters `forwardInvocation:`. Fixed: guard sentinel installation with `instancesRespondToSelector:` (checks full hierarchy) before calling `class_addMethod`. |
