#!/bin/sh
# Prints the counts and failure messages from an xcresult bundle, then deletes older bundles of the
# same kind. Usage: summarise-xcresult.sh <bundle>, where the bundle is named <kind>-<UTC stamp>.xcresult.
# Exit status 0 only if the bundle is readable, has tests, and none failed (adr/0022).

KEEP=3
BUNDLE=$1
if [ -z "$BUNDLE" ]; then
    echo "usage: $0 <bundle.xcresult>" >&2
    exit 2
fi

python3 -I - "$BUNDLE" <<'PY'
import json, os, subprocess, sys
bundle = sys.argv[1]
name = os.path.basename(bundle)
def run(kind):
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", kind, "--path", bundle],
                         capture_output=True, text=True)
    return json.loads(out.stdout) if out.returncode == 0 and out.stdout.strip() else None
summary = run("summary") if os.path.isdir(bundle) else None
if summary is None:
    print("%s: no readable result bundle (the build may have failed before testing)" % name)
    sys.exit(1)
passed, failed = summary.get("passedTests", 0), summary.get("failedTests", 0)
skipped, total = summary.get("skippedTests", 0), summary.get("totalTestCount", 0)
print("%s: passed=%d failed=%d skipped=%d total=%d" % (name, passed, failed, skipped, total))
def messages(node):
    # A test plan with several configurations nests the failure messages under a configuration node.
    found = []
    for kid in node.get("children", []):
        if kid.get("nodeType") == "Failure Message":
            found.append(kid.get("name", ""))
        else:
            found.extend(messages(kid))
    return found
def walk(node):
    if node.get("nodeType") == "Test Case" and node.get("result") == "Failed":
        msgs = list(dict.fromkeys(messages(node)))
        print("  FAILED %s: %s" % (node.get("name", ""), " | ".join(msgs) if msgs else "(no failure message in bundle)"))
        return
    for kid in node.get("children", []):
        walk(kid)
if failed:
    for root in (run("tests") or {}).get("testNodes", []):
        walk(root)
sys.exit(0 if failed == 0 and total > 0 else 1)
PY
STATUS=$?

# Keep the newest $KEEP bundles of this kind (names sort by their UTC stamp).
DIR=$(dirname "$BUNDLE")
KIND=$(basename "$BUNDLE" | sed 's/-[0-9]\{8\}T[0-9]\{6\}Z\.xcresult$//')
ls -d "$DIR/$KIND"-[0-9]*T*Z.xcresult 2>/dev/null | sort -r | tail -n +$((KEEP + 1)) | while read -r OLD; do
    rm -rf "$OLD"
done

exit $STATUS
