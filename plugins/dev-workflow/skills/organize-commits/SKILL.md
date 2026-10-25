---
name: organize-commits
description: >-
  How a change is split into commits a teammate can review — the diff as the
  deliverable, semantic changes kept apart from structural ones, dead code
  swept into the commit that killed it, and in-place edits preferred to
  restructuring.
when_to_use: >-
  Use when you start a change that touches several files or will span several
  commits, when you plan a refactor or a cleanup, and when you decide where one
  commit ends and the next begins. Also use it when the user asks how to split
  work for review. For the text of a message, use the
  `dev-workflow:commit-messages` skill.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here on 2026-08-15 so it travels with the
    rest of the planning and commit workflow.
  synced: 2026-08-15
---

# Organizing commits

How to plan and execute a non-trivial change — a refactor, a cleanup, a multi-step edit —
so a teammate can review it efficiently.

## One commit, one logical change

- Keep each commit small, and focused on one logical change. It may span several files.
- The commits tell a story, and each one builds on the one before it.
- A file appears in as many commits as there are distinct reasons it changed.
- The history shows the clean path. Rewrite the trial and error out of it before anyone
  reviews the branch.

## The diff is the deliverable

Where the artifact under review is a diff, optimize for the **review experience**, not for
the final state of the code alone. The two pull in different directions:

- *Final state* favors structural cleanup, names with no date in them, and semantic
  symmetry.
- *Review experience* favors localized changes, clear before-and-after pairing, and
  minimal churn.

Where a structural improvement creates a noisy diff that is hard to follow, split it into
its own commit, whose diff is unambiguously a no-op. The reviewer can verify only what
they can read.

Three tells that you are optimizing for the wrong one:

- You moved code across nesting levels, and the diff aligner now pairs unrelated lines.
- You renamed a context or a method alongside another change, and the reviewer cannot tell
  the two apart.
- Your cleaner version asks the reviewer to mentally undo your moves before they can check
  the logic change.

## Separate semantic changes from structural refactors

A single commit does one of these, not both:

- **Semantic** — changes behavior, drops a dead branch, renames for accuracy, removes an
  obsolete parameter.
- **Structural** — moves code between files or blocks, changes nesting, consolidates a
  pattern.

Bundled, they defeat the diff aligner: it pairs deletions with unrelated additions, and
the reviewer can isolate neither change. Where you find yourself doing both in one edit,
stop and split it.

## Pull dead code into the commit that killed it

Where a change makes other code dead — a `let` that now duplicates a default, a test
covered implicitly elsewhere, a helper with no remaining callers — remove it in the
**same commit**. Three reasons:

- Each commit stays self-consistent: after it, the codebase holds no leftover X.
- The reviewer never has to ask why the leftover is still there.
- No queue of follow-up cleanup commits accumulates to fragment the history.

When you make a change, look at the adjacent code and ask what the change made redundant.
Sweep that into the same commit.

## Walk through bundled changes before making them

Before a multi-step edit, write out the list of distinct things you are about to do, even
if only to yourself. Where the list runs past 5 items, split it into several edits or
commits. **5 is a house heuristic with no external source.**

The failure mode: you make an N-step edit in one shot, the reviewer cannot follow it, and
you end up explaining each piece afterwards. That explanation belongs *before* the edit,
where it would have exposed the bundling in time to fix it.

Where you cannot enumerate the steps clearly, you are not ready to make the edit.

## Default to in-place edits over restructuring

When you change existing code, prefer an edit that preserves the surrounding structure,
even where that structure is mildly suboptimal, over restructuring that produces a noisy
diff. Leave the wrapper whose name is now dated, the slightly redundant nesting level, and
the function that arguably wants splitting. They are not what the change is about.

Where structural cleanup is genuinely worth doing, do it in its own commit after the
semantic change. Two clear commits beat one muddy one.
