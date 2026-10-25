# Task template

A Task is technical work with no direct change for a person.

```markdown
## Why

<The reason for the work, and what it makes possible.>

## Scope

- <What the work changes.>
- <What the work does not change.>

## Acceptance criteria

- [ ] <One result that someone can check.>
```

## Sections

- **Why** stands in for the "so that" clause of a story. Name what the work unblocks or
  prevents.
- **Scope**: for a refactor, state "No change in behavior."
- **Acceptance criteria**: "The test suite passes" is a valid criterion for a Task.
- A **spike** is a Task to find an answer. Its Why names the question, and its one
  criterion is that the answer is recorded on the issue that it blocks.
- A **decision** Task has a decision as its whole deliverable. Its Why names the
  question. Its criteria are that the decision is recorded on the Task, and that any
  work the decision leads to is filed.
