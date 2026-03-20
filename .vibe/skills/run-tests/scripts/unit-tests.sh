#!/bin/sh

if [ $# -eq 0 ]; then
    xcodebuild -project AppScript/AppScript.xcodeproj -scheme AppScript test
	cd AppScript && make check
else
    xcodebuild -project AppScript/AppScript.xcodeproj -scheme AppScript -testPlan AppScript -only-test-configuration $1 test
fi
