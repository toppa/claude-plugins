---
title: Avoid Barrel File Imports
impact: MEDIUM
impactDescription: keeps a library's unused modules out of the graph Vite has to analyse
tags: bundle, imports, tree-shaking, barrel-files, performance
---

## Avoid Barrel File Imports

Import each symbol from its own path rather than through a library's barrel file:

```tsx
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
```

A **barrel file** is an entry point that re-exports its siblings (`export * from './module'`). An
icon or component library's barrel can name thousands of modules, so importing one symbol through it
puts the whole set into the graph the bundler has to resolve and analyse.

**Vite has no equivalent of the Next.js `optimizePackageImports` transform**, which rewrites barrel
imports at build time. That is the reason this rule is yours to apply by hand here rather than
something the toolchain does for you, and it is the line in this file that matters most.

**Module counts and dev-server timings from Next.js write-ups do not transfer.** Those are webpack
dev-server measurements, and Vite's dependency pre-bundling exists specifically to remove that class
of cost: it converts a package's many internal modules into a single pre-bundled artefact served as
one request. The "marked as external, so the bundler cannot optimise it" argument is likewise about
a server bundle and has no analogue in a Vite client build. What survives in this stack is the
graph-analysis cost and the tree-shaking
uncertainty, which is real but which nobody has measured here — so no number is quoted. If you want
one for your app, run `vite build` with `--profile` and compare.

> **TypeScript warning:** Some libraries (notably `lucide-react`) don't ship `.d.ts` files for their deep import paths. Importing from `lucide-react/dist/esm/icons/check` resolves to an implicit `any` type, causing errors under `strict` or `noImplicitAny`. Verify that the library exports types for its subpaths before you use direct imports.

Libraries commonly affected: `lucide-react`, `@mui/material`, `@mui/icons-material`, `@tabler/icons-react`, `react-icons`, `@headlessui/react`, `@radix-ui/react-*`, `lodash`, `ramda`, `date-fns`, `rxjs`, `react-use`.

Reference: [How we optimized package imports in Next.js](https://vercel.com/blog/how-we-optimized-package-imports-in-next-js)
