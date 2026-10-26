# toppa/claude-plugins

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This repository is a Claude Code plugin marketplace with five plugins. Two plugins give Claude
guidance for Rails 8.1 applications. One of the two is for a React front end over Inertia. The
other three plugins work in any programming language. They give Claude three things: a workflow
for issues, plans, commits, and pull requests; a guide for project documentation; and an output
style. The marketplace is for a developer who uses Claude Code.

Most of the Rails, Inertia, and React skills started in public skill packs, and we edited them
for correctness. One `dev-workflow` skill also started in a public skill pack. The `NOTICE.md`
files of [`rails-core`](plugins/rails-core/NOTICE.md),
[`inertia-react`](plugins/inertia-react/NOTICE.md), and
[`dev-workflow`](plugins/dev-workflow/NOTICE.md) name the source of each skill. We wrote the
other skills, the guide, and the output style here.

## Plugins

| Plugin | What it gives you |
|---|---|
| [`rails-core`](plugins/rails-core/README.md) | Skills and a `rails` agent for Ruby and Rails work in a Rails 8.1 application |
| [`inertia-react`](plugins/inertia-react/README.md) | Skills and a `frontend` agent for Inertia and React work in a Rails application |
| [`dev-workflow`](plugins/dev-workflow/README.md) | Skills for issues, plan documents, commits, pull request text, pull request review, and Sentry triage, in any programming language |
| [`standing-documents`](plugins/standing-documents/README.md) | The standing-documents guide, and the `adopt` skill that applies the guide to a project |
| [`ste-writing`](plugins/ste-writing/README.md) | An output style for the English that Claude writes, based on ASD-STE100 Simplified Technical English |

## Installation

```bash
/plugin marketplace add toppa/claude-plugins

/plugin install rails-core
/plugin install inertia-react
/plugin install dev-workflow
/plugin install standing-documents
/plugin install ste-writing       # then select the style in /config
```

`rails-core` is written for Rails 8.1 applications on Ruby 3.4 and PostgreSQL 17.
`inertia-react` is written for Rails 8.1 applications with `inertia_rails` 3 and React 19. The
`metadata:` block of each skill in these two plugins names the exact versions that its facts
were checked against. `dev-workflow`, `standing-documents`, and `ste-writing` work in any
programming language.

## Contributing

Issues are welcome. A pull request is welcome after we agree on its issue.
[`CONTRIBUTING.md`](CONTRIBUTING.md) says how to do both.
