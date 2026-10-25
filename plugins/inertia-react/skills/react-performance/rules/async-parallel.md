---
title: Promise.all() for Independent Operations
impact: CRITICAL
impactDescription: turns three sequential waits into one
tags: async, parallelization, promises, waterfalls
---

## Promise.all() for Independent Operations

When async operations have no interdependencies, start them all and await them together:

```typescript
const [user, posts, comments] = await Promise.all([
  fetchUser(),
  fetchPosts(),
  fetchComments()
])
```

Written as three consecutive `await`s, each request waits for the one before it, so the
total is the sum of the three latencies. `Promise.all` starts all three at once, so the
total is the slowest of the three.

**It is the same number of round trips either way** — three requests are three round trips.
What changes is wall-clock time. The saving is therefore bounded by the slowest call: three
100 ms calls go from ~300 ms to ~100 ms, while one 500 ms call alongside two 20 ms calls
saves almost nothing.

`Promise.all` rejects as soon as any input rejects, and the others keep running unobserved.
Use `Promise.allSettled` when a partial result is still useful.

When a guard on the first value usually short-circuits and makes the second call unnecessary,
`rules/async-defer-await.md` governs instead. The boundary between the two rules is whether the
second call is usually needed.
