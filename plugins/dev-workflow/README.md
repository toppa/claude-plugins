# dev-workflow

`dev-workflow` gives Claude a workflow for the work around the code. It covers issues in a
tracker, plan documents, the split of a change into commits, and commit messages. It also
covers pull request descriptions, pull request reviews, and the triage of a Sentry review
queue. It is for a developer who uses Claude Code in any project, in any programming language.

The plugin names no programming language, and it reads no `Gemfile`.

The plugin does not cover these subjects:

- **Direct access to a tracker other than Linear.** The issue skills hold a tracker file for
  Linear only. With another tracker, `write-issue` ends with the draft as Markdown for you to
  paste.
- **The code itself.** The language plugins, such as `rails-core`, cover it.

## Model-invoked

- **[commit-messages](skills/commit-messages/SKILL.md)**: Write, amend, or rewrite a commit message.
- **[implement-issue](skills/implement-issue/SKILL.md)**: Start work on an issue from a tracker, and close it with each acceptance criterion proven.
- **[implement-plan](skills/implement-plan/SKILL.md)**: Implement a plan document one step at a time, or pick up a plan that is part done.
- **[organize-commits](skills/organize-commits/SKILL.md)**: Split a change into commits that a teammate can review.
- **[pr-descriptions](skills/pr-descriptions/SKILL.md)**: Write, rewrite, or tighten the title and the body of a pull request.
- **[write-issue](skills/write-issue/SKILL.md)**: Draft a story, a bug, a task, or an epic for a tracker, and create it after your approval.
- **[write-plan](skills/write-plan/SKILL.md)**: Write or update a plan document, or work in plan mode.

## User-invoked

- **[pr-review](skills/pr-review/SKILL.md)**: A triaged review report on one pull request, from its URL. It uses the `gh` CLI.
- **[pr-review-queue](skills/pr-review-queue/SKILL.md)**: Work through the pull requests that await your review, one at a time. It uses the `gh` CLI.
- **[triage-sentry](skills/triage-sentry/SKILL.md)**: Triage the Sentry review queue, or change the projects that the triage covers. It needs a Sentry connection in the session.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install dev-workflow
```

Any programming language. Where a skill rests on a versioned standard, such as Conventional
Commits, the `metadata:` block of the skill names the exact version.
