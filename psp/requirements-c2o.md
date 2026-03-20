# Requirements: appscript-c2o — Source context display at AppScript error (clang-style)

## Overview

When `reportError:code:node:context:` fires in `ASInterpreter.m`, the error
output should include the source line from the `.appscript` file along with a
caret (`^`) pointing to the column where the error occurred — matching the
diagnostic style used by clang and rustc.

## Functional Requirements

### REQ-1: Source line in exception reason

The source line from the `.appscript` file at the error location **shall** be
appended to the `NSException` reason string, immediately after the existing
`"AppScript error at <path>:<line>:<col>: <message>"` line, separated by a
newline.

No side effects (no `NSLog`, no `stderr` output). The exception reason is the
sole output surface.

### REQ-2: Caret alignment

A second line consisting of a caret (`^`) **shall** be appended below the
source line. The caret **shall** be placed at position `column − 1` (0-based)
from the start of the (possibly tab-expanded) line, so it points directly at
the offending token.

Column values are 1-based as stored in `ASASTNode`.

### REQ-3: Tab expansion

Tab characters (`\t`) in the source line **shall** be expanded to 4 spaces
before both display and caret positioning. The caret position is calculated
after tab expansion.

### REQ-4: Zero line / zero column handling

- If `line == 0` (no node available): **omit** the source-context block
  entirely. The reason string is unchanged from the current format.
- If `line > 0` but `col == 0`: **show** the source line but **omit** the
  caret line.

### REQ-5: Missing or unreadable file

If the source file cannot be read (path is `"<unknown>"`, file does not exist,
or any `NSError` occurs during reading), append `"(source unavailable)"` as an
additional line to the exception reason string, provided `line > 0`.

## Non-functional Requirements

- No public API changes to `ASInterpreter` or any other header.
- The modification is confined to `ASInterpreter.m`.
- The feature must be covered by unit tests in `ASInterpreterTests.m`.
- The integration test suite (`integration-tests.sh`) must continue to pass.

## Design Decisions (from ambiguity resolution)

| # | Decision |
|---|----------|
| 1 | Source context appended to `NSException` reason only; no `NSLog`/stderr |
| 2 | Caret at `column − 1` spaces from start of **raw** (tab-expanded) line |
| 3 | Tabs expanded to **4 spaces** |
| 4 | `line == 0` → omit block; `col == 0` → show line, omit caret |
| 5 | Unreadable file → append `"(source unavailable)"` |
