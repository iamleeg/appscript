# submit feedback

Identifier: submit-feedback

Primary Actor: Citizen Developer
Supporting Actors: Analyst, Product Team, the App Developer's reporting channel

## Relationships

- Included by: specify-and-request-change
- Follows: recover-from-failure, prototype-new-capability, adjust-existing-layout
- Leads to: act-on-feedback

## Preconditions

- The Citizen Developer has a problem, patch, experiment or change request to report.

## Main Success Scenario

1. Analyst drafts a feedback report with the Citizen Developer, covering what they were trying to do, what happened, and any behaviour statements and patch.
2. Analyst advises where the report isn't clear or actionable, and Citizen Developer refines it.
3. System tells the Citizen Developer how many patches their copy already contains, and asks whether to include them.
4. System shows the Citizen Developer exactly what will be sent.
5. Citizen Developer removes anything they don't want to send, and confirms.
6. System passes the report to the App Developer's reporting channel.
7. System shows in the patch browser that the patch and its behaviour statements have been sent.

## Extensions

3a. The Citizen Developer chooses not to include their existing patches:
1. System states in the report that the copy contains patches that weren't included. The Citizen Developer can't remove this statement if they send the report.

5a. The Citizen Developer decides not to send the report:
1. System sends nothing, and any local patch stays installed. The Product Team doesn't learn about the patch.

6a. The report can't be sent:
1. System tells the Citizen Developer and keeps the report so they can try again.

## Postconditions

- The Product Team has received only what the Citizen Developer chose to send, or nothing if they chose not to send.
- Any report from a modified copy states that the copy has been modified.
- How the report is delivered, and any follow-up such as a task ID or questions from the team, is left to the App Developer's integration.
