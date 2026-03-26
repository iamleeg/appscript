# Requirements: NSValue BridgeSupport Struct Field Accessors (asu-2pl)

## Problem

AppScript is an Objective-C interpreter. When ObjC methods return structs (e.g. `NSScrollView.contentSize` returns `NSSize`, NSSplitView delegate receives `oldSize` as `NSSize`), those values are boxed as `NSValue`. AppScript code currently cannot access `.width`, `.height`, or any other named struct field on those values — the fields are inaccessible.

## Solution Overview

Parse `<struct>` elements from BridgeSupport XML (currently silently ignored). The `type64` attribute contains named field encodings, e.g. `{CGSize="width"d"height"d}`. Use this metadata to dynamically install field accessor methods so that AppScript code can call `.width` and `.height` on an `ASStructValue` object returned when a struct is boxed.

## Scope

Only implement what is needed to unblock `asu-79j` (Port ResearchNotesView) and `asu-cyc` (Port ResearchNotesController). Those tasks require `NSSize` (width/height). For generality the four main geometry/range structs are included: `CGSize`, `CGPoint`, `CGRect`, `NSRange`. Field type encodings supported: primitives (`d`, `Q`) and nested structs (`{…}`). Arrays, pointers, and bitfields are out of scope.

---

## Requirements

### R1 — ASBridgeSupportStructField model

A new class `ASBridgeSupportStructField` with:
- `name` (NSString, readonly copy) — field name as it appears in BridgeSupport, e.g. `@"width"`
- `typeEncoding` (NSString, readonly copy) — single-type ObjC encoding character or nested struct encoding, e.g. `@"d"` for double, `@"{CGPoint=dd}"` for nested struct
- Designated initializer: `initWithName:typeEncoding:`
- `init` unavailable

### R2 — ASBridgeSupportStruct model

A new class `ASBridgeSupportStruct` with:
- `canonicalName` (NSString, readonly copy) — the public-facing name used as the lookup key, e.g. `@"CGSize"`, `@"NSRange"` (see R3 for name mapping).
- `fields` (NSArray<ASBridgeSupportStructField *>, readonly copy) — ordered list of fields; may be empty for opaque structs.
- Designated initializer: `initWithCanonicalName:fields:`
- `init` unavailable

### R3 — ASBridgeSupportParser — parse `<struct>` elements

Extend the SAX delegate in `ASBridgeSupportParser` to handle `<struct>` elements:

- Prefer `type64` attribute; fall back to `type` (consistent with existing parsing).
- Extract the **imported name** from inside the opening brace: `{_NSRange=...}` → `_NSRange`. Apply the name mapping table (see below) to produce the **canonical name**.
- Parse the quoted-field format `"fieldname"typechar` to build an ordered array of `ASBridgeSupportStructField` objects. Nested struct fields record the nested encoding (stripped of field names) as the type, e.g. `{CGPoint=dd}`.
- Structs with zero parseable fields are **included** in the document as zero-field `ASBridgeSupportStruct` objects.

**Name mapping table** — a static table applied at parse time to map imported struct names to canonical names:

| Imported name | Canonical name |
|--------------|----------------|
| `_NSRange`   | `NSRange`      |

This table is the single authorised place for such mappings. Any future additions must go here.

### R4 — ASBridgeSupportDocument — structs property

Extend `ASBridgeSupportDocument` with:
- `structs` property: `NSArray<ASBridgeSupportStruct *> *` (readonly copy)
- `structNamed:` lookup: `- (nullable ASBridgeSupportStruct *)structNamed:(NSString *)canonicalName`
- Update designated initializer to accept `structs:` parameter.

### R5 — ASStructValue — new class for boxed structs

`ASStructValue` is an `NSObject` subclass (not an `NSValue` subclass) that holds the bytes of a C struct together with enough metadata to dispatch field accessors and produce a proper `NSValue` when needed.

**Properties / initializer:**
- `canonicalName` (NSString, readonly copy) — e.g. `@"CGSize"`, used to look up the struct in the global registry for accessor dispatch.
- `runtimeTypeEncoding` (NSString, readonly copy) — stripped encoding without field names, e.g. `{CGSize=dd}`. Used by `-asNSValue`.
- `bytes` (NSData, readonly) — the raw struct bytes.
- Designated initializer: `initWithBytes:(const void *)bytes length:(NSUInteger)length canonicalName:(NSString *)canonicalName runtimeTypeEncoding:(NSString *)runtimeTypeEncoding`
- `init` unavailable.

**`-asNSValue`:**
Returns `[NSValue valueWithBytes:self.bytes.bytes objCType:self.runtimeTypeEncoding.UTF8String]`.

**Field accessor dispatch (forwardInvocation: mechanism):**
Install `methodSignatureForSelector:` and `forwardInvocation:` on `ASStructValue`:

`methodSignatureForSelector:` — if the selector matches a field name in the registered struct, return `[NSMethodSignature signatureWithObjCTypes:"@@:"]`; otherwise fall through to super.

`forwardInvocation:` dispatch logic:
1. Look up `self.canonicalName` in the global struct registry (see R6).
2. If not found, fall through to super.
3. Find the field matching the invocation's selector name. If not found, fall through to super.
4. Compute the byte offset by summing `NSGetSizeAndAlignment` sizes of all preceding fields.
5. Extract bytes from `self.bytes.bytes + offset`.
6. Box the result:
   - Primitives (`d`, `f`, `i`, `I`, `l`, `L`, `q`, `Q`, `s`, `S`, `c`, `B`): box as `NSNumber`.
   - Nested struct (type starts with `{`): create a new `ASStructValue` with the field's bytes, the nested canonical name (extracted from between `{` and `=`), and the field's type encoding as `runtimeTypeEncoding`.
   - Other encodings: fall through to super (out of scope).
7. Set the boxed value as the invocation's return value.

**Chained access** (`rect.origin.x`): works in two hops automatically because `.origin` returns an `ASStructValue` with `canonicalName = @"CGPoint"`, which is also registered, so `.x` dispatches through the same mechanism.

### R6 — ASBridgeSupportInstaller — struct registry and ASStructValue setup

When installing a document:
1. Iterate `document.structs`.
2. For each struct **not already in the global registry**, add it. The registry is a process-wide `NSMutableDictionary<NSString *, ASBridgeSupportStruct *>` (keyed by canonical name) stored as a static variable in `ASBridgeSupportInstaller.m`. An existing entry is never overwritten.
3. For each field in each newly-added struct, install a sentinel instance method on `ASStructValue` via `class_addMethod` with `_objc_msgForward` IMP and encoding `@@:`. If a method already exists for that selector, skip it silently.
4. `forwardInvocation:` and `methodSignatureForSelector:` are installed on `ASStructValue` once (using `class_replaceMethod`) during the first struct install. A flag ensures this is done only once.

### R7 — Tests

**Unit / parser tests** (new `ASBridgeSupportStructTests.m` or extend existing):
- Parser produces correct `ASBridgeSupportStruct` and `ASBridgeSupportStructField` objects for a simple struct element (e.g. CGSize).
- Parser handles nested struct fields (e.g. CGRect containing CGPoint and CGSize).
- Parser stores zero-field structs (opaque) in the document.
- `_NSRange` imported name is mapped to canonical name `NSRange`.
- `ASBridgeSupportDocument.structNamed:` returns correct struct / nil for missing.

**Integration / accessor tests** (extend `ASBridgeSupportInstallerTests.m` or new file):
- After installing a document containing CGSize, sending `.width` and `.height` to an `ASStructValue` wrapping an `NSSize` returns the correct `NSNumber` values.
- `.x` and `.y` work on an `ASStructValue` wrapping `NSPoint`.
- `.origin` on an `ASStructValue` wrapping `NSRect` returns an `ASStructValue`; chaining `.x` on the result returns the correct value.
- `.size` on an `ASStructValue` wrapping `NSRect` returns an `ASStructValue`; chaining `.width` returns the correct value.
- `.location` and `.length` work on an `ASStructValue` wrapping `NSRange`.
- `-asNSValue` on an `ASStructValue` wrapping `NSSize` returns an `NSValue` with the correct `objCType` and bytes.
