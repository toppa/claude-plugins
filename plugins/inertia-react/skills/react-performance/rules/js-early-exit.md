---
title: Early Return from Functions
impact: LOW-MEDIUM
impactDescription: stops work once the answer is known, and reports the first cause
tags: javascript, functions, optimization, early-return
---

## Early Return from Functions

Return as soon as the answer is known:

```typescript
function validateUsers(users: User[]) {
  for (const user of users) {
    if (!user.email) {
      return { valid: false, error: 'Email required' }
    }
    if (!user.name) {
      return { valid: false, error: 'Name required' }
    }
  }

  return { valid: true }
}
```

The alternative — a `hasError` flag and an `errorMessage` variable assigned inside the loop, read
after it — keeps walking the list after the answer is settled. The saving from stopping is real but
usually small, because a validation loop is short.

**The reason to prefer the early return is that the flag version reports the wrong error.** Each
assignment overwrites the last, so the message you surface is the *final* failure encountered, not
the first — and with a `users` array the user sees a complaint about a row they cannot identify.
The early return makes the reported cause and the stopping point the same thing.

Two related rules cover the async version of the same idea: `rules/async-defer-await.md` for moving
an `await` past a guard, and `rules/async-cheap-condition-before-await.md` for testing a
synchronous condition before awaiting anything.
