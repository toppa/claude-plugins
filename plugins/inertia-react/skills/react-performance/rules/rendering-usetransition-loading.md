---
title: Use useTransition Over Manual Loading States
impact: LOW
impactDescription: one pending flag instead of a hand-managed boolean
tags: rendering, transitions, useTransition, loading, state
---

## Use useTransition Over Manual Loading States

`useTransition` gives you an `isPending` flag that React owns, so there is no
`setIsLoading(true)`/`setIsLoading(false)` pair to keep balanced across every early return
and every throw.

**First: in this stack, most loading states are Inertia's.** A form gives you `processing`
from `<Form>` or `useForm`; a visit gives you `router` progress; deferred props give you
`{ reloading }` from `<Deferred>`. Reach for `useTransition` for a *client-side* expensive
update — filtering a list you already hold, switching a heavy tab — not for a request.

**The update you want deferred has to be inside the transition function:**

```tsx
import { useState, useTransition } from 'react'

function TabPanel({ items }: { items: Item[] }) {
  const [tab, setTab] = useState('all')
  const [isPending, startTransition] = useTransition()

  const selectTab = (next: string) => {
    startTransition(() => {
      setTab(next)
    })
  }

  return (
    <>
      <TabBar onSelect={selectTab} />
      <div style={{ opacity: isPending ? 0.7 : 1 }}>
        <ExpensiveList items={items} tab={tab} />
      </div>
    </>
  )
}
```

**`await` inside `startTransition` ends the transition.** react.dev is explicit: "When you
use `await` inside a `startTransition` function, the state updates that happen after the
`await` are not marked as Transitions." So this shape does not do what it looks like it
does:

```tsx
startTransition(async () => {
  const data = await fetchResults(value)
  setResults(data)          // not in a transition
})
```

If you do need an async step, nest a second `startTransition` around the post-`await`
update.

**What `isPending` does and does not promise:**

- It is true while React is rendering the transition, and it resets even if the transition
  throws. That is the real win over a hand-managed boolean.
- **A new transition does not cancel an in-flight one's side effects.** react.dev: a
  Transition "will be interrupted by other state updates … React will restart the rendering
  work." Rendering restarts; a fetch already in flight keeps going, and an earlier
  `setResults` still lands. If you are racing requests, you still need your own
  last-write-wins guard — or let Inertia do it: a non-`async` visit calls
  `interruptInFlight()` on a request stream configured `maxConcurrent: 1,
  interruptible: true`, so the previous visit's request is cancelled rather than raced.

Reference: [useTransition](https://react.dev/reference/react/useTransition)
