# Caching Strategies: Low-Level Caching

## Basic Read/Write/Fetch

```ruby
# Read through a block (fetch — the pattern to reach for)
Rails.cache.fetch([ account, "stats" ], expires_in: 1.hour) do
  {
    total_events: account.events.count,
    total_revenue: account.orders.sum(:total_cents)
  }
end

# Read on its own (nil on a miss)
stats = Rails.cache.read([ account, "stats" ])

# Write on its own
Rails.cache.write([ account, "stats" ], stats, expires_in: 1.hour)

# Delete
Rails.cache.delete([ account, "stats" ])

# Many keys in one round trip
Rails.cache.fetch_multi(*accounts) { |account| expensive_stats_for(account) }
```

Passing the record or an array lets Rails build the key, which brings the record's
`cache_version` along and keeps the key recyclable. See "Cache key design" in the
`rails-core:caching-strategies` `SKILL.md`.

## In Service Objects

```ruby
# app/services/dashboard_stats_service.rb
class DashboardStatsService
  CACHE_TTL = 15.minutes

  def call(account:)
    Rails.cache.fetch(cache_key(account), expires_in: CACHE_TTL) do
      calculate_stats(account)
    end
  end

  def invalidate(account:)
    Rails.cache.delete(cache_key(account))
  end

  private

  def cache_key(account)
    [ account, "dashboard_stats" ]
  end

  def calculate_stats(account)
    {
      events_count: account.events_count,
      upcoming_events: account.events.upcoming.count,
      total_revenue: account.orders.sum(:total_cents)
    }
  end
end
```

`CACHE_TTL = 15.minutes` is a house default with no external source; pick the interval from how
stale the number is allowed to be.

## In Query Objects

```ruby
# app/queries/dashboard_stats_query.rb
class DashboardStatsQuery
  def initialize(account:, use_cache: true)
    @account = account
    @use_cache = use_cache
  end

  def stats
    return compute_stats unless @use_cache

    Rails.cache.fetch(cache_key("stats"), expires_in: 5.minutes) { compute_stats }
  end

  def upcoming_events(limit: 5)
    return fetch_upcoming_events(limit) unless @use_cache

    Rails.cache.fetch(cache_key("upcoming", limit), expires_in: 5.minutes) do
      fetch_upcoming_events(limit)
    end
  end

  private

  def cache_key(type, *args)
    [ @account, "dashboard", type, *args ]
  end

  def compute_stats
    {
      events_count: @account.events_count,
      upcoming_count: @account.events.upcoming.count
    }
  end

  def fetch_upcoming_events(limit)
    @account.events.upcoming.limit(limit).to_a
  end
end
```

The `use_cache: false` switch is what makes the query object testable without a store.

## Memoization

Memoization is per object or per request, so it needs no expiry and no store — reach for it first
when the same value is computed more than once inside one request.

### Instance Variable Memoization

```ruby
class EventPresenter < BasePresenter
  def total_cost
    @total_cost ||= event.event_vendors.sum(:amount_cents)
  end

  def vendor_count
    event.vendors_count   # a counter cache column: already one attribute read
  end
end
```

Memoize the computed values. A count with a counter-cache column behind it is already an attribute
read, so it needs nothing — see "Counter Caching" in
[cache-invalidation.md](cache-invalidation.md).

`@x ||= …` recomputes when the value is `nil` or `false`; use `defined?(@x) ? @x : @x = …` where
those are real results.

### Request-Scoped Memoization

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :dashboard_stats

  def dashboard_stats
    super || self.dashboard_stats = DashboardStatsQuery.new(account: account).stats
  end
end
```

Every name used has to be declared in `attribute` — `account` as well as `dashboard_stats` — and
`super` reaches the reader `attribute` generated, which is what makes the memoization work.
`CurrentAttributes` resets between requests, so this holds a value for the current request only.
