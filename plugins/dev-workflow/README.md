# dev-workflow

## Overview

This plugin contains skills I use almost every day in my software engineering work. I
designed them with two goals in mind:

1. They provide smooth workflows, which also means they are opinionated about those workflows.
2. They are adaptable. If there's an aspect of one that you wish were different, customize
   it for yourself (and if it's a change you think others might appreciate, please
  [contribute](../../CONTRIBUTING.md)).

You can use them in any typical software development workflow, in any programming language.

## Notes

- 🙋 The `write-issue`, `implement-issue`, and `triage-sentry` skills know how to connect to
  Linear. I designed them with future support for other trackers in mind as well. Please
  [open an issue](https://github.com/toppa/claude-plugins/issues) if you'd like to contribute
  support for one, and we can discuss a PR.
- 💁 The frontmatter of each skill is tailored for Claude Code, but you can modify it for use with
  another harness.
- 🤖 I write and maintain my skills using
  [Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
  so they are optimized for agent understanding.
- ✍️ I write and maintain this README by hand, so it's optimized for human understanding.

## User- and model-invocable skills

### [write-plan](skills/write-plan/SKILL.md)

#### Write or update a plan document for implementation

- Each plan has the following structure: a status, an approval mode, a context section that
  explains the motivation, and the implementation steps.
- Pro tip: use
  [Matt Pocock's grilling skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md)
  first, to shape what goes in the plan.
- Before the skill asks for your approval, an agent with no conversation context reviews
  the plan for gaps and errors.
- It names each plan file with the date and a verb phrase (not Claude's default random
  filename).
- When invoked for the first time in a project, it asks where plans for the project are
  stored, and records the location (so you can decide whether to put them under version
  control).
- It asks you to pick the approval mode when you approve the plan: `each step`, `before push`, or
  `draft PR` (see `implement-plan` below). With `draft PR`, the implementation starts as
  soon as you approve.
- When `implement-issue` writes the plan in its `draft PR` mode, it does not ask for your
  approval. It stops only for the first-run question above, and for a review finding that
  only you can settle.

### [implement-plan](skills/implement-plan/SKILL.md)

#### Implement a plan document in one shot, or with per-step review and feedback

- An agent does the work of each step, and the skill closes the step with checks, a review,
  a plan progress update, and a commit.
- It reads the `Approval mode:` line of the plan to decide whether it stops for your
  review after each step.
- After the final step, it removes implementation detail from the plan (and if there is a
  linked issue, it proves and checks off the issue's acceptance criteria via
  `implement-issue`).
- It ends the work at a draft PR whose CI checks pass. When the plan has a linked issue, the
  PR description names the issue with a closing line such as "Fixes ENG-123", so the issue
  closes when the PR merges. When the plan has no issue, it asks you whether to open a draft
  PR.
- With `Approval mode: draft PR`, it runs the whole plan to a draft PR whose CI checks
  pass, so that you review the work once, at the end. It does the work in a new git worktree.
- In the `draft PR` mode, it stops only where you must act: a question that it cannot settle
  alone, a problem that remains after two rounds of fixes, and a permission block (it gives
  you the command to run with `!`). It can also ask, once per project, whether you commit
  your plans. How often permission prompts stop the run depends on the permission mode of
  your session.
- Before the run ends, an agent with no conversation context reviews the PR with the
  `pr-review` skill. The run fixes each defect that the review finds.
- The run ends with one report: the PR link, the state of each check, and each decision that
  the run made in place of a stop. The report asks one question, which approves its
  recommended answer to each question that only you can settle. It saves a copy
  in the project's git-ignored `tmp/` directory (or in `~/tmp/`), so that you can review it
  in a later session.

### [write-issue](skills/write-issue/SKILL.md)

#### Draft and save an issue to a tracker, with acceptance criteria

- Currently supports Linear (please
  [contribute support for your tracker](../../CONTRIBUTING.md)). If you use an unsupported
  issue tracker, it gives you the issue as Markdown that you can copy and paste.
- Its templates cover bugs, tasks, features (as Agile user stories), and projects (as
  Agile epics).
- You can optionally pass a `label:`, an `assignee:`, etc.
- It asks about your tracker on the first run in a repository, and it saves a configuration
  for it.

### [implement-issue](skills/implement-issue/SKILL.md)

#### Start work on an issue from a tracker, and close it when all acceptance criteria are met

- Currently supports Linear (please
  [contribute support for your tracker](../../CONTRIBUTING.md)). If you use an unsupported
  tracker, you can paste the issue's text.
- Before the work starts, it reviews the issue, and stops only for a real blocker, such as a
  criterion that you cannot test.
- It proves each criterion with a passing spec, a command output, or a behavior in the app,
  and it checks the box for each criterion after your approval.
- If the implementation involves more detail than is appropriate to save in the issue itself
  (e.g. it needs numerous commits, involves code design decisions, etc.), it hands that work to
  `write-plan`.
- It uses the same configuration as `write-issue`.
- To run an issue to a draft PR in `implement-plan`'s `draft PR` mode (see above), add
  `draft-pr` after the issue key: `/dev-workflow:implement-issue ENG-123 draft-pr`. Any
  plan that it writes for the issue uses the same mode.
- In this mode, it also stops for the first-run setup, an open blocker, an issue that is not
  ready (with a revised draft of the issue for your approval), and a review finding on its
  plan that only you can settle. With an unsupported tracker, it still asks you to paste the
  issue.
- Where the criteria are clear but are not checkboxes, it leaves the issue as it is, and it
  writes its reading of the criteria in the PR description.
- It changes the issue only after you review the draft PR. The final report lists each proof,
  and it asks one question. The question approves the ticks, every other pending update, and
  its recommended answer to each review decision, as a batch.

### [commit-messages](skills/commit-messages/SKILL.md)

#### Write commit messages that focus on **why** a change was made

- Its commit messages do not reiterate **how** a change was made, because you can see that in
  the code. Instead they focus on **why**.
- If relevant, it will also explain why alternative approaches were rejected.
- It follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  format, with a scope that names the feature.
- Before the commit, it runs a check on each factual claim in the message.
- If the message explains more than two things, it proposes a split of the commit.
- Before it runs `git commit`, it shows you the message for your approval (or you can tell
  Claude not to wait if you prefer).

### [organize-commits](skills/organize-commits/SKILL.md)

#### Split a change into commits that are optimized for cohesiveness and for review

- For multistep work, the commits tell a story, and each one builds on the one before it.
- It aims to keep each commit small, and focused on one logical change.
- `write-plan` and `implement-issue` use it to organize their work (so you typically don't
  need to call it directly if you're using those skills).
- It treats the diff as the deliverable, so it plans the commits for reviewability.
- A change in behavior and a change in structure go in separate commits.

### [pr-descriptions](skills/pr-descriptions/SKILL.md)

#### Write, rewrite, or tighten the title and the body of a pull request

- It cuts the body to a one-sentence summary and optional details, and then it adds back only
  what the reviewer needs.
- Where the repository has a pull request template, it follows that template, with one
  sentence or "None" under each heading.
- It can tighten a description someone already wrote, and it keeps their meaning and their
  voice.
- It opens a new pull request as a draft unless you specifically ask for a ready one.
- It uses the `gh` CLI, and it's based on
  [the ruthless-pr-edit skill](https://github.com/jbarrieault/claude-marketplace/tree/main/plugins/ruthless-pr-edit).

## Skills only you can invoke

### [pr-review](skills/pr-review/SKILL.md)

#### Do a thorough PR review with prioritized findings and optional draft comments

- It marks each finding as blocking, a question/nit, or verified. A "steelman" pass tries to
  prove each finding wrong, to minimize false findings.
- It reviews for correctness, project conventions, test coverage, security, performance,
  deploy safety, and dependencies.
- It compares its findings with the comments already on the pull request, from people and
  from bots.
- You can ask it to draft a comment for each finding that you choose, and it never posts to
  GitHub unless you ask. The drafts are brief, and are phrased with deference to the PR
  author (e.g. "What do you think of changing X?" instead of "I want to see X changed.").
  The drafts concisely point in the direction of an alternative implementation if appropriate
  but are not presumptuous (they do not include fully coded solutions).
- You pass one pull request URL. It needs the `gh` CLI and a local clone, and it creates a
  temporary worktree unless you already have the PR's latest commit checked out.

### [pr-review-queue](skills/pr-review-queue/SKILL.md)

#### Work through the pull requests that await your review, one at a time

- It sorts the open pull requests into two tables: those that need your review, and those
  that two or more people already approved.
- After it shows the queue, it stops, so that you can set the order, skip certain PRs, etc.
- It reviews each pull request with the `pr-review` skill.
- Pro tip: usually you should stop after a few reviews, to avoid filling up your session
  context. Then clear context and invoke `pr-review-queue` again if you still have more to do.

### [triage-sentry](skills/triage-sentry/SKILL.md)

#### Triage the Sentry review queue, and create issues in an external tracker when appropriate

- It classifies each issue by a playbook, and it acts only after you confirm each
  recommendation (each issue gets a recommendation such as `Archive forever`, `Resolve`,
  `Quarantine`, etc.).
- It learns and saves the patterns of a project as it encounters issues (error-handling
  conventions, common noise patterns, etc.).
- It needs a Sentry connection with write access and `yq`. For creating associated issues in
  a tracker, it uses the `write-issue` skill and currently supports Linear (please
  [contribute support for your tracker](../../CONTRIBUTING.md)).
- Before it files a new issue in the optional external tracker, it checks that the tracker doesn't
  already have an issue for the same error, to avoid duplication.
- The first time you run it, it initiates a setup process with you and saves a Sentry
  configuration for use in future runs (which projects to triage, etc.).

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install dev-workflow
```
