---
title: Narrow Effect Dependencies
impact: LOW
impactDescription: minimizes effect re-runs
tags: rerender, useEffect, dependencies, optimization
---

## Narrow Effect Dependencies

Specify primitive dependencies instead of objects to minimize effect re-runs.

**Incorrect (re-runs on any user field change):**

```tsx
useEffect(() => {
  console.log(user.id)
}, [user])
```

**Correct (re-runs only when id changes):**

```tsx
useEffect(() => {
  console.log(user.id)
}, [user.id])
```

The mechanism is that React compares dependencies with `Object.is`, so an object recreated each
render is never equal to the previous one even when its contents are identical. A primitive read out
of it is.

**Narrow a threshold to the boolean too**, so the effect re-runs on the transition rather than on
every value that satisfies it:

```tsx
const isMobile = width < 768
useEffect(() => {
  if (isMobile) enableMobileMode()
}, [isMobile])
```

With `[width]` this effect runs at 767, 766, 765 and so on; with `[isMobile]` it runs once, when the
threshold is crossed.

`rules/rerender-derived-state.md` is the same idea one level up — stop the *component* subscribing to
the continuous value at all, by subscribing to a media query instead of a width. Prefer that where it
applies; narrow the dependency array when you are stuck with the continuous value.
