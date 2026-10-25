# Prop Types — Detailed Reference

Each prop type with real-world examples. Verified against `inertia_rails` 3.22.0 and
`@inertiajs/react` 3.6.1. The floor is **3.19.0**, the release that added Inertia.js 3.x
support and restructured the renderer (CHANGELOG 3.19.0) — nothing below it.

## Table of Contents

- [Regular Props](#regular-props)
- [Optional Props](#optional-props)
- [Deferred Props](#deferred-props)
- [Once Props](#once-props)
- [Merge Props](#merge-props)
- [Always Props](#always-props)
- [Scroll Props](#scroll-props)
- [Resetting Merge/Scroll Props](#resetting-mergescroll-props)
- [Combining Prop Types](#combining-prop-types)
- [Instance variables as props](#instance-variables-as-props)
---

## Regular Props

Always included in the initial page response. Wrap in `-> {}` to skip evaluation during partial reloads that don't request them.

```ruby
render inertia: {
  filters: filter_params,
  users: -> { User.where(active: true).map { |user| serialize_user(user) } },
  total_count: -> { User.active.count },
}
```

With `router.reload({ only: ['filters'] })`, `users` and `total_count` are never evaluated.

Rule of thumb: wrap anything involving a query in `-> {}`. Use plain values only for cheap data like literals and filter parameters.

Filter parameters go through strong parameters like any other input, so that a prop echoed
back to the page carries only the keys the page reads:

```ruby
def filter_params
  params.permit(:search, :sort).to_h
end
```

## Optional Props

Only evaluated when explicitly requested via partial reload headers.
Saves computation on initial page load.

```ruby
render inertia: {
  users: User.active.map { |user| serialize_user(user) },
  # Only computed when client requests it
  export_data: InertiaRails.optional { User.active.to_csv },
  detailed_stats: InertiaRails.optional { Analytics.compute_detailed },
}
```

Client requests optional props with `router.reload`:
```tsx
// Only fetches export_data, skips everything else
router.reload({ only: ['export_data'] })
```

## Deferred Props

Loaded automatically after the initial page render. The page loads fast
with a placeholder, then deferred data streams in.

```ruby
render inertia: {
  # Fast — included in initial response
  course: serialize_course(@course),

  # Slow — loaded after page renders
  reviews: InertiaRails.defer { @course.reviews.includes(:user).map { |r| serialize_review(r) } },

  # Grouped — fetched together in a single request
  chart_data: InertiaRails.defer(group: 'analytics') { Analytics.chart_for(@course) },
  engagement: InertiaRails.defer(group: 'analytics') { Analytics.engagement_for(@course) },
}
```

React side with `<Deferred>`:
```tsx
<Deferred data="reviews" fallback={<ReviewsSkeleton />}>
  <ReviewsList />
</Deferred>
```

## Once Props

Resolved once, then kept by the client while it navigates between pages that include the
prop. Use for reference data that rarely changes.

```ruby
render inertia: {
  # Fetched once, then not re-sent while the client keeps naming it
  countries: InertiaRails.once { Country.pluck(:name, :code) },
  timezones: InertiaRails.once { ActiveSupport::TimeZone::MAPPING.keys },
  roles: InertiaRails.once { User::ROLES },
}
```

**The retention is client-driven, not stored on the server.** Nothing is written to the
Rails session. The client sends `X-Inertia-Except-Once-Props` listing what it already
holds, and `props_resolver.rb:236-243` skips those. Navigate to a page that omits the prop
and the client drops it, so the next page that includes it pays for it again.

Three options shape that (`prop_onceable.rb:8-11`):

```ruby
render inertia: {
  # key: — a shared identity, so the value survives pages that name the prop differently
  countries: InertiaRails.once(key: 'countries') { Country.pluck(:name, :code) },

  # expires_in: — re-resolve after a TTL
  rates: InertiaRails.once(expires_in: 1.hour) { ExchangeRate.current },

  # fresh: — force a re-resolve on this response
  roles: InertiaRails.once(fresh: true) { User::ROLES },
}
```

## Merge Props

Appended to existing array on the client. Use for accumulating data across
partial reloads — new items are added to the existing list without replacing it.

When merging arrays, you may use the `match_on` parameter to match existing items
by a specific field and update them instead of appending new ones.

For **infinite scroll**, use `InertiaRails.scroll` (see [Scroll Props](#scroll-props)),
which handles page tracking and URL sync. Use `merge` for patterns where
data accumulates from user actions or background updates:

```ruby
# Activity log — poll or ActionCable triggers router.reload({ only: ['activities'] })
render inertia: {
  activities: InertiaRails.merge { @recent_activities.map { |a| serialize_activity(a) } },
}

# Chat / live feed — new messages appended via partial reload,
# existing ones updated by id
render inertia: {
  messages: InertiaRails.merge(match_on: 'id') { @messages.map { |m| serialize_message(m) } },
}

# Nested data
InertiaRails.merge(append: 'data', match_on: 'data.id') { post_data }

# Same as above, but using a hash shortcut...
InertiaRails.merge(append: { data: 'id' }) { post_data }

# Multiple properties with different match fields
InertiaRails.merge(append: { 'users.data' => 'id', 'messages' => 'uuid' }) { complex_data }
```

Client-side, `router.reload({ only: ['messages'] })` fetches the new batch
and Inertia appends it to the existing `messages` array automatically.

**Reset on fresh visit:** Merge only appends during partial reloads. A full
page visit (navigation, `router.get`) replaces the prop entirely — no stale
accumulation across pages.

## Always Props

Included even in partial reloads (which normally only include
requested props). Use sparingly for data that must always be fresh, and remember that an
`always` prop lands in the page object written to browser history state as well as in the
SSR payload.

```ruby
render inertia: {
  users: User.all.map { |user| serialize_user(user) },
  # Always included, even when the client requests only: ['users']
  server_time: InertiaRails.always { Time.current.iso8601 },
}
```

An asset-version prop is the wrong shape for this: `config.version` already travels on every
page object (`renderer.rb:135`), and `Rails.application.config` has no `version` or
`asset_version` attribute, so reaching for one raises `NoMethodError` at request time — and
inside an `always` prop that means on every response. Set `config.version = ViteRuby.digest`
in the initializer instead (see [Version Tracking](configuration.md#version-tracking)).

## Scroll Props

Scroll-aware props for infinite scroll. Combines with `<InfiniteScroll>` on the
client to automatically load more data as the user scrolls down.

`InertiaRails.scroll` takes the pagination metadata object as its first argument. A scroll
prop is not deferred, so `ScrollProp#metadata` runs on the initial render
(`props_resolver.rb:193-194`); called with no argument it raises
`InertiaRails::ScrollMetadata::MissingMetadataAdapterError` on first page load. The gem
recognises both Pagy metadata shapes (`scroll_metadata.rb:40-54`).

Where the project has no paginator gem, the `Hash` adapter takes the four page keys directly
(`scroll_metadata.rb:56-70`), and the `inertia-react:inertia-rails-performance` skill has that
form worked out in its "Server-side pagination props" section. The Pagy syntax below applies
where `Gemfile.lock` names the gem.

**Check the project's `Gemfile.lock` for the installed Pagy version** before writing
pagination code. Pagy's API was redesigned at **43.0.0** — its published history goes
`9.4.0` → `43.0.0.rc1` → `43.0.0`, with no majors in between (rubygems.org versions API;
latest 43.6.1 as of 2026-08). `limit:` exists from Pagy 9 onward; earlier versions spell it
`items:`.

```ruby
# Pagy 43+ syntax
class PostsController < ApplicationController
  include Pagy::Method

  def index
    pagy, posts = pagy(:offset, Post.order(created_at: :desc), limit: 20)
    # For cursor-based: pagy, posts = pagy(:keyset, Post.order(:id), limit: 20)

    render inertia: {
      posts: InertiaRails.scroll(pagy) { posts.map { |post| serialize_post(post) } },
    }
  end
end

# Pagy 9.x–42-none syntax, for a project still on the pre-43 API
class PostsController < ApplicationController
  include Pagy::Backend

  def index
    pagy, posts = pagy(Post.order(created_at: :desc), limit: 20)

    render inertia: {
      posts: InertiaRails.scroll(pagy) { posts.map { |post| serialize_post(post) } },
    }
  end
end
```

React side with `<InfiniteScroll>`:
```tsx
import { InfiniteScroll } from '@inertiajs/react'

export default function Index({ posts }: Props) {
  return (
    <InfiniteScroll data="posts" loading={() => <PostsSkeleton />}>
      {posts.map(post => <PostCard key={post.id} post={post} />)}
    </InfiniteScroll>
  )
}

// Manual mode — "Load more" button instead of auto-scroll
export function IndexManual({ posts }: Props) {
  return (
    <InfiniteScroll
      data="posts"
      manual
      next={({ loading, fetch, hasMore }) =>
        hasMore && (
          <button onClick={fetch} disabled={loading}>
            {loading ? 'Loading...' : 'Load more'}
          </button>
        )
      }
    >
      {posts.map(post => <PostCard key={post.id} post={post} />)}
    </InfiniteScroll>
  )
}
```

`<InfiniteScroll>` is the component for this: it tracks the page, syncs the URL, and
applies the merge behaviour. `<WhenVisible>` is a lower-level visibility trigger and does
none of that.

## Resetting Merge/Scroll Props

Merge and scroll props accumulate data across partial reloads. To discard the
accumulated state and start fresh **without a full page visit**, pass `reset`
on the client:

```tsx
// Fetch messages from scratch — clears the accumulated array first
router.reload({ only: ['messages'], reset: ['messages'] })
```

**Use when user changes filters / sort order: `reset` the prop so stale items are discarded.**

## Combining Prop Types

Which options a helper honours is decided by the modules its prop class prepends —
`PropMergeable` supplies `merge:`/`deep_merge:`/`match_on:`/`append:`/`prepend:`, and
`PropOnceable` supplies `once:`/`key:`/`expires_in:`/`fresh:`. Verified by invocation at
3.22.0:

| Helper | Accepts `merge:` | Accepts `once:` |
|---|---|---|
| `InertiaRails.defer` | yes | yes |
| `InertiaRails.merge` | it *is* the merge prop | yes |
| `InertiaRails.scroll` | it merges by construction | no |
| `InertiaRails.optional` | no — silently ignored | yes |
| `InertiaRails.once` | no — silently ignored | it *is* the once prop |
| `InertiaRails.always` | no — raises `ArgumentError` | no — raises `ArgumentError` |

```ruby
render inertia: {
  # Deferred + merge — loads after the initial render, then accumulates on subsequent reloads
  notifications: InertiaRails.defer(merge: true) {
    Current.user.notifications.recent.map { |n| serialize_notification(n) }
  },

  # Deferred + merge in a group — several props fetched together, all accumulating
  posts: InertiaRails.defer(group: 'feed', merge: true) {
    @posts.map { |post| serialize_post(post) }
  },
  comments: InertiaRails.defer(group: 'feed', merge: true) {
    @comments.map { |comment| serialize_comment(comment) }
  },

  # Deferred + once — fetched after the first render, then kept by the client
  countries: InertiaRails.defer(once: true, key: 'countries') { Country.pluck(:name, :code) },
}
```

For an `optional` or `once` prop that should accumulate, use `InertiaRails.merge` and drive
it with `router.reload({ only: [...] })` from the client. Where the `merge:` column says
"no", read on: the failure mode differs by helper.

- `InertiaRails.always(&block)` takes no keyword arguments at all
  (`inertia_rails.rb:77-79`), so any option raises `ArgumentError: wrong number of arguments
  (given 1, expected 0)` — loud, and easy to fix.
- `InertiaRails.optional(merge: true)` and `InertiaRails.once(merge: true)` raise nothing.
  Neither class prepends `PropMergeable`, so the instance has no `merge?` method,
  `collect_merge_metadata` bails on its first line (`props_resolver.rb:187-188`), and
  `BaseProp#initialize` swallows the keyword. The prop replaces the client-side array on
  every reload while the code reads as though it accumulates.

Setting both `deep_merge: true` and `merge: true` raises `ArgumentError` from
`prop_mergeable.rb:8` — pick one.

## Instance variables as props

An action's `@ivars` reach the page only under the `use_inertia_instance_props` class method
(`controller.rb:55-60`). It makes `inertia_view_assigns` hand *every* view assign to the
renderer (`controller.rb:119-123`, `renderer.rb:34-35`) — the gem's own feature, with no
third-party serializer involved, and one the upstream guide warns leaks whatever else the
action happened to assign. Naming the props in the `render inertia:` call is the alternative,
and the reason the skill body prefers it.

`config.default_render` is a separate setting and does not pass data: it only infers the
component name for an action with no explicit render. See
[Initializer](configuration.md#initializer) for where it sits.
