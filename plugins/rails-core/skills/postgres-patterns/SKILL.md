---
name: postgres-patterns
description: PostgreSQL patterns for Rails work — choosing an index type (composite, partial, covering, unique, GIN, BRIN) and a column type, adding an index without blocking writes, upserts, keyset pagination, claiming rows without lock contention, and the queries that find unindexed foreign keys, slow statements, and the dead tuples behind table bloat.
when_to_use: >-
  Use when you write SQL or a migration, design a schema, choose an index type,
  or ask why a query is slow, why a table is bloated, or which foreign keys lack
  an index.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/postgres-patterns/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: PostgreSQL 17.10, Rails 8.1.3.1
---

# PostgreSQL Patterns

Verified against PostgreSQL 17 and Rails 8.1. Three items are version-gated: `INCLUDE` needs PG 11,
`mean_exec_time` needs PG 13, and `uuidv7()` needs PG 18.

Express the index patterns below in the migration DSL, as the right-hand column shows. `add_index` covers every index
in this file (`unique`, `length`, `order`, `opclass`, `where`, `type`, `using`, `comment`,
`algorithm`, `include`, `nulls_not_distinct`), the schema dumper round-trips all of them into
`schema.rb`, and the migration stays reversible.

## Index Cheat Sheet

| Query Pattern | Index Type | Migration |
|--------------|------------|-----------|
| `WHERE col = value`, `WHERE col > value` | B-tree (default) | `add_index :orders, :status` |
| `WHERE a = x AND b > y` | Composite, equality column first | `add_index :orders, [ :status, :created_at ]` |
| Uniqueness, and the arbiter an upsert needs | Unique B-tree | `add_index :settings, [ :user_id, :key ], unique: true` |
| `WHERE jsonb_col @> '{...}'` | GIN (`jsonb_ops` covers `@>`) | `add_index :events, :payload, using: :gin` |
| `WHERE tsv @@ query` | GIN | `add_index :articles, :tsv, using: :gin` |
| Only part of the table is queried | Partial | `add_index :users, :email, where: "deleted_at IS NULL"` |
| The whole result comes from the index | Covering | `add_index :users, :email, include: [ :name ]` |
| A very large table, on a column correlated with physical row order | BRIN | `add_index :events, :created_at, using: :brin` |

Two preconditions, because both indexes look installed either way:

- **Covering** indexes serve an index-only scan when the visibility-map bit for the heap page is set.
  On a write-heavy table those bits are often clear, the heap page is visited anyway, and the extra
  payload columns cost write amplification for nothing. The win is on tables where most pages are
  all-visible.
- **BRIN** pays off where the column correlates with physical position — `created_at` on an
  append-only table. After heavy updates, backfills, or an unordered restore that correlation is
  gone. BRIN is also lossy (results need a recheck) and only earns its keep on large tables.

## Adding an index to a live table

Plain `CREATE INDEX` locks out writes on the table until it finishes. Build it concurrently instead,
which needs its own migration because PostgreSQL forbids `CREATE INDEX CONCURRENTLY` inside a
transaction block:

```ruby
class AddIndexToOrdersStatus < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :orders, :status, algorithm: :concurrently
  end
end
```

`disable_ddl_transaction!` applies to the whole migration, so keep one concurrent index per
migration and nothing else in it. A concurrent build that fails leaves an invalid index behind;
drop it and retry.

## Data Type Quick Reference

| Use Case | Type | In a migration |
|----------|------|----------------|
| Primary and foreign keys | `bigint` | the Rails default is already `bigserial primary key` |
| Strings | `text`, or `varchar` with no limit | `t.string` — `character varying` with no limit, and PostgreSQL documents no performance difference between the three. Give a real cap a check constraint rather than `limit: 255` |
| Timestamps | `timestamptz` | opt in once, below |
| Money | `numeric(p, s)` for decimal amounts, `bigint` for integer cents | `t.decimal :amount, precision: 10, scale: 2` |
| Flags | `boolean` | `t.boolean :active, null: false, default: false` |
| Client-generated or multi-region ids | `uuid`, time-ordered | `uuidv7()` on PG 18; PG 17's `gen_random_uuid()` is random v4 |

`t.timestamps` and `t.datetime` emit `timestamp without time zone`, because
`PostgreSQLAdapter.datetime_type` defaults to `:timestamp`. Choose it on day one — it is expensive to
change later — with an initializer:

```ruby
# config/initializers/postgresql_datetime_type.rb
ActiveSupport.on_load(:active_record_postgresqladapter) do
  self.datetime_type = :timestamptz
end
```

Use the load hook: the adapter constant is not loaded while `config/initializers/*` run, so a bare
`ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz` — the form the
adapter's own API docs show — raises `NameError` at boot on Rails 8.1.3.1. With
`schema_format = :ruby`, run `bin/rails db:migrate` right after adding it so `schema.rb` is dumped
against the new type.

## Common Patterns

**Upsert.** `ON CONFLICT` needs a unique index or constraint on the conflict columns to use as its
arbiter — a precondition, not a tuning step. In Rails, the same index that enforces the uniqueness
is the one `unique_by:` resolves to:

```ruby
add_index :settings, [ :user_id, :key ], unique: true

Setting.upsert_all(
  [ { user_id: 123, key: "theme", value: "dark" } ],
  unique_by: [ :user_id, :key ]
)
```

Without that index the call raises `ArgumentError: No unique index found for [:user_id, :key]`, and
raw SQL raises `there is no unique or exclusion constraint matching the ON CONFLICT specification`.
A model-level uniqueness validation does not satisfy either one.

**Keyset pagination.** Constant work per page, where `OFFSET` walks and discards every skipped row:

```ruby
scope = Product.order(:id).limit(20)
page = last_id ? scope.where("id > ?", last_id) : scope
```

The cursor column has to be unique, or pages silently skip and repeat rows. On a non-unique
ordering column, add the primary key as a tie-breaker and compare the pair:

```ruby
Product.where("(created_at, id) > (?, ?)", last_created_at, last_id)
       .order(:created_at, :id)
       .limit(20)
```

**Claiming rows without lock contention.** For background jobs, Solid Queue already does this — it
polls with `FOR UPDATE SKIP LOCKED` — so the `rails-core:solid-queue-setup` skill covers job queues
and no `jobs` table is needed. The pattern below is for the work queues that are not jobs: outbox
rows, import batches, rows a worker leases and marks done.

```sql
UPDATE outbox_messages SET status = 'processing'
WHERE id = (
  SELECT id FROM outbox_messages WHERE status = 'pending'
  ORDER BY created_at LIMIT 1
  FOR UPDATE SKIP LOCKED
) RETURNING *;
```

PostgreSQL blesses `SKIP LOCKED` for exactly this and states the limit: skipping locked rows gives an
inconsistent view of the data, so it suits queue-like consumption rather than general-purpose reads.

## Diagnostic queries

Three catalogue queries live in [references/diagnostic-queries.md](references/diagnostic-queries.md)
(~55 lines): foreign keys with no usable index, slow statements from `pg_stat_statements`, and the
dead-tuple ratio behind table bloat. Three rules make their results trustworthy:

- **An index serves a foreign key only when the constraint's first column is the index's *leading*
  column.** A trailing position in a composite index, and an `INCLUDE` payload, both appear in `indkey`
  and serve neither joins nor cascades. Requiring `indisvalid` also skips the leftover of a failed
  concurrent build.
- **`mean_exec_time` is milliseconds**, and reading it at all needs the `pg_stat_statements` extension.
- **Read `greatest(last_vacuum, last_autovacuum)`.** A Rails app relies on autovacuum, so `last_vacuum`
  alone is NULL for nearly every table and reads as "never vacuumed". `n_dead_tup` is an estimate, so
  the ratio to live rows tells you more than the raw count.

## Related skills

- `rails-core:postgresql-rails-analyzer` sweeps the whole codebase with three scripts: missing
  indexes, N+1 callers, and the database configuration. It scripts the unindexed-foreign-key
  query; the slow-statement and dead-tuple queries have no scripted counterpart, and its bloat material is
  prose, in the "Vacuum and Statistics" section of its performance guide. It is user-invoked only,
  so name it for the user to run and carry on with what this skill covers.
