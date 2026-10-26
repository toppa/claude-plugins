# My Claude Code Plugins

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This marketplace contains skills, agents, and an output style that I use frequently in my work. I designed them with two goals in mind:

1. They provide smooth workflows, and they are opinionated about those workflows.
2. They are adaptable. If there's an aspect of one that you don't like, customize it for yourself.

I write and maintain my skills using [Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents) so they are optimized for agent understanding.

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

- `rails-core` is written for Rails 8.1 applications on Ruby 3.4 and PostgreSQL 17.
- `inertia-react` is written for Rails 8.1 applications with `inertia_rails` 3 and React 19.
- `dev-workflow`, `standing-documents`, and `ste-writing` work in any programming language.

## Contributing

Issues are welcome. A pull request is welcome after we agree on its issue. A pull request that
adds support for another tracker needs no issue first.
[`CONTRIBUTING.md`](CONTRIBUTING.md) says how to do both.
