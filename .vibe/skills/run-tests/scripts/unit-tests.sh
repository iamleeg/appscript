#!/bin/sh

if [ $# -eq 0 ]; then
    xcodebuild -project AppScript/AppScript.xcodeproj -scheme AppScript test
else
    xcodebuild -project AppScript/AppScript.xcodeproj -scheme AppScript -testPlan AppScript -only-test-configuration $1 test
fi
