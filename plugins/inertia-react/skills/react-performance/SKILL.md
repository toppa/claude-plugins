---
name: react-performance
description: >-
  Fifty-six client-side React performance rules from Vercel Engineering, one per file,
  across seven areas: a component's own imports and `lazy` chunks, wasted re-renders,
  render and layout work, browser storage and DOM events, promise waterfalls, hot-path
  JavaScript, and stable-callback patterns.
when_to_use: >-
  Use when a component re-renders more than it needs to, when a component's own imports grow
  the bundle, when scrolling or typing feels janky, when a long list is slow to paint, when a
  touch or wheel listener delays a scroll, when reading or writing localStorage, when
  independent promises run one after another, or when a callback inside an effect sees a stale
  value. Read the one rule file that matches the symptom. This skill owns one component's own
  imports and `lazy` chunks. For splitting the bundle across pages, a
  large prop payload, or which prefetch cache tags a write invalidates, use the
  `inertia-react:inertia-rails-performance` skill; for the prefetch API itself — `<Link
  prefetch>`, `cacheFor`, `router.prefetch` — use the `inertia-react:inertia-rails-pages`
  skill. Query and response time belong to Rails.
license: MIT
metadata:
  upstream_repo: vercel-labs/agent-skills
  upstream_path: skills/react-best-practices/
  upstream_ref: 7c180d9044c9ae2b442b567aad4e42a28dd5ed62
  synced: 2026-08-08
  verified_against: >-
    React 19.2.8, react-dom 19.2.8, "@types/react" 19.2.17,
    "@inertiajs/react" 3.6.1, "@inertiajs/core" 3.6.1, Vite 8.1.5,
    vite_rails 3.11.1, TypeScript 7.0.2, node 24.3.0
---

# React Performance

Client-side performance rules for React, from Vercel Engineering. Fifty-six rules in seven
categories.

## The stack these rules run in

Rails serves the page. Inertia carries the data. React renders it. Vite builds it. There
are no React Server Components, no `next/*` module, and no route handler in JavaScript.

Five consequences shape how you read every rule below:

1. **Data arrives as props from a Rails controller.** The component does not fetch it.
2. **Server-side performance is a Rails problem.** A slow screen that waits on the server
   is fixed in the controller, the model, or the query — not in the component tree.
   `inertia-rails-performance` covers the Inertia half of that.
3. **Inertia owns forms.** `inertia-rails-forms` says `<Form>` with `defaultValue` and
   `defaultChecked`, because `reset()` and `defaults()` write straight to the DOM elements,
   which React undoes on its next render whenever the value is bound to React state.
   Controlled inputs are `useForm`'s model, not `<Form>`'s.
   `rules/rerender-use-deferred-value.md` shows a controlled search input as
   exemplary code. That example is about a search box, not a form. Where the two meet,
   Inertia wins.
4. **Code splitting is a Vite concern.** Use `React.lazy` and `Suspense`. There is no
   `next/dynamic` here. **This skill owns one component's own imports; splitting and
   invalidating chunks across pages belongs to `inertia-rails-performance`.** So a `lazy`
   boundary or a direct import path inside a component is a question for the `bundle-` rules
   here; how pages are chunked, prefetched and invalidated as a set is a question for that
   skill.
5. **`usePage()` subscribes the component to every visit.** `usePage` is
   `use(PageContext)`, and the provider's value is a fresh page object per visit, so a
   component calling it re-renders on every navigation whether or not the prop it reads
   changed. This is the largest avoidable re-render source in this stack and it does not
   look like a subscription. `rules/rerender-defer-reads.md` has the detail.

Upstream ships fourteen more rules that assume a Next.js server, including a whole
Server-Side Performance category. This copy deletes all fourteen, which is why the count here
is 56 and upstream's is 70.

## Rule Categories by Priority

Priority is reading order for a component you are reviewing cold, and it mostly tracks worst
case: the earlier categories contain the rules whose worst case is largest. Two categories sit
out of that order. `async-` is fifth despite holding the two CRITICAL rules, for the reason
stated below the table. `client-` is fourth at MEDIUM, above the fourteen `js-` rules; it is
two rules long, so the order costs a cold reader little either way. The Impact column is the range of the
`impact:` values in that category's own rule files, so it is a summary of them rather than a
separate claim — and nothing parses either value.

| Priority | Category | Impact | Rules | Prefix |
|----------|----------|--------|-------|--------|
| 1 | Bundle Size Optimization | HIGH–MEDIUM | 6 | `bundle-` |
| 2 | Re-render Optimization | HIGH–LOW | 15 | `rerender-` |
| 3 | Rendering Performance | HIGH–LOW | 11 | `rendering-` |
| 4 | Browser Storage and Events | MEDIUM | 2 | `client-` |
| 5 | Eliminating Waterfalls | CRITICAL–HIGH | 4 | `async-` |
| 6 | JavaScript Performance | HIGH–LOW | 14 | `js-` |
| 7 | Advanced Patterns | LOW-MEDIUM–LOW | 4 | `advanced-` |

**Why `async-` is fifth despite holding the two CRITICAL rules.** Its subject is a promise
waterfall, and in this stack the requests that would form one are made by Rails, in Ruby,
where `inertia-rails-performance` and the Rails skills apply. The category earns its place for
client-side promise work — several `import()` calls, a batch of browser API calls — which is
real but uncommon. Read it when you are looking at consecutive `await`s in a `.tsx` file, and
skip it otherwise. The `impact:` values inside the files are upstream's, written for a
Next.js route handler; they are accurate there and overstated here.

## Quick Reference

### 1. Bundle Size Optimization (HIGH–MEDIUM)

- `bundle-dynamic-imports` - `React.lazy` a heavy component into its own chunk, and know what
  it costs under SSR
- `bundle-analyzable-paths` - Keep a dynamic `import()` resolvable at build time
- `bundle-conditional` - Load a non-component module when its feature switches on
- `bundle-barrel-imports` - Import by direct path; Vite has no `optimizePackageImports`
- `bundle-preload` - Fetch a chunk on hover or focus
- `bundle-defer-third-party` - Load analytics after hydration

### 2. Re-render Optimization (HIGH–LOW)

- `rerender-no-inline-components` - Declare components at module scope, not inside a component
- `rerender-defer-reads` - Read a callback-only value in the callback; and `usePage()` fanout
- `rerender-memo` - Extract expensive work into a memoized component
- `rerender-derived-state` - Subscribe to a derived boolean, not a continuous value
- `rerender-derived-state-no-effect` - Derive during render rather than in an effect
- `rerender-dependencies` - Depend on primitives, not on objects
- `rerender-functional-setstate` - `setX(prev => …)` for a stable callback
- `rerender-lazy-state-init` - Pass a function to `useState` for an expensive initial value
- `rerender-split-combined-hooks` - Split a hook whose dependencies are independent
- `rerender-move-effect-to-event` - Put interaction logic in the event handler
- `rerender-transitions` - `startTransition` for a slow, non-urgent update
- `rerender-use-deferred-value` - Defer an expensive derived render; needs `memo` to work
- `rerender-use-ref-transient-values` - A ref for a value whose only destination is a style
- `rerender-simple-expression-in-memo` - Do not `useMemo` a primitive expression
- `rerender-memo-with-default-value` - Hoist a non-primitive default for a stable identity

### 3. Rendering Performance (HIGH–LOW)

- `rendering-content-visibility` - `content-visibility` for a long list, with its containment caveat
- `rendering-script-defer-async` - `defer` or `async` on a hand-written script tag
- `rendering-resource-hints` - `preconnect`, `prefetchDNS`, `preload`, `preinit`
- `rendering-activity` - `<Activity>` to preserve state across a toggle, and its effect teardown
- `rendering-hydration-no-flicker` - A client-only value that must not flash; try a shared prop first
- `rendering-hydration-suppress-warning` - Suppress a mismatch you expect
- `rendering-usetransition-loading` - `useTransition` for a client-side expensive update
- `rendering-hoist-jsx` - Hoist a static element, without dissolving a component
- `rendering-conditional-render` - Compare, do not rely on truthiness, when the value is a number
- `rendering-svg-precision` - Reduce SVG precision; name an output file
- `rendering-animate-svg-wrapper` - Unverified; measure before applying

### 4. Browser Storage and Events (MEDIUM)

- `client-passive-event-listeners` - Passive listeners on a scroll container
- `client-localstorage-schema` - Version the key and store only what the UI needs

### 5. Eliminating Waterfalls (CRITICAL–HIGH)

- `async-parallel` - `Promise.all` for independent operations
- `async-dependencies` - Chain promises to parallelise a partial dependency
- `async-defer-await` - Move an `await` past a guard that usually short-circuits
- `async-cheap-condition-before-await` - Test a synchronous condition before awaiting

### 6. JavaScript Performance (HIGH–LOW)

- `js-batch-dom-css` - Batch the style writes, then take the layout reads
- `js-tosorted-immutable` - Sort into a new array, never in place; and the `lib: ES2023` requirement
- `js-index-maps` - Index into a `Map` instead of `.find()` in a loop
- `js-request-idle-callback` - Schedule work nobody is waiting for
- `js-set-map-lookups` - A `Set` for repeated membership tests on a long list
- `js-cache-storage` - Cache repeated storage reads; split cookies on the first `=`
- `js-hoist-regexp` - Hoist a pattern, minding `/g`'s `lastIndex`
- `js-combine-iterations` - One pass instead of three, at a readability cost
- `js-early-exit` - Return when the answer is known, and report the first cause
- `js-min-max-loop` - A loop rather than a sort, and the spread-argument limit
- `js-length-check-first` - Compare lengths first; and why `sort().join()` is wrong
- `js-flatmap-filter` - `flatMap` for clarity, not for speed
- `js-cache-function-results` - Cache a pure result when the key space is bounded
- `js-cache-property-access` - Name an invariant; do not hoist `arr.length`

Two of these are asymptotic wins that grow with your data — `js-index-maps` and
`js-set-map-lookups`. One is neither: `js-batch-dom-css` is the category's only `impact: HIGH`
rule, and a forced synchronous reflow is measurable at any list length. The other eleven are
constant-factor rules whose effect on a list of a few dozen rows is unmeasurable; each says so
in its own file.

### 7. Advanced Patterns (LOW-MEDIUM–LOW)

- `advanced-init-once` - Initialise once per app load, not per mount
- `advanced-effect-event-deps` - Keep a `useEffectEvent` result out of the dependency array
- `advanced-event-handler-refs` - `useEffectEvent` for a subscription whose handler changes
- `advanced-use-latest` - The same hook applied to a debounce

## How to Use

Read the one rule file that matches the symptom you have:

```
rules/rerender-defer-reads.md
rules/bundle-dynamic-imports.md
```

Each file states the form to write, why it helps, and where the rule stops applying. Where a
rule quotes a measurement, it names the engine, the input size and what the number is for; where
the justification is asymptotic it says so instead of quoting a multiple.

## Related Skills

| Need | Skill |
|---|---|
| Large payload, bundle splitting across pages, prefetch cache invalidation, server-side pagination props | `inertia-rails-performance` |
| `<Link prefetch>`, `cacheFor`, `router.prefetch`, `<InfiniteScroll>` | `inertia-rails-pages` |
| Form state, uncontrolled inputs, `<Form>` versus `useForm` | `inertia-rails-forms` |
| Component API design, boolean props, compound components | `react-composition` |
| Turning SSR on or off, and what it changes | `inertia-rails-ssr` |
