# Query Object Patterns

## Basic Query Structure

```ruby
# app/queries/[name]_query.rb
class NameQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  # @return [ActiveRecord::Relation<Model>]
  def call
    account.models
      .where(conditions)
      .order(created_at: :desc)
  end
end
```

Every query object takes its tenant in the constructor and exposes `#call`. Keeping that
shape identical across queries is what lets a controller, a job and a channel each call
the same object without reading it first.

## Query Categories

### 1. Filter Queries

Return filtered ActiveRecord relations:

```ruby
# app/queries/confirmed_events_query.rb
class ConfirmedEventsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(date_range: nil)
    scope = account.events.confirmed
    scope = scope.where(event_date: date_range) if date_range
    scope.includes(:venue, :vendors).order(event_date: :asc)
  end
end
```

The status is `:confirmed`, one of the four the model's enum defines. A value the enum does
not define behaves differently on each side: assignment raises, but **a `where` clause
does not** — `EnumType#serialize` falls back to the Integer subtype, which casts an unknown
symbol to `nil`, so `where(status: :active)` compiles to `WHERE status IS NULL` and quietly
returns the wrong rows. `account.events.confirmed` uses the scope the enum generates, which
cannot go stale that way.

### 2. Aggregation Queries

Return computed statistics:

```ruby
# app/queries/revenue_stats_query.rb
class RevenueStatsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(period: :month)
    {
      total: total_revenue,
      by_period: revenue_by_period(period),
      by_category: revenue_by_category
    }
  end

  private

  def total_revenue
    account.orders.completed.sum(:total_cents)
  end

  def revenue_by_period(period)
    group_clause = case period
    when :day then "DATE(created_at)"
    when :week then "DATE_TRUNC('week', created_at)"
    when :month then "DATE_TRUNC('month', created_at)"
    end

    account.orders.completed
      .group(Arel.sql(group_clause))
      .sum(:total_cents)
  end

  def revenue_by_category
    account.orders.completed
      .joins(line_items: :product)
      .group("products.category")
      .sum(:total_cents)
  end
end
```

`Arel.sql` is required for a `group` argument built in Ruby, and it is safe here only
because `group_clause` comes from a `case` over a symbol the query controls. A fragment
containing anything from `params` needs a bind parameter instead.

### 3. Dashboard Queries

Several related metrics, returned as one hash. This is the canonical
`DashboardStatsQuery` — a controller and `DashboardChannel.broadcast_stats` both call
`DashboardStatsQuery.new(account: account).call`:

```ruby
# app/queries/dashboard_stats_query.rb
class DashboardStatsQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call
    {
      total_events: account.events.count,
      upcoming_events: account.events.upcoming.count,
      events_by_type: account.events.group(:event_type).count,
      pending_tasks: account.tasks.pending.count,
      leads_by_status: account.leads.group(:status).count,
      recent_events: account.events.recent.limit(5)
    }
  end
end
```

### 4. Search Queries

Full-text search with filters:

```ruby
# app/queries/vendor_search_query.rb
class VendorSearchQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(term:, filters: {})
    scope = account.vendors

    scope = apply_search(scope, term) if term.present?
    scope = apply_filters(scope, filters)
    scope = apply_sorting(scope, filters[:sort])

    scope.includes(:category, :reviews)
  end

  private

  def apply_search(scope, term)
    scope.where(
      "name ILIKE :term OR description ILIKE :term",
      term: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    )
  end

  def apply_filters(scope, filters)
    scope = scope.where(category_id: filters[:category]) if filters[:category]
    scope = scope.where(active: true) if filters[:active_only]
    scope = scope.where("rating >= ?", filters[:min_rating]) if filters[:min_rating]
    scope
  end

  def apply_sorting(scope, sort)
    case sort
    when "name" then scope.order(name: :asc)
    when "rating" then scope.order(rating: :desc)
    when "recent" then scope.order(created_at: :desc)
    else scope.order(name: :asc)
    end
  end
end
```

Rails ships the `LIKE` escaping: `ActiveRecord::Base.sanitize_sql_like`. A hand-rolled
`term.gsub(/[%_]/) { |x| "\\#{x}" }` escapes the two wildcards but not the escape
character itself, so a term containing a literal backslash produces a malformed pattern —
`50%_off\now` comes back as `50\%\_off\now`, where `\n` now escapes an `n`. The Rails
version doubles it: `50\%\_off\\now`.

### 5. Report Queries

Complex data for exports. **A row-per-event report that aggregates two independent
has-many associations needs one subquery per aggregate, not a join:**

```ruby
# app/queries/event_report_query.rb
class EventReportQuery
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def call(date_range:)
    account.events
      .where(event_date: date_range)
      .select(
        "events.*",
        "(SELECT COUNT(*) FROM attendees WHERE attendees.event_id = events.id) AS attendee_count",
        "(SELECT COALESCE(SUM(event_vendors.amount_cents), 0) FROM event_vendors " \
          "WHERE event_vendors.event_id = events.id) AS total_vendor_cost"
      )
      .order(event_date: :asc)
  end
end
```

`joins(:attendees, :event_vendors).group("events.id")` looks like the shorter way to write
this and it returns wrong money. The two joins produce a cartesian product, so every
`event_vendors` row repeats once per attendee and `SUM(event_vendors.amount_cents)` comes
back multiplied by the attendee count. Executed against Rails 8.1.3.1 and PostgreSQL: an
event with 3 attendees and vendor rows of 10,000 and 5,000 cents reports **45,000 instead
of 15,000**. `COUNT(DISTINCT attendees.id)` is right in the same query, which is what makes
the bug hard to see — `DISTINCT` protects the count and nothing protects the sum. The
`INNER JOIN` also drops every event with no attendees, so the report is short a row as
well as long on money; the subquery form returns that event with `0` and `7,000`.

A subquery per aggregate keeps one row per event, so `includes` is unnecessary here. Add it
only for an association the export itself reads, and never alongside a `select`/`group`
aggregate — the eager-load join adds the association's columns to the SELECT list, and
PostgreSQL rejects the query with `column "vendors.id" must appear in the GROUP BY clause`.

## Performance Patterns

### Eager Loading

```ruby
def call
  account.events
    .includes(:venue)                    # belongs_to
    .includes(:vendors)                  # has_many :through
    .includes(attendees: :user)          # nested
    .preload(:documents)                 # always a separate query
    .eager_load(:primary_contact)        # always a LEFT JOIN
end
```

### Batch Processing

```ruby
def process_all
  account.events.find_each(batch_size: 100) do |event|
    yield event
  end
end
```

### Subquery Optimization

```ruby
def call
  active_vendor_ids = account.vendors.active.select(:id)

  account.events
    .where(vendor_id: active_vendor_ids)
    .order(created_at: :desc)
end
```

`select(:id)` keeps this one statement. `pluck(:id)` would load every id into Ruby and
send them back as a literal list.

## Multi-Tenancy Patterns

### Always Scope Through Account

```ruby
def call
  account.events.confirmed
end
```

Reach through the tenant. `Event.where(account_id: account.id, status: :confirmed)` emits
identical SQL and is equally scoped, so the argument is not that one is a vulnerability and
the other is not — it is that reaching through the association makes the tenant predicate
structural, present because of where the query starts rather than because someone
remembered to type it. The line that is a real risk is the one that takes the tenant from
the request: `Event.where(account_id: params[:account_id])` scopes to whatever the client
asked for.

### Test Isolation

```ruby
RSpec.describe ConfirmedEventsQuery, type: :model do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  let!(:our_event) { create(:event, :confirmed, account: account) }
  let!(:their_event) { create(:event, :confirmed, account: other_account) }

  it "only returns events for the account" do
    result = described_class.new(account: account).call

    expect(result).to include(our_event)
    expect(result).not_to include(their_event)
  end
end
```

## Composition Patterns

### Query Chaining

```ruby
events = ConfirmedEventsQuery.new(account: account).call
upcoming = events.where(event_date: Date.current..)
```

A query object that returns a relation can be narrowed further by its caller. One that
returns a hash of computed metrics cannot, which is the practical reason to keep the two
kinds apart.

### Query Composition

```ruby
class ComplexReportQuery
  def initialize(account:)
    @events_query = ConfirmedEventsQuery.new(account: account)
    @revenue_query = RevenueStatsQuery.new(account: account)
  end

  def call(date_range:)
    {
      events: @events_query.call(date_range: date_range),
      revenue: @revenue_query.call
    }
  end
end
```

## Usage in Controllers

```ruby
class EventsController < ApplicationController
  def index
    @events = ConfirmedEventsQuery.new(account: current_account).call.limit(25)
  end

  def dashboard
    @stats = DashboardStatsQuery.new(account: current_account).call
  end
end
```

Both lines end in a value. A query object assigned without `#call` — `@stats =
DashboardStatsQuery.new(account: current_account)` — hands the view an object it will call
methods on lazily, which is how a dashboard ends up issuing its queries from inside the
template. `.page(params[:page])` in place of `.limit` needs `kaminari` or `pagy` in the
`Gemfile`.

## Checklist

- [ ] Constructor accepts `account:` or `user:`
- [ ] Always scoped through account (multi-tenant)
- [ ] Return type documented (`@return`)
- [ ] Uses `.includes()` to prevent N+1, except alongside a `select`/`group` aggregate
- [ ] Search terms escaped with `sanitize_sql_like`
- [ ] Aggregates over two associations use subqueries, not joins
- [ ] Spec tests tenant isolation
- [ ] Complex queries explain their purpose
