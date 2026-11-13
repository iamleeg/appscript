# specify and request change

Identifier: specify-and-request-change

Primary Actor: Citizen Developer
Supporting Actors: Analyst, Product Team

## Relationships

- Includes: specify-desired-behaviour, submit-feedback
- Extends: prototype-new-capability, adjust-existing-layout

## Preconditions

- The application is running, and the Analyst is available.
- The Citizen Developer's change has been assessed as high risk, or they've chosen not to install a local patch.

## Main Success Scenario

1. System explains that this change will be requested from the Product Team, not installed locally, and why.
2. System carries out specify-desired-behaviour to produce clear behaviour statements.
3. Analyst helps the Citizen Developer record the risks, stakeholders and other information the Product Team will need.
4. System carries out submit-feedback with the resulting change request.

## Extensions

1a. The Citizen Developer disagrees with a high-risk assessment:
1. System explains that the assessment can't be overridden to get a local patch.
2. Citizen Developer continues with the request or ends the use case.

1b. The real need is a conversation with other people, such as agreeing cost impact with a finance team:
1. Analyst helps the Citizen Developer describe the need and what they've learned.
2. The feedback report asks the Product Team to involve those people.

## Postconditions

- No change has been installed locally by this use case.
- The Citizen Developer has clear statements of what they want, and a report if they chose to send one.

## Open Questions

- If a request can't be built as an experiment, such as one needing an integration, can it still include a non-functional design?
