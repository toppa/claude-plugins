---
title: Define Generic Context Interfaces for Dependency Injection
impact: HIGH
impactDescription: enables dependency-injectable state across use-cases
tags: composition, context, state, typescript, dependency-injection
---

## Define Generic Context Interfaces for Dependency Injection

Give the context three parts — `state`, `actions`, and `meta` — and type it as a contract
that any provider can satisfy. The parts consume the contract, so the same UI runs against
more than one source of state.

**Core principle:** lift state, compose internals, keep the source of state in the
provider.

**The contract:**

```tsx
import { createContext, use } from 'react'
import type { RefObject } from 'react'

type ComposerState = {
  input: string
  attachments: Attachment[]
  isSubmitting: boolean
}

type ComposerActions = {
  update: (updater: (state: ComposerState) => ComposerState) => void
  submit: () => void
}

type ComposerMeta = {
  inputRef: RefObject<HTMLTextAreaElement | null>
}

type ComposerContextValue = {
  state: ComposerState
  actions: ComposerActions
  meta: ComposerMeta
}

const ComposerContext = createContext<ComposerContextValue | null>(null)

export function useComposer(): ComposerContextValue {
  const context = use(ComposerContext)
  if (!context) {
    throw new Error('Composer parts must render inside <Composer.Provider>')
  }
  return context
}
```

Two typing details that are easy to get wrong on React 19:

- `useRef<HTMLTextAreaElement>(null)` returns `RefObject<HTMLTextAreaElement | null>`, so
  the contract writes `| null` in the ref type. `@types/react` 19.2.17 declares
  `useRef<T>(initialValue: T | null): RefObject<T | null>`; a bare
  `RefObject<HTMLTextAreaElement>` is not assignable and gives `TS2322`.
- Every part reads through `useComposer()`, never `use(ComposerContext)` directly. The
  latter is `ComposerContextValue | null` and destructuring it fails under `strict`.

**A part consumes the contract, not the implementation:**

```tsx
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
```

**Two providers, one contract.** The first holds local state; the second reads a draft
that Rails sent with the page. Both hand the parts the same three keys, so
`Composer.Input` works under either:

```tsx
// Local state, for an ephemeral form
function ForwardMessageProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(initialState)
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const submit = useForwardMessage()

  return (
    <Composer.Provider
      state={state}
      actions={{ update: setState, submit }}
      meta={{ inputRef }}
    >
      {children}
    </Composer.Provider>
  )
}

// Server state, for a draft that arrived as a page prop
function ChannelProvider({ children }: { children: ReactNode }) {
  const { draft } = usePage<{ draft: ComposerState }>().props
  const [state, setState] = useState(draft)
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const submit = useSubmitToChannel()

  return (
    <Composer.Provider
      state={state}
      actions={{ update: setState, submit }}
      meta={{ inputRef }}
    >
      {children}
    </Composer.Provider>
  )
}
```

`Composer.Provider` requires all three keys — omit `meta` and it is a `TS2741`. Give the
provider a `meta` even when nothing in that variant uses the ref.

**The provider boundary is what matters, not the visual nesting.** A component that needs
the composer's state has to be inside the provider; it does not have to be inside
`Composer.Frame`:

```tsx
function ForwardMessageDialog() {
  return (
    <ForwardMessageProvider>
      <Dialog>
        <Composer.Frame>
          <Composer.Input placeholder="Add a message, if you'd like." />
          <Composer.Footer>
            <Composer.Formatting />
            <Composer.Emojis />
          </Composer.Footer>
        </Composer.Frame>

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

function MessagePreview() {
  const { state } = useComposer()
  return <Preview message={state.input} attachments={state.attachments} />
}
```

`ForwardButton` and `MessagePreview` sit outside the composer box and still read its state
through the same hook every part uses.

**When one context value costs too much.** `<ComposerContext value={{ state, actions, meta }}>`
builds a fresh object on every provider render, and every consumer of that context
re-renders when it changes — so a keystroke in `Composer.Input` re-renders
`Composer.Submit`, `MessagePreview` and `ForwardButton` too. That is the right trade while
the consumer count is small. When it is not, split the contract along its own seam: the
`state` changes per keystroke, while `actions` and `meta` are stable for the provider's
lifetime.

```tsx
const ComposerStateContext = createContext<ComposerState | null>(null)
const ComposerActionsContext = createContext<ComposerActions | null>(null)

function ComposerProvider({ state, actions, children }: ProviderProps) {
  return (
    <ComposerActionsContext value={actions}>
      <ComposerStateContext value={state}>{children}</ComposerStateContext>
    </ComposerActionsContext>
  )
}
```

A part that only submits reads `useComposerActions()` and stops re-rendering on every
keystroke. Keep the `actions` object stable too — `useMemo` or a `useCallback` per action
— or the split buys nothing. Confirm the win with the React DevTools Profiler, counting the
renders a keystroke causes before and after.

The UI is parts you compose. The state comes from the provider. Swap the provider, keep
the UI.
