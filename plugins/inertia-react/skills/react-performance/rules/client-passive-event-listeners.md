---
title: Use Passive Event Listeners for Scrolling Performance
impact: MEDIUM
impactDescription: eliminates scroll delay caused by event listeners
tags: client, event-listeners, scrolling, performance, touch, wheel
---

## Use Passive Event Listeners for Scrolling Performance

Pass `{ passive: true }` when you attach a `touchstart`, `touchmove`, `wheel` or `mousewheel`
listener to a **scroll container**. The browser otherwise has to wait for the listener to
return before it knows whether `preventDefault()` was called, which delays the scroll.

```typescript
useEffect(() => {
  const list = listRef.current
  if (!list) return

  const handleWheel = (event: WheelEvent) => track(event.deltaY)
  list.addEventListener('wheel', handleWheel, { passive: true })

  return () => list.removeEventListener('wheel', handleWheel)
}, [])
```

**On `window`, `document`, `<html>` and `<body>` these events are already passive**, so
adding the option there changes nothing. The DOM standard's "default passive value" algorithm
returns true for exactly those four event types when the target is one of those four nodes. A
listener on a `div` you scroll — a message list, a virtualised table, a canvas — is the case
where the option matters.

**Do not pass it when the listener needs `preventDefault()`**: a custom swipe gesture, a
pinch-zoom control, a wheel handler that zooms instead of scrolling. Calling
`preventDefault()` inside a passive listener is ignored and logs a console warning, so the
gesture silently stops working.

Note the removal call takes no options — the options object is matched on `capture` only, so
`removeEventListener(type, fn)` removes a listener added with `{ passive: true }`.
