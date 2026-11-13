# prototype new capability

Identifier: prototype-new-capability

Primary Actor: Citizen Developer
Supporting Actors: Analyst

## Relationships

- Includes: specify-desired-behaviour, assess-change-risk
- Extends: recover-from-failure (when a failure is a request for behaviour that doesn't exist yet)
- May lead to: specify-and-request-change, submit-feedback

## Preconditions

- The application is running, and the Analyst is available.
- The Citizen Developer wants to do something the application doesn't support, or wants a correct version of something that gives a wrong result.

## Main Success Scenario

1. Citizen Developer chooses the option for doing something the application doesn't support.
2. Citizen Developer describes what they want.
3. System carries out specify-desired-behaviour to produce behaviour statements.
4. System carries out assess-change-risk, which finds that the change can be built as an experiment.
5. Analyst generates a prototype of the capability.
6. System adds the prototype to the Experiments Area, with "under construction" styling.
7. Citizen Developer tries the prototype on their real data through the application's existing interfaces.
8. Citizen Developer asks for refinements, and Analyst updates the behaviour statements and prototype. Steps 5 to 8 repeat until the Citizen Developer is satisfied.
9. Analyst advises whether the behaviour statements are clear enough to submit.
10. Citizen Developer submits the experiment (see submit-feedback).

## Extensions

4a. The change can't be built as a contained experiment:
1. System explains why it can't be built locally.
2. The use case continues as specify-and-request-change.

4b. The Citizen Developer prefers not to build anything locally:
1. The use case continues as specify-and-request-change.

5a. The request needs an integration with an outside service:
1. Analyst explains that it can't build integrations as part of a prototype.
2. Citizen Developer changes the request, or the use case continues as specify-and-request-change.

5b. The capability needs data the application doesn't store:
1. Analyst gives the experiment its own dataset, which augments production data and is contained to that experiment.
2. System explains that making this data more widely available requires a feature request, so the Product Team can upstream the experiment.
3. The scenario continues at step 6.

5c. The Citizen Developer wants to correct a wrong result:
1. Analyst builds a duplicate of the feature in the Experiments Area that behaves as the behaviour statements describe.
2. System leaves the production feature unchanged, and explains that the experiment shows the Product Team what's needed and isn't a long-term replacement.
3. The scenario continues at step 6.

7a. The prototype sends a request for behaviour that hasn't been defined yet, such as a new button whose action hasn't been described:
1. System enters the debugger for that operation.
2. Analyst asks the Citizen Developer what should happen next.
3. The scenario continues at step 3 for the newly described behaviour.

7b. The prototype fails:
1. System handles the failure as in recover-from-failure, and the scenario continues at step 8.

7c. The prototype causes an unwanted change to the data:
1. Citizen Developer uses the application's existing features to recover.
2. The scenario continues at step 8.

8a. The Citizen Developer stops working on the prototype:
1. Citizen Developer stops using it, and it stays in the Experiments Area until they remove it or an update supersedes it.

10a. The Citizen Developer decides not to submit:
1. The experiment stays available until they remove it or an update supersedes it.

## Postconditions

- The experiment is available in the Experiments Area and listed in the patch browser, linked to its behaviour statements.
- If submitted, the experiment remains available to the Citizen Developer while the Product Team considers upstreaming it.
- Production behaviour and the production data model are unchanged.

## Open Questions

- Should the existing-interface rule be enforced, or is it guidance the Analyst follows?
