---
name: write-plan
description: >-
  How a plan document is written — where the file lives, what it is called, what
  it carries, and the approval it needs before implementation starts.
when_to_use: >-
  Use when you write a plan document, when you update one, and in plan mode.
  Also use it when the user asks for a plan, asks for a design to be written
  down, or asks where a plan file belongs. For the workflow that runs while the
  plan is implemented, use the `dev-workflow:implement-plan` skill.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here on 2026-08-15 so it travels with the
    rest of the planning and commit workflow.
  synced: 2026-08-15
---

# Writing a plan

## Standing documents outrank the plan

A plan is temporary. It ends when the work ships. A standing document outlives it.

A project's CLAUDE.md names its standing documents. A glossary, a rules file, and a set
of ADRs are all of that kind, and so are CLAUDE.md and README.md themselves. Where one
exists, the plan defers to it.

- **Read it first.** Write the plan against the terms and the rules those documents
  already hold.
- **State a rule once.** Where the plan needs a rule a standing document holds, give it in
  one line and name the document that holds it. Leave the reason where it is. Two copies
  of one reason drift.

An epic that governs several plans outranks each of them the same way. It lives in the
plan directory or in the team's issue tracker, and it ends when its work ships.

The implement-plan skill's "Step completion workflow" covers the other direction: a step
that settles a term or a rule edits the standing document in that same step.

A document CLAUDE.md does not name is not standing. A brainstorm, a scratch design, or a
spec from an earlier session is input. Fold its decisions into the plan. Leave the
document as it is.

## Where the file lives, and what it is called

The **plan directory** comes from a per-user file,
`~/.claude/data/dev-workflow/write-plan/plan-directories.yml`. Each machine keeps its own
copy. Find this project's entry before any other plan work. Write the plan in that
directory.

- **The key** is the main worktree's absolute path, so all worktrees of one repo share it.
  Outside a git repo, the key is the current directory.
- **The value** has one of two forms:
  - An absolute path, or a path that starts with `~`. The directory is outside the repo,
    and every worktree uses it.
  - A relative path. It resolves against the current worktree's root. Outside a git repo,
    it resolves against the key.

```yaml
/Users/alex/Projects/shop: docs/plans
/Users/alex/Code/billing: /Users/alex/Code/billing-plans
```

### The first question

Where the file has no entry for the key, ask the user for the plan directory. Ask before
any other plan work, because a question that comes later breaks the user's focus on the
plan. Ask with `AskUserQuestion`, and offer two suggestions in this order:

1. `docs/plans`, inside the repo.
2. `<parent of the key>/<repo name>-plans`, outside the repo. `<repo name>` is the last
   part of the key.

`AskUserQuestion` adds "Other" for a typed path. Accept an answer when the directory
exists, or when you can create it. Where an absolute answer is inside the key, store it as a
path relative to the key. An absolute value always names the same directory, so in a linked
worktree it puts the plan in the main worktree's files. Outside plan mode, create the directory at once. Then
write the entry, and create the file if it does not exist. Plan mode allows a write to the
plan file only, so in plan mode both wait until after approval.

### The file name

Name the file with a YYYYMMDD date, a hyphen, and a verb phrase:

- `20251219-add-order-export.md`
- `20251220-show-backorder-status.md`

**The final name is always this dated name.** Plan mode gives the file a random name, such
as `greedy-mixing-jellyfish.md`, which carries neither the date nor the verb phrase. That
name is temporary.

### In plan mode

Plan mode chooses the plan file's path, and no setting changes it. Plan mode allows a write
to that file only, and `ExitPlanMode` reads the plan from it. So write the plan to plan
mode's file, and move the file after approval.

Put a **Move pending** block below the Approvals required line, and below the Issue line where
the plan carries one. The block holds three values:

```
**Move pending:**
- From: ~/.claude/plans/greedy-mixing-jellyfish.md
- Directory: docs/plans
- To: /Users/alex/Projects/shop/docs/plans/20260930-add-plan-review.md
```

- **From** is plan mode's file.
- **Directory** is the plan directory as the per-user file holds it, or as the user gave
  it in the first question. A relative value stays relative.
- **To** is the final absolute path: the resolved plan directory and the dated name. A
  cleared context can start in a subdirectory, where a relative path resolves to the wrong
  place.

The block lives in the plan file, because that file survives a cleared context. An
approval with "clear context" starts a new context, and that context does not load this
skill. The plan file is then the only record of the move.

**The move** runs after approval, in this order:

1. Record the Directory value in the per-user file, where the file has no entry for the
   key.
2. Create the directory, where it does not exist.
3. Move the file from From to To. Do not copy it, because two plan files then drift apart.
4. Delete the Move pending block.

Run the move as soon as the user approves. Where the approval cleared the context, the
implement-plan skill runs the move before its first step.

## File structure

- **Title** — an H1 that says what the plan does.
- **Status** — a line under the Title: `**Status:** not started`. The value is one of
  `not started`, `in progress`, or `done`. A new plan carries `not started`. The
  implement-plan skill writes the other two. An epic carries the same line, and it is
  `done` when every plan under it is `done`.
- **Implement with** — a line under the Status line, in every plan:
  `**Implement with:** the dev-workflow:implement-plan skill.` A later session reads the
  plan without this skill, so the plan itself names the skill that runs it.
- **Approvals required** — a line under the Implement with line, in every plan:
  `**Approvals required:** each step` or `**Approvals required:** none`. Write `each step`.
  Ask for the mode in the approval request. A missing line means `each step`, so an omission
  never removes a stop. The implement-plan skill's "Approval mode" section says
  which stops `none` removes.
- **Issue** — a line under the Approvals required line, only in a plan that comes from an
  issue: `**Issue:** <key>. Close with the dev-workflow:implement-issue skill's "Close the issue"
  section.` An approval with "clear context" starts the implementation from the plan alone, so
  the plan itself names the issue and the close that runs after the final step.
- **Move pending** — a temporary block, in a plan written in plan mode only. "In plan
  mode" defines it.
- **Context** — an opening that states the *why*: the goal, and where you weighed
  alternatives, the reason for this approach. Every plan carries one, because a plan that
  does not say why it exists is a worse plan. Scale it to the decisions rather than to a
  fixed length: one sentence for a small standalone change, and as much as it takes to
  keep the reasoning where the design involved real tradeoffs.
- **Steps** that tell a story, each building on the one before it.
  - Each step is small, and focused on one logical and cohesive change. It may span
    several files.
  - Tests for new or changed behavior belong in the step that changes the behavior, not in
    a later step. Skip them where they do not apply, as for a Rake task, a script, or
    trivial config.
  - A finished step is marked ✅.
  - **Agent** — a line directly under each step's heading, in every plan:
    `**Agent:** <name>`, or `**Agents:** <a>, then <b>` for a step that needs several
    agents in order. The implement-plan skill runs the step in that agent, and does not
    choose again. Take each name from the agent routing in the project's CLAUDE.md. Where
    CLAUDE.md names no routing, or no row of it covers the step's work, write
    `general-purpose`.
  - Name several agents where one job crosses two agents' scopes, and one agent's report
    feeds the next. The last agent proves the outcome of the whole step. Split such a job
    into two steps only where each half passes its checks alone.

To draw the boundary between one step and the next, use the organize-commits skill. Its
"Separate semantic changes from structural refactors" and "Walk through bundled changes
before making them" sections apply to a step as they do to a commit.

## Review the plan

Review the plan after you write it, and before you ask for approval. The review has two
parts, and each part runs where it can see what it checks.

**In this context**, check that every decision from the conversation is in the plan. Only
this context holds the conversation. An approval with "clear context" starts the
implementation from the plan alone.

**In a subagent**, run the other three checks. Give the subagent the plan file's path and
the three checks, and nothing from the conversation. The subagent then reads the plan as
its **implementer** does. Tell it to return a report, and to leave the plan file unchanged.

1. Every fact about the code holds. Each file, class, method, and section that the plan
   names exists, and says what the plan claims.
2. Every rule in the write-plan skill's "File structure" section holds.
3. An open read of the plan as its implementer. The subagent reports whatever would make
   the implementer stop and ask.

Judge each finding against the conversation and the code, because the subagent did not see
the conversation. Give each finding one verdict:

- **Wrong.** The conversation or the code disproves it. Drop it.
- **Defect.** It has one correct fix. Fix it in the plan.
- **Decision.** It belongs to the user. Ask about it in the approval request.

Run one round. A change that the user asks for before approval gets no second review,
because the user's request is itself a review.

## Approval, then stop

Ask the user to review and approve the plan. In the request, list each fix from the review
in one line, and put each decision as a question. List each dropped finding in one line,
with the reason, so the user can overrule the verdict. Ask for the approval mode,
`each step` or `none`. Where the user picks `none`, edit the Approvals required line. Then
stop and wait, even after they approve it. Implementation starts on its own instruction,
under the implement-plan skill.

An approval with "clear context" is the one exception. Claude Code then starts a new
context with "Implement the following plan", and that message is the instruction to
implement.
