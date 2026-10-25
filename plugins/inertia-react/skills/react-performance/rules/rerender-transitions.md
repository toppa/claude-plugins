---
title: Use Transitions for Non-Urgent Updates
impact: MEDIUM
impactDescription: keeps an urgent update from waiting on a slow one
tags: rerender, transitions, startTransition, performance
---

## Use Transitions for Non-Urgent Updates

Mark a state update as a transition when its render is slow and something else on screen has
to stay responsive:

```tsx
import { startTransition, useState } from 'react'

function Filters({ rows }: { rows: Row[] }) {
  const [text, setText] = useState('')
  const [filter, setFilter] = useState('')

  const handleChange = (value: string) => {
    setText(value)                                  // urgent: the input
    startTransition(() => setFilter(value))         // non-urgent: the table
  }

  return (
    <>
      <input value={text} onChange={(e) => handleChange(e.target.value)} />
      <ExpensiveTable rows={rows} filter={filter} />
    </>
  )
}
```

The transition render is interruptible, so a second keystroke abandons the first table render
instead of queueing behind it.

**A transition still renders once per update.** react.dev's governing caveat: "A state update
marked as a Transition will be interrupted by other state updates … React will restart the
rendering work." That makes transitions a good fit for updates that arrive at human speed and
a poor one for updates that arrive at frame rate: with one `startTransition` per scroll event,
restarting is the dominant behaviour and you have paid for scheduling without saving a render.

**For a value that changes every frame, do not render it at all.** A scroll position, a pointer
position, or a drag offset belongs in a ref, written straight to the DOM node —
`rules/rerender-use-ref-transient-values.md` has that pattern, and it produces zero renders
where this rule produces one per event. Choose between the two by asking whether React needs
to see the value: if the value only ever becomes a style, use the ref; if other components
render from it, use a transition.

`rules/rendering-usetransition-loading.md` is the `useTransition` form of this rule, for when
you also want React's `isPending` flag. Read it before you put an `await` inside a transition:
the state updates after the `await` are not transitions, and that file carries the react.dev
statement to that effect.
