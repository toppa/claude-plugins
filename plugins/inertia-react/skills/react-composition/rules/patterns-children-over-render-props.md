---
title: Prefer Composing Children Over Render Props
impact: MEDIUM
impactDescription: cleaner composition, better readability
tags: composition, children, render-props
---

## Prefer Children Over Render Props

Take `children` for structure. A part that only needs to place its children in the right
element takes `children: ReactNode` and nothing else:

```tsx
import type { ReactNode } from 'react'

function ComposerFrame({ children }: { children: ReactNode }) {
  return <form>{children}</form>
}

function ComposerFooter({ children }: { children: ReactNode }) {
  return <footer className="flex">{children}</footer>
}
```

The call site is then plain JSX, so what renders where is visible without knowing any
callback signatures:

```tsx
<Composer.Frame>
  <CustomHeader />
  <Composer.Input />
  <Composer.Footer>
    <Composer.Formatting />
    <Composer.Emojis />
    <SubmitButton />
  </Composer.Footer>
</Composer.Frame>
```

Children also compose without an API change: adding a third item to the footer is one more
line at the call site, whereas a `renderFooter` prop makes the parent's props the place
where every arrangement has to be expressed.

**Keep render props for the case they are for: the parent supplies the data.** When the
child cannot be written until the parent knows the item, a callback prop is the right
shape:

```tsx
<List
  data={items}
  renderItem={({ item, index }) => <Item item={item} index={index} />}
/>
```

The rule of thumb: `children` when the parent renders a slot, a callback prop when the
parent passes a value into the slot. `@inertiajs/react` uses both — `<Link>` takes
children, while `<Deferred>` and `<Form>` call their children as a function with the state
they own.
