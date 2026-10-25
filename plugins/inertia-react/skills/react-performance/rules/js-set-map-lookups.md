---
title: Use Set/Map for O(1) Lookups
impact: LOW-MEDIUM
impactDescription: O(n) to O(1) per lookup, once the list is long enough
tags: javascript, set, map, data-structures, performance
---

## Use Set/Map for O(1) Lookups

When the same list is searched repeatedly, build a `Set` once and check membership against it:

```typescript
const allowedIds = new Set(permittedIds)
const permitted = items.filter((item) => allowedIds.has(item.id))
```

`includes` walks the array on every call, so *m* lookups over a list of *n* cost O(m·n); the
`Set` costs O(n) once plus O(1) per lookup.

**The justification is asymptotic, so it only pays once the list is long enough.** Building the
`Set` is O(n) work you did not previously do, and at a small *n* the linear scan finishes before
that has paid for itself. Apply this where the list is long or its length is not bounded by the
code — a permission list, a set of ids from the server — and leave a three-element `includes`
alone.

> Measured to locate roughly where the two cross over: node 24.3.0, 10,000 lookups against one
> pre-built list, 200 passes after 20 warm-up passes. At a 3-element list, `includes` 0.0878 ms
> and `Set.has` 0.0808 ms per pass — a wash. At 200 elements, `includes` 1.5904 ms and `Set.has`
> 0.1005 ms per pass — an order of magnitude apart. Role: an illustration of the shape of the
> curve on one engine. It is not a threshold; do not read "200" as a rule about when to switch,
> because the crossover moves with the number of lookups per list.

**Build the Set outside the loop.** `items.filter(item => new Set(list).has(item.id))`
constructs a Set per item and is slower than `includes`. If the list is a prop or a literal,
hoist the Set to module scope or wrap it in `useMemo`.

For looking up a *value* by key rather than testing membership, `Map` is the same idea and the
same asymptotics — see `rules/js-index-maps.md`, which covers replacing a repeated `.find()`.
