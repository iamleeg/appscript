---
name: run-tests
description: Use this skill to correctly run integration tests and unit tests
license: AGPL-3.0-or-later
user-invokable: true
---
# AppScript test-runner skill

This skill provides scripts to run the unit tests and integration tests for this project. You must **always** run these scripts to get the results of tests; don't create other commands.

After each xcodebuild run, the scripts print one line with the passed, failed, skipped and total counts read from the run's result bundle, and the name and message of each failed test. The bundles are kept in `AppScript/TestResults/` (named `unit-`, `unit-asan-`, `unit-tsan-` or `integration-` plus the UTC time), the newest 3 of each kind, so you can inspect a run afterwards with `xcrun xcresulttool get test-results tests --path <bundle>`. The exit status is non-zero if any phase fails: xcodebuild, the bundle summary, or the GNUstep `make check`.

These scripts run _all_ of the tests of the specified type. Run all tests when you make a change (both unit tests and integration tests), so you can check for unexpected regressions in behavior.

The tests are designed to run with the appscript source folder as current working directory. If you're working in a project that contains `appscript` as a submodule, you need to change to that folder.

```bash
% PWD
/home/user/src/asu/appscript # You can run the script

% PWD
/home/user/src/asu # Change directory first
% cd appscript # You can run the script
```

## Run the unit tests

Run the script at `scripts/unit-tests.sh`, relative to the base directory for this skill.

Run the script with no arguments to use the default test configuration (no runtime sanitizers).
This builds and runs the tests with xcodebuild, which must compile, run every test and pass. Then, if GNUstep is installed, it runs them with GNUstep make as well, and those must pass too. AppScript is macOS-first: when GNUstep isn't installed, the script prints `GNUstep: SKIPPED` and the reason, and doesn't fail. You can go ahead without GNUstep, but still aim not to break GNUstep compatibility.

The script uses `GNUSTEP_MAKEFILES` if it's set, and `/Library/GNUstep/Makefiles` if it isn't. GNUstep counts as installed when `common.make` is in that directory.

Run the script with a single argument that's a configuration name to use that test configuration instead; this just uses xcodebuild (no need to additionally use GNUstep for the alternate configurations). The test configurations are:

- `ASan`: Run with the Address Sanitizer enabled.
- `TSan`: Run with the Thread Sanitizer enabled.

It's **critical** that the project never contains any address or thread sanitizer issues.

## Run the integration tests

Run the script at `scripts/integration-tests.sh`, relative to the base directory for this skill. It's **critical** that there are no regressions in integration tests, even when you make low-level changes that don't result in new integration tests.
