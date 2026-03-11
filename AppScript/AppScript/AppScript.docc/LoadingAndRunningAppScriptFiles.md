# Loading and Running AppScript Files

Embed the AppScript framework in your app and execute scripts at runtime.

## Overview

The AppScript runtime follows a four-phase pipeline:

1. **Load** — discover `.appscript` files in a bundle and read their source text.
2. **Lex and parse** — `ASLexer` tokenizes the source, then `ASParser` builds an abstract syntax tree.
3. **Install** — `ASRuntimeInstaller` registers new Objective-C classes and installs method implementations backed by the interpreter.
4. **Invoke** — the host application instantiates and calls AppScript-defined classes through the normal Objective-C messaging system.

## Loading scripts from a bundle

Call `-[NSBundle loadAppScriptsInBundle:]` once per bundle. The method finds all `.appscript` files, lexes and parses them, and installs every class and category definition it finds:

```objc
NSError *error = nil;
if (![[NSBundle mainBundle] loadAppScriptsInBundle:&error]) {
    NSLog(@"Failed to load scripts: %@", error);
}
```

Calling this method a second time on the same bundle returns `NO` and populates the error parameter.

## Invoking AppScript-defined classes

Once a bundle is loaded, AppScript classes are first-class Objective-C classes. Instantiate and call them exactly as you would any other class:

```objc
Class myClass = NSClassFromString(@"MyFeatureTest");
id instance = [myClass new];
id result = [instance runTests];
NSLog(@"%@", [result description]);
```

## Error handling

If the interpreter encounters a runtime error, it prints the AppScript file path and line number to `stderr` and calls `abort()`. If your app encounters an error in `-[NSBundle loadAppScriptsInBundle:]`, present it to the user and avoid calling code that you implement in AppScript.
