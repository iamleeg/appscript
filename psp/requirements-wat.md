# Requirements — asu-wat: NSNumber Rounding and Clamping

## Problem statement

AppScript code needs `round()` and `floor()` for pixel-aligned layout calculations, and `MAX()`/`MIN()` for clamping split-view pane sizes. These are C macros or `libm` functions and are **not** present in `libSystem.bridgesupport`, so they cannot be reached via the BridgeSupport proxy. The AppScript runtime must provide them as category methods on `NSNumber`.

## Requirements

### R1 — `rounded`

Add the following instance method to `NSNumber (AppScriptArithmetic)`:

```objc
- (NSNumber *)rounded;
```

- Returns a new `NSNumber` wrapping `round([self doubleValue])`.
- Uses `round()` semantics: rounds half-away-from-zero (e.g. 2.5 → 3.0, −2.5 → −3.0).
- Return value is a `double`-typed `NSNumber` (i.e. `+[NSNumber numberWithDouble:]`), consistent with all other methods in the category.

### R2 — `floored`

Add the following instance method to `NSNumber (AppScriptArithmetic)`:

```objc
- (NSNumber *)floored;
```

- Returns a new `NSNumber` wrapping `floor([self doubleValue])`.
- Rounds toward −∞ (e.g. 2.9 → 2.0, −2.1 → −3.0).
- Return value is a `double`-typed `NSNumber`.

### R3 — `numberMaximumOfSelfAnd:`

Add the following instance method to `NSNumber (AppScriptArithmetic)`:

```objc
- (NSNumber *)numberMaximumOfSelfAnd:(NSNumber *)other;
```

- Returns a new `NSNumber` wrapping `fmax([self doubleValue], [other doubleValue])`.
- `fmax` is used (not the `MAX` macro) for correct NaN/infinity handling.
- Return value is a `double`-typed `NSNumber`.

### R4 — `numberMinimumOfSelfAnd:`

Add the following instance method to `NSNumber (AppScriptArithmetic)`:

```objc
- (NSNumber *)numberMinimumOfSelfAnd:(NSNumber *)other;
```

- Returns a new `NSNumber` wrapping `fmin([self doubleValue], [other doubleValue])`.
- `fmin` is used (not the `MIN` macro) for correct NaN/infinity handling.
- Return value is a `double`-typed `NSNumber`.

### R5 — Implementation location

All four methods are added to the **existing** `NSNumber+AppScriptArithmetic.h` / `NSNumber+AppScriptArithmetic.m` files. No new files are created for the implementation.

### R6 — Documentation

`ARCHITECTURE.md` is updated to document all four new methods in the AppScriptArithmetic section (the runtime categories table and/or the "Basic arithmetic" section).

### R7 — Tests

Unit tests for all four methods are added to `AppScriptTests/NSNumber_AppScriptArithmeticTests.m`, following the existing naming convention (`test_<method>_<scenario>_<expected>`). Cover at minimum:

- `rounded`: positive fraction, negative fraction, half-way (0.5), negative half-way (−0.5), already-integer value
- `floored`: positive fraction, negative fraction, already-integer value
- `numberMaximumOfSelfAnd:`: left larger, right larger, equal values
- `numberMinimumOfSelfAnd:`: left smaller, right smaller, equal values

## Out of scope

- `ceil()` / `ceiled` — not needed by any blocked issue; can be added separately if required.
- Returning integer-typed `NSNumber` from `rounded`/`floored` — use `double` for consistency (resolved ambiguity).
- BridgeSupport or `ASLibSystem` proxy approach — not possible; these functions are absent from `libSystem.bridgesupport`.
