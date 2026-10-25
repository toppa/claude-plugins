---
title: Prefer Statically Analyzable Paths
impact: HIGH
impactDescription: keeps a dynamic import resolvable at build time
tags: bundle, vite, rollup, esbuild, path
---

## Prefer Statically Analyzable Paths

A dynamic `import()` has to be resolvable at build time. Write a map of import functions, so
every specifier in the bundle is a literal:

```ts
const PAGE_MODULES = {
  home: () => import('./pages/home'),
  settings: () => import('./pages/settings'),
} as const

const Page = await PAGE_MODULES[pageName]()
```

**What `import(variable)` costs here is not a bigger bundle — it is a broken import.** The
webpack cost model (`require.context` pulling in a directory, slower builds, more memory) does
not transfer to Vite. Rollup handles variables in `import()` through
`@rollup/plugin-dynamic-import-vars`, and it only handles a narrow shape: the specifier must
begin with `./`, must end with a file extension, and the variable may span one path segment
only, and the template literal has to sit inside the `import()` call. A specifier held whole in a
variable — `const path = './pages/' + pageName; import(path)` — matches none of that, so you get a
build-time warning and an import that fails at runtime, which is worse than a large chunk because
it survives the build.

**Inertia's own page resolution is the shape that does work, and it is generated for you.**
`@inertiajs/vite` 3.6.1 rewrites `pages: '../pages'` in `createInertiaApp` into a `resolve`
function built on `import.meta.glob` (`dist/index.js:366`). `import.meta.glob` gives Vite a
literal glob to expand at build time, so the resulting map is static even though the page name
is not — the same trick as the map above, written by the plugin. If you need your own
directory-wide map, `import.meta.glob` is the tool, not string concatenation.

Reference: [Vite features](https://vite.dev/guide/features.html), [Rollup dynamic import vars](https://www.npmjs.com/package/@rollup/plugin-dynamic-import-vars)
