# Examples

Read these before drafting. They carry the taste.

---

## 1. The thorough one

Nothing here is false. Almost none of it is needed.

**Before** — *Refactor: Implement comprehensive caching layer for organization lookups*

> ## Summary
>
> This PR implements a comprehensive caching layer for organization lookups in order to
> improve performance. Currently, every request performs a database query to fetch the
> organization, which is inefficient at scale.
>
> ## Changes
>
> - Added a new `RedisCache` wrapper class in `app/lib/redis_cache.rb`
> - Modified `OrgLookup#find` to check the cache before querying Postgres
> - Added a `cache_key` private method that builds a key from org id and `updated_at`
> - Set a TTL of 5 minutes (configurable via `ORG_CACHE_TTL`)
> - Added cache invalidation on the `Organization` model's `after_commit` hook
> - Updated `spec/lib/redis_cache_spec.rb` with 12 new test cases
>
> ## How it works
>
> When a request comes in, `OrgLookup#find` first checks Redis using the generated cache
> key. On a hit, it deserializes and returns. On a miss, it falls through to Postgres and
> writes the result back...
>
> ## Testing
>
> All existing tests pass. Added new unit tests for the cache wrapper. Manually verified
> locally.
>
> ## Future work
>
> We could potentially extend this pattern to other lookups.

**After** — *perf(orgs): cache org lookups in Redis*

> ## Summary
>
> Org lookups hit Redis instead of Postgres, with a five-minute TTL and invalidation when
> the org changes.

The passes cut everything that the diff or the commits hold, and everything that
interested nobody. The TTL and the invalidation stayed. They are the two things the
reviewer would ask about and cannot see at a glance. They fold into the Summary, so they
earn no Details section.

---

## 2. When something earns its way back

Reduction comes first. Then one sentence returns, because the reviewer would be wrong
without it.

**Before** — *Add tenant_id to messages table and backfill*

> ## Summary
>
> This PR adds a `tenant_id` column to the `messages` table so that we can scope messages
> per tenant, which is a prerequisite for the multi-tenancy work described in ENG-4471.
>
> ## Details
>
> The migration adds the column as nullable with no default so that it doesn't lock the
> table. A separate backfill task iterates in batches of 1000 with a sleep between
> batches. Once the backfill completes we'll add the NOT NULL constraint in a follow-up.
> The column is indexed. Note that `messages` is our largest table (~400M rows) so the
> backfill will take roughly six hours to run.
>
> ## Changes
>
> - `db/migrate/20260901_add_tenant_id_to_messages.rb`
> - `lib/tasks/backfill_message_tenant_id.rake`
> - Index added concurrently
>
> ## Testing
>
> Ran the migration and backfill against a staging snapshot.

**After** — *feat(messages): add tenant_id column*

> ## Summary
>
> Each message can now belong to a tenant (ENG-4471).
>
> ## Details
>
> The column ships nullable, and a follow-up PR adds the constraint after the backfill
> finishes. Deploy this PR before you run the backfill, which takes about six hours on
> production's 400M rows.

The batch size, the sleep, the concurrent index, and the file list are all *how*, and the
diff and the commits hold them. Details exists here, and only here, because of the
ordering. A reviewer who misses it approves a change that behaves differently from what
they expect.

---

## 3. When reduction reveals emptiness

Subtraction does not mean a shorter body. Sometimes the passes show a body that never
said anything. Then the fix is a real sentence, not a shorter empty one.

**Before** — *Fix bug*

> Fixes the bug where things weren't working. See ticket.

**After** — *fix(webhooks): stop dropping retries after a 500*

> ## Summary
>
> Webhook deliveries that hit a 500 now go back on the queue, where before they were
> marked complete and lost (ENG-4502).

The new body is barely longer. It now tells the reviewer the effect, and the reason
clause says why the effect matters. It has no Details section, because the reviewer would
get nothing wrong without one.

---

## 4. When a commit needs placing

The Summary covers the effect, but one commit does not fit it.

**Commits**

```
refactor(search): extract the query builder from SearchController
feat(search): filter results by date range
feat(search): filter results by author
```

**Before** — *Search filters*

> ## Summary
>
> This PR adds date range and author filters to search.
>
> ## Changes
>
> - Extracted `SearchQueryBuilder` from `SearchController#index`
> - Added `date_from` and `date_to` params
> - Added `author_id` param
> - Added specs

**After** — *feat(search): filter results by date and author*

> ## Summary
>
> Search results can be filtered by date range and by author.
>
> ## Details
>
> The first commit restructures the search query code without a change in behaviour, so
> both filters can share it.

The `Changes` list restated the commits, so pass 1 cut it. Pass 5 brought one sentence
back. A reviewer who read only the Summary does not expect the refactor commit, and the
sentence places it. The two filter commits need no sentence, because the Summary already
places them.

---

## Titles

| Before | After |
| --- | --- |
| `[WIP] Various fixes and improvements to the sync service` | `fix(sync): retry on transient S3 errors` |
| `ENG-4471` | `feat(messages): add tenant_id column` |
| `refactor(auth): update the way we handle token refresh logic` | `fix(auth): refresh tokens before expiry, not after` |
| `Update dependencies` | `build(deps): upgrade Sidekiq 6 → 7` |
| `This PR adds support for exporting reports as CSV files` | `feat(reports): export reports as CSV` |
