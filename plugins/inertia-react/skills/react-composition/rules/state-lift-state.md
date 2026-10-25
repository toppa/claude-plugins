---
title: Lift State into Provider Components
impact: HIGH
impactDescription: enables state sharing outside component boundaries
tags: composition, state, context, providers
---

## Lift State into Provider Components

Put the state in a provider component that wraps everything which needs it. A sibling
rendered next to the UI — a preview, a dialog's own action buttons — then reads and
updates that state through the context, with no props passed down, no `useEffect` copying
a child's state upward, and no ref read at submit time.

**The provider owns the state:**

```tsx
function ForwardMessageProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(initialState)
  const forwardMessage = useForwardMessage()
  const inputRef = useRef<HTMLTextAreaElement>(null)

  return (
    <Composer.Provider
      state={state}
      actions={{ update: setState, submit: forwardMessage }}
      meta={{ inputRef }}
    >
      {children}
    </Composer.Provider>
  )
}
```

**Everything that needs the state goes inside it:**

```tsx
function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        <ForwardMessageComposer />
        <MessagePreview />
        <DialogActions>
          <CancelButton />
          <ForwardButton />
        </DialogActions>
      </Dialog>
    </ForwardMessageProvider>
  )
}

function ForwardButton() {
  const { actions } = useComposer()
  return <button type="button" onClick={actions.submit}>Forward</button>
}
```

`useComposer()` is the guard hook from `rules/architecture-compound-components.md`. Use it
rather than reaching for a `Composer.Context` key on the compound object — the compound
object holds components, and exporting the raw context alongside them gives two ways to
read the same value, one of which skips the missing-provider check.

**What this replaces.** Three shapes disappear once the state is in the provider, and each
is worth recognising in existing code:

- A prop passed down purely so a child can call back up (`onInputChange={setInput}`),
  usually paired with a `useEffect` in the child that fires on every change.
- A ref handed to a child so the parent can read its state at submit time. The value is
  invisible to React, so nothing re-renders when it changes and a preview cannot show it.
- A parent that holds a copy of the child's state and drifts out of sync with it.

**Key insight:** components that share state do not have to be nested inside each other —
they only have to be inside the same provider.
