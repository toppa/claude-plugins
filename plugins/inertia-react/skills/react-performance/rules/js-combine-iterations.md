---
title: Combine Multiple Array Iterations
impact: LOW-MEDIUM
impactDescription: three passes become one, at the cost of three declarative filters
tags: javascript, arrays, loops, performance
---

## Combine Multiple Array Iterations

Three `.filter()` calls over the same array walk it three times. When the array is large enough
for that to matter, do it in one pass:

```typescript
const admins: User[] = []
const testers: User[] = []
const inactive: User[] = []

for (const user of users) {
  if (user.isAdmin) admins.push(user)
  if (user.isTester) testers.push(user)
  if (!user.isActive) inactive.push(user)
}
```

**Know what you are trading.** The saving is a constant factor — three passes to one, so at best
it removes two thirds of the traversal, and traversal is rarely where the time goes. What you give
up is three self-describing expressions, replaced by a loop whose output is three
separately-declared mutable arrays. That is a real readability cost and it is why this rule is
`LOW-MEDIUM` rather than higher.

Apply it when the array is long and the code is on a hot path — a list you re-derive on every
keystroke. Leave the three filters alone for a list of a few dozen rows rendered once per visit.
If the categories are what you actually want, `Object.groupBy` says so more directly, and needs
`lib: ES2024`. `rules/js-tosorted-immutable.md` makes the same point for ES2023 and states the
premise both share: where `tsconfig.app.json` sets `lib` below the version a method needs, such as
ES2020, raising `lib` is a project decision.
