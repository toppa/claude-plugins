# dev-workflow

This plugin contains skills I use frequently in my work. I designed them with two goals in mind:

1. They provide smooth workflows, and they are opinionated about those workflows.
2. They are adaptable. If there's an aspect of a skill that you don't like, customize it for yourself.

You can use them in any typical software development workflow, in any programming language. I tailored the frontmatter of the skills for Claude Code, but you can modify it for use with another harness.

The `write-issue`, `implement-issue`, and `triage-sentry` skills know how to connect to Linear. I designed them to support other trackers as well. PRs for supporting other trackers are welcome! [CONTRIBUTING.md](../../CONTRIBUTING.md) says what such a pull request needs.

I write and maintain my skills using [Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents) so they are optimized for agent understanding.

## Model-invoked

- **[write-plan](skills/write-plan/SKILL.md)**: Write or update a plan document.
  - Each plan has a fixed structure: a status, an approval mode, a context section that explains why, and the steps.
  - Pro tip: use [Matt Pocock's grilling skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) first, to determine what will go in the plan.
  - Before it asks for your approval, an agent with no conversation context reviews the plan for gaps and errors.
  - It names each plan file with the date and a verb phrase.
  - It asks where plans go on the first run in a repository, and it writes the answer to `~/.claude/data/dev-workflow/write-plan/plan-directories.yml`.
- **[implement-plan](skills/implement-plan/SKILL.md)**: Implement a plan document one step at a time, or resume a plan that is partly done.
  - An agent does the work of each step, and the skill closes the step with checks, a review, a plan update, and a commit.
  - It reads the `Approvals required:` line of the plan to decide whether it stops for your review after each step.
  - After the final step, it removes implementation detail from the plan (and if there is a linked issue, it closes the issue via `implement-issue`).
- **[write-issue](skills/write-issue/SKILL.md)**: Draft an issue for a tracker (currently supports Linear) with acceptance criteria, and create it after your approval.
  - Its templates cover bugs, tasks, features (as user stories), and projects (as epics), and it proposes a split where the work needs several pull requests.
  - It can revise an existing issue or epic, and it changes only the passages that the revision needs.
  - It creates the issue through a connection to the tracker, and otherwise it gives you Markdown to paste.
  - It asks about your tracker on the first run in a repository, and it saves a configuration to `~/.claude/data/dev-workflow/issue-trackers.yml`.
  - You can pass an optional description of the work, a `label:`, an `assignee:`, and a link.
- **[implement-issue](skills/implement-issue/SKILL.md)**: Start work on an issue from a tracker (currently supports Linear), and close it when all acceptance criteria are met.
  - Before the work starts, it reviews the issue, and it stops only for a real blocker, such as a criterion that you cannot test.
  - It proves each criterion with a passing spec, a command output, or a behavior in the app, and it ticks the criteria after your approval.
  - Where the work needs several commits, or holds a design decision, it hands the work to `write-plan`.
  - It uses a tracker connection where one is present, and otherwise it works from issue text that you paste.
  - Its configuration file is the one that `write-issue` writes, `~/.claude/data/dev-workflow/issue-trackers.yml`.
- **[commit-messages](skills/commit-messages/SKILL.md)**: Write, amend, or rewrite a commit message.
  - It writes [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), with a scope that names the feature.
  - The message body explains **why** the change was made.
  - It runs a command to check each factual claim in the body before the commit.
  - Where the body must explain more than two things, it proposes a split of the commit.
  - Before it runs `git commit`, it shows you the message, and waits for your approval (you can tell Claude not to wait).
- **[organize-commits](skills/organize-commits/SKILL.md)**: Split a change into commits that are optimized for review.
  - It treats the diff as the deliverable, so it plans the commits for reviewability.
  - A change in behavior and a change in structure go in separate commits.
  - It removes code that a change makes dead in the same commit as that change.
  - It lists the steps before a large edit, and it splits the work where the list has more than five steps.
  - `write-plan` and `implement-issue` use it to organize their work.
- **[pr-descriptions](skills/pr-descriptions/SKILL.md)**: Write, rewrite, or tighten the title and the body of a pull request.
  - It cuts the body to a one-sentence summary and optional details, and then it adds back only what the reviewer needs.
  - Where the repository has a pull request template, it follows that template, with one sentence or "None." under each heading.
  - It can tighten a description someone already wrote, and it keeps their meaning and their voice.
  - It applies the result to the pull request, and it opens a new pull request as a draft unless you ask for a ready one.
  - It uses the `gh` CLI, and it derives from [the ruthless-pr-edit skill](https://github.com/jbarrieault/claude-marketplace/tree/main/plugins/ruthless-pr-edit).

## User-invoked

- **[pr-review](skills/pr-review/SKILL.md)**: A triaged review report on one pull request, from its URL.
  - A "steelman" pass tries to prove each finding wrong, to minimize false findings, and it marks each finding as blocking, a question, or verified.
  - It compares its findings with the comments already on the pull request, from people and from bots.
  - You can ask it to draft a comment for each finding that you name, and it never posts to GitHub unless you ask.
  - It needs the `gh` CLI and a local clone, and it creates a temporary worktree where the clone is not at the pull request's head.
  - You pass one pull request URL, and optionally a file path for the report.
- **[pr-review-queue](skills/pr-review-queue/SKILL.md)**: Work through the pull requests that await your review, one at a time.
  - It sorts the pull requests into those that need your review, and those that other reviewers already cover.
  - After it shows the queue, it stops, so that you can set the order, skip rows, or add a covered pull request.
  - It reviews each pull request that you keep with the full `pr-review` method.
  - It keeps no local state, so a new session rebuilds the queue from GitHub.
  - It needs the `gh` CLI and a local clone of each repository.
- **[triage-sentry](skills/triage-sentry/SKILL.md)**: Triage the Sentry review queue, and create issues in a tracker (currently supports Linear).
  - It classifies each issue by a playbook, and it acts only after you confirm each recommendation.
  - Before it files a new task, it looks for an existing tracker task for the same error.
  - It needs a Sentry connection with write access and `yq`, and a tracker connection to create issues (for Linear, also the Linear integration in Sentry).
  - It asks for each missing setting at the start of a run, and it writes the answers to `~/.claude/data/dev-workflow/triage-sentry/config.yml`.
  - You can pass an optional Sentry search query, a project to triage, or a configuration change.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install dev-workflow
```

Any programming language. Where a skill rests on a versioned standard, such as Conventional
Commits, the `metadata:` block of the skill names the exact version.
