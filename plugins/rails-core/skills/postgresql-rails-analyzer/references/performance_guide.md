# PostgreSQL Performance Best Practices for Rails

This reference contains key performance concepts and recommendations from "High Performance PostgreSQL for Rails" by Andrew Atkinson.

## Table of Contents

- [Index Optimization](#index-optimization) (FK indexes, partial, composite, covering, expression, GIN, maintenance, live builds)
- [Query Optimization](#query-optimization) (N+1 prevention, eager loading, counter caches, batch processing, select)
- [Database Configuration](#database-configuration) (connection pool, timeouts, prepared statements, reaping)
- [Query Analysis with EXPLAIN](#query-analysis-with-explain) (key metrics, common issues)
- [Vacuum and Statistics](#vacuum-and-statistics) (autovacuum, manual ANALYZE)
- [Bulk Operations](#bulk-operations) (inserts, updates, upserts)
- [Schema Design Best Practices](#schema-design-best-practices) (data types, constraints, enums)
- [Monitoring and Observability](#monitoring-and-observability) (extensions, metrics, tools)
- [Common Performance Patterns](#common-performance-patterns) (pagination, full-text search, materialized views)

## Index Optimization

### Foreign Key Indexes
Always add indexes to foreign key columns. PostgreSQL doesn't automatically index foreign keys.

```ruby
# Migration example
add_index :posts, :user_id
add_index :comments, :post_id
```

### Partial Indexes
Worth their maintenance when the predicate matches a small fraction of the table **and** your queries
carry that same predicate. Index the rows you actually select.

```ruby
# A small number of jobs have failed, and the query is Job.where(failed: true)
add_index :jobs, :failed, where: "failed = true"
```

A partial index on the majority value is a full index with extra bookkeeping, and one on a value you
never filter by is never used. See `anti_patterns.md` entry 9.

### Composite Indexes
Order the columns by how the query uses them: equality columns first, then the single column used with a
range, then columns used only for `ORDER BY`.

```ruby
# WHERE status = 'active' AND created_at > '2024-01-01'
add_index :orders, [:status, :created_at]
```

PostgreSQL bounds a multicolumn B-tree scan by the equality constraints on the leading columns and then
by the first inequality; columns after that are filtered, not searched. "Most selective column first" is
not the rule — the PostgreSQL documentation on multicolumn indexes describes this structure and never
mentions selectivity.

This index already serves `WHERE status = ?` on its own, so do not add a standalone index on `status` as
well. A composite does not cover its *trailing* columns, so `WHERE created_at > ?` alone still needs its
own index. See `anti_patterns.md` entry 11 for the UNIQUE exception.

### Covering Indexes
Add non-key columns so the query can be answered from the index alone. The included columns must exist on
the table being indexed, and `INCLUDE` requires PostgreSQL 11 or newer.

```ruby
# posts.user_id is the key; posts.title is returned without a heap lookup
add_index :posts, :user_id, include: [:title]
```

### Expression Indexes
Index computed or transformed values that are frequently queried.

```ruby
# For case-insensitive email lookups
add_index :users, "lower(email)", name: "index_users_on_lower_email"
```

### GIN Indexes for JSON/Array Columns
Use GIN indexes for PostgreSQL JSON and array columns.

```ruby
add_index :products, :metadata, using: :gin
add_index :posts, :tags, using: :gin
```

### Index Maintenance
- Remove unused indexes (they slow down writes); an index backing a UNIQUE constraint stays, even
  at `idx_scan = 0`
- Rebuild bloated indexes with `REINDEX CONCURRENTLY`
- Use pg_stat_user_indexes to monitor index usage — its columns are `relname` and `indexrelname`

### Building Indexes on a Live Table
Every `add_index` above is written in its plain form. On a table large enough to matter, build it
concurrently, which keeps reads and writes running:

```ruby
class AddIndexToOrdersStatus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :orders, :status, algorithm: :concurrently
  end
end
```

`algorithm: :concurrently` and `disable_ddl_transaction!` go together and neither works alone: without
the second, the migration runs inside a transaction and PostgreSQL rejects the build with
`ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`. Because the migration is then
not atomic, use one index per migration — a failure part-way through leaves the earlier indexes applied
and an INVALID index behind, which must be dropped before retrying.

A concurrent build still takes a `SHARE UPDATE EXCLUSIVE` lock, so it blocks other DDL on the table; what
it avoids is blocking reads and writes.

## Query Optimization

### N+1 Query Prevention

#### Problem Pattern
```ruby
# Controller - loads users
@users = User.all

# View - triggers N+1 queries
@users.each do |user|
  user.posts.each do |post|  # N queries for posts
    post.comments.count        # N*M queries for comment counts
  end
end
```

#### Solution: Eager Loading
```ruby
# Load all associations upfront
@users = User.includes(posts: :comments).all

# Counting takes a different fix. A counter cache reads a column, so the association
# does not load at all — read "Counter Caches" below for the three deploys it costs.
@users = User.all  # then user.posts_count
```

### Eager Loading Methods

**includes()** - Loads associations (uses LEFT OUTER JOIN or separate queries)
```ruby
User.includes(:posts)
User.includes(posts: :comments)
```

**preload()** - Always uses separate queries
```ruby
User.preload(:posts)
```

**eager_load()** - Always uses LEFT OUTER JOIN
```ruby
User.eager_load(:posts)
```

**strict_loading** - Prevents lazy loading (raises error)
```ruby
# In model
class User < ApplicationRecord
  has_many :posts, strict_loading: true
end

# Or per-query
User.strict_loading.all
```

### Counter Caches
Avoid counting associations at query time. Cache the count.

```ruby
user.posts_count  # No query needed
```

**On a table that already has rows, this takes three deploys, and doing it in one returns wrong
answers.** The column starts at zero, and `size`, `any?`, `empty?` and `none?` read the column rather
than the database, so a user with three posts reports as having none. Rails says so in `belongs_to`'s own
documentation: the values "must be backfilled separately of the column addition … and before the use of
`:counter_cache` (otherwise methods like `size`/`any?`/etc … can produce incorrect results)".

`anti_patterns.md` entry 2 has the three steps, the `counter_cache: { active: false }` form that makes the
transition safe, and the measured before-and-after table. Follow it rather than the two-line version.

### Batch Processing
Use find_each/in_batches for processing large datasets.

```ruby
# Bad: Loads all records into memory
User.all.each { |user| user.process }

# Good: Processes in batches of 1000
User.find_each(batch_size: 1000) { |user| user.process }
```

### Select Only Needed Columns
Don't load columns you don't need.

```ruby
# Bad: Loads all columns
User.all

# Good: Only loads id and email
User.select(:id, :email)
```

## Database Configuration

### Connection Pool Sizing
The pool is per process, so size it to one process's thread count.

```yaml
# database.yml
production:
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

`max_connections` is the current key; `pool` is a deprecated alias, and setting both to different values
raises "Ambiguous configuration".

Each forked worker holds its own `ConnectionPool`, so there is no worker factor in this number. Rails'
generator writes exactly the line above, and `config/puma.rb` takes its thread count from the same
variable.

`processes × threads × servers` is a separate number — the total connections the cluster can open, which
is what to compare against the PostgreSQL server's own `max_connections` setting. Using it as the pool
size over-provisions by the worker count.

### Timeouts
Set appropriate timeouts to prevent hanging connections and long-running queries.

```yaml
production:
  connect_timeout: 5          # Connection timeout in seconds
  checkout_timeout: 5         # Pool checkout timeout in seconds
  variables:
    statement_timeout: 30000  # Query timeout in milliseconds (30s)
    lock_timeout: 5000        # Lock wait timeout in milliseconds (5s)
```

### Prepared Statements
Keep enabled unless using PgBouncer in transaction mode.

```yaml
production:
  prepared_statements: true  # Default, improves performance
```

### Connection Reaping
Rails reaps stale connections on its own every 20 seconds (`reaping_frequency`'s default in 8.1). Leave it
alone unless you have measured a reason to change it — setting it to 60 makes reaping three times less
frequent than the default, not more diligent.

## Query Analysis with EXPLAIN

`explain` on its own only plans the query. Pass `:analyze` to execute it and report real timings and row
counts, which is what the plan is worth comparing against.

```ruby
# In Rails console — emits EXPLAIN (ANALYZE) SELECT ...
User.where(status: 'active').explain(:analyze)

# Add :verbose, :buffers as needed
User.where(status: 'active').explain(:analyze, :buffers)

# Or in PostgreSQL
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active';
```

`:analyze` runs the statement, so on an `UPDATE` or `DELETE` wrap it in a transaction you roll back.

### Key Metrics to Watch
- **Seq Scan**: Sequential scan (table scan) - usually slow for large tables
- **Index Scan**: Using an index - usually good
- **Rows**: Estimated vs actual rows - large differences indicate statistics issues
- **Cost**: Query planner's cost estimate
- **Execution Time**: Actual time taken

### Common Issues
- **Sequential Scans on Large Tables**: Add an index
- **Large Row Estimate Differences**: Run ANALYZE
- **Nested Loop with Many Rows**: Consider a different join strategy
- **High Cost**: Query might need optimization or better indexes

## Vacuum and Statistics

### Autovacuum
PostgreSQL's autovacuum reclaims dead tuples and updates statistics. Ensure it's running.

```sql
-- Check autovacuum status
SELECT schemaname, relname, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_autovacuum;
```

### Manual ANALYZE
Update statistics after bulk data changes.

```sql
-- Analyze all tables
ANALYZE;

-- Analyze specific table
ANALYZE users;
```

## Bulk Operations

### Bulk Inserts
`insert_all` sends one INSERT with many VALUES rows instead of one statement per record.

```ruby
User.insert_all(rows)
```

It is not a drop-in for `create`. Verified on 8.1.3.1: it **does** set `created_at` and `updated_at`, and
it **skips** validations, callbacks and the STI `type` column — a row violating a presence validation
inserted anyway, and its `type` came back `nil`. Use it for rows already validated, set `type` yourself on
an STI table, and follow it with `ANALYZE` (see "Manual ANALYZE" above) when the insert is large.

`upsert_all` carries the same caveats.

### Bulk Updates
Use update_all or update_counters for bulk updates.

```ruby
# Bad: N UPDATE queries
User.where(status: 'pending').each { |u| u.update(status: 'active') }

# Good: Single UPDATE query
User.where(status: 'pending').update_all(status: 'active')
```

### Upserts (INSERT ON CONFLICT)
Use upsert_all for insert-or-update operations.

```ruby
User.upsert_all(
  users,
  unique_by: :email,
  update_only: [:name, :updated_at]
)
```

## Schema Design Best Practices

### Use Appropriate Data Types
- `bigint` primary keys are already the default (since Rails 5.1), so `id: :bigint` changes nothing
- Use `text` instead of `varchar` (no performance difference in PostgreSQL)
- Use `jsonb` not `json` (parsed form, and the only one GIN can index)
- `timestamptz` records an absolute instant, and Rails' PostgreSQL adapter does **not** use it by
  default — `datetime_type` defaults to `:timestamp`, so opt in with
  `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz`. It does not store a
  time zone: PostgreSQL converts the input to UTC and, in the documentation's words, "the originally
  stated or assumed time zone is not retained". Choose it for correct comparison across zones, not to
  remember one.

### Constraints and Validation
Add database constraints for data integrity.

```ruby
# In migration
add_foreign_key :posts, :users
add_check_constraint :products, "price > 0", name: "positive_price"
change_column_null :users, :email, false
```

`add_not_null_constraint` is a `strong_migrations` method, not a Rails one — zero hits across
activerecord 8.1.3.1. Rails' method is `change_column_null`.

### Enum vs String Columns
For limited set of values, consider PostgreSQL enums or constrained strings.

```ruby
# String with constraint
add_column :orders, :status, :string
add_check_constraint :orders, "status IN ('pending', 'shipped', 'delivered')"
```

```ruby
# Or a PostgreSQL enum, via Rails' own API (7.0+)
create_enum :order_status, %w[pending shipped delivered]
add_column :orders, :status, :enum, enum_type: :order_status, default: "pending", null: false
```

Prefer `create_enum` over a raw `execute "CREATE TYPE …"`: it is reversible, and it reads as schema rather
than as a side effect. Both do round-trip through `schema.rb` — the PostgreSQL schema dumper enumerates
enum types from the catalog, so a type created by raw `execute` is still dumped as `create_enum`, verified
on 8.1.3.1. Adding a value later is `ALTER TYPE … ADD VALUE`, which cannot run inside a transaction;
removing one means recreating the type.

## Monitoring and Observability

### Essential Extensions
Enable these extensions in PostgreSQL:

```sql
-- Query statistics
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Index bloat checking
CREATE EXTENSION IF NOT EXISTS pgstattuple;
```

### Key Metrics to Monitor
- Active connections vs connection pool size
- Slow queries (via pg_stat_statements)
- Buffer cache hit ratio — expect 99% or better on an OLTP database, which is also PgHero's default
  `cache_hit_rate_threshold`. A 90% target would leave one read in ten going to disk and still look green
- Index usage vs sequential scans
- Table and index bloat
- Lock waits and deadlocks

### Tools
Available without adding anything:
- **pg_stat_statements** and **pgstattuple**: PostgreSQL extensions, no gem required
- **EXPLAIN (ANALYZE)**: query execution plans, via `.explain(:analyze)`
- **Rails query logs**: enable in development for visibility
- **strict_loading**: `strict_loading_by_default` with `action_on_strict_loading_violation`, which is
  Rails' own runtime N+1 detection

Gems — check the `Gemfile` first and suggest one only if it is already there:
- **PgHero**: web dashboard for PostgreSQL monitoring
- **Bullet**: runtime N+1 detection, superseded for most purposes by `strict_loading`

## Common Performance Patterns

### Pagination
Use keyset pagination for better performance on large datasets.

```ruby
# Bad: OFFSET pagination — the server still walks the skipped rows
User.limit(20).offset(1000)

# Good: Keyset pagination, ordered by the same column the cursor uses
User.where('id > ?', last_id).order(:id).limit(20)
```

The `ORDER BY` is not optional. Without it PostgreSQL may return the 20 rows in any order, so successive
pages skip and repeat rows. Order by the cursor column, and where it is not unique — `created_at` — order
by it *and* the primary key, and compare the pair:

```ruby
User.where('(created_at, id) > (?, ?)', last_created_at, last_id).order(:created_at, :id).limit(20)
```

### Full-Text Search
Use PostgreSQL's built-in full-text search with GIN indexes.

Use a stored generated column, which PostgreSQL maintains itself — no trigger to keep in step with the
column list, and Rails 8.1 supports it (`supports_virtual_columns?` is true on the PostgreSQL adapter).

```ruby
create_table :posts do |t|
  t.string :title
  t.text :body
  t.virtual :search_vector, type: :tsvector, stored: true,
            as: "to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))"
  t.index :search_vector, using: :gin
end
```

```ruby
Post.where("search_vector @@ plainto_tsquery('english', ?)", "rails postgresql")
```

Verified end to end on PostgreSQL 17.10: the generated column populated itself on insert and the GIN index
matched the query. The expression must be immutable, which is why the language is written out rather than
left to the `default_text_search_config` setting.

A `BEFORE INSERT OR UPDATE` trigger calling `tsvector_update_trigger` is the older form and still works;
prefer the generated column on PostgreSQL 12 and above.

### Materialized Views
Cache complex query results.

```ruby
execute <<~SQL
  CREATE MATERIALIZED VIEW user_statistics AS
  SELECT user_id, COUNT(*) AS post_count, MAX(created_at) AS last_post
  FROM posts
  GROUP BY user_id;
SQL

# Required before any concurrent refresh: a unique index with no WHERE clause
execute "CREATE UNIQUE INDEX user_statistics_user_id ON user_statistics (user_id);"
```

```ruby
execute "REFRESH MATERIALIZED VIEW CONCURRENTLY user_statistics;"
```

The unique index is not optional. Refreshing concurrently without one fails with
`ERROR: cannot refresh materialized view "public.user_statistics" concurrently / HINT: Create a unique
index with no WHERE clause on one or more columns of the materialized view.` — verified on PostgreSQL
17.10. A plain `REFRESH MATERIALIZED VIEW` needs no index but takes an `ACCESS EXCLUSIVE` lock, so readers
block until it finishes.
