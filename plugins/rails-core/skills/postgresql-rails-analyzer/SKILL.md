---
name: postgresql-rails-analyzer
description: >-
  Audits an existing Rails codebase for PostgreSQL problems — N+1 queries,
  missing indexes, anti-patterns, and database configuration — and reports a fix
  for each one.
when_to_use: >-
  Use when the user asks to audit an existing database for N+1 queries, missing
  indexes, or configuration problems.
disable-model-invocation: true
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/postgresql-rails-analyzer/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: Rails 8.1.3.1 (activerecord), PostgreSQL 17.10
---

# PostgreSQL Rails Analyzer

Analyze Rails applications for PostgreSQL performance issues and provide actionable optimization recommendations based on "High Performance PostgreSQL for Rails" best practices.

This skill audits code that already exists. For index choice and column type choice while writing new code, the `rails-core:postgres-patterns` skill covers that in its "Index Cheat Sheet" and "Data Type Quick Reference" sections, and is model-invocable.

## Analysis Scripts

Run from the Rails application root directory. All three exit 0 when the analysis ran and 1 when it could
not run — a missing `db/schema.rb`, an unparseable `database.yml`, a directory that is not a Rails root.
Findings arrive on stdout, so a non-zero exit always means the script itself failed, never that it found
something.

### 1. N+1 Query Analysis

```bash
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_n_plus_one.rb"
```

Reads the `belongs_to` / `has_many` / `has_one` names declared in `app/models`, then reports where
`app/controllers` iterates a query without eager loading and touches one of those associations inside the
loop. Grounding it in the application's own declarations is what separates `post.user.name` from
`post.title.upcase`.

It catches three shapes: a query bound to a name and iterated later in the action, a query written inline
and iterated directly, and a `has_many` read straight off a record.

**Scope: Ruby under `app/controllers`.** Association access inside a template is not analyzed. For
coverage that reaches templates, jobs and mailers, use Rails' own runtime detection:

```ruby
config.active_record.strict_loading_by_default = true
config.active_record.action_on_strict_loading_violation = :log
```

### 2. Index Analysis

```bash
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_indexes.rb"
```

Reads `db/schema.rb`, plus the `where` calls in `app/models` and `app/controllers`, and reports:

- Columns declared by `add_foreign_key` with no index leading with them (warning)
- Other `*_id` columns with no index leading with them, which may be external identifiers rather than
  foreign keys (info, confirm before acting)
- Polymorphic columns, listed separately when a `[type, id]` composite already covers them
- Boolean columns with no index, where a partial index may pay off
- Columns used in `where` clauses in `app/models` and `app/controllers`

### 3. Configuration Analysis

```bash
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_config.rb"
```

Reviews `database.yml`, per environment and per named database, for:

- `max_connections` sizing, including the deprecated `pool` alias and the ambiguity of setting both
- `statement_timeout` and `connect_timeout`. The script does not read `lock_timeout`, which
  `references/anti_patterns.md` and `references/performance_guide.md` both prescribe, so check
  that one by hand
- Prepared statements settings
- SSL/TLS configuration in production
- Recommended PostgreSQL extensions

A finding that applies to several databases is reported once, naming each one.

## Workflow

### Step 1: Understand the Request

Sort the request into one of four kinds without asking: a full performance audit, a specific
issue (slow queries, N+1 problems), a configuration review, or schema optimization. A request
that names none of the four is a full audit. Ask the user only where the answer changes which
scripts Step 2 runs.

### Step 2: Run Appropriate Analysis Scripts

A full audit runs all three. A configuration review runs `analyze_config.rb` alone; schema and
index work runs `analyze_indexes.rb`; an N+1 report runs `analyze_n_plus_one.rb`. None of the
three measures query time, so a slow-query question goes to `pg_stat_statements` and
`.explain(:analyze)` rather than to a script.

```bash
# For comprehensive analysis, run all three
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_n_plus_one.rb"
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_indexes.rb"
ruby "${CLAUDE_PLUGIN_ROOT}/skills/postgresql-rails-analyzer/scripts/analyze_config.rb"
```

### Step 3: Review Results

Script output categorizes issues by severity:

- **WARNING**: High-priority issues that likely impact performance
- **INFO**: Optimization opportunities and best practice recommendations

Neither severity is dropped. Step 3 is done when every WARNING and every INFO line has a
destination in Step 4's list.

### Step 4: Provide Recommendations

Create a prioritized list of actionable recommendations, checking the code the scripts flagged
against `references/anti_patterns.md`, whose 25 entries cover the anti-patterns no script detects:

1. **Critical Issues** (fix immediately) — FK indexes, N+1 in hot paths, missing timeouts
2. **Performance Optimizations** (high impact) — partial indexes, counter caches, eager loading
3. **Best Practices** (preventative) — configuration tuning, pool optimization, monitoring

### Step 5: Generate Migration Code

For index and schema recommendations, provide ready-to-use migration code. On a table large enough to
matter, build the index concurrently, which keeps reads and writes running:

```ruby
class AddIndexToPostsUserId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :posts, :user_id, algorithm: :concurrently
  end
end
```

`algorithm: :concurrently` and `disable_ddl_transaction!` go together and neither works alone. Without the
second, the migration runs inside a transaction and PostgreSQL rejects the build with
`ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`. So write both, or write neither
and use a plain `add_index`.

Because the migration is then not atomic, **use one index per migration**: if the second of three
`add_index` calls fails, the first stays applied and the failed one leaves an INVALID index that must be
dropped before retrying. A concurrent build still takes a `SHARE UPDATE EXCLUSIVE` lock, so other DDL on
the table waits; what it avoids is blocking reads and writes.

### Step 6: Reference Additional Documentation

`references/anti_patterns.md` is already required by Step 4. Load
`references/performance_guide.md` when a recommendation needs a form no script emits — an
EXPLAIN reading, a vacuum setting, a pagination or full-text rewrite.

- `references/performance_guide.md` — best practices by area (indexes, queries, configuration, EXPLAIN, vacuum, bulk operations, schema design, monitoring, pagination, full-text search, materialized views)
- `references/anti_patterns.md` — 25 entries in 7 sections (queries, indexes, schema, configuration, transactions, writing queries, maintenance). Each leads with the form to write and then names the smell to search for

## Advanced Analysis

For deeper analysis beyond the scripts, manually review:

- **Schema Design** — data types (`bigint` is already the default primary key; `jsonb` over `json`), constraints (`change_column_null`, CHECK, FOREIGN KEY)
- **Query Patterns** — in `rails c`, `Model.where(...).explain(:analyze)` to get real timings rather than the plan alone; check for sequential scans on large tables
- **Model Code** — counter caches (they need the three-deploy rollout in `anti_patterns.md` entry 2, not a one-liner), batch operation opportunities (`find_each` instead of `each`)

## Limitations

These analysis scripts read source and schema text, so they see shapes rather than behaviour. Two limits worth stating to the user:

- The N+1 analysis covers `app/controllers` only, and cannot see association access inside a template.
- The index analysis reads `db/schema.rb`, so it reports what the schema declares, not which indexes the planner actually chooses or whether one is INVALID.

Confirm fixes against the running database with `.explain(:analyze)`, and prefer `strict_loading` for anything that depends on runtime behaviour.

## Complementary Tools

Rails 8.1 already ships runtime N+1 detection: `strict_loading` on a relation, `strict_loading!(mode: :n_plus_one_only)` on a record, and `config.active_record.strict_loading_by_default` with `action_on_strict_loading_violation` to choose raise or log. Reach for those first, and use Rails query logging for development visibility.

`pg_stat_statements` is a PostgreSQL extension, so it needs no gem. For anything that does — PgHero for a dashboard, Bullet for N+1 — check the `Gemfile` first and suggest it only if it is already there.
