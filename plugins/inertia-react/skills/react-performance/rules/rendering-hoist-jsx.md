---
title: Hoist Static JSX Elements
impact: LOW
impactDescription: reuses one element object instead of allocating per render
tags: rendering, jsx, static, optimization
---

## Hoist Static JSX Elements

When a piece of JSX takes no props and closes over nothing, build the element once at module scope
and reference it:

```tsx
const SPINNER = (
  <svg className="animate-spin" width="24" height="24" viewBox="0 0 24 24" aria-hidden="true">
    <circle cx="12" cy="12" r="10" stroke="currentColor" />
  </svg>
)

function SubmitButton({ processing }: { processing: boolean }) {
  return <button type="submit">{processing ? SPINNER : 'Save'}</button>
}
```

Each render then reuses the same element object rather than allocating a new one. React can also
skip re-rendering that subtree, because the element is referentially identical to last time.

**Keep the comparison honest: hoisting an element is not the same as extracting a component.**
Replacing `{loading && <LoadingSkeleton />}` with a hoisted `{loading && loadingSkeleton}` is not a
like-for-like change — `<LoadingSkeleton />` is a component boundary, and deleting it changes where
React can bail out and where a future hook or piece of state would live. Hoist a literal element
tree, as above; do not dissolve an existing component into one to satisfy this rule.

The payoff is largest for a big static SVG, where the element tree being allocated is deep. For a
`<div className="…" />` it is unmeasurable, which is why this rule is `LOW`.

**Note:** if your project has [React Compiler](https://react.dev/learn/react-compiler) enabled, the
compiler hoists static JSX for you and this rule is moot.
