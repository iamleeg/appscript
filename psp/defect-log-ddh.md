# PSP Defect Recording Log

- Name: Claude (psp0-appraiser)
- Date: 2026-03-19
- Program: appscript-ddh

| # | Date | Type | Phase Injected | Phase Removed | Fix Time (min) | Description |
|---|------|------|---------------|---------------|----------------|-------------|
| 1 | 2026-03-19T13:33:53+00:00 | 30 (Build) | Code | Compile | 1 | GNUstep defaults to MRC; ASScope.m uses weak property requiring ARC. Fixed by adding ADDITIONAL_OBJCFLAGS = -fobjc-arc to GNUmakefile. |
| 2 | 2026-03-19T13:37:45+00:00 | 30 (Build) | Postmortem | Postmortem | 1 | Attempted to edit .gitignore without reading it first — tool error. Fixed by reading the file before editing. |
