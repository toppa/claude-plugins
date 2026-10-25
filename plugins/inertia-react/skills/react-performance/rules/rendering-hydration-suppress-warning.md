---
title: Suppress Expected Hydration Mismatches
impact: LOW-MEDIUM
impactDescription: avoids noisy hydration warnings for known differences
tags: rendering, hydration, ssr
---

## Suppress Expected Hydration Mismatches

This rule applies only when Inertia SSR is on. Some values are intentionally different on server vs client (random IDs, dates, locale/timezone formatting). For these *expected* mismatches, wrap the differing text — and nothing else — in an element carrying `suppressHydrationWarning`. Scope it to the one element whose text differs, so the rest of the subtree still reports a mismatch you would want to see. A warning you cannot trace to a value the server genuinely cannot know is a bug, and this attribute hides it.

**Where the value must also be visibly correct on the first paint, this is the wrong rule.** A theme read from `localStorage` is the example: suppressing the warning leaves the flicker. `rules/rendering-hydration-no-flicker.md` covers that case. Suppress only where the difference is formatting nobody sees as wrong.

**Incorrect (known mismatch warnings):**

```tsx
function Timestamp() {
  return <span>{new Date().toLocaleString()}</span>
}
```

**Correct (suppress expected mismatch only):**

```tsx
function Timestamp() {
  return (
    <span suppressHydrationWarning>
      {new Date().toLocaleString()}
    </span>
  )
}
```
