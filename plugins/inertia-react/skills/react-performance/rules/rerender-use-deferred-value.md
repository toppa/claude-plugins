---
title: Use useDeferredValue for Expensive Derived Renders
impact: MEDIUM
impactDescription: keeps input responsive during heavy computation
tags: rerender, useDeferredValue, optimization, concurrent
---

## Use useDeferredValue for Expensive Derived Renders

When typing drives an expensive render, keep the input on the urgent update and let the
expensive part lag one step behind. `useDeferredValue` gives you the lagging copy; React then
re-renders the expensive subtree in the background, interruptibly.

**Three pieces are all required — the deferred value, `useMemo` on the computation, and
`memo` on the child that renders it:**

```tsx
import { memo, useDeferredValue, useMemo, useState } from 'react'

const ResultsList = memo(function ResultsList({ results }: { results: Item[] }) {
  return <ul>{results.map((item) => <li key={item.id}>{item.name}</li>)}</ul>
})

function Search({ items }: { items: Item[] }) {
  const [query, setQuery] = useState('')
  const deferredQuery = useDeferredValue(query)
  const filtered = useMemo(
    () => items.filter((item) => fuzzyMatch(item, deferredQuery)),
    [items, deferredQuery]
  )
  const isStale = query !== deferredQuery

  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <div style={{ opacity: isStale ? 0.7 : 1 }}>
        <ResultsList results={filtered} />
      </div>
    </>
  )
}
```

Leave out `memo` and the rule does not deliver what it promises. react.dev is explicit:
"Without `memo`, it would have to re-render anyway, defeating the point." `useMemo` spares the
`fuzzyMatch` pass, but the child still re-renders synchronously inside the urgent keystroke
update — which is the cost the rule exists to move.

**"Background", not "when idle".** There is no delay built into `useDeferredValue`; react.dev
states "There is no fixed delay caused by `useDeferredValue` itself." React starts the deferred
render immediately at a lower priority and abandons it if another keystroke arrives. So the
input stays responsive because the expensive render is interruptible, not because it is
postponed to an idle moment.

**When to use:**

- Filtering or searching a large list you already hold in memory
- An expensive visualisation reacting to an input
- Any derived render slow enough to be felt between keystrokes

For a list that comes from the server, this is the wrong tool: send the filter to Rails as a
partial reload and let `<Deferred>` or `processing` render the pending state.

Reference: [React useDeferredValue](https://react.dev/reference/react/useDeferredValue)
