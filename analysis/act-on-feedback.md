# act on feedback

Identifier: act-on-feedback

Primary Actor: Product Team
Supporting Actors: Citizen Developer

## Relationships

- Follows: submit-feedback
- Leads to: reevaluate-patches-after-update

## Preconditions

- The Product Team has received a feedback report.

## Main Success Scenario

1. Product Team reads the report, including any behaviour statements, patch and prototype design.
2. Product Team investigates the impact of the problem and any proposed change across the product.
3. Product Team treats the content as one person's view and clarifies it with other stakeholders where necessary.
4. Product Team builds a robust solution, upstreaming any submitted experiment and its dataset design where appropriate.
5. Product Team issues an update.

## Extensions

1a. The report comes from a copy with patches that weren't included:
1. Product Team takes that into account during investigation, and may ask the Citizen Developer for more information through its own channels.

2a. The change would affect other stakeholders, or raises security, compliance or complexity concerns:
1. Product Team involves the relevant people and works with the Citizen Developer to clarify the need.

2b. Product Team decides not to make the change:
1. The Citizen Developer's local patch stays in their copy, subject to reevaluate-patches-after-update.

## Postconditions

- The problem or request has been considered across the product.
- Any resulting update reaches every Citizen Developer, and re-evaluation of existing patches begins.
- Any response to the Citizen Developer, such as a task ID or questions, is left to the App Developer's integration.
