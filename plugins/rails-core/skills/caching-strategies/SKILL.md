---
name: caching-strategies
description: >-
  Rails caching — choosing a cache store, Solid Cache in production, low-level
  caching with `Rails.cache`, cache key design, HTTP caching with ETags and
  `Cache-Control`, counter caches, memoization, cache invalidation, fragment
  caching of an ERB partial, and caching one key of a props hash or a JSON payload.
when_to_use: >-
  Use when the user asks to add caching or to cache a slow page, or mentions
  cache keys, cache invalidation, a stale cache, ETags, `Cache-Control`, Solid
  Cache, a counter cache, memoization, Russian doll caching, or caching one
  prop or one part of a JSON response, and when testing a cache or reading its
  hit rate.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/caching-strategies/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: Rails 8.1.3.1, solid_cache 1.0.10, inertia_rails 3.22.0, Ruby 3.4.5
---

# Caching Strategies for Rails 8

Five layers, and they are chosen independently:

- **`Rails.cache`** — arbitrary values, and the one that applies to every Rails app whatever it
  renders. Start here.
- **HTTP caching** — ETags, `Last-Modified` and `Cache-Control`, for browsers and CDNs.
- **Counter caches and memoization** — cheaper than a cache store, because there is nothing to expire.
- **Fragment caching** — an ERB partial, through the `cache` view helper. It is the main layer
  under Hotwire.
- **Prop caching** — one key of a response the action builds itself, under Inertia or JSON API.

Verified against Rails 8.1.3.1, solid_cache 1.0.10 and inertia_rails 3.22.0.

## Choosing a store

| Store | Fits | Properties |
|-------|------|------------|
| `:solid_cache_store` | Production, and the Rails 8 default | Database-backed, shared across processes, size-capped, and it relies on recyclable cache keys |
| `:memory_store` | Development, and the generated default there | Per-process, size-limited, resets on reload |
| `:redis_cache_store` | Production, where `redis` is already in the Gemfile | Shared, fast |
| `:file_store` | A single-host deployment | Persistent on that host, local to it |
| `:null_store` | Test, and the generated default there | Accepts every write and returns a miss for every read |

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

Solid Cache is what a Rails 8.1 app already has, so it is the store to configure first. Reach for
`:redis_cache_store` when `rg -n '"redis"' Gemfile` finds the gem, because `RedisCacheStore` needs it
and says so at boot; suggest the gem to the user rather than adding it.

Development generates `:memory_store` already, wrapped so that caching is off until you ask for it:

```bash
bin/rails dev:cache     # creates tmp/caching-dev.txt and restarts with caching on
```

That toggle is what the generated `if Rails.root.join("tmp/caching-dev.txt").exist?` block in
`development.rb` exists to serve, so leave the block in place and use the command. Note what the
toggle covers: `perform_caching` gates fragment and collection caching, and `Rails.cache` reads and
writes happen either way.

## Low-level caching with `Rails.cache`

`Rails.cache.fetch` with a block is the pattern that carries most of the value — an expensive query,
an external API response, a computed dashboard, or the props a controller is about to render.

```ruby
Rails.cache.fetch([ account, "dashboard_stats" ], expires_in: 15.minutes) do
  DashboardStatsQuery.new(account: account).stats
end
```

See [low-level-caching.md](references/low-level-caching.md) for fetch/read/write/delete, caching in
service and query objects, instance-variable memoization, and request-scoped memoization with
`CurrentAttributes`.

## Cache key design

Pass records and arrays rather than interpolated strings, and Rails builds the key:

```ruby
Rails.cache.fetch([ event, current_user, "summary" ]) { … }
```

- `event.cache_key` is the stable `"events/123"`, and the timestamp lives separately in
  `event.cache_version`. `cache_versioning` has been on since `load_defaults 5.2`, so the version is
  compared on read rather than baked into the key. That is what makes keys **recyclable**, and it is
  how a size-capped store such as Solid Cache reuses one entry per record as it changes.
- `relation.cache_key_with_version` gives a collection its own key, including the newest
  `updated_at` and the row count.
- Rails formats those timestamps at microsecond precision, in `cache_version` and in the
  `cache_key_with_version` string. A hand-rolled `"#{event.updated_at.to_i}"` is second-precision, so
  two writes inside one second produce the same value and the stale entry survives.

A fragment cache key adds the compiled template digest, digest first:

```
views/events/_event:abc123digest/events/123
```

## HTTP caching

`stale?` and `fresh_when` handle conditional GET, and `expires_in` sets `Cache-Control`. One
`expires_in` call per action carries the whole policy, since a second call replaces the options the
first one set. See [http-caching-and-testing.md](references/http-caching-and-testing.md).

## Counter caches and memoization

A counter column answers `event.vendors_count` with no query, and `counter_cache: true` maintains it
with an atomic `UPDATE … SET c = c + 1`. It moves the count and leaves `updated_at` alone, so pair it
with `touch: true` when a cache key depends on the parent record changing. See
[cache-invalidation.md](references/cache-invalidation.md).

Memoization is the other half of this heading, and it lives in
[low-level-caching.md](references/low-level-caching.md), section "Memoization". It holds a
value per object or per request, so it needs no store and no expiry.

## Cache invalidation

Three mechanisms: time-based expiry via `expires_in`, key-based expiry via the record's version, and
explicit deletion by key. Key-based expiry is the one that needs no bookkeeping, and `touch: true` on
a `belongs_to` extends it up an association chain. See
[cache-invalidation.md](references/cache-invalidation.md) for each mechanism, for which stores
implement `delete_matched`, and for counter caches.

## Fragment caching in ERB views

Under Hotwire this layer carries most of the win, because every page the app serves is an ERB
template. The `cache` helper caches a partial keyed on a record plus the template
digest, and nesting the calls gives Russian-doll caching, where inner fragments survive an
outer miss:

```erb
<%# app/views/events/show.html.erb %>
<% cache @event do %>
  <h1><%= @event.name %></h1>
  <% @event.comments.each do |comment| %>
    <% cache comment do %>
      <%= render comment %>
    <% end %>
  <% end %>
<% end %>
```

For the nesting to pay off, a change to a `Comment` has to move `@event.updated_at`, which is what
`belongs_to :event, touch: true` on the child does.

Collection rendering caches each item in one multi-read:

```erb
<%= render partial: "events/event", collection: @events, cached: true %>
<%= render partial: "events/event", collection: @events,
           cached: ->(event) { [ event, current_user.admin? ] } %>
```

An Inertia or JSON API project serves no page templates, so this layer covers only the ERB such
a project still has: the layouts, and the mailer views. A mailer view that renders a collection
earns its `cached: true` for the same reason a page does.

## Caching one piece of a response the action builds

Where the action builds the response itself — a props hash under Inertia, a payload under JSON
API — the unit of caching is one key of that response rather than one partial. It is the same
thinking as a fragment, and everything above about key design transfers to it.

Reach for it where one key is expensive and the rest of the response is cheap: a report, an
aggregate, or a long serialized association list. Where the whole response is expensive, cache
the query behind it with `Rails.cache.fetch` instead. That one entry then serves every caller of
the query rather than this action alone.

Under JSON API this needs nothing new: `Rails.cache.fetch` around the value, in the form the
"Low-level caching with `Rails.cache`" section above shows. Under Inertia the gem ships its own
version:

```ruby
def show
  event = Event.find(params[:id])

  render inertia: "Events/Show", props: {
    event: serialize_event(event),
    vendors: InertiaRails.cache([ event, :vendors ], expires_in: 1.hour) do
      event.vendors.map { |vendor| serialize_vendor(vendor) }
    end
  }
end
```

The key accepts a record or an array exactly as the `cache` helper does, so
`cache_key_with_version` and `touch: true` drive invalidation the same way. The rest belongs to
the `inertia-react:inertia-rails-performance` skill, in its "Memoising an expensive prop"
section: what the store is, what is stored, the `cache:` option a `defer` or an `optional` prop
takes, and the caches an Inertia app has that are not `Rails.cache` at all.

## Instrumentation

```ruby
# config/environments/production.rb
config.action_controller.enable_fragment_cache_logging = true
```

For hit rates across all stores, subscribe to `cache_read.active_support` and read
`payload[:hit]` — see [http-caching-and-testing.md](references/http-caching-and-testing.md).

## Checklist

- [ ] Cache store chosen per environment, with Solid Cache in production
- [ ] `Rails.cache.fetch` around the expensive query or API call
- [ ] Keys built from records and arrays, so versions and digests come for free
- [ ] `touch: true` where a child's change has to invalidate a parent's key
- [ ] Counter caches for counts
- [ ] Under Hotwire, `cache` around a partial keyed on a record, and `cached: true` on a collection
- [ ] Under Inertia or JSON API, each expensive key of the response cached on its own
- [ ] HTTP caching headers on API and read-mostly endpoints
- [ ] An invalidation mechanism named for every key written
- [ ] Tests that run against a real store, so they can fail
- [ ] Hit/miss rates visible in logs or metrics

## References

- [low-level-caching.md](references/low-level-caching.md) — fetch/read/write, service objects, query objects, memoization
- [cache-invalidation.md](references/cache-invalidation.md) — expiry mechanisms, `delete_matched` by store, `touch:`, counter caches
- [http-caching-and-testing.md](references/http-caching-and-testing.md) — ETags, `Cache-Control`, spec configuration, instrumentation

## Related skills

- A page that is slow from N+1 queries gets its biggest win from the queries, and caching compounds
  that win afterwards. The `rails-core:postgresql-rails-analyzer` skill finds them and is
  user-invoked only, so name it for the user to run and carry on with the caching work in front of
  you.
- Warming or refreshing a cache on a schedule is a job whose body is this skill's — the `fetch`
  call and the key. The schedule around it belongs to `rails-core:solid-queue-setup`, in its
  "Recurring jobs" and "Creating jobs" sections; it says nothing about caching itself.
