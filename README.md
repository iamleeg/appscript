# AppScript

> "Objective-C without the C"

AppScript is an interpreted scripting language embedded in macOS applications. It lets you iterate rapidly on Objective-C code — defining classes, sending messages, and wiring up Cocoa — without a compile-link-run cycle. Scripts are written in a syntax familiar to any Objective-C developer, loaded at runtime as a framework, and executed with full access to the host application's classes.

## What it looks like

```appscript
@class Greeter : NSObject

- greetingForName: name {
    id upper = [name uppercaseString]
    return [upper stringByAppendingString: @"!"]
}

@end
```

That defines a real Objective-C class. Once the bundle is loaded, the host application instantiates it and calls it normally:

```objc
Class cls = NSClassFromString(@"Greeter");
id greeter = [cls new];
NSLog(@"%@", [greeter greetingForName:@"world"]); // WORLD!
```

## Language features

- **All-object model**: every value is an `id`. Numbers, booleans, and geometry structs are automatically boxed and unboxed.
- **Objective-C message syntax**: `[receiver keyword:arg]`, multi-keyword messages, `super`, blocks — all work as expected.
- **Classes and categories**: define new subclasses or extend existing Objective-C classes with `@class` / `@category` / `@end`.
- **Properties**: `@property` with the usual modifiers (`strong`, `weak`, `copy`, `readonly`, …); accessors are synthesised automatically.
- **Blocks**: zero- to four-parameter blocks with lexical capture of `self` and surrounding variables.
- **BridgeSupport integration**: call C functions and read C constants from any framework by loading its BridgeSupport metadata once, then messaging the `AS<FrameworkName>` proxy class.
- **No C escapes**: no raw pointers, no `#import`, no operator overloading. Every operation is a message send.

For the full language reference, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Embedding AppScript in your app

### 1. Add the framework

Add `AppScript.xcodeproj` to your Xcode workspace and link `AppScript.framework` to your target.

### 2. Load scripts

Call `-[NSBundle loadScriptsWithError:]` once before you need to use any AppScript-defined classes:

```objc
#import <AppScript/AppScript.h>

NSError *error = nil;
if (![[NSBundle mainBundle] loadScriptsWithError:&error]) {
    NSLog(@"Script load failed: %@", error);
    abort();
}
```

The method discovers all `.appscript` files in the bundle, parses them, and registers the classes they define in the Objective-C runtime.

### 3. Optionally load BridgeSupport

If your scripts call C functions or constants from a system framework, load the framework's BridgeSupport metadata before loading scripts:

```objc
#import <AppScript/NSBundle+AppScriptBridgeSupportLoading.h>

// Load Foundation's companion dylib so dlsym can find inline functions.
NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
NSURL *companionURL = [[[foundationBundle resourceURL]
                         URLByAppendingPathComponent:@"BridgeSupport"]
                         URLByAppendingPathComponent:@"Foundation.dylib"];
dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

[NSBundle loadBridgeSupportForFramework:@"Foundation"];
```

Scripts can then call `[ASFoundation NSMakeRect:0 :0 :800 :600]` and similar.

## Comparison with other scripting languages for Objective-C

Several other languages provide scripting over Objective-C or GNUstep runtimes. AppScript occupies a different position from each of them.

### Objective-Smalltalk

[Objective-Smalltalk](http://www.objective-smalltalk.com) is a full Smalltalk dialect that compiles to native Objective-C and integrates deeply with Cocoa. It is a general-purpose language suitable for building complete applications or frameworks on top of Cocoa — you can write an entire macOS app in Objective-Smalltalk and ship it. The language has its own syntax, type system, and semantics; learning it means learning Smalltalk.

AppScript is narrower in scope: it is explicitly a subset of Objective-C, not a new language. The goal is to let an Objective-C developer move a method or class into a script file without learning new idioms. AppScript is not intended for building entire applications; it is intended for rapid prototyping of Objective-C code that will eventually be rewritten in Objective-C or Swift.

### StepTalk

[StepTalk](https://github.com/nickhealthy/StepTalk) is a scripting framework for GNUstep that embeds Smalltalk as a scripting language in GNUstep applications. Like Objective-Smalltalk it is a general-purpose Smalltalk environment. StepTalk is well suited to extending GNUstep applications with user-scriptable behaviour — end users can write scripts that drive the application without touching its source code.

AppScript serves a different audience: the developer, not the end user. An AppScript script is a first-class part of the application's source code, written and maintained by the same people who write the Objective-C. The syntax is deliberately kept close to Objective-C so that reviewing, refactoring, and eventually replacing a script is as low-friction as possible.

### Summary

| | AppScript | Objective-Smalltalk | StepTalk |
|---|---|---|---|
| **Syntax** | Objective-C subset | Smalltalk | Smalltalk |
| **Primary use** | Rapid prototyping by the developer | Full application development | End-user scripting of GNUstep apps |
| **Platform** | macOS | macOS / iOS | GNUstep |
| **Intended lifespan of a script** | Temporary — migrated to ObjC/Swift | Permanent | Permanent |
| **Learning curve for ObjC developer** | Minimal | Moderate | Moderate |

## Project structure

```
ARCHITECTURE.md          AppScript language reference
CODING_STANDARDS.md      Engineering practices for contributors
AppScript/               Xcode project
  AppScript/             Framework source (runtime, parser, interpreter)
  AppScriptTests/        XCTest unit tests
  AppScriptHarness/      Integration test harness (macOS app)
  AppScript.docc/        DocC articles (framework embedding guide)
LICENSES/                Third-party licence texts
```

## Documentation

- **Language reference**: [ARCHITECTURE.md](ARCHITECTURE.md) — complete description of AppScript syntax and semantics.
- **Coding standards**: [CODING_STANDARDS.md](CODING_STANDARDS.md) — engineering practices for contributors.
- **Framework API** (DocC): build the `AppScript` scheme with *Product → Build Documentation* to browse the embedded API reference, including articles on loading scripts, defining classes, BridgeSupport integration, and runtime implementation details.

## Licence

AppScript is free software, released under the [GNU Affero General Public License v3](LICENSES/Affero-GPL-v3.txt) or later.
