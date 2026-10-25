# 0002 — Claude Code puts only `description` and `when_to_use` into context

## Context

Each `SKILL.md` carries a `metadata:` block: the upstream repository, path, and ref, the sync
date, and the versions our facts were checked against. A trimming pass on the five preloaded
`inertia-react` skills flagged that block as sediment, on the assumption that frontmatter is
resident. If it were, every key would cost tokens at every spawn, and the block would have to
go. We settled the question on 2026-08-12, against the Claude Code 2.1.228 binary.

## Decision

Claude Code puts only `description` and `when_to_use` into context, through the skill index.
It never puts the rest of the frontmatter into context. So:

- A `metadata:` block costs nothing at run time, and it stays in every skill.
- A skill's body costs context only when the skill loads: at a preload, or at an invocation.
- A change to `description` or `when_to_use` changes the resident index, so `CLAUDE.md` asks
  that each such change be weighed.

## The alternative that lost

Move the metadata out of each skill, into one file per plugin, to cut the spawn cost. That
saves nothing, because the block was never in the prompt. It also separates a skill from the
upstream ref that its drift check needs.

## Evidence

The skill loader in Claude Code 2.1.228 stores only the body after the closing `---` as
`markdownContent`, and it builds the prompt from that. The skill-index string is built from
`description` and `when_to_use`.

A spawn's cost is therefore the sum of the preloaded bodies, and not of the whole files. On
2026-08-12, the six bodies that the `rails` agent preloads totalled 44,632 bytes, and the five
that the `frontend` agent preloads totalled 64,646 bytes.
