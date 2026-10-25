---
title: Use React DOM Resource Hints
impact: HIGH
impactDescription: reduces load time for critical resources
tags: rendering, preload, preconnect, prefetch, resource-hints
---

## Use React DOM Resource Hints

**Impact: HIGH (reduces load time for critical resources)**

React DOM provides APIs to hint the browser about resources it will need. Call them in a persistent layout, so each hint fires once per app load rather than once per page visit.

- **`prefetchDNS(href)`**: Resolve DNS for a domain you expect to connect to
- **`preconnect(href)`**: Establish connection (DNS + TCP + TLS) to a server
- **`preload(href, options)`**: Fetch a resource (stylesheet, font, script, image) you'll use soon
- **`preloadModule(href)`**: Fetch an ES module you'll use soon
- **`preinit(href, options)`**: Fetch and evaluate a stylesheet or script
- **`preinitModule(href)`**: Fetch and evaluate an ES module

**Example (preconnect to third-party APIs):**

```tsx
import { preconnect, prefetchDNS } from 'react-dom'

export default function App() {
  prefetchDNS('https://analytics.example.com')
  preconnect('https://api.example.com')

  return <main>{/* content */}</main>
}
```

**Example (preload critical fonts and styles):**

```tsx
import { preload, preinit } from 'react-dom'

export function AppLayout({ children }: { children: React.ReactNode }) {
  // Preload font file
  preload('/fonts/inter.woff2', { as: 'font', type: 'font/woff2', crossOrigin: 'anonymous' })

  // Fetch and apply critical stylesheet immediately
  preinit('/styles/critical.css', { as: 'style' })

  return <div className="min-h-screen">{children}</div>
}
```

**`preloadModule` and `preinitModule` need a URL you cannot write by hand here.** Vite's
output is content-hashed and resolved through its manifest — which is why
`vite_javascript_tag` calls into the manifest rather than emitting a literal path — so
`preloadModule('/dashboard.js')` names a file that does not exist and the hint 404s. The
cases you would have reached for it in are already covered:

- **A component's own chunk:** `void import('./monaco-editor')` in a hover handler. The
  specifier is resolved at build time, so the hashed URL is correct. See
  `rules/bundle-preload.md`.
- **A static import's chunk:** `vite_preload_tag` already emits `modulepreload` links, with
  early hints, for everything the entrypoint statically imports.

- **The next page:** that is a props fetch, not a module fetch — `<Link prefetch>`, owned by
  `inertia-rails-pages`, in its "`<Link>` and `router`" section. Note also that a plain
  `<a href>` in an Inertia app is a full
  document reload; use `<Link>`.

**When to use each:**

| API | Use case |
|-----|----------|
| `prefetchDNS` | Third-party domains you'll connect to later |
| `preconnect` | APIs or CDNs you'll fetch from immediately |
| `preload` | Critical resources needed for current page — fonts, images, a stylesheet |
| `preinit` | A stylesheet or script that must execute early |
| `preloadModule` / `preinitModule` | An ES module at a URL you control; not Vite's hashed output |

All six exist in the installed `react-dom` 19.2.8. The two module hints are the ones this
stack rarely has a use for; `preconnect`, `prefetchDNS`, `preload` and `preinit` are the
ones that earn their place, because a third-party origin or a font path is a literal you do
write by hand.

Reference: [React DOM Resource Preloading APIs](https://react.dev/reference/react-dom#resource-preloading-apis)
