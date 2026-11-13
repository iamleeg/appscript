# assess change risk

Identifier: assess-change-risk

Primary Actor: Analyst
Supporting Actors: Citizen Developer

## Relationships

- Included by: prototype-new-capability, adjust-existing-layout
- Uses rules from: configure-change-rules

## Preconditions

- A Citizen Developer has requested a change.
- The application has change rules, either configured or by default.

## Main Success Scenario

1. Analyst compares the requested change with the application's rules.
2. Analyst decides whether the change is low risk.
3. System records the decision and reason, and allows the requesting use case to continue with a local patch.

## Extensions

2a. The change is high risk, for example an integration or a change to production behaviour or the production data model:
1. Analyst explains the decision in plain language.
2. If the need can be met by an experiment without an integration, System offers that through prototype-new-capability.
3. Otherwise, System doesn't allow a local patch, and the requesting use case continues as specify-and-request-change.

2b. Risk becomes apparent only partway through the work:
1. Analyst reassesses the change and explains what has changed.
2. The scenario continues at step 2.

3a. The Citizen Developer chooses specify-and-request-change for a low-risk change:
1. System allows the choice, and the use case continues as specify-and-request-change.

Any step. The Citizen Developer prompts the Analyst into misapplying the rules:
1. The resulting patch is treated as low risk, because it only affects the Citizen Developer's own data, which is already under their control.

## Postconditions

- The change has a recorded risk decision and reason.
- No change correctly assessed as high risk is installed in production code. Its need may instead be met by a contained experiment.

## Open Questions

- What happens to a prototype that's found to be high risk at 2b? Does it stay available?
