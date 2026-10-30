# My Claude Code Plugins

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This marketplace contains skills, agents, and an output style that I use frequently in my
work. I designed them with two goals in mind:

1. They provide smooth workflows, which also means they are opinionated about those workflows.
2. They are also adaptable. If there's an aspect of one that you don't like, customize it for 
   yourself.

I write and maintain my skills using
[Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
so they are optimized for agent understanding.

## Plugins

| Plugin | What it does                                                                                                                                                           |
|---|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`dev-workflow`](plugins/dev-workflow/README.md) | Skills for plan documents, issues, commits, PR reviews, PR descriptions, and Sentry triage                                                                             |
| [`standing-documents`](plugins/standing-documents/README.md) | A skill that sets up any software project with a comprehensive and self-maintaining documentation system (alpha stage)                                                 |
| [`ste-writing`](plugins/ste-writing/README.md) | An output style that makes Claude easier to understand, based on [ASD-STE100 Simplified Technical English](https://en.wikipedia.org/wiki/Simplified_Technical_English) |
| [`rails-core`](plugins/rails-core/README.md) | Skills and a `rails` agent for Ruby and Rails work in a Rails 8 application                                                                                            |
| [`inertia-react`](plugins/inertia-react/README.md) | Skills and a `frontend` agent for Inertia and React work in a Rails application                                                                                        |

- `dev-workflow`, `standing-documents`, and `ste-writing` work in any programming language.
- `rails-core` targets Rails 8.1 on Ruby 3.4 and PostgreSQL 17.
- `inertia-react` targets Rails 8.1 applications with `inertia_rails` 3 and React 19.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins

/plugin install dev-workflow
/plugin install standing-documents
/plugin install ste-writing       # then select the style in /config
/plugin install rails-core
/plugin install inertia-react
```

## Contributing

Issues are welcome. A pull request is welcome after we agree on its issue.
[`CONTRIBUTING.md`](CONTRIBUTING.md) says how to do both.
