---
title: React 19 API Changes
impact: MEDIUM
impactDescription: cleaner component definitions and context usage
tags: react19, refs, context, hooks
---

## React 19 API Changes

Two APIs changed shape in React 19: `ref` is a plain prop, and `use()` joins `useContext()`
as a way to read a context.

### Take `ref` as a prop

A function component can declare `ref` in its own props and pass it on. There is no
wrapper:

```tsx
import type { ComponentProps, Ref } from 'react'

type ComposerInputProps = ComponentProps<'textarea'> & {
  ref?: Ref<HTMLTextAreaElement>
}

function ComposerInput({ ref, ...props }: ComposerInputProps) {
  return <textarea ref={ref} {...props} />
}
```

The call site is unchanged — `<ComposerInput ref={inputRef} />` — so this is a change to
how you write a new component, not to how anything calls it.

**`forwardRef` is not removed, and existing components using it are not broken.**
`@types/react` 19.2.17 declares it at `index.d.ts:1403` with no `@deprecated` tag, and
`@inertiajs/react` 3.6.1 itself builds `Form`, `InfiniteScroll` and `Link` with it.
react.dev says `forwardRef` *will be* deprecated in a future release. So: write new
components with `ref` as a prop, and convert an existing `forwardRef` component when you
are already editing it, not as a sweep.

### Read a context with `use()`

```tsx
const value = use(MyContext)
```

`use(Context)` and `useContext(Context)` read the same value and neither is deprecated —
`useContext` carries no `@deprecated` tag in `@types/react` 19.2.17 either. What `use` adds
is that it may be called inside a condition or a loop, which the rules of hooks forbid for
`useContext`:

```tsx
function Row({ compact }: { compact: boolean }) {
  if (compact) {
    const theme = use(ThemeContext)
    return <CompactRow theme={theme} />
  }
  return <FullRow />
}
```

So reach for `use` when the read is conditional, and leave a working top-level
`useContext` call alone. Two constraints on `use` from react.dev: it must be called inside
a component or a hook, and reading a context with `use` is not supported in Server
Components — which this stack does not have, since Rails renders the document.

For the guard hook that both forms should sit behind when the context default is `null`,
see `rules/architecture-compound-components.md`.
