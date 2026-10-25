---
name: inertia-rails-architecture
description: >-
  The router for Inertia Rails and React work — a decision matrix that maps a need
  (page data, global data, flash, forms, navigation, data refresh, a non-page request,
  real time) to its server-driven Inertia answer, plus eleven rules ranked by impact.
when_to_use: >-
  Use first, before any other Inertia skill, when you add or change a page component
  under `app/frontend/pages`, wire a Rails action to a React screen, or decide where a
  piece of state lives. Also use it when you weigh a React or SPA habit against the
  Inertia equivalent.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-architecture/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, "@inertiajs/react" 3.6.1, "@inertiajs/core" 3.6.1,
    React 19.2.8, "@types/react" 19.2.17, TypeScript 7.0.2, Vite 8.1.5,
    Rails 8.1.3.1
---

# Inertia Rails Architecture

The stack is `inertia_rails` 3, `@inertiajs/react` 3, React 19, and Vite. Inertia 3
drops React 18, so React 19 is a floor rather than a preference. This file carries no code:
the examples are in the two reference files, and every TypeScript block in them compiles
under TypeScript 7.0.2 in `strict` mode against `@inertiajs/*` 3.6.1.

## The Core Mental Model

The server owns routing, data and authentication; React receives data as props and
renders it. There is no client-side router, no global state store, and no API layer.

**Before building any feature, ask who owns the state.** In the URL or the database → the
server owns it, so it arrives as a prop. Ephemeral UI → React owns it, so `useState`. A
React or SPA habit → the matrix below names Inertia's server-driven equivalent.

## Decision Matrix

| Need | Use this |
|------|----------|
| Page data from server | Controller props |
| Global data (auth, config) | `inertia_share` + `usePage().props` |
| Flash messages / toasts | Rails `flash` + `usePage().flash` |
| Form submission | The `<Form>` component, or `useForm` for programmatic control |
| Navigate between pages | `<Link>` / `router.visit` |
| Refresh specific data | `router.reload({ only: [...] })` |
| A request that returns data, not a page | `useHttp` |
| Expensive server data | `InertiaRails.defer` |
| Data only some visits need | `InertiaRails.optional` |
| Infinite scroll | `InertiaRails.scroll` + `<InfiniteScroll>` |
| Stable reference data | `InertiaRails.once` |
| Real-time updates (core feature) | ActionCable + `router.reload` |
| Simple polling (MVP/prototyping) | `usePoll` — it throttles itself in a background tab |
| URL-driven UI state (dialogs, tabs) | Controller reads `params` → prop, `router.get` to update |
| Ephemeral UI state | `useState` / `useReducer` |
| Non-browser consumer | A dedicated API endpoint — see "When you do need a separate API" |

Every entry in the right column rides Inertia's own HTTP client — `XhrHttpClient` by
default, with `axiosAdapter` as an opt-in. That client is what attaches the CSRF token,
follows the redirect, and maps a 422 into `errors`, so `<Form>`, `useForm`, `router` and
`useHttp` get all three for free. Anything built on a bare `fetch` or a second `axios`
instance owes you all three, and CSRF is the one it usually misses.

### Three choices that are genuinely close

**Toast versus standing banner.** `flash` clears after one response, so it fits
"User created!". A shared prop persists until you change it, so it fits "Your trial ends
Friday".

**Where `flash` lives.** A top-level key on the page object, a **sibling of `props`** —
`usePage().flash`. `router.flash('notice', '…')` writes that same key from the browser, for
a message with no server round trip. The other page-object siblings are listed in
`inertia-rails-typescript`, section "Where each value lives on the page object".

**`inertia_share` versus React Context.** Server-owned data every page reads — the signed-in
user, feature flags, the plan — belongs in `inertia_share`. Client-only state that siblings
share — a drag target, a wizard step — lifts to their closest common parent, and Context is the
fallback when lifting gets unwieldy. Rare here, because Inertia pages are shallow.

## Rules (by impact)

| # | Impact | Rule | WHY |
|---|--------|------|-----|
| 1 | CRITICAL | Take page data from controller props | Inertia re-renders the full component on navigation; a `useEffect` fetch creates a second data lifecycle that drifts from props and causes stale UI |
| 2 | CRITICAL | Gate access in the controller, and let React trust the props it receives | The server is the only place a check cannot be bypassed; if the component renders at all, the request already passed the gate |
| 3 | CRITICAL | Submit with `<Form>` or `useForm` | Both handle CSRF, redirect-following, error mapping, file detection, and history state |
| 4 | HIGH | Navigate with `<Link>` and `router` | They swap the page component in place; an `<a>` or a `window.location` assignment is a full document load, which discards React state and remounts the layout |
| 5 | HIGH | Refresh data with a partial reload | `router.reload({ only: [...] })` re-runs one prop against the same page-based cache and version that every other visit uses |
| 5b | HIGH | Reach for `usePoll` on an MVP and ActionCable in production | `usePoll` hits the server on every interval whether or not anything changed; ActionCable pushes only on an actual change |
| 6 | HIGH | Put server-owned global data in `inertia_share` | A shared prop is computed per request and participates in partial reloads |
| 7 | HIGH | Raise one-time notifications through Rails `flash` | `flash` clears after one response, so the toast cannot reappear on the next navigation |
| 8 | MEDIUM | Wrap an expensive query in `InertiaRails.defer` or `InertiaRails.optional` | The first paint then waits on the fast props only, and the slow one arrives in a follow-up request |
| 9 | MEDIUM | Set the layout once, so it persists across navigations | A layout that remounts loses scroll position, audio playback, and open WebSocket connections |
| 10 | MEDIUM | Keep page components as renderers and give child components their data as props | A component that fetches is hard to test and cannot participate in Inertia's version and cache handling |

## Skill Map

| Workflow | Skills |
|----------|--------|
| New page with props | `inertia-react:inertia-rails-controllers` + `inertia-react:inertia-rails-pages` + `inertia-react:inertia-rails-typescript` |
| Form with validation | `inertia-react:inertia-rails-forms` + `inertia-react:inertia-rails-controllers` |
| Flash toasts | `inertia-react:inertia-rails-controllers` + `inertia-react:inertia-rails-pages` |
| Deferred or lazy data | `inertia-react:inertia-rails-controllers` + `inertia-react:inertia-rails-pages` |
| URL-driven dialog or tabs | `inertia-react:inertia-rails-controllers` + `inertia-react:inertia-rails-pages` |
| Prefetching a link, and its cache duration and tags | `inertia-react:inertia-rails-pages` |
| Long list, pagination, large payload, cross-page cache invalidation | `inertia-react:inertia-rails-performance` |
| Indexable HTML, SEO, Open Graph tags | `inertia-react:inertia-rails-ssr` |
| Request specs for an Inertia action | `inertia-react:inertia-rails-testing` |

Invoke a skill by the scoped name in that column. The `frontend` agent already holds
`-controllers`, `-pages`, `-forms` and `-typescript` in context and applies them from there.

## References

Read [`references/decision-trees.md`](references/decision-trees.md) (~145 lines) when the
matrix above leaves the choice open — it holds flowcharts for where a value lives, how to
update it, where component state belongs, whether to prefetch, poll, defer or use ActionCable,
how to navigate, how to notify, and where to redirect after a mutation. The prop-type wrappers
themselves are `inertia-react:inertia-rails-controllers`', in its prop-types reference.

Read [`references/rules-expanded.md`](references/rules-expanded.md) (~430 lines) when you
need a rule's full-stack example, or when a reviewer disputes one. It expands each of the
eleven rules above into worked code and the mechanism behind it — controller Ruby where the rule
has a server half, component TypeScript where it is client-only. The one-line rules cover routine
work on their own.

## When you do need a separate API

| Signal | Why | Example |
|--------|-----|---------|
| Non-browser consumer | Inertia's JSON envelope (`component`, `props`, `url`, `version`) is shaped for the frontend adapter, and nothing else can read it | Mobile API, CLI tools, payment webhooks |
| Large-dataset search | The dataset is too big to send as a prop and each keystroke needs server filtering. Drive it with `useHttp`, which returns `{ data, setData, response, processing, errors, cancel }` and shares Inertia's client — then let a `<Link>` or `router.visit` handle what the reader picks. | City/address autocomplete, postal-code lookup |
| Binary or streaming response | Inertia delivers JSON props only. Use a standard Rails route with a normal download response. | PDF/CSV export, file downloads |
