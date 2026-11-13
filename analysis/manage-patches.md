# manage patches

Identifier: manage-patches

Primary Actor: Citizen Developer
Supporting Actors: Analyst

## Relationships

- Extended by: reevaluate-patches-after-update
- May lead to: submit-feedback

## Preconditions

- The application is running.

## Main Success Scenario

1. Citizen Developer opens the patch browser.
2. System lists each patch in the application with a plain-language description, its status, its linked behaviour statements where they exist, and whether it has been sent to the Product Team.
3. Citizen Developer selects a patch and chooses to enable or disable it.
4. System makes the change and shows the new status.

## Extensions

2a. There are no patches:
1. System says this copy is unmodified.

3a. The Citizen Developer removes an experiment:
1. System removes it from the Experiments Area and the list.

3b. The Citizen Developer wants to report a patch:
1. The use case continues as submit-feedback.

3c. The Citizen Developer wants to change a patch:
1. If the Analyst is available, it refines the patch with the Citizen Developer.
2. System updates the patch and its linked behaviour statements.

4a. The application can't apply the change until it restarts:
1. System tells the Citizen Developer and applies the change on restart.

## Postconditions

- The application is running with the patches the Citizen Developer has enabled.
- The patch browser accurately shows what's in this copy.

## Open Questions

- Can other patches depend on one being disabled, and what should the Citizen Developer see if they do?
- Crash patches may have no behaviour statements. What does the browser show for them?
