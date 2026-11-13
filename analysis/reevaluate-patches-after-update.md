# re-evaluate patches after update

Identifier: reevaluate-patches-after-update

Primary Actor: Citizen Developer
Supporting Actors: Analyst, Product Team

## Relationships

- Extends: manage-patches
- Follows: act-on-feedback

## Preconditions

- The Product Team has issued an update, and it has been installed.
- The Citizen Developer's copy contained patches before the update.

## Main Success Scenario

1. System disables all existing patches.
2. Analyst checks whether each crash patch still applies, and uses behaviour statements to reason about whether each other patch still applies.
3. System records each patch's status in the patch browser: superseded by the update, applies cleanly, or needs changes.
4. System prompts the Citizen Developer to visit the patch browser.
5. Citizen Developer reviews the statuses and chooses which patches to reapply.
6. System reinstalls the chosen patches.

## Extensions

2a. The Analyst is unavailable:
1. System leaves the patches disabled and retries the evaluation when the Analyst is available.

3a. A patch has been superseded by the update:
1. If it's an experiment, System removes it from the Experiments Area.
2. System tells the Citizen Developer that the update replaces it.

5a. A chosen patch doesn't apply cleanly:
1. Analyst updates the patch against the new version.
2. Citizen Developer tries the result and accepts or rejects it.

5b. A patch can't be updated:
1. System keeps it disabled and tells the Citizen Developer why.
2. Citizen Developer can begin prototype-new-capability or submit-feedback.

5c. The Citizen Developer doesn't visit the patch browser:
1. Patches stay disabled, and the application continues without them.

## Postconditions

- The application is running only the patches that the Citizen Developer has chosen to reapply.
- Each patch's status for this update is recorded in the patch browser.

## Constraints

- A Citizen Developer can't refuse an update to keep their patches.

## Open Questions

- What happens to an experiment's own dataset when the experiment is disabled or superseded? This is deferred, because long-lived experiments are an edge case.
- If a disabled crash patch is still needed and the failure returns, should the system point to the old patch before starting a new investigation?
