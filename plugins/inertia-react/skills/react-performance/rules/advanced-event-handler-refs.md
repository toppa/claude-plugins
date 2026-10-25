---
title: Keep a Subscription Stable When Its Handler Changes
impact: LOW
impactDescription: stable subscriptions
tags: advanced, hooks, refs, event-handlers, optimization
---

## Keep a Subscription Stable When Its Handler Changes

An effect that subscribes to something and lists a callback prop in its dependencies
re-subscribes on every render, because the callback is a new function each time. Wrap the
callback in `useEffectEvent` and leave it out of the array:

```tsx
import { useEffect, useEffectEvent } from 'react'

function useWindowEvent(event: string, handler: (e: Event) => void) {
  const onEvent = useEffectEvent(handler)

  useEffect(() => {
    window.addEventListener(event, onEvent)
    return () => window.removeEventListener(event, onEvent)
  }, [event])
}
```

`onEvent` stays out of the dependency array — see `rules/advanced-effect-event-deps.md`, whose
whole subject is that listing it there re-runs the effect on every render. `useEffectEvent`
returns a function that always calls the latest `handler`, so the subscription is created once
per `event` and the handler is never stale. It is real and stable
at the installed versions: `react` 19.2.8 exports it (`cjs/react.development.js:1227`) and
`@types/react` 19.2.17 declares it (`index.d.ts:1791`).

**The manual version is what you write when `useEffectEvent` is not available:**

```tsx
function useWindowEvent(event: string, handler: (e: Event) => void) {
  const handlerRef = useRef(handler)
  useEffect(() => {
    handlerRef.current = handler
  }, [handler])

  useEffect(() => {
    const listener = (e: Event) => handlerRef.current(e)
    window.addEventListener(event, listener)
    return () => window.removeEventListener(event, listener)
  }, [event])
}
```

It has the same effect and more moving parts: a ref, a syncing effect, and a wrapper function
whose only job is the indirection. Recognise it in existing code and leave it be; write the
`useEffectEvent` version in new code.

`rules/advanced-use-latest.md` applies the same hook to a debounce, which is the other common
shape.
