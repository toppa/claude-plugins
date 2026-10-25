---
title: Avoid Boolean Prop Proliferation
impact: CRITICAL
impactDescription: prevents unmaintainable component variants
tags: composition, props, architecture
---

## Avoid Boolean Prop Proliferation

Give each mode its own component and let the modes share parts rather than a parent. A
shared component's props should describe what it renders, not which caller is rendering
it.

Boolean mode props are the shape to move away from: `n` of them describe `2^n` states, of
which only a few are reachable, and the component body carries a nested conditional for
every one. Two of them also tend to be mutually exclusive with no type that says so, so
the illegal combination compiles.

**Each variant composes the parts it needs:**

```tsx
function ChannelComposer() {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <Composer.Footer>
        <Composer.Attachments />
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

// A thread adds one field. Nothing else changes.
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <Composer.Frame>
      <Composer.Header />
      <Composer.Input />
      <AlsoSendToChannelField channelId={channelId} />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.Submit />
      </Composer.Footer>
    </Composer.Frame>
  )
}

// Editing has different footer actions and no header.
function EditComposer() {
  return (
    <Composer.Frame>
      <Composer.Input />
      <Composer.Footer>
        <Composer.Formatting />
        <Composer.Emojis />
        <Composer.CancelEdit />
        <Composer.SaveEdit />
      </Composer.Footer>
    </Composer.Frame>
  )
}
```

Each variant is explicit about what it renders, the shared internals stay shared, and
adding a fourth mode adds a file rather than a branch in three others. The value each
variant needs — the channel id here — travels as a named prop to the one part that uses
it, not into a parent that forwards it.

**When a boolean prop is the right prop.** A boolean that describes the rendered result
rather than the caller is fine: `disabled`, `required`, `open`. The test is whether the
component body branches on it to render a different structure. `disabled` sets an
attribute; `isThread` picks a subtree.

For the variant components themselves and how each wires its own provider, see
`rules/patterns-explicit-variants.md`. For the `Composer` object these examples compose,
see `rules/architecture-compound-components.md`.
