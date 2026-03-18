# Requirements Specification: Support loading scripts from arbitrary paths and runtime strings

## Problem Statement
The current AppScript implementation only supports loading scripts from bundled resources (via `NSBundle+AppScriptLoading`). Users need the ability to load AppScript scripts from arbitrary file paths and from runtime strings to enable use cases like user-defined scripts, plugin systems, and REPL-style development workflows.

## Requirements

### R1. Load Scripts from File Paths
The system shall provide an API to load AppScript scripts from arbitrary file paths (not limited to bundle resources).

**Details:**
- API should accept a file path (NSString) pointing to an .appscript file
- The file may be located anywhere in the filesystem
- Loading should follow the same parsing and installation process as bundle loading

### R2. Load Scripts from Runtime Strings
The system shall provide an API to load AppScript scripts from NSString/source supplied at runtime.

**Details:**
- API should accept an NSString containing AppScript source code
- The source code may be generated, user-provided, or downloaded at runtime
- Loading should follow the same parsing and installation process as bundle loading

### R3. Full Runtime Participation
Scripts loaded via the new APIs shall participate fully in the AppScript runtime.

**Details:**
- Loaded scripts can define new classes
- Loaded scripts can extend existing AppScript classes with new methods/properties
- Loaded scripts can replace existing class definitions
- All loaded scripts share the same runtime state

### R4. Error Handling
The system shall provide comprehensive error handling for script loading.

**Details:**
- Clear error messages for file not found
- Clear error messages for lexer/parser errors
- Clear error messages for runtime installation errors
- Error information should include file path and line/column where possible

### R5. Thread Safety
The system shall ensure thread-safe script loading.

**Details:**
- Multiple scripts can be loaded from different threads
- Runtime state is properly synchronized
- No race conditions in class registration

### R6. Duplicate Load Detection
The system shall detect and prevent duplicate loading of the same script.

**Details:**
- Same file path should not be loaded twice
- Same source string should not be loaded twice (if applicable)
- Clear error message when duplicate is detected

## Non-Functional Requirements

### NFR1. Performance
Script loading should be efficient and not block the main thread for extended periods.

### NFR2. Compatibility
The new API should be compatible with existing bundle-based loading.

### NFR3. Testability
All new APIs shall be thoroughly tested with unit tests.

## Use Cases

### UC1. User-Defined Scripts
A user can specify a path to an AppScript file, and the application loads and executes it.

### UC2. Plugin Systems
An application can load plugin scripts from a plugins directory at runtime.

### UC3. REPL Development
A developer can enter AppScript code in a REPL and have it immediately loaded and executed.

### UC4. Dynamic Configuration
An application can load configuration scripts from a user-specified location.
