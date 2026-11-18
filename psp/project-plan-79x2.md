# PSP Project Plan Summary

- Name: Graham Lee
- Date: 2026-11-18
- Program: AppScript-79x2 (exception handler boundary)
- Language: Objective-C

## Time in Phase

The plan estimated 360 min in total across seven steps; the per-phase estimates below are derived retroactively from those steps. Planning and Postmortem weren't estimated. Actuals are reconstructed.

| Phase | Estimate | Actual | Actual% |
|-------|----------|--------|---------|
|Planning| n/a | 25 | 46 |
|Design| 30 | 2 | 4 |
|Code| 210 | 7 | 13 |
|Compile| 30 | 3 | 6 |
|Test| 90 | 12 | 22 |
|Postmortem| n/a | 9 | 17 |
|Total| 360 | 58 | 100 |

## Defects Injected

| Phase | Count | % |
|-------|-------|---|
|Planning| 2 | 28.6 |
|Design| 2 | 28.6 |
|Code| 1 | 14.3 |
|Compile| 0 | 0 |
|Test| 2 | 28.6 |
|Total in Development| 7 | 100 |

## Defects Removed

| Phase | Count | % |
|-------|-------|---|
|Planning| 0 | 0 |
|Design| 1 | 20 |
|Code| 0 | 0 |
|Compile| 1 | 20 |
|Test| 3 | 60 |
|Total in Development| 5 | 100 |
|Total After Development| 1 | |

Defect 4 (retried owning-family sends may leak) was accepted by the user rather than removed. Defect 7 was removed in the postmortem.
