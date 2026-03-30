# AppScript

> "Objective-C without the C"

AppScript is an interpreted scripting language embedded in macOS applications. It lets you and your coding assistant iterate rapidly on Objective-C code. You write scripts in a language that's very similar to a subset of the Objective-C language, but that doesn't include primitive types or bare pointers—making it safer and easier to get to working software.

## What it looks like

```appscript
@class Greeter : NSObject

- greetingForName: name {
    id upper = [name uppercaseString]
    return [upper stringByAppendingString: @"!"]
}

@end
```

That defines a real Objective-C class. You can call it normally from within AppScript, and even grab a reference to the class from within Objective-C:

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
- **Blocks**: code blocks with lexical capture of `self` and surrounding variables.
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

## Project goals

AppScript has two intended audiences:

1. Objective-C developers who want to quickly iterate on ideas using a simple but powerful subset of the language. You can distribute apps written wholly or partially in AppScript, or incrementally port to Objective-C. **Note**: to distribute an app on macOS, you should copy your AppScript to the app bundle and ensure you sign your app.
2. Citizen developers who want to access the power of Cocoa without having to learn all of C's sharp edges.

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
