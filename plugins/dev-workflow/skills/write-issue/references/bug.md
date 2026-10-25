# Bug template

A Bug is current behavior that is wrong. An exception that an error monitor reports is a
Bug.

```markdown
## Impact

<Who sees the bug, and what it costs them.>

## Current behavior

<What happens now.>

## Expected behavior

<What should happen.>

## Steps to reproduce

1. <Step.>
2. <Step.>

## Evidence

- <Error monitor>: <ERROR-ID>
- Events: <n>. People affected: <n>.
- First seen <date>, last seen <date>
- <The shape of any data involved.>

## Context

<Facts the implementer needs that no other section holds, such as an earlier issue for
the same symptom. Omit this section where it is empty.>

## Suspected cause

<The cause as the evidence shows it. Omit this section where nobody has a lead.>

## Acceptance criteria

- [ ] <The expected behavior, as someone can observe it.>
```

## Sections

- **Impact** stands in for the "so that" clause of a story. Name the people, as in
  "staff who refund a charge", and the cost, as in "they retry, because they never see
  the reason".
- **Steps to reproduce**: where nobody reproduced the bug, replace the steps with **"Not
  reproduced."** and a hypothesis for the trigger.
- **Evidence**: write the error monitor's id for the error as bare text, because a search
  in a tracker finds an id and not a URL. Put the error monitor's URL on the issue as
  "Create order" in `SKILL.md` says. Describe the shape of leaked data, such as "an email
  address in the message text", and quote no value.
- **Context** holds facts. A guess goes in Suspected cause.
- **Suspected cause** is optional. Label a guess as a guess.
- **Acceptance criteria** state behavior that someone can observe. A spec is how the
  implementer proves a criterion, so a spec is not a criterion.
