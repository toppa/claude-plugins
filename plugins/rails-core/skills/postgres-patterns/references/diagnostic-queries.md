# Diagnostic queries

The rules that make these results trustworthy are in the `rails-core:postgres-patterns` skill's
`SKILL.md`, section "Diagnostic queries". This file
holds the SQL. Verified against PostgreSQL 17; `mean_exec_time` needs PG 13.

The `rails-core:postgresql-rails-analyzer` skill sweeps a whole codebase with three scripts: missing
indexes, N+1 callers, and the database configuration. Only the first overlaps this file — the
slow-statement and dead-tuple queries below have no scripted counterpart there. It is user-invoked
only, so name it for the user to run and carry on with the queries here.

## Foreign keys with no usable index

Matching the constraint's first column against the index's *leading* column is what makes this correct: on
a schema with one bare FK, one trailing-position FK and one `INCLUDE`-payload FK, this returns all three
where an `attnum = ANY(i.indkey)` test returns one.

```sql
SELECT c.conrelid::regclass AS table_name,
       a.attname            AS column_name
FROM   pg_constraint c
JOIN   pg_attribute  a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
WHERE  c.contype = 'f'
  AND  NOT EXISTS (
         SELECT 1 FROM pg_index i
         WHERE i.indrelid = c.conrelid
           AND i.indisvalid
           AND i.indkey[0] = c.conkey[1]
       )
ORDER  BY 1;
```

## Slow statements

Needs the `pg_stat_statements` extension.

```sql
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC;
```

## Dead-tuple accumulation, the vacuum lag behind table bloat

```sql
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       greatest(last_vacuum, last_autovacuum) AS last_vacuumed
FROM   pg_stat_user_tables
WHERE  n_dead_tup > 1000
ORDER  BY dead_pct DESC NULLS LAST
LIMIT  20;
```
