---
title: Create Explicit Component Variants
impact: MEDIUM
impactDescription: self-documenting code, no hidden conditionals
tags: composition, variants, architecture
---

## Create Explicit Component Variants

Name each variant as its own component, take the props that variant actually needs, and
have it wire its own provider. The call site then reads as what it renders:

```tsx
<ThreadComposer channelId="abc" />
<EditMessageComposer messageId="xyz" />
<ForwardMessageComposer messageId="123" />
```

Where `rules/architecture-avoid-boolean-props.md` is about what the shared component
accepts, this rule is about the variant files: each one pairs a provider with a
composition, and that pairing is the variant's whole definition.

```tsx
function ThreadComposer({ channelId }: { channelId: string }) {
  return (
    <ThreadProvider channelId={channelId}>
      <Composer.Frame>
        <Composer.Input />
        <AlsoSendToChannelField channelId={channelId} />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Submit />
        </Composer.Footer>
      </Composer.Frame>
    </ThreadProvider>
  )
}

function EditMessageComposer({ messageId }: { messageId: string }) {
  return (
    <EditMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.CancelEdit />
          <Composer.SaveEdit />
        </Composer.Footer>
      </Composer.Frame>
    </EditMessageProvider>
  )
}

function ForwardMessageComposer({ messageId }: { messageId: string }) {
  return (
    <ForwardMessageProvider messageId={messageId}>
      <Composer.Frame>
        <Composer.Input placeholder="Add a message, if you'd like." />
        <Composer.Footer>
          <Composer.Formatting />
          <Composer.Emojis />
          <Composer.Mentions />
        </Composer.Footer>
      </Composer.Frame>
    </ForwardMessageProvider>
  )
}
```

Three things are visible in each variant without reading any other file: which provider
supplies its state, which parts it renders, and which actions are therefore available.

Two mechanics to keep straight:

- A part that takes a prop has to declare it. `<Composer.Input placeholder="…" />` needs
  `ComposerInput` to accept `placeholder`, or it is a `TS2322`. Keep the prop list of a
  part to the things that vary per call site; everything else comes from the context.
- Each provider takes the props its own source needs — `channelId`, `messageId` — and
  those props stop at the provider. They do not continue into the parts.
