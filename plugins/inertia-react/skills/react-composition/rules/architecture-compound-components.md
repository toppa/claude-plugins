---
title: Use Compound Components
impact: HIGH
impactDescription: enables flexible composition without prop drilling
tags: composition, compound-components, architecture
---

## Use Compound Components

Structure a complex component as a set of parts over a shared context. Each part reads
what it needs from the context, so the consumer composes the pieces it wants and no prop
travels through a middle component that does not use it.

Three things make this work: a context whose default is `null`, one hook that reads the
context and throws when a part is rendered outside the provider, and a single object that
names every part.

**The context and the guard hook:**

```tsx
import { createContext, use } from 'react'

const ComposerContext = createContext<ComposerContextValue | null>(null)

export function useComposer(): ComposerContextValue {
  const context = use(ComposerContext)
  if (!context) {
    throw new Error('Composer parts must render inside <Composer.Provider>')
  }
  return context
}
```

The `null` default is what makes a missing provider a loud error instead of a silent
`undefined` read, and the hook is where that check lives — once, rather than in every
part. Reading the context directly with `use(ComposerContext)` returns
`ComposerContextValue | null`, which does not destructure under `strict`. See
`rules/state-context-interface.md` for the shape of `ComposerContextValue`.

**The parts:**

```tsx
import type { ReactNode } from 'react'

function ComposerProvider({ state, actions, meta, children }: ProviderProps) {
  return (
    <ComposerContext value={{ state, actions, meta }}>{children}</ComposerContext>
  )
}

function ComposerFrame({ children }: { children: ReactNode }) {
  return <form>{children}</form>
}

function ComposerInput({ placeholder }: { placeholder?: string }) {
  const { state, actions, meta } = useComposer()
  return (
    <textarea
      ref={meta.inputRef}
      value={state.input}
      placeholder={placeholder}
      onChange={(event) =>
        actions.update((s) => ({ ...s, input: event.target.value }))
      }
    />
  )
}

function ComposerSubmit() {
  const { state, actions } = useComposer()
  return (
    <button type="button" onClick={actions.submit} disabled={state.isSubmitting}>
      Send
    </button>
  )
}
```

`<ComposerContext value={…}>` is the React 19 form: a context object is itself a
component, so there is no `.Provider`.

**One object names every part, and that object is the component's API:**

```tsx
export const Composer = {
  Provider: ComposerProvider,
  Frame: ComposerFrame,
  Header: ComposerHeader,
  Input: ComposerInput,
  Footer: ComposerFooter,
  Attachments: ComposerAttachments,
  Formatting: ComposerFormatting,
  Emojis: ComposerEmojis,
  Mentions: ComposerMentions,
  Submit: ComposerSubmit,
  CancelEdit: ComposerCancelEdit,
  SaveEdit: ComposerSaveEdit,
}
```

Keep the object complete. `<Composer.SaveEdit />` is a `TS2339` if `SaveEdit` is not a
key, so every part a variant renders belongs here. Export `useComposer` alongside it for
one-off components that need the state but are not parts of the composer — see
`rules/state-context-interface.md`.

**Usage:**

```tsx
<Composer.Provider state={state} actions={actions} meta={meta}>
  <Composer.Frame>
    <Composer.Header />
    <Composer.Input />
    <Composer.Footer>
      <Composer.Formatting />
      <Composer.Submit />
    </Composer.Footer>
  </Composer.Frame>
</Composer.Provider>
```

The consumer composes exactly what it needs, with no flags to reason about, and the
state, actions and meta are supplied by whichever provider is above.
