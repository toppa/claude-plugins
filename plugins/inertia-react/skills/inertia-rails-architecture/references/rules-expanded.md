# Architecture Rules — Expanded Reference

The full-stack form of each architecture rule: controller Ruby where the rule has a server
half, component TypeScript where it is client-only, and the mechanism that makes it the right
shape. Use it when you need a rule's whole example, or when a reviewer disputes one.

Every TypeScript block here compiles under TypeScript 7.0.2 in `strict` mode against
`@inertiajs/react` 3.6.1, `@inertiajs/core` 3.6.1 and `@types/react` 19.2.17.

## Table of Contents

- [Rule 1: Server Owns Data (CRITICAL)](#rule-1-server-owns-data-critical)
- [Rule 2: Server Owns Auth (CRITICAL)](#rule-2-server-owns-auth-critical)
- [Rule 3: Use Form Component (CRITICAL)](#rule-3-use-form-component-critical)
- [Rule 4: Navigation (HIGH)](#rule-4-navigation-high)
- [Rule 5: Data Refresh (HIGH)](#rule-5-data-refresh-high)
- [Rule 5b: Polling (HIGH)](#rule-5b-polling-high)
- [Rule 6: Global Data (HIGH)](#rule-6-global-data-high)
- [Rule 7: Flash Messages (HIGH)](#rule-7-flash-messages-high)
- [Rule 8: Expensive Queries (MEDIUM)](#rule-8-expensive-queries-medium)
- [Rule 9: Persistent Layouts (MEDIUM)](#rule-9-persistent-layouts-medium)
- [Rule 10: Components as Renderers (MEDIUM)](#rule-10-components-as-renderers-medium)

---

## Rule 1: Server Owns Data (CRITICAL)

The controller decides what the page gets, and names the columns.

```ruby
# app/controllers/users_controller.rb
class UsersController < InertiaController
  def index
    render inertia: {
      users: User.select(:id, :name, :email).as_json(only: [:id, :name, :email]),
    }
  end
end
```

```tsx
// app/frontend/pages/users/index.tsx — path matches controller/action
export default function Index({ users }: { users: User[] }) {
  return <UserList users={users} />
}
```

The data arrives with the page, so the component needs no loading state, no fetch error
path, and no guard against a response landing after the reader has navigated away.

Name the columns rather than sending the record whole. `use_script_element_for_initial_page`
defaults to `false`, so `helper.rb:50` puts the initial page in
`tag.div('data-page': page.to_json)` — every prop of the first render is readable from
View Source with JavaScript off. `inertia-react:inertia-rails-controllers` owns the
serialization rule; the reason it is a disclosure rule and not only a payload rule is this
one.

**Refreshing data without a full page load:**

```tsx
// Re-run one prop against the current page
router.reload({ only: ['users'] })

// A write sends its payload as the second argument, and options as the third
router.post('/users', formData, { only: ['users'] })
```

`only:` on a write is honoured only when the redirect target renders the **same**
component: the gem gates partial data on `X-Inertia-Partial-Component == @component`
(`renderer.rb:117`). Redirect somewhere else and the response is a full page, which is
usually what you wanted anyway.

---

## Rule 2: Server Owns Auth (CRITICAL)

The gate is a `before_action`. If the component renders at all, the request already passed
it.

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < InertiaController
  def index
    render inertia: {
      stats: DashboardStats.for(Current.user),
    }
  end
end
```

```tsx
// If this component renders, the reader IS authenticated
export default function Index({ stats }: DashboardIndexProps) {
  return <DashboardContent stats={stats} />
}
```

Rails 8.1's generated authentication puts `before_action :require_authentication` in the
`Authentication` concern that `ApplicationController` includes, so every controller
inherits the gate and no per-controller callback is needed. Open one action up with the
class method the same concern provides:

```ruby
class SessionsController < InertiaController
  allow_unauthenticated_access only: %i[new create]
end
```

`Current.user` is the reader — `Current` delegates `user` to `session`, so it is `nil`
rather than an error on an unauthenticated request. React never decides who is signed in;
it reads `usePage().props.auth` for what to *display*, and the redirect for an
unauthenticated request has already happened before any React code runs.

---

## Rule 3: Use Form Component (CRITICAL)

```tsx
import { Form } from '@inertiajs/react'

export default function CreateUser() {
  return (
    <Form method="post" action="/users">
      {({ errors, processing }) => (
        <>
          <input type="text" name="name" />
          {errors.name && <span>{errors.name}</span>}
          <button type="submit" disabled={processing}>Create</button>
        </>
      )}
    </Form>
  )
}
```

`<Form>` handles CSRF tokens, redirect following, error mapping, processing state, file
upload detection, scroll preservation, and browser history state — with no `onChange`
handlers and no local state.

CSRF works end to end because the gem sets an `XSRF-TOKEN` cookie
(`controller.rb:18-26`) and the client's `XhrHttpClient` reads it back out as an
`X-XSRF-TOKEN` header. That is the piece a hand-rolled `fetch` or a second `axios`
instance has to reproduce, and the one it usually misses.

Use the `useForm` hook when you need programmatic control: dynamic fields, an external
submit trigger, a transform before send, or a pre-populated edit form.
`inertia-react:inertia-rails-forms` owns both.

---

## Rule 4: Navigation (HIGH)

```tsx
import { Link, router } from '@inertiajs/react'

// Declarative
<Link href="/users">Users</Link>
<Link href="/users/1/edit">Edit</Link>

// Programmatic
router.visit('/users')
router.post('/users', { name: 'John' })
```

`<Link>` and `router` swap the page component in place, which keeps React state and a
persistent layout alive. There is no global anchor interception in 3.6.1, so a plain `<a>`
is a full document load — correct for an external destination, and a state reset for an
internal one.

**`router.post`, `put` and `patch` take the payload as their second argument and options as
their third** — `post(url, data?, options?)`, with
`VisitHelperOptions = Omit<VisitOptions, 'method' | 'data'>` (`types/router.d.ts:12`,
`types/types.d.ts:392`). `router.get(url, params)` and `router.delete(url, options)` take
two, which is what makes the write helpers easy to get wrong.

That mistake does not surface as a type error. The second parameter is typed
`T extends RequestPayload`, so an options object satisfies it and
`router.post('/users', { data: formData, only: ['users'] })` compiles under TypeScript
7.0.2 — then posts the whole object as the body. Executed against 3.6.1 with a spy on
`Router.prototype.visit`:

```
router.post('/users', { data: { name: 'John' }, only: ['users'] })
  -> {"method":"post","data":{"data":{"name":"John"},"only":["users"]}}

router.post('/users', { name: 'John' }, { only: ['users'] })
  -> {"method":"post","data":{"name":"John"},"only":["users"]}
```

Rails then reads `params[:data][:name]`, strong parameters reject it, and `only:` arrives as
a form field instead of a partial-reload option. Nothing raises. Verify a write helper by
its arity, not by whether it compiles.

Prefetching a link, its cache duration and its cache tags live in
`inertia-react:inertia-rails-pages`.

---

## Rule 5: Data Refresh (HIGH)

```tsx
// Re-run specific props against the current page
router.reload({ only: ['users'] })

// After a user action, ask for the one prop the action changed
const handleDelete = (id: number) => {
  router.delete(`/users/${id}`, { only: ['users'] })
}
```

A partial reload uses the same page cache and version string as every other visit, so it
cannot drift from the props the page already holds. A second client-side cache — React
Query, SWR — has its own key space and its own staleness clock, and Inertia has no way to
invalidate it when a version bump forces a full load.

`router.reload` already sets `preserveScroll` and `preserveState` to `true`, and it does
so *after* spreading your options, so they are not overridable and not worth passing.
Their absence from `ReloadOptions` is deliberate:
`ReloadOptions = Omit<VisitOptions, 'preserveScroll' | 'preserveState'>`.

---

## Rule 5b: Polling (HIGH)

```tsx
import { usePoll } from '@inertiajs/react'

// Poll one prop every 30 seconds
usePoll(30000, { only: ['notifications'] })

// Keep polling while the tab is hidden
usePoll(30000, { only: ['notifications'] }, { keepAlive: true })

// Hand the reader the switch
const { start, stop } = usePoll(5000, { only: ['stats'] }, { autoStart: false })
```

The **third** argument is `PollOptions` — `keepAlive`, `autoStart` and `mode`. The second
is reload options, so `only` and `except` go there. Putting `keepAlive` in the second
argument is a type error and, untyped, would be sent to the server as a request field.

`usePoll` earns its place over a hand-rolled `setInterval` on three counts: it throttles
to every tenth tick while `document.hidden` (`keepAlive: true` turns that off), it stops
on unmount, and its request goes through the same visit pipeline as everything else, so it
respects the version string.

Reach for it on an MVP. In production a poll pays for a request per interval whether or not
anything changed, so ActionCable plus `router.reload({ only: [...] })` in the subscription
callback is the cheaper shape once the feature is real.

---

## Rule 6: Global Data (HIGH)

```ruby
# app/controllers/inertia_controller.rb — the base class the gem's installer generates
class InertiaController < ApplicationController
  inertia_share do
    { auth: { user: Current.user&.as_json(only: [:id, :name, :email, :role]) } }
  end
end
```

```tsx
// Read it anywhere in the React tree
import { usePage } from '@inertiajs/react'

function UserMenu() {
  const { props } = usePage()
  return <span>{props.auth.user?.name}</span>
}
```

`inertia_share` is a real class method: it registers a `before_action` and honours
`:if`, `:unless`, `:only` and `:except` (`controller.rb:34`), there is an instance-level
counterpart at `:71`, and the renderer consumes it through `inertia_shared_data`
(`renderer.rb:87`).

Put it on `InertiaController`, not on `ApplicationController`. That class exists precisely
for this — the installer generates it with a commented `inertia_share` example — and it
keeps the callback off responses that will never carry props, such as ActiveStorage
redirects and the health-check endpoint.

A shared prop is recomputed per request and participates in partial reloads, which is what
React Context cannot do for server data. Context is still the right tool for client-only
state several siblings read; see the `inertia-react:inertia-rails-architecture` skill's "Three
choices that are genuinely close".

---

## Rule 7: Flash Messages (HIGH)

Rails `flash` is wired up already. Set it the ordinary way:

```ruby
def create
  @user = User.create!(user_params)
  redirect_to users_path, notice: "User created!"
end
```

```ruby
# config/initializers/inertia_rails.rb — only if you need keys beyond notice and alert
InertiaRails.configure do |config|
  config.flash_keys = %i[notice alert toast]
end
```

```tsx
// flash is a top-level key on the page object — a sibling of props, not a member of it
import { usePage } from '@inertiajs/react'

function FlashMessages() {
  const { flash } = usePage()
  return (
    <>
      {flash.notice && <Toast type="success">{flash.notice}</Toast>}
      {flash.alert && <Toast type="error">{flash.alert}</Toast>}
    </>
  )
}
```

The server writes `@page[:flash]` (`renderer.rb:140-141`) and the client normalizes it to
`flash: initialPage.flash ?? {}`, so `flash.notice` cannot throw. `config.flash_keys`
defaults to `%i[notice alert]` (`configuration.rb:69`).

Its type comes from the app's own augmentation: `app/frontend/types/globals.d.ts` declares
`flashDataType` on `@inertiajs/core`'s `InertiaConfig`, and without that file `flash` is
`{}` and `flash.notice` will not compile.

Flash is deliberately not written into history state — the client replaces it with `{}`
before `pushState` — so a toast does not reappear on a back navigation. For a message the
client raises with no server round trip, write into the same key from the browser:

```tsx
router.flash('notice', 'Copied to clipboard')
```

A message that should survive several navigations is not flash. Put that in
`inertia_share` and clear it explicitly.

---

## Rule 8: Expensive Queries (MEDIUM)

```ruby
def index
  render inertia: {
    basic_stats: DashboardStats.quick,
    detailed_stats: InertiaRails.defer { DashboardStats.detailed },
    permissions: InertiaRails.defer(group: 'auth') { Current.user.permissions },
  }
end
```

```tsx
import { Deferred } from '@inertiajs/react'

export default function Index({ basic_stats }: DashboardIndexProps) {
  return (
    <>
      <QuickStats data={basic_stats} />
      <Deferred data="detailed_stats" fallback={<Spinner />}>
        <DetailedStats />
      </Deferred>
    </>
  )
}
```

The first paint waits on `basic_stats` only. Inertia then issues one follow-up request per
`group:`, so props that belong together should share a group and props that do not should
not — otherwise a fast prop waits on a slow one.

`InertiaRails.defer` is for a prop the page *will* show; `InertiaRails.optional` is for one
it might not, and it is evaluated only when a request names it in `only:`. Both accept
`cache:`, so an expensive prop can be memoised as well as deferred.
`inertia-react:inertia-rails-controllers` owns the prop wrappers and
`inertia-react:inertia-rails-pages` owns `<Deferred>`.

---

## Rule 9: Persistent Layouts (MEDIUM)

Set the default once, in the entry point:

```tsx
createInertiaApp({
  pages: '../pages',
  layout: () => AppLayout,
})
```

`layout` is a first-class `createInertiaApp` option. The adapter calls it with
`(pageComponentName, page)`, so it can also pick a layout per page, and it applies the
result only when the page component has not named one itself.

Override for one page by assigning to the component:

```tsx
import { AppLayout } from '@/layouts/app-layout'

export default function Show({ course }: CourseShowProps) {
  return <CourseContent course={course} />
}

Show.layout = (page: React.ReactNode) => <AppLayout>{page}</AppLayout>
```

The layout element persists across navigations, so an audio player keeps playing, a
WebSocket stays open, and a heavy sidebar does not reinitialize. Rendering `<AppLayout>`
inside the page's own return value instead puts the layout below the swapped node, which
remounts it on every visit.

The generated React entry point has no `resolve` callback — it uses the `pages` shorthand,
which `@inertiajs/vite` expands into one at build time. Anything that used to be written
inside a `resolve` callback now goes in a top-level option.
`inertia-react:inertia-rails-pages` owns layout composition, named layouts and layout
props.

---

## Rule 10: Components as Renderers (MEDIUM)

```tsx
// A pure renderer: everything it draws arrives as a prop
function UserProfile({ user }: { user: User }) {
  return <ProfileCard user={user} />
}
```

```ruby
# The page's data comes from the controller
# app/controllers/users_controller.rb
def show
  render inertia: {
    user: User.find(params[:id]).as_json(only: [:id, :name, :email, :bio])
  }
end
```

The page component is the one bridge between server data and React rendering. A child that
needs data takes it as a prop from that page. That keeps the component testable with a
plain object, and it keeps every query in the one place a request spec can assert against.
