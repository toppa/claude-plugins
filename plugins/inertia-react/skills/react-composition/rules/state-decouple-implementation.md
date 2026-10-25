---
title: Decouple State Management from UI
impact: MEDIUM
impactDescription: enables swapping state implementations without changing UI
tags: composition, state, architecture
---

## Decouple State Management from UI

The provider is the only component that knows where state comes from. The parts read the
context contract, so they work the same whether the values started in `useState`, arrived
from Rails as a page prop, or are being written back through a form.

**The provider holds every detail of the source:**

```tsx
function ChannelProvider({
  channelId,
  children,
}: {
  channelId: string
  children: ReactNode
}) {
  const { draft } = usePage<{ draft: ComposerState }>().props
  const [state, setState] = useState(draft)
  const inputRef = useRef<HTMLTextAreaElement>(null)
  const submit = useSubmitToChannel(channelId)

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

**The UI takes no props about state at all:**

```tsx
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

function Channel({ channelId }: { channelId: string }) {
  return (
    <ChannelProvider channelId={channelId}>
      <ChannelComposer />
    </ChannelProvider>
  )
}
```

`Composer.Input` takes no `value` and no `onChange`, and `Composer.Submit` takes no
`onClick`. Both read the context. That is the property being bought: the page can change
where the draft comes from without touching either part.

**The test of it is a second provider.** If a variant needs local state instead of the
page's draft, only the provider changes:

```tsx
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
```

`ChannelComposer` renders unchanged under either one.

**Where the seam is worth drawing.** One provider and one source is the common case, and a
component that will only ever have one source does not need this. Draw the seam when a
second variant of the same UI genuinely exists — an edit mode, a forward dialog, a
draft-restoring page. For a form, the seam already exists: `<Form>` owns the state and
`useFormContext()` is how a nested part reads it, so write neither the provider nor the
contract. See `inertia-rails-forms`, section "Reading form state from a nested child with
`useFormContext`".
