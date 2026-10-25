---
title: Early Length Check for Array Comparisons
impact: LOW
impactDescription: an O(1) guard before an O(n log n) comparison
tags: javascript, arrays, performance, optimization, comparison
---

## Early Length Check for Array Comparisons

When a comparison sorts, serialises, or walks both arrays, compare lengths first: arrays of
different lengths cannot be equal, and the check is O(1).

```typescript
function hasChanges(current: string[], original: string[]) {
  if (current.length !== original.length) return true

  const currentSorted = [...current].sort()
  const originalSorted = [...original].sort()
  for (let i = 0; i < currentSorted.length; i++) {
    if (currentSorted[i] !== originalSorted[i]) return true
  }
  return false
}
```

Copy before sorting. `current.sort()` reorders the caller's array, so a "comparison" function
that sorts its inputs in place changes the data it was asked to inspect —
`rules/js-tosorted-immutable.md` covers why that bites. (`toSorted` reads better and needs
`lib: ES2023`; see that rule.)

**The bigger reason to write it this way is correctness, not speed.** The shorter form

```typescript
return current.sort().join() !== original.sort().join()
```

is wrong, and quietly. `join()` inserts commas, so any element containing a comma makes the
result ambiguous: executed in node 24, `['a,b', 'x']` and `['a', 'b,x']` both join to
`'a,b,x'` at equal length, and `hasChanges` returns `false` for two arrays that differ. It
also mutates both inputs — `['c','a','b']` comes back as `['a','b','c']`.

**On the speed claim: the length guard saves the sort only when the lengths differ.** When
they match, which is the common case for a dirty-check, the guard costs one comparison and
saves nothing. That is worth one line of code, but it is not a hot-path optimisation, which is
why this rule is `impact: LOW`. If the real goal is a dirty-check on a form, `<Form>` and
`useForm` already publish `isDirty` and you should not be comparing arrays at all.
