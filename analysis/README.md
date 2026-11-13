# AI-assisted debugging and application augmentation: analysis

An application built with AppScript can include an LLM that bridges the people using the application and the team building it. When scripted code fails, the LLM investigates and tries to repair the application so that the person can carry on. When the application can't do something a person wants, the LLM helps them say what they want and try a prototype. In both cases, the result can become clear, actionable feedback for the product team.

The feature is mainly for self-healing and clarifying bug reports. Long-lived experiments are an edge case.

ResearchBuddy is the test application. Its audience is intelligent but not necessarily made up of programmers.

## Actors

| Actor | Description |
|---|---|
| Citizen Developer | A person using the application who can describe what they want but isn't expected to read code. A version for programmers is out of scope. |
| Analyst | The LLM that investigates failures, helps write behaviour statements, assesses risk and produces patches. |
| Product Team | The people who build and release the application. They receive feedback and issue updates. |
| App Developer | The member of the Product Team who integrates this feature and configures its rules. |

## Terms

| Term | Meaning |
|---|---|
| Behaviour statement | A description of desired behaviour in given-when-then form, used for analysis by the Analyst and the Product Team. |
| Patch | A locally installed change to the application, produced by the Analyst. |
| Experiment | A patch that adds new user interface in the Experiments Area, optionally with its own dataset. It's a way to show the Product Team what's wanted, and is meant to be submitted for upstreaming, not kept as a permanent workaround. |
| Experiments Area | The part of the application where new generated user interface appears, making it clear that it's local and provisional. |
| Feedback report | What the Citizen Developer chooses to send to the Product Team: a problem report or change request, with any behaviour statements, patches or prototype design they include. |

## Use cases

| Identifier | Primary actor | Summary |
|---|---|---|
| [recover-from-failure](recover-from-failure.md) | Citizen Developer | A failure in scripted code is investigated and repaired so the person can carry on. |
| [prototype-new-capability](prototype-new-capability.md) | Citizen Developer | The person builds and tries something the application doesn't support. |
| [adjust-existing-layout](adjust-existing-layout.md) | Citizen Developer | The person makes a small layout change in place. |
| [specify-and-request-change](specify-and-request-change.md) | Citizen Developer | The person specifies a change and requests it from the Product Team without installing it locally. |
| [specify-desired-behaviour](specify-desired-behaviour.md) | Citizen Developer | Included use case: turn what the person wants into clear behaviour statements. |
| [assess-change-risk](assess-change-risk.md) | Analyst | Included use case: decide whether a change may be installed locally. |
| [submit-feedback](submit-feedback.md) | Citizen Developer | The person reviews and sends a feedback report. |
| [manage-patches](manage-patches.md) | Citizen Developer | The person sees and controls the patches in their copy. |
| [reevaluate-patches-after-update](reevaluate-patches-after-update.md) | Citizen Developer | Patches are checked after an update, and the person reapplies the ones still needed. |
| [configure-change-rules](configure-change-rules.md) | App Developer | The App Developer sets the rules that govern local changes. |
| [act-on-feedback](act-on-feedback.md) | Product Team | The Product Team investigates a report and issues a robust update. |

## Rules that apply across use cases

- **Risk:** crash fixes, experiments and layout tweaks are low risk and can be installed locally. Integrations, and changes to production behaviour or production data models, are high risk. A change that would be high risk in production can still be tried as an experiment, unless it needs an integration.
- **Misapplied risk assessments:** if someone prompts the Analyst into misapplying the rules, this is treated as low risk because it only affects the user's own data, which is already under their control. No further protection is required.
- **Wrong results with no failure:** these can be handled as experiments. The buggy version stays in the main application alongside a duplicate feature in the experiment until the Product Team upstreams a fix.
- **Team involvement:** the Product Team doesn't block low-risk patches and learns about them after the fact, if the Citizen Developer submits them. High-risk requests end with detailed information being passed to the team.
- **One-way choice:** a Citizen Developer can always switch from patch-and-submit to specify-and-request, but can't override a high-risk decision to get a local patch.
- **Recovery boundary:** recovery can't extend past the point where execution leaves scripted code. Within that boundary, "continue" means whatever can safely be achieved. Some work may be lost, but no more than if the application had simply crashed.
- **Generated work is identifiable:** generated user interface has "under construction" styling, and generated code can be identified as generated.
- **Modified copies are never hidden:** the Citizen Developer must not be allowed to believe their application is unmodified.
- **The user controls what is sent:** nothing goes to the Product Team until the Citizen Developer has decided to send it, and they can decline. Any report they do send states that the copy has been modified.
- **User data is untrusted:** the Analyst can see values from the failed operation, including application data, but its prompt makes clear that they may contain prompt injection attempts. Application data isn't otherwise used as prompts. The problem report conversation is an exception. These risks are accepted for the initial limited distribution.
- **No data provenance:** output produced by patched code isn't marked as such.
- **No integrations in prototypes:** guardrails stop the Analyst from writing integrations with outside services as part of a prototype.
- **Data access:** experiments use production data through the application's existing interfaces, so the person can use existing features to recover from accidents. An experiment can also have its own dataset that augments production data, contained to that experiment. To make it more widely useful, the person files a feature request so the experiment can be upstreamed into production code.
- **Missing behaviour:** the Product Team is assumed to test shipped code, so a request for behaviour that doesn't exist should only occur in patched code.

## Obligations on App Developers

These need adding to the developer documentation:

- Operations that can fail should be recoverable, rewindable or idempotent.
- The Analyst works within guardrails and guidance, but App Developers are expected to investigate each reported patch and its impact before issuing a robust update.
- App Developers integrate how feedback reports are delivered to the Product Team, along with any follow-up such as task IDs or questions from the team.

## Decisions outside the use cases

- **Model, v1:** Apple Foundation Models. The feature is unusable if they're unavailable. Bringing your own model through a local server (LM Studio, Ollama and similar) may be added later.
- **Distribution:** out of scope. The App Developer is assumed to have a mechanism compatible with deploying this feature.
- **Rollout:** the initial version has limited distribution, which is why the prompt injection risk is accepted for now.
- **Scale:** not designed for until there are customers.
- **Testing:** running behaviour statements as tests in the tool is out of scope for now, and may be explored later.
- **Report delivery and follow-up:** out of scope for this feature, and left to each App Developer's integration. The feature only shows the Citizen Developer in the patch browser that a patch and its behaviour statements have been sent.
- **Patch mechanics (intended):** a patched method calls through to a marked generated method, and generated classes and methods carry markers in their names.

## Deferred

To resolve during design or from user feedback:

- Where to intercept unrecognised messages, what extra state to capture, and the precise meaning of "continue".
- Failures on the main thread, and what the person sees when a failure keeps repeating, such as during drawing.
- Failures with no scripted frames, including native crashes.
- Whether suspended work can continue after the person changes the data it depends on.
- Whether to warn the person before they save over good work after a recovery.
- Patch dependencies, and how to describe patches in plain language.
- What happens to an experiment's own dataset if the experiment is disabled, removed or superseded.
- How prompt injection protection should change before distribution widens.
- Whether "Axminster" in the voice note refers to a real tool.
