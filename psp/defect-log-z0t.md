# PSP Defect Recording Log

- Name: Claude
- Date: 2026-03-19
- Program: appscript-z0t (Port unit tests to GNUstep XCTest)
- Language: GNUstep Make / Objective-C

| Project | Time | Number | Type | Inject | Remove | Fix Time | Fix Ref | Description |
|---------|------|--------|------|--------|--------|----------|---------|-------------|
| appscript-z0t | 2026-03-19T16:06:26+00:00 | 1 | 60 | Code | Compile | 1 min | | `check:` single-colon rule conflicts with GNUstep Make's existing `check::` double-colon rule in rules.make; fixed by changing to `internal-check::` |
