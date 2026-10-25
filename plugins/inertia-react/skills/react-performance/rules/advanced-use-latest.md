---
title: Read the Latest Callback in an Effect with useEffectEvent
impact: LOW
impactDescription: prevents effect re-runs
tags: advanced, hooks, useEffectEvent, refs, optimization
---

## Read the Latest Callback in an Effect with useEffectEvent

Read the latest value of a callback from inside an effect without listing it as a dependency:

```tsx
import { useEffect, useEffectEvent, useState } from 'react'

function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('')
  const search = useEffectEvent(onSearch)

  useEffect(() => {
    const timeout = setTimeout(() => search(query), 300)
    return () => clearTimeout(timeout)
  }, [query])

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />
}
```

`query` stays in the dependency array, because a change to it *should* restart the debounce.
`onSearch` comes out, because a new function identity from the parent should not. Without
`useEffectEvent` you get one of two bugs: list `onSearch` and every parent render cancels and
restarts the timer, so a re-rendering parent means the debounce never fires; omit it and the effect
calls a stale closure.

Do not put `search` in the dependency array — see `rules/advanced-effect-event-deps.md`, which is
about exactly that mistake.

**This is the same hook and the same reasoning as `rules/advanced-event-handler-refs.md`**, applied
to a debounce rather than a subscription. That file also shows the pre-`useEffectEvent` ref-copy
workaround, which is what you will find in existing code. Read one of the two; there is no third
idea between them.
