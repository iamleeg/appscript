# configure change rules

Identifier: configure-change-rules

Primary Actor: App Developer
Supporting Actors: None

## Relationships

- Used by: assess-change-risk

## Preconditions

- The App Developer is integrating this feature into their application.

## Main Success Scenario

1. App Developer reviews the default change rules provided with the feature.
2. App Developer adjusts the rules for what is low and high risk in their application.
3. App Developer releases the application with those rules.
4. The application enforces those rules whenever a change is assessed.

## Extensions

2a. The App Developer doesn't change the rules:
1. The application uses the defaults.

## Postconditions

- The application has rules that the Citizen Developer and Analyst can't change.

## Open Questions

- Can the rules reclassify crash fixes and experiments, or are those always low risk?
