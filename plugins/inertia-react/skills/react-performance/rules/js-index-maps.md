---
title: Build Index Maps for Repeated Lookups
impact: LOW-MEDIUM
impactDescription: turns a nested scan into one pass plus constant-time lookups
tags: javascript, map, indexing, optimization, performance
---

## Build Index Maps for Repeated Lookups

When you look values up by the same key across a list long enough for the scan to cost, index
them into a `Map` first:

```typescript
function processOrders(orders: Order[], users: User[]) {
  const userById = new Map(users.map(u => [u.id, u]))

  return orders.map(order => ({
    ...order,
    user: userById.get(order.userId)
  }))
}
```

`users.find(…)` inside `orders.map(…)` scans the users array once per order, so the two array
lengths multiply: *m* orders over *n* users is O(m·n). Building the index is one O(n) pass and
each lookup is then constant time, giving O(m + n). That is the whole argument, and it is
asymptotic — it grows with your data rather than depending on an engine.

**Because the argument is asymptotic, it only pays once the list is long enough.** Building the
`Map` is O(n) work you did not previously do. `rules/js-set-map-lookups.md` measures where the
two forms cross over and states the same boundary for `Set`. Leave a join over a handful of
rows as a `find`.

This matters in an Inertia app specifically because both arrays usually arrive together as page
props, so the join happens in the component on every render of a list. If the join is stable,
build the `Map` in a `useMemo` keyed on the source array, or have Rails send the association
already nested and skip the join entirely — `inertia-rails-performance` covers shaping props for
that, in its "Prop payload size" section.
