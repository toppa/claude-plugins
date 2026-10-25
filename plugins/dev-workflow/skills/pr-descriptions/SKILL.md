---
name: pr-descriptions
description: >-
  A pull request title and body, written by subtraction: cut until only the
  essential remains, then add back only what the reviewer would be wrong
  without.
when_to_use: >-
  Use when you open a pull request, and when the user asks you to write,
  rewrite, or tighten a pull request title or body.
metadata:
  upstream_repo: jbarrieault/claude-marketplace
  upstream_path: plugins/ruthless-pr-edit/skills/ruthless-pr-edit/SKILL.md
  upstream_ref: 78c2bc2ec9d81972c8a530bcdb346ed53e161f66
  upstream_version: ruthless-pr-edit 1.0.1
  synced: 2026-09-23
  verified_against: Conventional Commits 1.0.0
---

# Pull request descriptions

The method is **subtraction**. Removal is the work. Addition is the exception, and it
comes last. You cannot know what a body needs until you read it without the parts you
assumed were necessary.

## The premise

**The reviewer** is a colleague who knows the codebase but not this branch. The title
and the body do two jobs for the reviewer:

- **Decide.** The reviewer knows what the change does, and whether to take the review.
  The target is thirty seconds of reading, a heuristic from the upstream skill.
- **Place.** The reviewer can place every commit in the log as a step toward the
  Summary.

The commits carry the why of each step. The diff carries where and how. The title and
the body leave those jobs to them.

State the **effect**: what a user, a caller, or an operator sees differently after the
merge. Add the reason in one clause only when the effect does not explain itself. A
refactor is the common case, because its effect is that nothing changes for the user.

A sentence that names a class, a file, a method, a flag, or a variable is almost always
how. Cut it. Keep the identifier when the identifier is the change: a renamed public
API, a new endpoint, a removed config key.

- *How* (cut): "Wraps `OrgLookup#find` in a `RedisCache` with a 5-minute TTL keyed on
  org id and `updated_at`."
- *Effect* (keep): "Org lookups now hit Redis instead of Postgres on every request."

Check the effect in two ways.

- **It names the old state and the new state.** "Runs go red instead of green" names
  both. "Runs now fail" leaves the reader to supply the old state.
- **A condition carries one real case.** Where the effect holds only under a condition,
  as in a "when" or an "if" clause, give one case of it with "such as" or "for
  example". The case ties the condition to an event the reader can picture, and not
  to the rule in the code that detects it. "When the bot skips for a reason the prompt
  does not give" names the rule. "When the bot fails partway, such as when it cannot
  commit its fixes" names the event.

## Before you cut

Read `examples.md` in this skill directory. It carries the taste this skill is for.

Then gather only what you need:

- Existing PR: `gh pr view <n> --json title,body,url,headRefName,baseRefName`
- Base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
- The change: `git log <base>..HEAD --oneline` then `git diff --stat <base>...HEAD`
- Conventions: `.github/pull_request_template.md`, `CLAUDE.md`, and one or two recently
  merged PRs (`gh pr list --state merged --limit 3 --json title,body`)

Describe the change in one sentence before you write anything. This sentence becomes
the Summary. If you cannot write it, read the diff, not more prose.

An honest, overlong first draft can help you find the shape. It is scaffolding, so
expect to delete most of it.

## The passes

Run all five passes, in order.

**1 — Delete whole sections.** Delete anything that restates the diff:

- file-by-file walkthroughs
- "Changes" lists that name functions
- code snippets that the diff already holds
- "Testing" sections that say the tests pass
- unfilled checklists
- "Notes for reviewers" that say "let me know what you think"

**2 — Delete sentences that exist to sound thorough.** Delete these:

- rationale that the linked ticket already holds
- background that the reviewer already has
- explanations of how the code works
- alternatives that nobody asked about
- future work that is not in this PR
- self-assessment of the work's quality

**3 — Delete fluff words.** "simply", "just", "basically", "essentially", "currently",
"leverage", "robust", "comprehensive", "seamlessly", "under the hood". Hedges. Adverbs.

**4 — Challenge the identity.** Cut one more real thing: the piece you are sure has to
stay. Reread the body as the reviewer. If the reviewer still gets it, the cut stays.
Repeat until a cut breaks understanding. Restore that one cut, and stop.

**5 — Add back, reluctantly.** A sentence comes back only when it passes one of two
tests.

- **Decide:** would the reviewer make a wrong call without it? These pass:
  - a risk not visible in the diff
  - deploy, migration, or merge ordering
  - a decision that could have gone another way and is expensive to reverse
  - a blast radius larger than the diff suggests
  - something deliberately left undone that looks like an oversight
- **Place:** would a commit in `git log <base>..HEAD` surprise a reviewer who read only
  the Summary? Then add one sentence that names how the commits relate, not what each
  one does. A PR with one commit needs no place sentence, because its commit message
  places it. Sometimes only "this PR also does X" explains the commit. Then the commit
  may be out of scope. Name it in the report, and leave it out of the body.

Nothing else comes back. Each addition is one sentence, and it goes in Details.

## The title

The title is the whole PR for most people who see it. It carries the effect, in the
reviewer's terms. It stands alone in a merge log a year from now.

- Write it in Conventional Commits format: `type(scope): subject`.
- Take the type from the effect. When the commits have mixed types, the type of the
  effect wins.
- Lead the subject with the change, not the area: `perf(orgs): cache org lookups in
  Redis`, not `chore: Redis changes`.
- The title holds the prefix and the change only. The ticket key goes in the body, and
  the draft status goes on the PR. End the title without a period.
- Keep it under about 70 characters, prefix included, a heuristic from the upstream
  skill. Shorter is better than clever.

## Shape

Two sections, and the second is optional.

```markdown
## Summary

<one sentence: the effect of the change>

## Details

<only if pass 5 added something: the sentences it added>
```

**Summary** is the one sentence from "Before you cut". It is one sentence, not two
joined by a semicolon or an em-dash.

**Details** holds the sentences that pass 5 added, held to the same standard as the
Summary. Both checks on the effect apply: each sentence names the old state and the new
state, and a condition in it carries one real case. Most PRs need one or two. When more
pass, keep each one, because accuracy outranks brevity. If pass 5 added nothing, delete
the heading. An empty or superfluous Details section is worse than no Details section.

The body is these two sections. A section per file, or a `Changes` bullet list, restates
the commit log in a worse form, so neither belongs.

**IMPORTANT:** A repo's own `pull_request_template.md` replaces this shape. Keep its
structure, and starve it:

- one sentence per heading
- no invented content to fill a heading
- every required heading kept
- "None." under a heading with nothing to say

**A PR that implements an issue** ends its body with one line that names the issue key with a
closing word, such as "Fixes ENG-123". Put the line in a repo's template where it has one. The
passes keep this line. A closing word lets a tracker's integration with the code host close
the issue when the PR merges. Linear's GitHub integration works this way
(https://linear.app/docs/github). A PR that delivers only part of the issue names the key with
a word that links only, such as "Part of ENG-123". The criteria stay in the issue only, because
a copy in the body drifts from the issue.

## Rules that outrank brevity

1. **Accuracy.** Keep every true, critical fact, even past a word count. Compression
   must imply nothing false about scope or risk.
2. **You are the reducer, not the author.** When you edit someone else's PR, keep their
   meaning and their voice. Cut their words, and do not replace them with yours.
3. **This skill wins over general PR guidance.** Without a repo template, Summary and
   Details are the shape, even where broader instructions describe a fuller template.
   Mechanics follow project and user convention: labels, reviewers, ticket links, and a
   trailer that the project or the harness requires.

## Apply it

The passes are done when the title and the body are on the PR.

If the PR exists, edit it in place. Leave its draft status as it is: a ready PR stays
ready, and a draft stays a draft. If the PR does not exist, create it as a draft. Create
a ready PR only when the user explicitly asks for one. Silence means draft.

## Report

After you apply the final title and body, tell the user. The report holds two things:

- each cut that a reasonable person would have kept, with the reason, in one line
- each commit that the place test found out of scope

The passes stay out of the report.
