#!/bin/sh
# Runs the AppScript unit tests and prints counts from each result bundle (kept in AppScript/TestResults).
# No argument: xcodebuild, then GNUstep make check. One argument (ASan or TSan): that configuration.
# Exit status is non-zero if any phase fails.

DIR=$(dirname "$0")
RESULTS=AppScript/TestResults
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
STATUS=0
mkdir -p "$RESULTS"

run() { # run <kind> <xcodebuild arguments...>
    KIND=$1; shift
    BUNDLE="$RESULTS/$KIND-$STAMP.xcresult"
    xcodebuild "$@" -resultBundlePath "$BUNDLE" test || STATUS=1
    sh "$DIR/summarise-xcresult.sh" "$BUNDLE" || STATUS=1
}

if [ $# -eq 0 ]; then
    run unit -project AppScript/AppScript.xcodeproj -scheme AppScript
    # GNUstep is tested when it's installed, and skipped (not failed) when it isn't (ADR 38).
    GNUSTEP_MAKEFILES=${GNUSTEP_MAKEFILES:-/Library/GNUstep/Makefiles}
    if [ -f "$GNUSTEP_MAKEFILES/common.make" ]; then
        export GNUSTEP_MAKEFILES
        (cd AppScript && make check) || STATUS=1
    else
        echo "GNUstep: SKIPPED (no common.make in $GNUSTEP_MAKEFILES; GNUstep isn't installed)"
    fi
else
    CONFIG=$(echo "$1" | tr 'A-Z' 'a-z')
    run "unit-$CONFIG" -project AppScript/AppScript.xcodeproj -scheme AppScript -testPlan AppScript -only-test-configuration "$1"
fi

exit $STATUS
