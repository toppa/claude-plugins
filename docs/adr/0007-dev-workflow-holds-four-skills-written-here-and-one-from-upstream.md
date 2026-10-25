# 0007 — `dev-workflow` holds four skills written here and one from `jbarrieault/claude-marketplace`

## Context

Four skills lived in `~/.claude/skills` as hand-written, git-tracked files: `commit-messages`,
`implement-plan`, `organize-commits`, and `write-plan`. A fifth, for pull request
descriptions, was available upstream as `ruthless-pr-edit`. These skills call each other:
`implement-plan` calls `commit-messages`, and `write-plan` calls `organize-commits`.

## Decision

**The four skills moved into this plugin on 2026-08-15**, and were deleted from
`~/.claude/skills` in the same change. Two skills with one name, loaded at once, put two
descriptions into the index that compete for the same trigger.

**`pr-descriptions` comes from `jbarrieault/claude-marketplace`**, from `ruthless-pr-edit`
1.0.1. It was copied on 2026-09-23 and edited in the same change. The method stays the
upstream's: five passes of subtraction, then a short add-back.
`docs/upstream-divergences/dev-workflow.md` lists what we changed.

**All five skills are model-invocable.** No agent preloads them, and none sets
`disable-model-invocation`. Each skill must reach the others, and only the user reaches a
user-only skill ([0001](README.md)). `pr-descriptions` calls no other skill, but Claude often
opens a pull request at the end of other work, where nobody types a skill name.

**No `dev-workflow` skill points at a skill outside the plugin.** Such a pointer resolves to
nothing for anyone else who installs the plugin.

## The alternative that lost

Keep the four skills in `~/.claude/skills` and install the plugin beside them. Each skill
would then load twice, from two places, under one name.
