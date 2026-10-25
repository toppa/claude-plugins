---
title: Use flatMap to Map and Filter in One Pass
impact: LOW
impactDescription: one expression instead of two; no reliable speed gain
tags: javascript, arrays, flatMap, filter, performance
---

## Use flatMap to Map and Filter in One Pass

`flatMap` expresses "transform, and drop some" as one operation, which is its real advantage
over `.map(…).filter(Boolean)`:

```typescript
const userNames = users.flatMap((user) => (user.isActive ? [user.name] : []))

const emails = responses.flatMap((r) => (r.success ? [r.data.email] : []))

const numbers = strings.flatMap((s) => {
  const n = Number.parseInt(s, 10)
  return Number.isNaN(n) ? [] : [n]
})
```

It also avoids the trap in `.map(x => cond ? x : null).filter(Boolean)`, which drops legitimate
`0` and `''` values along with the nulls. That correctness point is the strongest reason to
prefer it.

**Do not reach for it as an optimisation.** The "no intermediate array" premise is false:
`flatMap` allocates a fresh `[x]` for every kept element, so it trades one array of length *n*
for *n* arrays of length 1, then flattens them. That is why neither form reliably wins — which is
ahead depends on the keep ratio and the shape of the data, so treat them as equal on speed.

> Measured to settle the direction, not to give a ratio worth quoting: node 24.3.0, 10,000
> objects with half kept, 200 passes after 20 warm-up passes. `.filter().map()` 0.0789 ms per
> pass; `flatMap` 0.0939 ms per pass. So on this input `flatMap` was the slower of the two.
> Role: evidence against the rule's stated mechanism. Do not carry the ratio to another input
> size — reverse the keep ratio and it moves.

If the pass is genuinely hot, neither is the answer — a plain loop allocates one array and calls
no callback per element, and on the same harness it came in at 0.0139 ms per pass:

```typescript
const userNames: string[] = []
for (const user of users) {
  if (user.isActive) userNames.push(user.name)
}
```

Write the declarative form by default and the loop when a profile says this line matters.
