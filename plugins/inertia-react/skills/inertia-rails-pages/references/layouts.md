# Layouts — Detailed Reference

Persistent, nested and conditional layout patterns for Inertia.js + React.

Verified against `@inertiajs/react` and `@inertiajs/core` 3.6.1, React 19.2.8,
TypeScript 7.0.2 (`strict`). Every layout form below was rendered through the
adapter's own layout resolution and `normalizeLayouts`.

## Table of Contents

- [Why Persistent Layouts](#why-persistent-layouts)
- [Single Layout](#single-layout)
- [Nested Layouts](#nested-layouts)
  - [What each array form means](#what-each-array-form-means)
- [Default Layout](#default-layout)
- [Conditional Layouts](#conditional-layouts)
- [Layout with Props](#layout-with-props)
  - [Named layouts](#named-layouts)
  - [Passing data up from the page](#passing-data-up-from-the-page)
  - [Layout props from a callback](#layout-props-from-a-callback)
  - [Arrow-function layouts need an array](#arrow-function-layouts-need-an-array)
- [Scroll Regions](#scroll-regions)

---

## Why Persistent Layouts

In Inertia, layouts persist across navigations. A layout assigned to
`Page.layout` keeps its state, so:

- Audio/video players continue playing
- WebSocket connections stay alive
- Heavy component trees don't re-render

Returning `<AppLayout>` from inside the page's own JSX gives up all three: the
layout is part of the page, so it unmounts and remounts on every navigation.
Assign it to `Page.layout` instead.

## Single Layout

```tsx
import { AppLayout } from '@/layouts/app-layout'

export default function Index({ users }: Props) {
  return <UserList users={users} />
}

Index.layout = (page: React.ReactNode) => <AppLayout>{page}</AppLayout>
```

## Nested Layouts

An array of layout components nests them, **outermost first**:

```tsx
import { SiteLayout } from '@/layouts/site-layout'
import { DocsLayout } from '@/layouts/docs-layout'

export default function Show({ article }: Props) {
  return <Article article={article} />
}

Show.layout = [SiteLayout, DocsLayout]
// renders <SiteLayout><DocsLayout><Show /></DocsLayout></SiteLayout>
```

Each layout in the chain persists independently: navigating between two pages
that both declare `[SiteLayout, DocsLayout]` remounts neither.

### What each array form means

The array is overloaded, and the three forms are distinguished by what sits in
the second slot. `@inertiajs/core` treats a two-element array as a
component-plus-props tuple only when the second element is a plain object:

| Written as | Means |
|---|---|
| `[Layout]` | one layout — the wrapper that makes an arrow-function component unambiguous |
| `[Layout, { title: 'Profile' }]` | one layout, with `title` passed to it as a prop |
| `[Outer, Inner]` | two nested layouts, `Outer` outermost |
| `[Outer, Inner, { title: 'x' }]` | three entries, and the third is not a component — this throws `Invalid layout definition: received object` |

So a props object may only ever appear as the second element of a two-element
array. To give props to a nested chain, use the per-entry tuple form:

```tsx
Show.layout = [[SiteLayout, { wide: true }], DocsLayout]
```

## Default Layout

Since Inertia 3.0, `createInertiaApp` takes a `layout` option that receives the
page's component name and returns the layout for it. This is the route to use:
it runs for every page, accepts every layout format above, and **returns
`null` to mean "no layout"**.

```tsx
// app/frontend/entrypoints/inertia.tsx
import { createInertiaApp } from '@inertiajs/react'
import { AppLayout } from '@/layouts/app-layout'

void createInertiaApp({
  pages: '../pages',
  layout: (name) => (name.startsWith('auth/') ? null : AppLayout),
})
```

`pages: '../pages'` is what `rails generate inertia:install` writes, and it
replaces the `resolve` + `import.meta.glob` boilerplate: the
`@inertiajs/vite` plugin resolves page components at build time. An app that
still hand-writes `resolve` assigns the default with
`page.default.layout ??= …` instead.

**A page opts out of the default by name, in the `layout` option.** Setting
`Page.layout = null` on the page does not opt out under either mechanism —
`??=` fires on `null` as well as `undefined`, and the adapter resolves the
layout as `Page.layout ?? layoutOption(name, page)`, so a `null` on the page
falls through to the default and the page renders wrapped. Rendered both ways
against 3.6.1 to confirm.

## Conditional Layouts

Choose the layout from the page name in the same option:

```tsx
void createInertiaApp({
  pages: '../pages',
  layout: (name) => {
    if (name.startsWith('admin/')) return AdminLayout
    if (name.startsWith('auth/')) return null
    return AppLayout
  },
})
```

The option's second argument is the whole page object, so the choice can also key
on `page.url`. It is typed with the *default* `PageProps`, not the app's
augmented `sharedPageProps`, so reading `page.props.auth` there is `unknown`
under `strict`; branch on the component name or the URL here and read shared
props with `usePage()` inside the layout.

## Layout with Props

A layout receives the page's props, plus any props from its own definition,
plus whatever the page sets dynamically. Access shared props with `usePage()`:

```tsx
// app/frontend/layouts/app-layout.tsx
import { usePage, Link } from '@inertiajs/react'

export function AppLayout({ children }: { children: React.ReactNode }) {
  const { props, flash } = usePage()

  return (
    <div className="min-h-screen">
      <nav>
        <Link href="/">Home</Link>
        {props.auth.user && (
          <span>{props.auth.user.name}</span>
        )}
      </nav>

      <main>{children}</main>

      {flash.notice && <Toast>{flash.notice}</Toast>}
    </div>
  )
}
```

**This snippet needs the app's `InertiaConfig` augmentation to type-check.**
`usePage()` returns `props.auth` as `unknown` and `flash` as `{}` until
`sharedPageProps` and `flashDataType` are declared — under TypeScript 7.0.2 the
four lines above then fail with `TS18046` and `TS2322`. Declare the
augmentation once in `app/frontend/types/globals.d.ts`; the shape is in the
`inertia-rails-typescript` skill.

### Named layouts

Give the layouts names by defining them as an object. Each value is a layout in
any of the forms above, and the entries nest in key order, first key outermost:

```tsx
import { AppLayout } from '@/layouts/app-layout'
import { SidebarLayout } from '@/layouts/sidebar-layout'

Dashboard.layout = { app: AppLayout, sidebar: SidebarLayout }
```

The names are what `setLayoutProps(name, props)` targets, so define layouts this
way when one layout in a chain needs values a sibling should not receive.

### Passing data up from the page

`usePage()` covers shared props. For a value the *page* owns — a title, a
sidebar toggle — call `setLayoutProps` in the page's component body. It is a
plain function, not a hook.

```tsx
import { setLayoutProps } from '@inertiajs/react'

export default function Show({ course }: Props) {
  setLayoutProps({ title: course.name, showSidebar: false })
  return <CourseContent course={course} />
}
```

The layout reads `title` and `showSidebar` as ordinary props. To reach one named
layout only, pass the name first:

```tsx
setLayoutProps('sidebar', { collapsed: true })
```

Four sources can supply the same prop name. Later wins:

1. the page's own props
2. static props in the layout definition — `[AppLayout, { wide: true }]`
3. `setLayoutProps({ … })`
4. `setLayoutProps('sidebar', { … })`, for the layout with that name

Inertia clears the dynamic values (3 and 4) itself on any navigation that does
not preserve state, so a page sets what it needs and nothing else. `resetLayoutProps()`
exists for the rare case of clearing them *within* a page — a wizard step that
sets a title and then wants the layout's own default back. Call it from an event
handler or an effect. In a component body it wipes what that body just set, on
every render.

### Layout props from a callback

A function assigned to `layout` that returns an array or a props object is called
with the page's props — typed as `SharedPageProps`, so the app's augmentation is
what makes it useful — which is how a layout prop derives from server state
without the page body doing anything:

```tsx
Profile.layout = (props) => [AppLayout, { title: `Profile: ${props.auth.user?.name}` }]
```

### Arrow-function layouts need an array

`Page.layout` accepts both a *render function* (`page => <AppLayout>{page}</AppLayout>`)
and a *layout component*, and Inertia tells them apart at run time by what the
function returns. Any `layout` function of at most one parameter and no
`prototype` is called once with the page's props (`@inertiajs/react`
`dist/index.js:62-64,154-164`). A React element back means a render function. An
array or a component back means a layout, which is how the props callback above
works. A bare arrow-function component returns an element, so Inertia takes it
for a render function. It then calls the component a second time, with the page
element as the argument. The component finds no `children` and renders an empty
layout — the page body disappears with no error. Wrap it in an array:

```tsx
const Layout = ({ children }) => <main>{children}</main>

Dashboard.layout = [Layout]
```

A `function` declaration, a `React.memo(…)` and a `forwardRef(…)` result all
fail that shape test — the first has a `prototype`, the other two are objects —
so they need no array. **Where the component was defined is irrelevant:** an
imported arrow-function component needs the array just as much as a local one.

## Scroll Regions

By default, Inertia resets scroll to the top on navigation.
For layouts with scrollable regions, use `scroll-region`:

```tsx
export function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen">
      <aside className="w-64 overflow-y-auto" scroll-region>
        <Navigation />
      </aside>
      <main className="flex-1 overflow-y-auto" scroll-region>
        {children}
      </main>
    </div>
  )
}
```

The `scroll-region` attribute tells Inertia to remember and restore
scroll position for that element across navigations.

Preserve scroll on specific navigations:
```tsx
<Link href="/users" preserveScroll>Users</Link>
router.visit('/users', { preserveScroll: true })
```
