---
title: Dynamic Imports for Heavy Components
impact: HIGH
impactDescription: moves a heavy component into its own chunk
tags: bundle, dynamic-import, code-splitting, react-lazy
---

## Dynamic Imports for Heavy Components

Use `React.lazy` with a `Suspense` boundary to load large components that the first
render does not need. Vite splits each `import()` into its own chunk.

**Incorrect (Monaco bundles with main chunk ~300KB):**

```tsx
import { MonacoEditor } from './monaco-editor'

function CodePanel({ code }: { code: string }) {
  return <MonacoEditor value={code} />
}
```

**Correct (Monaco loads on demand):**

```tsx
import { lazy, Suspense } from 'react'

const MonacoEditor = lazy(() =>
  import('./monaco-editor').then(m => ({ default: m.MonacoEditor }))
)

function CodePanel({ code }: { code: string }) {
  return (
    <Suspense fallback={<EditorSkeleton />}>
      <MonacoEditor value={code} />
    </Suspense>
  )
}
```

`lazy` expects a module whose `default` export is the component. A named export needs the
`.then` above.

**What this buys is chunk separation, and it costs you the SSR'd markup for that subtree.** Two
things to be precise about:

- `lazy` does not "load after hydration". It starts the import during the render pass that first
  reaches the component, so with no `Suspense` boundary above the fold the request goes out
  immediately. The win is that the code is a separate chunk, not that it is fetched later.
- **With Inertia SSR on, a `lazy` boundary ships its fallback in the server-rendered HTML.** Inertia
  renders with `renderToString`, and react.dev is explicit: if a component suspends — "for example,
  because it's defined with `lazy`" — `renderToString` will not wait, and "the content will not
  appear until the client code loads." So applied to something above the fold, this rule moves LCP
  the *wrong* way: the first paint contains a skeleton where the real content used to be. Inertia 3
  runs SSR automatically in development, so you will see this locally.

Use it for what is genuinely below the fold or behind an interaction — an editor, a chart, a modal's
contents. For a component the first screen shows, leave it statically imported and reduce its cost
some other way. `inertia-rails-ssr` covers turning SSR on and off, in its "SSR setup with
`@inertiajs/vite`" and "Turning SSR off for some pages" sections.

Reference: [React lazy](https://react.dev/reference/react/lazy)
