---
title: Use Activity Component for Show/Hide
impact: MEDIUM
impactDescription: preserves state and DOM across hide/show
tags: rendering, activity, visibility, state-preservation
---

## Use Activity Component for Show/Hide

`<Activity>` keeps a subtree mounted while hiding it, so its state and DOM survive a
hide/show cycle that conditional rendering would destroy.

```tsx
import { Activity, useState } from 'react'

function Dropdown() {
  const [isOpen, setIsOpen] = useState(false)
  return (
    <>
      <button onClick={() => setIsOpen((open) => !open)}>Menu</button>
      <Activity mode={isOpen ? 'visible' : 'hidden'}>
        <ExpensiveMenu />
      </Activity>
    </>
  )
}
```

`Activity` is exported by `react` 19.2.8 and typed with `mode?: "hidden" | "visible"`.

**Know the hidden-mode contract before you reach for it**, because it is not "the subtree is
frozen":

- **All Effects in the hidden subtree are destroyed.** Cleanup runs on hide and setup runs
  again on show. A child that fetches in an effect will re-fetch every time it is revealed, and
  a subscription will be torn down and rebuilt. *State* is preserved; *effects* are not.
- **Hidden children still re-render**, at a lower priority, when their props or state change. So
  the saving is in mount/unmount work and state loss, not in re-render count.
- React's Pitfalls list media and embedded content: a hidden `<video>`, `<audio>` or `<iframe>`
  keeps running.
- The subtree is mounted as soon as `<Activity>` renders, even in `hidden` mode. That is the
  point when you want the DOM ready in advance, and a cost you pay for a menu the user never
  opens. If you would rather not pay it up front, render `<Activity>` only after the first
  open and leave it mounted from then on.

Use it for something the user toggles repeatedly and whose state matters: an open panel with
scroll position and a partially typed filter. For a one-shot reveal, plain conditional
rendering is cheaper and has no effect-teardown surprises.
