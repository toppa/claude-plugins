---
title: Preload Based on User Intent
impact: MEDIUM
impactDescription: reduces perceived latency
tags: bundle, preload, user-intent, hover
---

## Preload Based on User Intent

Start fetching a heavy chunk before the click that needs it, so the click does not pay for
the download. Two signals are worth acting on: the user is about to ask for the feature, and
a flag has just turned the feature on.

**Preload on hover and focus:**

```tsx
function EditorButton({ onClick }: { onClick: () => void }) {
  const preload = () => {
    void import('./monaco-editor')
  }

  return (
    <button onMouseEnter={preload} onFocus={preload} onClick={onClick}>
      Open Editor
    </button>
  )
}
```

`onFocus` alongside `onMouseEnter` is what makes this reachable by keyboard. Repeated calls
are free: a module is evaluated once and `import()` returns the same promise afterwards.

**Preload when a feature flag turns the feature on:**

```tsx
function FlagsProvider({ children, flags }: Props) {
  useEffect(() => {
    if (!flags.editorEnabled) return
    void import('./monaco-editor').then((mod) => mod.init())
  }, [flags.editorEnabled])

  return <FlagsContext value={flags}>{children}</FlagsContext>
}
```

**This is not the same thing as Inertia's prefetch, and neither replaces the other.**
`<Link prefetch>` fetches the *page props* for the next visit — a JSON round trip to Rails.
This rule fetches a *JavaScript chunk* for a component the current page may render. A
hovered link can want both. `inertia-rails-pages` owns `<Link prefetch>` and `cacheFor`, in
its "`<Link>` and `router`" section.

No `typeof window` guard is needed on either example. Rollup decides what to bundle from the
`import()` specifier at build time, so a runtime check cannot change the module graph, and
neither an event handler nor an effect runs during server rendering.
