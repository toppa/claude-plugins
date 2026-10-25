# Story template

A Story is a change in behavior that a person can see or use.

```markdown
As a <role>, I want <goal> so that <benefit>.

## Context

<What the implementer needs to know: the current behavior, the trigger for the
work, and links. Omit this section where the story sentence says enough.>

## Acceptance criteria

- [ ] <One behavior that someone can observe.>
- [ ] Given <precondition>, when <action>, then <result>.

## Out of scope

- <A related change that this issue does not make.>
```

## The story sentence

- **The role** is a specific role in the product, such as "an organization
  administrator", "a staff member who signs in with 2-step verification", or "a support
  agent". It is never "a user" or "a developer".
- **The goal** is what the person does or gets, in their words.
- **The benefit** is why the goal matters to that person. It names a result that the goal
  alone does not state. "So that I can see the message" restates the goal. "So that I
  know to sign in again, rather than contact support" names a benefit.

## Sections

- **Context** carries facts, not a design. A suggested approach goes here only as a
  suggestion, because the implementer chooses the implementation.
- **Out of scope** is optional. Use it where a reader would expect the issue to cover a
  related change.
