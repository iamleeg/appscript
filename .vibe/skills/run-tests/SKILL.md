---
name: run-tests
description: Use this skill to correctly run integration tests and unit tests
license: AGPL-3.0-or-later
user-invokable: true
---
# AppScript test-runner skill

This skill provides scripts to run the unit tests and integration tests for this project. You must **always** run these scripts to get the results of tests; don't create other commands.

These scripts run _all_ of the tests of the specified type. It's always good practice to run all tests when you make a change, so you can check for unexpected regressions in behavior.

## Run the unit tests

Run the script at `scripts/unit-tests.sh`, relative to the base directory for this skill.

Run the script with no arguments to use the default test configuration (no runtime sanitizers). Run the script with a single argument that's a configuration name to use that test configuration instead. The test configurations are:

- `ASan`: Run with the Address Sanitizer enabled.
- `TSan`: Run with the Thread Sanitizer enabled.

It's **critical** that the project never contains any address or thread sanitizer issues.

## Run the integration tests

Run the script at `scripts/integration-tests.sh`, relative to the base directory for this skill.
