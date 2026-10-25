# 0003 — A plugin ships its license notices, and its maintainer records live in `docs/`

## Context

Each plugin carried a `PROVENANCE.md`: 2,518 lines in `rails-core`, 1,524 in `inertia-react`,
and 509 in `dev-workflow`. The files began as a record of each skill's upstream source. They
grew into a log of every edit, and most of that log repeated the commit history. Each
`SKILL.md` pointed at its file through an `edits_detail:` key that Claude Code does not read.

## Decision

A plugin ships what a person who installs it needs, and nothing else. The test for each
passage is: does a person who installs the plugin need it?

- **The plugin ships `NOTICE.md`.** The MIT license requires its notice to travel with the
  covered parts, so `NOTICE.md` names each skill and the upstream repository it came from, or
  says that the skill was written here.
- **`docs/` holds the maintainer's records.** `docs/` ships with no plugin.
  - `docs/adr/` holds the decisions.
  - `docs/upstream-divergences/<plugin>.md` holds each derived skill's current divergences
    from upstream. A maintainer revises it in place, and it does not grow as a log.
  - `docs/upstream-sync.md` holds the clone commands, the drift check, and the schedule.
- **A skill's `metadata:` is the only home of the pinned ref for a sync.** `CLAUDE.md`
  defines each key.
- **`PROVENANCE.md` and `edits_detail:` are gone.** Every other `metadata:` key stays.

## The alternative that lost

Keep the full record in each plugin. A 2026-09-07 plan argued for this: the plugin ships to
every install and git history does not, so the record travels with the plugin. That is true,
and no reader in an install uses the record. Claude Code never puts frontmatter or
`PROVENANCE.md` into context ([0002](README.md)). The only reader is a maintainer, and the
maintainer works in this repository.

## Evidence

An audit on 2026-10-01 compared each edit log with `git log`, the skill files, and the plans.
It found 150 facts in the edit logs, and 66 in the design sections, that no other source held.
Of the 150, 77 were decisions, and most gave the reason why our copy differs from upstream.
Without that reason, a re-sync can bring back a passage that we cut on purpose. So each fact
went to an ADR, a divergence file, or `CLAUDE.md`, or was deleted with a reason, before any
`PROVENANCE.md` was deleted.

The private archive of the earlier history holds each deleted file at its path,
`plugins/<plugin>/PROVENANCE.md`, as ADR [0020](README.md) records. Finished plans and commit
bodies that cite it stay as they are.
