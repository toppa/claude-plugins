---
name: inertia-rails-pages
description: >-
  React page components for Inertia — persistent, nested and named layouts,
  `setLayoutProps`, `<Link>` and `router` navigation, prefetching in full
  (`<Link prefetch>`, `cacheFor`, cache tags, `router.prefetch`),
  `router.replaceProp`, URL-driven UI state, flash access, and the
  `<Deferred>`, `<WhenVisible>`, and `<InfiniteScroll>` components.
when_to_use: >-
  Use when you build or review a page component, add navigation, add or nest a
  persistent layout, pass a page's own value such as a title up to its layout,
  prefetch a link, drive a dialog or a tab from the URL, refresh data without
  navigating, or lazy-load a section of a page. Also use it when flash reads as
  undefined, or when a page renders with the wrong layout or with none at all.
  This skill owns the prefetch API itself; for invalidating that cache across pages
  after a write, use the `inertia-react:inertia-rails-performance` skill. When a page
  must be accessible — WCAG, a screen reader, keyboard order, contrast — its Related
  Skills section names the accessibility skill the user can invoke.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-pages/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, "@inertiajs/react" 3.6.1, "@inertiajs/core" 3.6.1,
    React 19.2.8, "@types/react" 19.2.17, TypeScript 7.0.2, Rails 8.1.3.1
---

# Inertia Rails Pages

**The five rules the rest of this skill rests on:**
- The controller is the source of URL state. It reads `params` and passes them as props; the component derives from those props, and `router.get` with new query params is what changes them.
- Flash is a top-level key on the page object, a sibling of `props`: read it as `usePage().flash`.
- `<Deferred>`'s render function receives `{ reloading }`. The deferred data itself comes from `usePage()`.
- A persistent layout is assigned to `Page.layout`, or supplied for every page by `createInertiaApp`'s `layout` option.
- One prop, one purpose: send the columns the page renders, because every prop of the first response is serialized into the HTML document.

## Page Component Structure

Pages are default exports receiving controller props as function arguments.

```tsx
type Props = {
  posts: Post[]
}

export default function Index({ posts }: Props) {
  return <PostList posts={posts} />
}
```

Declare `Props` as a `type` alias rather than an `interface`; `inertia-rails-typescript`
holds the TS2344 reason, in its "`type` vs `interface` for page props" section.

## Persistent Layouts

A layout assigned to `Page.layout` persists across navigations — it does not remount, so
scroll position, audio playback and component state survive.

```tsx
import { AppLayout } from '@/layouts/app-layout'

export default function Show({ course }: Props) {
  return <CourseContent course={course} />
}

// Single layout
Show.layout = (page: React.ReactNode) => <AppLayout>{page}</AppLayout>
```

A page passes data **up** to its layout with `setLayoutProps`. This is a plain function,
not a hook, so call it in the component body:

```tsx
import { setLayoutProps } from '@inertiajs/react'

export default function Show({ course }: Props) {
  setLayoutProps({ title: course.name, showSidebar: false })
  return <CourseContent course={course} />
}
```

Inertia clears those values itself on any navigation that does not preserve state.

Default layout for every page, set once in the entrypoint:

```tsx
// app/frontend/entrypoints/inertia.tsx
void createInertiaApp({
  pages: '../pages',
  layout: (name) => (name.startsWith('auth/') ? null : AppLayout),
})
```

**A page opts out of the default by returning `null` from that option for its
name.** `Page.layout = null` does not opt out: the adapter resolves
`Page.layout ?? layoutOption(…)`, so `null` falls through to the default.

Nested layouts (`Page.layout = [SiteLayout, DocsLayout]`), named layouts and the
array form an arrow-function layout needs are in
[`references/layouts.md`](references/layouts.md).

## Navigation

### `<Link>` and `router`

Internal navigation is `<Link href="...">`, and programmatic navigation is
`router.get/post/patch/delete`. The features worth knowing:

```tsx
// Prefetching — preloads page data on hover after 75ms
<Link href="/users" prefetch>Users</Link>
<Link href="/users" prefetch cacheFor="30s">Users</Link>

// Prefetch with cache tags — invalidate together after a mutation
<Link href="/users" prefetch cacheTags="users">Users</Link>

// Programmatic prefetch (e.g., likely next destination)
router.prefetch('/settings', {}, { cacheFor: '1m' })

// Partial reload — refresh specific props without navigation
router.reload({ only: ['users'] })

// Partial reload from a page that is showing validation errors
router.reload({ only: ['users'], preserveErrors: true })
```

**Every `router` write helper takes the payload as its second argument**:
`router.post('/users', formData)`, and visit options third. `useForm`'s helpers
are the ones that take options second, because the form holds the payload
already. Passing `{ data: formData }` to `router.post` type-checks and sends a
field named `data`, one level too deep, with no error at build or run time.
`router.delete` is the one exception: it carries no payload, so its visit options
move up to second.

`preserveErrors` earns its place because `rails generate inertia:install` sets
`config.always_include_errors_hash = true`: every response then carries an `errors`
hash wrapped in `InertiaRails.always`, which a partial reload cannot exclude, and the
empty hash clears the errors on screen. Inertia passes it for you on deferred loads,
`<WhenVisible>` and `<InfiniteScroll>` — pass it yourself on a hand-fired reload.

### Client-Side Prop Helpers

Update props without a server round-trip:

```tsx
import type { SharedPageProps } from '@inertiajs/core'

// Replace a single prop (dot notation supported)
router.replaceProp('show_modal', false)
router.replaceProp('user.name', 'Jane Smith')

// With a callback — annotate the parameters
router.replaceProp('count', (current: unknown) => (current as number) + 1)

// Append/prepend to array props
router.appendToProp('messages', { id: 4, text: 'New' })
router.prependToProp('notifications', (current: unknown, props: SharedPageProps) => ({
  id: Date.now(),
  message: `Hello ${props.auth.user?.name}`,
}))
```

`unknown` absorbs the value's union type, so there is no signature to infer the
callback's parameters from: annotate them or every one is `TS7006`.

These are shortcuts to `router.replace()` with `preserveScroll` and `preserveState`
automatically set to `true`. They fit a client-only change — a modal toggle, a counter;
`router.reload` is the one that brings fresh data back from the server.

## URL-Driven State (Dialogs, Tabs, Filters)

A dialog, a tab or a filter is server state: the controller reads `params` and sends the
value as a prop, the component derives its UI from that prop, and `router.get(url, params,
{ preserveState: true, preserveScroll: true })` is what changes it.

The cycle is URL → server → props → render: `router.get('/users', { user_id: 5 })` → the
controller runs with `params[:user_id] = 5` → new props arrive with `selected_user_id: 5` →
the dialog renders open. Reading the URL in the component adds a second copy that drifts.

A prop the page never renders is published anyway: `render inertia: { users: User.all }`
puts `password_digest`, internal flags and soft-delete timestamps in view-source while the
TypeScript type still reads `users: User[]`. Name the columns in a private `serialize_x`, as
the gem's scaffold does. Prop shapes and wrappers are `inertia-rails-controllers`', in its
"Prop Types" and "Serializing Props" sections.

The full worked pair — the controller action and the dialog component — is in
[`references/navigation.md`](references/navigation.md), section "URL-driven state".

## Shared Props and Flash

A page's `type Props` names only the page's own props. Shared props and flash are typed
globally through the `InertiaConfig` augmentation, and without it `props.auth` is `unknown`
and `flash` is `{}`, so the reads fail to compile rather than merely losing autocomplete —
`inertia-rails-typescript` owns that setup.

Read flash at `usePage().flash.notice` / `.alert`. Which keys are forwarded is `flash_keys`,
in `inertia-rails-controllers`.

## `<Deferred>` Component

Renders `fallback` until the deferred props arrive. `fallback` is required — the
component throws without it.

Children may be a plain `ReactNode` or a render function, which receives
`{ reloading }` — `true` while a partial reload of one of the same props is in
flight. The deferred data itself comes from `usePage()`, not from that argument.

```tsx
import { Deferred } from '@inertiajs/react'

export default function Dashboard({ basic_stats }: Props) {
  return (
    <>
      <QuickStats data={basic_stats} />
      <Deferred data="detailed_stats" fallback={<Spinner />}>
        {({ reloading }) => <DetailedStats dimmed={reloading} />}
      </Deferred>
    </>
  )
}
```

`fallback` shows on the first load only: a later partial reload leaves the current
content on screen and flips `reloading`, so this state needs no hand-rolled
`router`-event indicator.

`rescue` renders instead of the children when the server reported that prop failed,
which is what `InertiaRails.defer(rescue: true) { … }` enables. Without `rescue`, a
failed prop leaves `fallback` on screen forever.

## `<InfiniteScroll>` Component

Automatic infinite scroll — loads next pages as user scrolls down. Pairs with
`InertiaRails.scroll` on the server (see `inertia-rails-controllers`).

**`data` takes the prop name as a string, not the array itself.**

```tsx
import { InfiniteScroll } from '@inertiajs/react'

export default function Index({ posts }: Props) {
  return (
    <InfiniteScroll data="posts" loading={() => <Spinner />}>
      {posts.map(post => <PostCard key={post.id} post={post} />)}
    </InfiniteScroll>
  )
}
```

Props: `data` (prop name), `loading` (fallback), `manual` (button instead of auto),
`manualAfter={3}` (auto for first 3 pages, then button), `preserveUrl` (don't update URL).

For the server side of a paginated list, see `inertia-rails-performance`, its "Server-side
pagination props" section.

## `<WhenVisible>` Component

Loads data when the element enters the viewport — for a **lazy section** such as comments or
related items. An endless list is `<InfiniteScroll>`'s job instead.

```tsx
import { WhenVisible } from '@inertiajs/react'

<WhenVisible data="comments" fallback={<Spinner />}>
  <CommentsList />
</WhenVisible>
```

Its children may also be a render function, receiving `{ fetching }`.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Layout remounts on every navigation | Layout markup returned from the page's own JSX | Assign it to `Page.layout` |
| Page renders with the default layout after `Page.layout = null` | `null` falls through to the default | Return `null` for that page name from `createInertiaApp`'s `layout` option |
| Page body disappears inside a layout | Layout is a bare arrow-function component, which Inertia reads as a render function | Wrap it: `Page.layout = [Layout]` |
| `Deferred` children never render | `fallback` missing, or the prop is being rescued with no `rescue` given | `fallback` is required; add `rescue` for `defer(rescue: true)` props |
| Flash is `undefined` | Reading `usePage().props.flash` | Flash is top-level: `usePage().flash` |
| A `router.post` body arrives nested under `data` | Payload passed in the options slot | The payload is the second argument: `router.post(url, formData)` |
| URL state lost on navigation | UI state held in the component instead of the URL | Derive from props — controller reads `params` and passes as prop |
| `WhenVisible` never triggers | Element not in viewport or prop name wrong | `data` must match a prop name the controller provides on partial reload |
| Component state resets on `router.get` | Missing `preserveState: true` | Add `preserveState: true` to visit options for filter/sort/tab changes |
| Scroll jumps to top after form submit | Missing `preserveScroll` | Add `preserveScroll: true` to the visit or form options |
| `TS7006` on a `replaceProp` callback parameter | `unknown` absorbs the union, so there is nothing to infer from | Annotate the parameters |

## Related Skills
- **Flash config, prop wrappers, `InertiaRails.defer`, history encryption** → `inertia-rails-controllers`
- **Shared props typing (`InertiaConfig`)** → `inertia-rails-typescript`
- **`router.flash()`, client-side visits** → `inertia-rails-architecture`
- **Cross-page cache invalidation after a mutation, pagination, bundle splitting across pages** → `inertia-rails-performance`
- **A WCAG audit of the markup a page renders** → `rails-core:accessibility-review`, whose
  "Client-Side Navigation (Inertia)" section covers `<Head title>` per page and the polite live
  region that announces a `router` visit, and whose "Most Common Failures & Fixes" section covers
  contrast, target size and focus visibility. It is user-invoked only, so name it for the user to
  run and carry on with the page.

Prefetching itself — `<Link prefetch>`, the three modes, `cacheFor`, cache tags,
`router.prefetch`, `router.flush` — is this skill's, in `references/navigation.md`.

## References

The examples above cover `<Link>`, the `router` calls for a visit, a prefetch, a reload and a
prop rewrite, and a single-level layout. These two files are for the branches beyond that.

**MANDATORY — READ ENTIRE FILE** when implementing event callbacks (`onBefore`,
`onStart`, `onProgress`, `onFinish`, `onCancel`, `onHttpException`,
`onNetworkError`), prefetching beyond a bare `prefetch` prop, URL-driven state, or a
redirect to an external URL:
[`references/navigation.md`](references/navigation.md) (~390 lines) — full
callback and global-event list, the whole prefetch cache API, the URL-driven dialog, and
`inertia_location`.

**MANDATORY — READ ENTIRE FILE** when implementing nested layouts, named
layouts, conditional layouts, layout-level data sharing, or scroll regions:
[`references/layouts.md`](references/layouts.md) (~285 lines) — nested and named
layout patterns, layout props, the `layout` option, and scroll regions.
