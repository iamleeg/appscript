# adjust existing layout

Identifier: adjust-existing-layout

Primary Actor: Citizen Developer
Supporting Actors: Analyst

## Relationships

- Includes: assess-change-risk
- May lead to: submit-feedback, specify-and-request-change

## Preconditions

- The application is running, and the Analyst is available.
- The Citizen Developer wants a small change to the layout of existing user interface, such as centring some text.

## Main Success Scenario

1. Citizen Developer describes the change they want.
2. System carries out assess-change-risk, which finds that the change is a low-risk layout tweak.
3. Analyst generates a patch.
4. System applies the patch in place, without using the Experiments Area.
5. Citizen Developer sees the change in the existing user interface and accepts it.
6. System offers to prepare a feedback report containing the change (see submit-feedback).

## Extensions

2a. The change is more than a layout tweak:
1. If it adds new user interface, the use case continues as prototype-new-capability.
2. If it's high risk, the use case continues as specify-and-request-change.

5a. The result isn't what the Citizen Developer wanted:
1. Citizen Developer describes a refinement, and the scenario continues at step 3.

5b. The Citizen Developer rejects the change:
1. System removes the patch, and the use case ends.

## Postconditions

- The accepted change applies wherever that user interface is used.
- The patch is listed in the patch browser, and generated code can be identified as generated.

## Open Questions

- Is a behaviour statement needed for a layout tweak, so that it can be re-evaluated after an update?
- Does in-place layout carry "under construction" styling? This use case assumes not, because that styling is for generated new user interface.
