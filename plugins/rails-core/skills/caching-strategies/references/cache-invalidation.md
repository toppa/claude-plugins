# Caching Strategies: Cache Invalidation

One schema runs through this file: an `Event` has many `Vendor` records, each `vendor` holds an
`event_id`, and `events.vendors_count` is a counter column.

## Time-Based Expiry

```ruby
Rails.cache.fetch([ account, "stats" ], expires_in: 1.hour) { … }
```

The mechanism to reach for when the value has no record behind it — an external API response, a
report over a date range, a rate-limit tally.

## Key-Based Expiry

```ruby
Rails.cache.fetch([ event, "summary" ]) { expensive_summary(event) }
```

Rails takes `event.cache_key` (`"events/123"`) plus `event.cache_version` (its `updated_at` at
microsecond precision), so a saved record reads as a miss with no deletion step, and the store reuses
the one entry. For a collection, `relation.cache_key_with_version` folds in the newest `updated_at`
and the row count:

```ruby
Rails.cache.fetch([ event.vendors.cache_key_with_version, "roster" ]) { … }
```

Let Rails format the version. A hand-rolled `"event/#{event.id}-#{event.updated_at.to_i}"` is
second-precision, so two saves inside one second share a key and the first value is served for the
second save.

## Explicit Deletion

```ruby
# app/services/events/update_service.rb
class Events::UpdateService
  def call(event, params)
    event.update!(params)
    invalidate_related_caches(event)
    success(event)
  end

  private

  def invalidate_related_caches(event)
    Rails.cache.delete([ event.account, "dashboard_stats" ])
    Rails.cache.delete([ event.account, "event_count" ])
  end
end
```

A model callback works too, and `after_commit` is the hook that runs once the write is durable:

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  after_commit :invalidate_account_caches

  private

  def invalidate_account_caches
    Rails.cache.delete([ account, "dashboard_stats" ])
  end
end
```

Every deletion here names a whole key, which is the form every store supports.

## Deleting Groups of Keys

`delete_matched` is optional in the `Cache::Store` contract, and support at Rails 8.1 splits like
this:

| Store | `delete_matched` |
|-------|------------------|
| `:memory_store`, `:file_store` | Implemented, and the matcher is a **Regexp** |
| `:redis_cache_store` | Implemented, and the matcher is a glob |
| `:solid_cache_store` | Absent, so the base-store method raises `NotImplementedError` |
| `:null_store` | Accepted and does nothing |

Two consequences on the default stack. Solid Cache is the Rails 8 production store, so a
`delete_matched` call in an `after_commit` succeeds in development on `:memory_store` and raises in
production on the first save — the gem's failsafe rescues transient Active Record errors only, so it
propagates out of the callback. And on Memory and File stores the matcher goes through
`key_matcher`, which calls `pattern.source`, so a String matcher plus a `:namespace` raises
`NoMethodError: undefined method 'source' for an instance of String` — and the generated
`config/cache.yml` sets `namespace`.

Two portable mechanisms cover the same ground:

```ruby
# 1. A generation stamp in the key: one write invalidates the whole group.
def dashboard_generation(account)
  Rails.cache.fetch([ account, "dashboard_generation" ]) { Time.current.to_f }
end

def bump_dashboard(account)
  Rails.cache.write([ account, "dashboard_generation" ], Time.current.to_f)
end

Rails.cache.fetch([ account, "dashboard", dashboard_generation(account), "stats" ]) { … }

# 2. Name each key, and delete the ones that changed.
Rails.cache.delete_multi([ [ account, "dashboard", "stats" ], [ account, "dashboard", "events" ] ])
```

The generation counter is the one that scales, because the number of keys stays out of the caller.

## Touch for Cascade Invalidation

```ruby
# app/models/vendor.rb
class Vendor < ApplicationRecord
  belongs_to :event, touch: true, counter_cache: true
end
```

`touch: true` moves `event.updated_at` each time a vendor is created, updated or destroyed, which
moves `event.cache_version`, which is what makes a cache keyed on the event pick up the change —
including a nested fragment cache, where the outer `cache @event` needs to miss for a changed child
to appear.

`touch: true` is the option that registers the touch callbacks. `counter_cache: true` on its own
maintains the counter column and leaves `updated_at` where it is, so pass both when a cache key
depends on the count.

## Counter Caching

```ruby
# Migration
add_column :events, :vendors_count, :integer, default: 0, null: false

# Model
class Vendor < ApplicationRecord
  belongs_to :event, counter_cache: true, touch: true
end

# Usage: one attribute read, no query
event.vendors_count
```

Active Record maintains it with an atomic `UPDATE events SET vendors_count = vendors_count + 1`, so
concurrent writes stay correct. `counter_cache: true` derives the column name from the association,
and `counter_cache: :active_vendors_count` names it explicitly.

For a **filtered** count, where the built-in counter has no scope to work with, key a cached count on
the collection's own version rather than maintaining a second column:

```ruby
class Event < ApplicationRecord
  has_many :vendors

  def confirmed_vendors_count
    Rails.cache.fetch([ vendors.cache_key_with_version, "confirmed_count" ]) do
      vendors.confirmed.count
    end
  end
end
```

That stays correct through concurrent writes and keeps `updated_at` semantics intact, both of which a
hand-maintained column plus `update_columns` gives up — `update_columns` skips timestamps, so a
parent's cache key would stop moving.

To recount after a backfill or a data repair:

```ruby
Event.find_each { |event| Event.reset_counters(event.id, :vendors) }
```
