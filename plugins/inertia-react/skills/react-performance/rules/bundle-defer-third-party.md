---
title: Defer Non-Critical Third-Party Libraries
impact: MEDIUM
impactDescription: moves the vendor code into its own chunk
tags: bundle, third-party, analytics, defer
---

## Defer Non-Critical Third-Party Libraries

Analytics, logging, and error tracking do not block user interaction, so give each one its
own chunk behind `lazy`. What you buy is chunk separation. `lazy` starts the import during
the render pass that reaches the component, not after hydration.

**Incorrect (blocks initial bundle):**

```tsx
import { Analytics } from 'analytics-vendor/react'

export function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div>
      {children}
      <Analytics />
    </div>
  )
}
```

**Correct (its own chunk):**

```tsx
import { lazy, Suspense } from 'react'

const Analytics = lazy(() =>
  import('analytics-vendor/react').then(m => ({ default: m.Analytics }))
)

export function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div>
      {children}
      <Suspense fallback={null}>
        <Analytics />
      </Suspense>
    </div>
  )
}
```

The layout is a persistent Inertia layout, so this import runs once per app load rather
than once per page visit.

`fallback={null}` is doing real work here, and it is why analytics is a good fit for this rule
where a visible component is not. With Inertia SSR on, `renderToString` does not wait for a
suspended `lazy` component — so whatever the fallback is goes into the server-rendered HTML. For
analytics the fallback is nothing, so nothing is lost. For a component the user looks at, see the
SSR note in `rules/bundle-dynamic-imports.md` before applying the same pattern.
