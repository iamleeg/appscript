# specify desired behaviour

Identifier: specify-desired-behaviour

Primary Actor: Citizen Developer
Supporting Actors: Analyst

## Relationships

- Included by: prototype-new-capability, specify-and-request-change
- Used by: recover-from-failure (when a problem must be reported)

## Preconditions

- The Citizen Developer has described something they want, or a problem they want resolved.
- The Analyst is available.

## Main Success Scenario

1. Citizen Developer says what they want in their own words.
2. Analyst drafts given-when-then behaviour statements and presents them in plain language.
3. Analyst asks about anything ambiguous or missing.
4. Citizen Developer answers and corrects the statements.
5. Steps 2 to 4 repeat until Citizen Developer and Analyst agree the statements are clear.
6. System stores the statements so that they can be used for analysis and linked to any resulting patch.

## Extensions

3a. The Citizen Developer doesn't know the answer:
1. Analyst records it as an open question in the statements, and the scenario continues.

5a. Agreement isn't reached:
1. System keeps the statements so far, marks them as incomplete and returns them to the calling use case.

## Postconditions

- Behaviour statements describe what the Citizen Developer wants as clearly as possible, along with any open questions.
