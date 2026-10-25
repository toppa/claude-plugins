# PostgreSQL Patterns in Rails, and the Smells They Replace

Each entry states the form to write, then names the smell to search for in prose. Verified against
Rails 8.1.3.1 and PostgreSQL 17.10.

## Table of Contents

- [Queries](#queries) (1-7: N+1, counter caches, batching, existence, pluck, counting)
- [Indexes](#indexes) (8-11: foreign keys, partial, column order, redundancy)
- [Schema](#schema) (12-15: text, constraints, jsonb, primary keys)
- [Configuration](#configuration) (16-18: timeouts, pool size, pg_stat_statements)
- [Transactions](#transactions) (19-20: duration, savepoints)
- [Writing Queries](#writing-queries) (21-23: bind parameters, exact matches, case insensitivity)
- [Maintenance](#maintenance) (24-25: index usage, statistics)

## Queries

### 1. Eager load every association a loop touches

```ruby
@posts = Post.includes(:user).limit(10)
```

`includes` lets Active Record choose between a second query and a `LEFT OUTER JOIN`; `preload` always
uses a second query, `eager_load` always joins.

**Smell:** an iteration that reads an association absent from the query's eager-load list. Search for
`.each`, `.map`, `render inertia:`, and `render partial:` with `collection:` near a query. Check each
association the block touches. Under Hotwire the loop usually sits in the template rather than the
controller, so search `app/views/**/*.erb` as well.
`${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_n_plus_one.rb` does this over
`app/controllers` only, using the associations your models declare. For runtime coverage that reaches templates and background jobs, set
`config.active_record.strict_loading_by_default = true` with
`action_on_strict_loading_violation = :log`.

### 2. Roll out a counter cache in three steps, in three deploys

A counter cache trades a `COUNT` per read for a column. On a table that already has rows, adding it in
one step **returns wrong answers**, because `size`, `any?`, `empty?` and `none?` read the column and the
column starts at zero.

Rails states this in `belongs_to`'s own documentation: the values "must be backfilled separately of the
column addition (to not lock the table for too long) and before the use of `:counter_cache` (otherwise
methods like `size`/`any?`/etc, which use counter caches internally, can produce incorrect results)".

**Step 1 — add the column.** A default plus `null: false` is safe on PostgreSQL 11+, which stores the
default in the catalog rather than rewriting the table.

```ruby
add_column :users, :posts_count, :integer, default: 0, null: false
```

**Step 2 — declare it inactive, and deploy.** Writes now maintain the column, while reads keep going to
the database, so nothing reads a half-filled column.

```ruby
class Post < ApplicationRecord
  belongs_to :user, counter_cache: { active: false }
end
```

**Step 3 — backfill in batches, then activate in a deploy that ships after the backfill has
finished every row.**

```ruby
User.in_batches do |batch|
  batch.each { |user| User.reset_counters(user.id, :posts) }
end
```

```ruby
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end
```

Measured on PostgreSQL 17.10 with a user holding three posts, adding the column and the
`counter_cache` declaration together, in each of its two forms:

| Read | With `counter_cache: true`, not backfilled | With `counter_cache: { active: false }` |
|---|---|---|
| `user.posts.size` | `0` | `3` |
| `user.posts.any?` | `false` | `true` |
| `user.posts.empty?` | `true` | `false` |
| `user.posts.count` | `3` | `3` |

`count` is right in both columns because it always issues the query. That is what makes the bug hard to
see: the reads that break are the ones that look like they cannot break.

**Smell:** a `counter_cache` added in the same commit as its column, or any migration adding a
`*_count` column with no backfill beside it.

### 3. Iterate in batches

```ruby
User.find_each(batch_size: 1000) { |user| user.deliver_welcome }
```

`in_batches` yields relations instead of records when you want `update_all` or `delete_all` per batch.

**Smell:** `.all.each`, or `.each` on a relation with no limit.

### 4. Ask the database whether rows exist

```ruby
if user.posts.exists?
```

On an unloaded relation `any?` is `!empty?`, and `empty?` is `!exists?`, so **`any?` and `exists?` issue
the same statement**. Verified: both emit `SELECT 1 AS one FROM "widgets" WHERE ... LIMIT $2`. Prefer
`exists?` for saying what you mean, not for saving a query. On an *already loaded* relation `any?` uses
the loaded records and issues nothing, which is the better choice there.

**Smell:** `.length` or `.to_a.any?` on a relation you have not loaded — those do load every row
(`SELECT "widgets".* FROM "widgets" WHERE ...`). Also `.count` where existence is the question, since
`COUNT` scans more than a `LIMIT 1`.

### 5. Pluck every column you need in one call

```ruby
User.where(active: true).pluck(:id, :name)  # => [[1, "Alice"], [2, "Bob"]]
```

**Smell:** two `pluck` calls on the same conditions.

### 6. Pluck instead of instantiating

```ruby
User.where(active: true).pluck(:email)
```

**Smell:** `.map(&:some_attribute)` on a relation, which loads every column of every row to read one.

### 7. Choose between count, size and length deliberately

- `count` issues `COUNT`, every time.
- `size` issues `COUNT` when the relation is unloaded and counts in memory when it is loaded. It also
  reads a counter cache when one is active, which is why entry 2 matters.
- `length` loads the relation and counts in memory.

**Smell:** `length` on an unloaded relation, or `count` inside a loop over records already in memory.

## Indexes

### 8. Index every foreign key

```ruby
create_table :posts do |t|
  t.belongs_to :user, foreign_key: true  # index: true is the default
end
```

PostgreSQL creates an index for a `PRIMARY KEY` and for `UNIQUE`, but **not** for a foreign key
constraint. Without one, every delete or key update on the parent scans the child table.

**Smell:** a `bigint` column named `*_id` with no index leading with it.
`${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_indexes.rb` reports these,
ranking columns that `add_foreign_key` declares above ones guessed from the name.

### 9. Make a partial index match the query, on a minority of rows

A partial index is worth its maintenance only when its predicate matches a small fraction of the table
**and** your queries carry that same predicate.

```ruby
# A job queue where a small number of rows have failed, queried as Job.where(failed: true)
add_index :jobs, :failed, where: "failed = true"
```

The predicate belongs on the value you actually select. A partial index on the majority value is close
to a full index with extra bookkeeping, and one on a value you never filter by is never used.

**Smell:** a partial index whose predicate does not appear verbatim in any query, or a plain index on a
boolean where one value holds nearly every row.

### 10. Order composite index columns by how the query uses them

Equality columns first, then the one column used with a range, then columns used only for `ORDER BY`.

```ruby
# WHERE status = 'active' AND created_at > '2024-01-01'
add_index :orders, [:status, :created_at]
```

PostgreSQL can use a multicolumn B-tree when there are constraints on the leading columns; the scan is
bounded by the equality constraints and then by the first inequality, and columns after that are
filtered rather than searched. "Put the most selective column first" is not the rule — the PostgreSQL
documentation on multicolumn indexes describes the equality-then-inequality structure and does not
mention selectivity.

**Smell:** a composite index whose leading column is the one used with `>`, `<` or `BETWEEN`.

### 11. Keep one index per access path

```ruby
add_index :posts, [:user_id, :created_at]
```

This serves `WHERE user_id = ?` as well as `WHERE user_id = ? AND created_at > ?`, so a separate index
on `user_id` alone adds write cost for nothing. Two exceptions:

- A single-column **UNIQUE** index is not redundant with a composite that starts with the same column —
  it enforces a constraint the composite does not.
- A composite does **not** cover its trailing columns, so `WHERE created_at > ?` alone still needs its
  own index.

**Smell:** an index whose column list is a leading prefix of another index's, and which is not UNIQUE.

## Schema

### 12. Use text for strings

```ruby
t.text :description
```

`varchar(n)`, `varchar` and `text` have the same performance in PostgreSQL. A length cap belongs in a
check constraint or a model validation, where changing it does not require altering the column type.

**Smell:** `limit:` on a `t.string`, chosen for storage reasons rather than a real domain rule.

### 13. Put the constraint in the database as well as the model

```ruby
class AddEmailConstraints < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :email, unique: true
    change_column_null :users, :email, false
  end
end
```

A uniqueness validation alone loses to a race between two requests; only the unique index rejects the
second write. The version bracket is required — inheriting from `ActiveRecord::Migration` with no
version raises "Directly inheriting from ActiveRecord::Migration is not supported."

**Smell:** `validates :x, uniqueness: true` with no matching unique index; `add_not_null_constraint`,
which is a `strong_migrations` method rather than a Rails one — Rails' own method is
`change_column_null`.

### 14. Use jsonb

```ruby
add_column :products, :metadata, :jsonb
add_index :products, :metadata, using: :gin
```

`json` stores the original text and reparses on every access; `jsonb` stores a parsed form and is the
only one of the two that GIN can index.

**Smell:** a `:json` column, especially one that anything queries into.

### 15. Take the default primary key

```ruby
create_table :events do |t|
  t.timestamps
end
```

Rails has created `bigint` primary keys since 5.1, so `id: :bigint` is a no-op — verified by dumping
both forms on PostgreSQL 17.10, which reports `bigint` for each. The decision actually worth making is
`bigint` against `uuid`, and that turns on whether ids are generated by clients or leak ordering, not on
range.

**Smell:** `id: :bigint` written as though it changed something, or a table still on `id: :integer`
carried over from a Rails 4 schema.

## Configuration

### 16. Set both timeouts

```yaml
production:
  variables:
    statement_timeout: 30000  # milliseconds
    lock_timeout: 5000        # milliseconds
```

`statement_timeout` bounds a query's run time; `lock_timeout` bounds how long it waits for a lock, which
is the one that keeps a migration from queueing behind a long read.

**Smell:** a `production:` block with no `variables:` key.

### 17. Size the pool to one process's threads

```yaml
production:
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

Each forked worker holds its own `ConnectionPool`, so the pool is per process and the number to match is
the thread count of one process. Rails' generator writes exactly this, and `config/puma.rb` derives its
thread count from the same variable.

`processes × threads × servers` is a different number: the total connections the cluster can open, which
is what to compare against the server's `max_connections` setting. Multiplying the pool by the worker
count over-provisions by that factor.

`max_connections` is the current key name; `pool` is a deprecated alias, and setting both to different
values raises "Ambiguous configuration".

**Smell:** a pool sized from a worker count, or a `pool:` key on a Rails 8.1 app.

### 18. Enable pg_stat_statements

```sql
-- postgresql.conf, then restart
shared_preload_libraries = 'pg_stat_statements'
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

It is a PostgreSQL extension, so it needs no gem.

**Smell:** no query statistics available when asked which statements are slow.

## Transactions

### 19. Keep transactions short, and do slow work outside them

```ruby
User.find_each { |user| user.update!(processed: true) }
```

```ruby
User.update_all(processed: true)
```

Both forms keep each transaction to one statement: `find_each` wraps one `update!` at a time, and
`update_all` is a single `UPDATE`. Neither holds a transaction open across the whole scan.

An open transaction holds its locks and keeps `VACUUM` from reclaiming rows that changed after it began,
so a long one costs bloat as well as blocking.

**Smell:** an HTTP call, a file read, a `sleep`, or an unbounded loop inside `transaction do`.

### 20. Ask for a savepoint when you want an inner rollback

```ruby
ActiveRecord::Base.transaction do
  user.save!

  ActiveRecord::Base.transaction(requires_new: true) do
    post.save!
  end
end
```

PostgreSQL has no true nested transactions. Without `requires_new: true` the inner block joins the outer
one, so an inner failure rolls back everything; with it, Rails issues a `SAVEPOINT` the inner block can
roll back to on its own.

**Smell:** a nested `transaction do` whose purpose is to isolate a failure, without `requires_new:`.

## Writing Queries

### 21. Pass values as bind parameters

```ruby
User.where(email: params[:email])
```

```ruby
User.where("email = ?", params[:email])
```

**Smell:** `#{}` anywhere inside a string handed to `where`, `order`, `group` or `find_by_sql`.

### 22. Compare exact values with equality

```ruby
User.where(email: email)
```

**Smell:** `LIKE ?` with a pattern holding no `%` or `_`.

### 23. Normalize at write time, then compare directly

```ruby
class User < ApplicationRecord
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
```

```ruby
add_index :users, :email_address, unique: true
User.find_by(email_address: params[:email_address])
```

This is what the Rails 8.1 authentication generator writes, and it is the strongest of the three
options: the column holds one canonical form, so a plain B-tree index serves both the lookup and the
uniqueness constraint. `normalizes` applies to writes and to finder arguments.

When you cannot normalize the stored value — an existing column with mixed case in it — the options are
an expression index, which the query must match exactly:

```ruby
add_index :users, "lower(email)", name: "index_users_on_lower_email"
User.where("lower(email) = ?", params[:email].downcase)
```

or the `citext` type, which compares case-insensitively without either side spelling out `lower()`.

**Smell:** `lower(...)` in a query with no matching expression index; or a `downcase` at the call site of
a column that `normalizes` already handles, which is a sign the two layers disagree about whose job it
is.

## Maintenance

### 24. Check which indexes are actually read

```sql
SELECT schemaname, relname, indexrelname, idx_scan, last_idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY relname, indexrelname;
```

`pg_stat_user_indexes` names its columns `relname` and `indexrelname`. It has no `tablename` or
`indexname` column — asking for those fails with `ERROR: column "tablename" does not exist`.
`last_idx_scan` tells you when a non-zero counter was last touched, which distinguishes an index that is
still in use from one that was read months ago.

Read the counters relative to when they were last reset, and remember that an index backing a UNIQUE
constraint earns its place even at `idx_scan = 0`.

**Smell:** an index nobody can name a query for.

### 25. Update statistics after a bulk change

```ruby
User.insert_all(rows)

ActiveRecord::Base.with_connection { |connection| connection.execute("ANALYZE users") }
```

The planner works from statistics, so a large insert followed by a query can be planned against a row
count from before the insert. `ActiveRecord::Base.connection` is soft-deprecated in 8.1 and warns;
`with_connection` checks a connection out and returns it.

`insert_all` is not a drop-in for `create`: it **does** set `created_at` and `updated_at`, and it
**skips** validations, callbacks and the STI `type` column — all three verified on 8.1.3.1, where a row
violating a presence validation inserted anyway and its `type` came back `nil`. Use it for rows you have
already validated, and set `type` yourself on an STI table.

**Smell:** `insert_all` on a model with validations or callbacks that the caller assumes still run.
