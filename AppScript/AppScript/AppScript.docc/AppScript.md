# ``AppScript``

An interpreted scripting language embedded in macOS applications, offering Objective-C syntax without the C.

## Overview

AppScript lets you embed a safe, memory-managed scripting runtime in any macOS app or command-line tool. Scripts are written in a simplified subset of Objective-C, compiled to an AST at load time, and executed by the interpreter with full access to the host application's Objective-C classes.

## Topics

### Loading and running scripts

- <doc:LoadingAndRunningAppScriptFiles>

### Defining classes and categories

- <doc:DefiningClassesAndCategories>
- ``ASClassDefinitionNode``
- ``ASCategoryDefinitionNode``
- ``ASRuntimeInstaller``

### Control flow and arithmetic

- <doc:ControlFlowAndArithmetic>

### Accessing C APIs via BridgeSupport

- <doc:BridgeSupportIntegration>

### Foundation bridges

- ``NSString``
- ``NSURL``

### Runtime support

- ``ASInterpreter``
- ``ASScope``
- ``ASBoxer``
- ``ASNull``


