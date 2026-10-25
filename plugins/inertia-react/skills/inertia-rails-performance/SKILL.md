---
name: inertia-rails-performance
description: >-
  Inertia payload and navigation cost — prop payload size and the disclosure risk that
  comes with it, `InertiaRails.cache` for an expensive prop, Vite bundle splitting across
  pages, invalidating the client's prefetch cache across pages, instant visits, server-side
  pagination props, asset versioning, progress indicators, navigation timing, and view
  transitions.
when_to_use: >-
  Use when a prop payload is large, when a list still shows a record a write already
  deleted, when you decide which prefetch cache tags a write invalidates, when you split
  the JavaScript bundle across pages, when you paginate a long list, or when you measure
  how long a navigation takes. This skill owns which pages go stale together and therefore
  what the cache tags should be; the prefetch API that carries them — `<Link prefetch>`,
  `cacheFor`, `cacheTags`, `router.prefetch`, the `flush` family — is the
  `inertia-react:inertia-rails-pages` skill's. Splitting one component's own imports is the
  `inertia-react:react-performance` skill's; splitting across pages is here. For a slow query
  behind the page, reach for `rails-core:postgres-patterns` and
  `rails-core:caching-strategies` first.
metadata:
  upstream_repo: cole-robertson/inertia-rails-skills
  upstream_path: skills/inertia-rails-performance/SKILL.md
  upstream_ref: 77d0172e1390ae746f759c0c75d4b95aacbbd429
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, vite_ruby 3.10.2, "@inertiajs/react" 3.6.1,
    "@inertiajs/core" 3.6.1, "@inertiajs/vite" 3.6.1, "@types/react" 19.2.17,
    TypeScript 7.0.2, Vite 8.1.5
---

# Inertia Rails Performance

This skill owns what a page costs to send and to navigate to. Its neighbours own the
mechanisms it measures:

- Server-side prop helpers — the form and the defaults of `defer`, `optional`, `once` and `merge` → `inertia-react:inertia-rails-controllers`. Three of them return below, where a payload decision turns on them: `optional` for what a prop costs, the `cache:` option on `defer` and `optional`, and `merge` for pagination.
- `<Deferred>`, `<WhenVisible>`, `<InfiniteScroll>`, scroll regions, and the whole prefetch API → `inertia-react:inertia-rails-pages`
- Splitting one component's own imports → `inertia-react:react-performance`. Splitting **across** pages is here.

Every TypeScript block below compiles under TypeScript 7.0.2 in `strict` mode against
`@inertiajs/*` 3.6.1.

## Prop payload size

The props of a page travel on every visit to it. Payload size is the first thing to
measure and usually the largest win.

```ruby
# Sends the four columns the page renders
render inertia: {
  users: User.select(:id, :name, :email, :avatar_url).as_json
}
```

`select` beats `as_json(only:)` alone when the table is wide, because it also keeps the
unused columns out of the database round trip. Use both when you want the query narrowed
*and* the JSON keys pinned.

**Sending a whole record is a disclosure bug, not only a payload bug.** The initial page
object is serialized into the HTML document as plain text, so every prop of the first render
is readable from View Source with JavaScript off. `render inertia: { users: User.all }` puts
password digests, internal flags and soft-delete columns on the page.

Which element holds it does not change that. `use_script_element_for_initial_page` is
`false` in the gem's own defaults (`configuration.rb:59`), giving
`tag.div('data-page': page.to_json)`, but the install generator's initializer template sets
it to `true`, giving `<script type="application/json">` (`helper.rb:38-51`) — so a
generator-installed app has the script element and the JSON is in the document either way.
The `true` form is defence in depth for CSP, not for exposure.

Eager-load anything the serialization touches, and keep the foreign key in the select list
when the association needs it:

```ruby
users = User.select(:id, :name, :organization_id).includes(:organization)

render inertia: {
  users: users.as_json(only: [:id, :name],
                       include: { organization: { only: [:name] } })
}
```

Reading an attribute a `select` omitted raises `ActiveModel::MissingAttributeError`
(`query_methods.rb:409-412`). A `has_one` survives without the key because the foreign key
sits on the other table; a `belongs_to` does not.

## Shared props evaluate on every full visit

A lambda inside `inertia_share` does **not** make the prop selective. On any full visit the
resolver evaluates it, because only `IgnoreOnFirstLoadProp` and deferred props are skipped
for a non-partial request (`props_resolver.rb:225-234`). The lambda saves work only on a
partial reload whose `only:`/`except:` leaves that key out.

```ruby
# Both queries run on every full visit, lambda or not
inertia_share do
  { recent_posts: -> { Post.recent.limit(5).as_json },
    total_users: -> { User.count } }
end
```

`InertiaRails.optional` is the selective tool: it is evaluated only when a request names it
in `only:`.

```ruby
inertia_share do
  { unread_count: InertiaRails.optional { Current.user.notifications.unread.count } }
end
```

## Memoising an expensive prop

`InertiaRails.cache(key) { … }` stores the prop's **serialized JSON** in the configured
cache store and hands it back as an `InertiaRails::RawJson` (`raw_json.rb:10`), so a repeat
render skips both the query and the serialization (`prop_cacheable.rb:25-30`). The key is
required. It is namespaced under `inertia_rails/` and expanded through
`ActiveSupport::Cache.expand_cache_key`, so a record or a relation works as a key and brings
its own cache-key versioning.

```ruby
render inertia: {
  report: InertiaRails.cache([current_account, 'monthly-report'], expires_in: 1.hour) {
    MonthlyReport.new(current_account).as_json
  }
}
```

`cache:` is also an option on `defer` and `optional`, so a prop can be both deferred and
memoised:

```ruby
detailed_stats: InertiaRails.defer(cache: { key: 'detailed-stats', expires_in: 5.minutes }) {
  DashboardStats.detailed
}
```

The store is the gem's own `config.cache_store`, which falls back to `Rails.cache`
(`configuration.rb:152-153`). Set it inside an `InertiaRails.configure` block to give props a
different store from the rest of the app — a different receiver, the same key name as
Rails'.

Give each prop of one record its own key suffix, because the namespace is shared:
`[current_account, 'monthly-report']` and `[current_account, 'daily-report']` become
`inertia_rails/accounts/7-<ts>/monthly-report` and `…/daily-report`.

There are four caches in an Inertia app and they do different jobs: `Rails.cache` behind this
and behind `rails-core:caching-strategies`, `ssr_cache` for rendered HTML in
`inertia-react:inertia-rails-ssr`, the client's own prefetch cache below, and the browser's,
which conditional GET drives. The gem folds its own request headers into the ETag
(`controller.rb:16,126-130`), so one URL answered as HTML, as Inertia JSON, and as a partial
reload gets three separate validators rather than one shared, wrong one.

## Code splitting across pages

The generated entry point asks for pages by directory and `@inertiajs/vite` expands that
into a resolver at build time. One chunk per page is the default — `lazy` defaults to
`true` (`@inertiajs/vite` 3.6.1 `dist/index.js:305`), so the shorthand already splits:

```js
createInertiaApp({ pages: '../pages' })
```

The path is relative to the entry point file, so from `app/frontend/entrypoints/inertia.tsx`
it is `'../pages'`. `'./pages'` resolves to `app/frontend/entrypoints/pages`, which does not
exist.

The knob worth knowing is the opposite one. Turn splitting off when the whole application
is a handful of small pages and the extra requests cost more than the bytes:

```tsx
createInertiaApp({
  pages: { path: '../pages', extension: '.tsx', lazy: false },
})
```

`extension` takes the leading dot, and defaults to `['.tsx', '.jsx']` for React.

Splitting one component's own imports — a chart library behind a tab, a rich-text editor
behind an edit button — belongs to `inertia-react:react-performance`. This section is about
the page boundary, which Inertia draws for you.

## Cross-page cache invalidation

**A list that still shows a record the reader just deleted is the symptom this section
exists for.** The navigation was served out of the prefetch cache a previous hover filled,
and the write never told that cache the resource had changed.

`inertia-react:inertia-rails-pages` owns the prefetch API and every option that carries it
out — `prefetch`, `cacheFor` and `cacheTags` on `<Link>`, `router.prefetch`,
`invalidateCacheTags` on a write, and the `flush` family. What is left over, and what this
section is, is the **design question that spans pages**: which pages go stale together, and
therefore what the tags should be.

The rule that answers it: **tag by the resource a page reads, not by the page.** Every
prefetched page whose content comes from `users` carries the tag `users`, whatever its URL
looks like, and a page showing two resources carries both tags. Then a write names only the
resource it changed and every affected page drops out, including the ones whose existence
the author of that write never thought about.

```tsx
<Link href="/users" prefetch cacheTags="users">All Users</Link>
<Link href="/users/active" prefetch cacheTags="users">Active Users</Link>
<Link href="/teams/1" prefetch cacheTags={['users', 'teams']}>Team</Link>
```

Those three URLs share no prefix, so no URL-based scheme would have connected them, and a
single-page example cannot show the problem. That is the whole of what is specific to this
skill.

Two consequences worth planning around:

- **A tag is only as good as its worst page.** One prefetched page that reads `users` and
  forgets the tag is enough to keep serving stale content after every write, and nothing
  reports it. Add the tag when you add the `prefetch`, not afterwards.
- **Tag breadth trades correctness against cache hits.** One tag for the whole app is always
  correct and caches nothing useful; a tag per URL keeps every hit and goes stale. Resource
  names sit at the right granularity because writes are already scoped to resources.

Where no tag scheme exists yet — a page prefetched from a third-party component, a one-off
report — bypass the cache for that visit instead:

```js
router.visit('/users', { fresh: true })
```

`fresh: true` is a per-visit bypass, not an invalidation: the cache is consulted only
`if (!params.fresh && …)`, so the entry stays and the next visit hits it again. There is no
`{ cache: false }` option — `cached` is an internal read-only flag on the visit, and tsc
suggests it, which is how the wrong spelling gets written.

## Instant visits

An instant visit renders the target page immediately, while the request is still in flight,
then fills in the real props when the response lands.

```tsx
<Link href="/dashboard" component="Dashboard">Dashboard</Link>
```

With `component` alone, the intermediate frame gets the current page's **shared** props —
the ones `sharedProps` names — and nothing else. That is the safe default.

`pageProps` **replaces** those rather than adding to them
(`intermediateProps = resolvedPageProps !== null ? { ...resolvedPageProps } : { ...sharedProps }`,
`@inertiajs/core` `dist/index.js:3403-3404`). So a literal object is a trap: a
`Users/Show` page that reads `user.id` throws on the intermediate frame if the placeholder
only has `name`. Use the callback form, which receives the current props and the shared
props, and spread what you want to keep:

```tsx
<Link
  href="/users/123"
  component="Users/Show"
  pageProps={(currentProps, sharedProps) => ({ ...sharedProps, user: { name: 'Loading…' } })}
>
  View User
</Link>
```

```js
router.visit('/dashboard', { component: 'Dashboard' })
```

The client needs to know which shared props exist before the response arrives.
`config.expose_shared_prop_keys` already defaults to `true`
(`configuration.rb:77`), so there is nothing to configure — but if an initializer has set
it to `false`, an instant visit renders an empty shell.

An instant visit pays off in proportion to how much of the target page comes from
`inertia_share`. A page whose content is all page props shows a shell either way.

## Server-side pagination props

`InertiaRails.scroll` pairs page metadata with the prop, so the client knows there is a
next page. It resolves the metadata through an adapter, and the `Hash` adapter needs no
paginator gem at all — supply the four keys yourself
(`scroll_metadata.rb:56-70`):

```ruby
class UsersController < InertiaController
  PER_PAGE = 20

  def index
    page = params.fetch(:page, 1).to_i
    records = User.order(:id).offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)
    has_more = records.length > PER_PAGE

    render inertia: {
      users: InertiaRails.scroll(
        page_name: 'page',
        previous_page: (page - 1 if page > 1),
        next_page: (page + 1 if has_more),
        current_page: page
      ) { records.first(PER_PAGE).as_json(only: [:id, :name]) }
    }
  end
end
```

Fetching one extra row is how you learn there is a next page without a `COUNT`.

`inertia_rails` 3.22.0 also ships a `KaminariAdapter` and a `PagyAdapter`, so if the project
already has one of those gems you can pass the paginator object straight in and skip the
four keys. Check the `Gemfile` first — neither is a Rails default, and the two have
different method names (`current_page`/`last_page?` against `page`/`next`), so an example
written for one raises `NoMethodError` under the other.

The `<InfiniteScroll>` component that consumes a scroll prop is in
`inertia-react:inertia-rails-pages`. Without it, `InertiaRails.merge` appends each page to
the array and you drive the loading:

```ruby
render inertia: {
  posts: InertiaRails.merge { records.as_json(only: [:id, :title]) },
  pagination: { current_page: page, has_more: has_more }
}
```

```tsx
router.reload({ data: { page: pagination.current_page + 1 }, only: ['posts', 'pagination'] })
```

`router.reload` already forces `preserveScroll` and `preserveState` — it sets both *after*
spreading your options, and `ReloadOptions` omits them for that reason — so passing them
is a type error and would be ignored anyway.

## Asset versioning

Inertia compares a version string on every response. When it changes, the client does a
full page load instead of an XHR visit, so a deploy cannot leave a reader on stale
JavaScript.

```ruby
InertiaRails.configure do |config|
  config.version = ViteRuby.digest
end
```

**Assign the value, do not wrap it in a lambda** — that is what the install generator's
initializer template writes, and the difference is per-request cost. `ViteRuby.digest` is
`watched_files_digest`: a `Dir[]` glob over `watched_paths` plus a SHA1 of every match,
memoised for only one second (`vite_ruby/builder.rb:54-63`). Assigned directly it runs once
at boot; wrapped in `-> { … }` the configuration evaluates it per request
(`configuration.rb:180-185`), which is real filesystem I/O on every response.

Booting once is right in production, where the assets are built before the process starts.
It is wrong in development, where a rebuild will not bump a digest captured at boot — but
development is also where a stale version string costs nothing, because the dev server
reloads the bundle itself.

And version checking narrows the window rather than closing it.
`stale_inertia_get?` is `get? && stale_inertia_request?`, so a stale POST, PUT, PATCH or
DELETE is executed against the new server code by the old client. The version string
protects navigation, not writes.

## Progress indicators

The bar is on by default with sensible values — `delay: 250`, `color: '#29d'`,
`includeCSS: true`, `showSpinner: false`, `popover: null`
(`@inertiajs/core` `dist/index.js:5064-5069`). Configure only what you want different:

```tsx
createInertiaApp({
  pages: '../pages',
  progress: { delay: 500, showSpinner: true },
})
```

`delay` is the setting worth tuning: a bar that flashes on every fast visit reads as
slowness that is not there. `ProgressOptions` is exactly those five keys — `showProgress`
is a per-visit option and not one of them.

Per-visit suppression is already the default for a background request:
`showProgress: options.showProgress ?? (!options.async || !!options.optimistic)`, so
`async: true` with no `optimistic` callback resolves to `false` on its own.

```js
router.post('/analytics/track', { event: 'view' }, { async: true })
```

Three arguments there, in that order: URL, **payload**, options. Every option named here
— `async`, `showProgress`, `invalidateCacheTags` — belongs in the third.
`router.post(url, { async: true })` compiles and then posts `{"async":true}` as the request
body, because the second parameter is typed `T extends RequestPayload` and an options object
satisfies it. `router.get(url, params)` and `router.delete(url, options)` really do take two,
which is what makes the three-argument helpers easy to get wrong.

## Measuring a navigation

`PendingVisit` and `ActiveVisit` are closed types, so there is nowhere on the visit to hang
a timestamp. Keep it outside the handler, and skip the prefetch traffic — `start` and
`finish` fire for prefetch requests too, so without the guard the warning fires on
background work the reader is not waiting for:

```tsx
let visitStartedAt = 0

router.on('start', (event) => {
  if (event.detail.visit.prefetch) return
  visitStartedAt = performance.now()
})

router.on('finish', (event) => {
  if (event.detail.visit.prefetch) return
  const duration = performance.now() - visitStartedAt
  if (duration > 1000) {
    console.warn(`Slow navigation to ${event.detail.visit.url.pathname}: ${duration}ms`)
  }
})
```

The 1000ms figure is a house heuristic with no external source — pick the threshold your
app's navigations should beat. This measures the whole visit: the server, the network, and
the render. Compare it against the Rails log to find which one you are paying for.

## View transitions

```tsx
<Link href="/users" viewTransition>Users</Link>
```

```js
router.on('before', (event) => {
  event.detail.visit.viewTransition = true
})
```

```css
::view-transition-old(root) { animation: slide-out 0.3s ease-in-out; }
::view-transition-new(root) { animation: slide-in 0.3s ease-in-out; }
```

The View Transitions API is not in every browser. Inertia checks for
`document.startViewTransition` and navigates normally when it is absent, so this degrades
on its own.
