# Navigation — Detailed Reference

Programmatic navigation, partial reloads, events, external URLs, history
management, URL-driven state, and the whole of prefetching: modes, cache
duration, cache tags, and cache flushing.

Verified against `@inertiajs/react` and `@inertiajs/core` 3.6.1, `inertia_rails`
3.22.0, Rails 8.1.3.1, TypeScript 7.0.2 (`strict`).

## Table of Contents

- [Programmatic Navigation](#programmatic-navigation)
- [Partial Reloads](#partial-reloads)
- [External URLs](#external-urls)
- [History Management](#history-management)
- [Global Events](#global-events)
- [Link Prefetching](#link-prefetching)
  - [Cache Duration](#cache-duration)
  - [Cache Tags](#cache-tags)
  - [Programmatic Prefetching](#programmatic-prefetching)
  - [Cache Flushing](#cache-flushing)
- [URL-driven state](#url-driven-state)

---

## Programmatic Navigation

### Basic Navigation

**Every `router` helper takes the payload as its second argument and the visit
options as its third.** `router.delete` has no payload, so options move up to
second.

```tsx
import { router } from '@inertiajs/react'

router.visit('/users')                          // GET (default)
router.get('/users', { search: 'john' })        // GET with query params
router.post('/users', { name: 'John' })         // POST with body
router.put(`/users/${id}`, formData)            // PUT
router.patch(`/users/${id}`, formData)          // PATCH
router.delete(`/users/${id}`)                   // DELETE
router.post('/users', formData, { preserveScroll: true })
```

The payload argument is a bag of user data, so `{ data: formData }` type-checks
and sends a field literally named `data` — one level too deep, with no error at
build time or run time. `useForm`'s helpers are the ones whose second argument is
options (`form.post(url, options)`), because the form already holds the payload.

### Visit Options
```tsx
router.visit('/users', {
  method: 'get',
  data: { search: 'john', page: 2 },
  preserveState: true,      // keep component state
  preserveScroll: true,     // keep scroll position
  replace: true,            // replace history entry
  only: ['users'],          // partial reload
  except: ['stats'],        // exclude from reload
  fresh: true,              // ignore any prefetched copy of this URL
  headers: { 'X-Custom': 'value' },
  onBefore: (visit) => { /* return false to cancel */ },
  onStart: (visit) => { /* show loading indicator */ },
  onProgress: (progress) => { /* upload progress */ },
  onSuccess: (page) => { /* handle success */ },
  onError: (errors) => { /* handle validation errors */ },
  onHttpException: (response) => { /* 4xx/5xx that is not an Inertia response */ },
  onNetworkError: (error) => { /* request never completed */ },
  onFinish: (visit) => { /* always runs */ },
  onCancel: () => { /* request was cancelled */ },
  onFlash: (flash) => { /* flash data received */ },
})
```

`router.reload` accepts the same options except `preserveScroll` and
`preserveState`: it forces both to `true` after spreading what you passed, so
they are omitted from its type rather than merely ignored.

## Partial Reloads

Refresh specific props without reloading the entire page.

```tsx
// Only refresh these props
router.reload({ only: ['users', 'pagination'] })

// Refresh all props EXCEPT these
router.reload({ except: ['expensive_stats'] })

// From a page that is currently showing validation errors
router.reload({ only: ['users'], preserveErrors: true })
```

`preserveErrors` matters because `rails generate inertia:install` writes
`config.always_include_errors_hash = true`, so every response carries an
`errors` hash and the gem wraps it in `InertiaRails.always` — a partial reload
cannot exclude it, and the empty hash clears the errors already on screen.
Inertia sets `preserveErrors` for you on deferred-prop loads, `<WhenVisible>`
and `<InfiniteScroll>`; pass it yourself on a reload you fire from a page with a
form on it.

### Search/Filter Pattern
```tsx
function handleSearch(query: string) {
  router.get('/users', { search: query }, {
    preserveState: true,    // keep other form inputs
    preserveScroll: true,   // don't jump to top
  })
}
```

## External URLs

### From the Server (CRITICAL)

Use `inertia_location` for any URL outside the Inertia app. It responds `409`
with an `X-Inertia-Location` header, which the client turns into a full page
visit.

```ruby
inertia_location "https://stripe.com/checkout/session_xxx"
```

Two separate mechanisms stop a plain `redirect_to` from doing this job, and it
is worth knowing which one you are looking at:

1. **Rails stops it first.** Under `config.load_defaults 8.1`,
   `action_on_open_redirect` is `:raise`, so a cross-host `redirect_to` raises
   `ActionController::Redirecting::OpenRedirectError` before Inertia sees
   anything. The backtrace names Action Pack, not Inertia.
2. **If it is allowed through** — `allow_other_host: true`, or an older
   `load_defaults` — the XHR follows the redirect and gets a response with no
   `X-Inertia` header, which the client reports through `httpException` and
   renders in an error modal rather than navigating.

### From the Client

```tsx
// For external URLs in React use <a> tag (intentionally NOT <Link>)
<a href="https://external-site.com" target="_blank" rel="noopener">
  External Site
</a>

// Or use window.location.href (rare — prefer server-side)
window.location.href = 'https://external-site.com'
```

## History Management

### Replace vs Push
```tsx
// Push new entry (default) — user can go back
router.visit('/users')

// Replace current entry — no back navigation
router.visit('/users', { replace: true })
```

### Client-Side Prop Updates (No Server Round-Trip)

The value may be a literal or a callback. **Annotate the callback's
parameters:** they are typed `unknown | ((oldValue: unknown, props: TProps) => unknown)`,
and `unknown` absorbs the union, so TypeScript has no signature to
contextually type them from and reports `TS7006` on every unannotated one.

```tsx
import type { SharedPageProps } from '@inertiajs/core'

// Replace a prop value
router.replaceProp('show_modal', false)
router.replaceProp('user.name', 'Jane Smith')

// With a callback
router.replaceProp('count', (current: unknown) => (current as number) + 1)

// Append/prepend to arrays
router.appendToProp('messages', { id: 4, text: 'New' })
router.prependToProp('notifications', (current: unknown, props: SharedPageProps) => ({
  id: Date.now(),
  message: `Hello ${props.auth.user?.name}`,
}))
```

## Global Events

`createInertiaApp` enables the progress bar by default (`delay` 250 ms, colour
`#29d`, no spinner), so a loading indicator is not something to build. Tune it
with `progress: { delay: 100 }` or turn it off with `progress: false`, and
suppress it for one visit with `showProgress: false`.

Reach for `router.on` for the states the progress bar does not cover — transport
failures, and flash data arriving on a visit that does not swap the page:

```tsx
import { useEffect } from 'react'
import { router } from '@inertiajs/react'
import { showToast } from '@/lib/toast'

// In a layout or app-level component
useEffect(() => {
  const stop = [
    router.on('flash', (event) => showToast(event.detail.flash)),
    router.on('networkError', (event) => {
      showToast({ alert: 'You appear to be offline.' })
      return false // handled — skip Inertia's own error handling
    }),
  ]

  return () => stop.forEach((remove) => remove())
}, [])
```

Returning `false` from a listener on a **cancelable** event calls
`preventDefault()` for you.

| Event | Fires when | Cancelable |
|---|---|---|
| `before` | a visit is about to start | yes |
| `start` | the request has been sent | no |
| `progress` | upload progress on a request with files | no |
| `beforeUpdate` | a page swap is about to be applied | no |
| `success` | an Inertia response arrived and the page swapped | no |
| `error` | the response carried validation errors | no |
| `httpException` | a 4xx/5xx that is not an Inertia response | yes |
| `networkError` | the request never completed | yes |
| `finish` | the visit finished, any outcome | no |
| `cancel` | the visit was cancelled | no |
| `navigate` | history navigation completed | no |
| `clientVisit` | a `router.replace`/`push`/prop update was applied | no |
| `prefetching` | a prefetch request started | no |
| `prefetched` | a prefetch response was cached | no |
| `flash` | flash data arrived | no |
| `location` | an `X-Inertia-Location` full page visit is starting | yes |

`error` is validation only. `httpException` and `networkError` are the transport
split, and they are the two to reach for when a request fails rather than a
form.

## Link Prefetching

Prefetch page data before the user clicks for instant navigation. This skill
owns prefetching end to end; `inertia-rails-performance` owns invalidating a
cache across pages after a mutation, in its "Cross-page cache invalidation" section.

```tsx
// Prefetch on hover after a 75 ms delay — the default when `prefetch` has no value
<Link href="/users" prefetch>Users</Link>

// Prefetch on mount (eager)
<Link href="/dashboard" prefetch="mount">Dashboard</Link>

// Prefetch on mousedown — fires later, and defaults to no caching at all
<Link href="/users" prefetch="click">Users</Link>

// Several modes at once
<Link href="/users" prefetch={['mount', 'hover']}>Users</Link>
```

The hover delay is an app-wide default (75 ms), not a per-link prop; set it
through `createInertiaApp`'s `defaults`.

### Cache Duration

`cacheFor` controls how long a prefetched response stays usable. The default is
30 seconds for every mode except `prefetch="click"` on its own, where it is 0 —
a click-prefetch is meant to be consumed immediately.

```tsx
// Cache for 30 seconds
<Link href="/users" prefetch cacheFor="30s">Users</Link>

// Cache for 5 minutes
<Link href="/dashboard" prefetch cacheFor="5m">Dashboard</Link>

// Two values = stale-while-revalidate: usable for 1m, refetched after 30s
<Link href="/users" prefetch cacheFor={['30s', '1m']}>Users</Link>
```

With two values the entry stays usable for the second duration, and after the
first has elapsed the next prefetch trigger refetches it while the existing copy
keeps serving. One value sets both, so the entry is refetched only once it has
already been discarded.

### Cache Tags

Tag prefetched pages so a mutation can invalidate all of them together:

```tsx
// Tag prefetched pages
<Link href="/users" prefetch cacheTags="users">Users</Link>
<Link href="/dashboard" prefetch cacheTags={['dashboard', 'users']}>Dashboard</Link>

// Invalidate matching caches when the form submits
form.post('/users', {
  invalidateCacheTags: ['users', 'dashboard'],
})

// Same option on a router write — third argument, because the second is the payload
router.post('/users', formData, {
  invalidateCacheTags: ['users'],
})
```

`invalidateCacheTags` is a visit option, not a `<Link>` prop.

### Programmatic Prefetching

Prefetch without a `<Link>` — useful for predictive loading based on user context:

```tsx
import { router } from '@inertiajs/react'

// Prefetch a likely destination after user completes a step
router.prefetch('/onboarding/step-2')

// Visit options second, prefetch options third
router.prefetch('/settings', {}, { cacheFor: '1m' })
```

`usePrefetch(options)` reports on the current page's prefetch state —
`{ lastUpdatedAt, isPrefetching, isPrefetched, flush }`.

### Cache Flushing

```tsx
router.flush('/users')   // one URL — smallest blast radius
router.flushAll()        // everything
```

To bypass the cache for a single visit without discarding it, pass
`fresh: true` on the visit. There is no `cache` visit option; the compiler will
suggest `cached`, which is an internal flag on the visit rather than a knob.

## URL-driven state

The worked pair for a dialog driven by the URL. The controller reads `params` and sends the
selection as a prop:

```ruby
def index
  render inertia: {
    users: User.all.map { |user| serialize_user(user) },
    selected_user_id: params[:user_id]&.to_i
  }
end

private

def serialize_user(user)
  user.as_json(only: %i[id name])
end
```

The component derives the open state from that prop and navigates to change it:

```tsx
type Props = {
  users: User[]
  selected_user_id: number | null  // from controller
}

export default function Index({ users, selected_user_id }: Props) {
  const selectedUser = selected_user_id
    ? users.find(u => u.id === selected_user_id)
    : null

  const openDialog = (id: number) =>
    router.get('/users', { user_id: id }, {
      preserveState: true,
      preserveScroll: true,
    })

  const closeDialog = () =>
    router.get('/users', {}, {
      preserveState: true,
      preserveScroll: true,
    })

  return (
    <Dialog open={!!selectedUser} onOpenChange={(open) => !open && closeDialog()}>
      <DialogContent>{/* ... */}</DialogContent>
    </Dialog>
  )
}
```

The same shape drives tabs and filters: one prop per URL parameter, derived in the component,
updated with `router.get`.
