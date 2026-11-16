#!/bin/sh
# Runs the AppScript harness (integration) tests and prints counts from the result bundle
# (kept in AppScript/TestResults). Exit status is non-zero if the run fails.

DIR=$(dirname "$0")
RESULTS=AppScript/TestResults
BUNDLE="$RESULTS/integration-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
STATUS=0
mkdir -p "$RESULTS"

xcodebuild -project AppScript/AppScript.xcodeproj -scheme AppScriptHarness -resultBundlePath "$BUNDLE" test || STATUS=1
sh "$DIR/summarise-xcresult.sh" "$BUNDLE" || STATUS=1

exit $STATUS
