---
title: Defer Non-Critical Work with requestIdleCallback
impact: MEDIUM
impactDescription: keeps UI responsive during background tasks
tags: javascript, performance, idle, scheduling, analytics
---

## Defer Non-Critical Work with requestIdleCallback

**Impact: MEDIUM (keeps UI responsive during background tasks)**

Use `requestIdleCallback()` to schedule non-critical work during browser idle periods. This keeps the main thread free for user interactions and animations, reducing jank and improving perceived performance.

**Do the user-visible work now and schedule the bookkeeping for later:**

```typescript
function handleSelect(query: string) {
  applySelection(query)

  requestIdleCallback(() => {
    analytics.track('search', { query })
  })

  requestIdleCallback(() => {
    saveToRecentSearches(query)
  })
}
```

Each of those is work nobody is waiting for, so running it inside the handler charges its cost to
the interaction that triggered it.

**Note what the example does *not* do: fetch.** `searchItems` and `prefetchTopResults` are the
kind of thing this rule's upstream version put in the handler, and in this stack a search that hits
the server is a partial reload — `router.reload({ only: ['results'] })` — not a client-side fetch
whose scheduling you manage. Inertia gives you `processing` for the pending state. Keep
`requestIdleCallback` for work that is genuinely local and genuinely nobody's business:
telemetry, writing a preference to `localStorage`, warming a cache.

**With timeout for required work:**

```typescript
// Ensure analytics fires within 2 seconds even if browser stays busy
requestIdleCallback(
  () => analytics.track('page_view', { path: location.pathname }),
  { timeout: 2000 }
)
```

**Chunking large tasks:**

```typescript
function processLargeDataset(items: Item[]) {
  let index = 0

  function processChunk(deadline: IdleDeadline) {
    // Process items while we have idle time (aim for <50ms chunks)
    while (index < items.length && deadline.timeRemaining() > 0) {
      processItem(items[index])
      index++
    }

    // Schedule next chunk if more items remain
    if (index < items.length) {
      requestIdleCallback(processChunk)
    }
  }

  requestIdleCallback(processChunk)
}
```

**With fallback for unsupported browsers:**

```typescript
const scheduleIdleWork = window.requestIdleCallback ?? ((cb: () => void) => setTimeout(cb, 1))

scheduleIdleWork(() => {
  // Non-critical work
})
```

Detaching `window.requestIdleCallback` from `window` like that is safe — Web IDL operations on the
`Window` interface tolerate a detached receiver, so the call does not throw "Illegal invocation".
(Checked in Chrome 151: the detached call runs.) Safari is the browser that has historically lacked
it, which is what the fallback is for.

**When to use:**

- Analytics and telemetry
- Saving state to localStorage/IndexedDB
- Prefetching resources for likely next actions
- Processing non-urgent data transformations
- Lazy initialization of non-critical features

**When NOT to use:**

- User-initiated actions that need immediate feedback
- Rendering updates the user is waiting for
- Time-sensitive operations
