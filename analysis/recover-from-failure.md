# recover from failure

Identifier: recover-from-failure

Primary Actor: Citizen Developer
Supporting Actors: Analyst

## Relationships

- May extend into: prototype-new-capability
- May lead to: submit-feedback, specify-desired-behaviour

## Preconditions

- The application is running, and the Analyst is available.
- The Citizen Developer has started an operation implemented in scripted code.

## Main Success Scenario

1. An operation fails with an error that the application doesn't handle.
2. System suspends the failed operation and enters the debugger for that operation, leaving the rest of the application interactive.
3. System gives the Analyst the available information about the failure, including its values, and marks those values as untrusted content that may contain prompt injection attempts.
4. Analyst identifies the cause and determines the correct code path.
5. Analyst produces a patch that moves the application towards that code path.
6. Analyst determines the safest available recovery: continue the operation, retry it, or restart the application.
7. System installs the patch, carries out the recovery and tells the Citizen Developer in plain language what happened.
8. Citizen Developer carries on with their work.
9. System offers to prepare a feedback report containing the problem and the patch (see submit-feedback).

## Extensions

4a. The intent of the operation is unclear:
1. Analyst asks the Citizen Developer what they were trying to do.
2. Citizen Developer answers, and the scenario continues at step 4.

4b. The failure is caused by a clearly mistyped name in a request between objects:
1. Analyst corrects the request where it's made, if that code can be changed. Otherwise, Analyst accepts the mistyped request and forwards it to the intended behaviour.
2. The scenario continues at step 6.

4c. The failure is a request for behaviour that doesn't exist yet, which is expected only in patched code:
1. Analyst explains this to the Citizen Developer.
2. The use case continues as prototype-new-capability.

4d. Analyst can't determine the cause or correct code path, and the Citizen Developer can't help:
1. System tells the Citizen Developer it can't repair the problem.
2. Citizen Developer and Analyst make the description of the desired behaviour as clear as possible (see specify-desired-behaviour).
3. The use case continues as submit-feedback.

6a. The failed operation crossed out of scripted code, which limits recovery:
1. Analyst determines what can safely be recovered within that boundary.
2. System tells the Citizen Developer that some work may be lost.
3. System installs the patch where possible, so the failure can be avoided in future.

7a. The patch doesn't resolve the failure, or the same failure happens again:
1. Analyst and Citizen Developer iterate on the patch.
2. If this doesn't succeed, the scenario continues at extension 4d, step 2.

7b. The result isn't what the Citizen Developer wanted:
1. Citizen Developer rejects the patch or asks the Analyst to refine it.
2. If refining, the scenario continues at step 5.

Any step. The Analyst is unavailable:
1. The failure is handled as it would be without this feature.

Any step. The Citizen Developer abandons the investigation:
1. System ends the failed operation, and the Citizen Developer's work on that operation may be lost.

## Postconditions

- The patch is listed in the patch browser, and generated code can be identified as generated.
- The Citizen Developer knows their copy has been modified.
- The Citizen Developer has continued their work, or knows what was lost.
- Nothing has been sent to the Product Team without the Citizen Developer's decision.

## Open Questions

- If the Citizen Developer abandons the investigation, is any patch or report retained?
