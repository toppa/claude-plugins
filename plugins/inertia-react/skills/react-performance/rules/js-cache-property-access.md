---
title: Hoist Loop-Invariant Work out of a Loop
impact: LOW
impactDescription: readability; hoisting arr.length measured as no saving
tags: javascript, loops, optimization
---

## Hoist Loop-Invariant Work out of a Loop

If a value does not change across iterations, read it once above the loop:

```typescript
const value = obj.config.settings.value
for (let i = 0; i < arr.length; i++) {
  process(value)
}
```

Hoisting `obj.config.settings.value` is worth doing: it is three property reads per iteration
replaced by three in total, and it says plainly that the value is invariant.

**Hoisting `arr.length` is not worth doing.** It is the canonical modern-JIT myth: V8 hoists the
bounds check itself for an array whose length the loop body does not modify, so there is nothing
left for you to hoist.

> Measured to check that claim, not to give you a budget: node 24.3.0, one array of 10,000
> objects, 200 passes after 20 warm-up passes. `i < arr.length` in the condition, 0.0066 ms per
> pass; `const len = arr.length` hoisted, 0.0068 ms per pass. The hoisted version came out
> marginally *slower*, which is another way of saying both readings are inside the run-to-run
> noise of this harness. Role: an illustration that the effect is absent on this engine — not a
> threshold, and not a figure to design against.

So the rule to keep is the readability one: name an invariant once so a reader can see it is
invariant. Do not restructure a loop for the length read. And if the loop body is the expensive
part, none of this is where the time is going — profile before rewriting.
