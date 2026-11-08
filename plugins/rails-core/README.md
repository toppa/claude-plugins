# rails-core

## Overview

This plugin gives Claude expertise in Ruby on Rails. It includes an agent and a number of skills covering architecture, PostgreSQL, caching,
background jobs, authentication, security, RSpec, RuboCop, the Rails 8.1 forms of older
idioms, code review for Ruby and Rails, and accessibility audits.

It does not provide front-end expertise. For controllers (the seam between the back end and
the front end), it knows how to work with Hotwire, Inertia, and the JSON API. See
["Response mode"](skills/rails-architecture/SKILL.md#response-mode) in
the `rails-architecture` skill for details.

The plugin does not cover:

- **Inertia and React.** The `inertia-react` plugin covers them.
- **Turbo and Stimulus code.**
- **Action Cable, Active Storage, and internationalization (I18n).**

## Notes

- 🎯 The plugin targets Rails 8.1 applications on Ruby 3.4 and PostgreSQL 17.
- 👯 Most of the skills in this plugin started in public skill packs, and I edited them for correctness
  and agent readability. [`NOTICE.md`](NOTICE.md) names the sources.
- 🤖 I write and maintain my skills using
  [Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
  so they are optimized for agent understanding.
- ✍️ I write and maintain this README by hand, so it's optimized for human understanding.

## User- and model-invocable skills

- **[authentication-flow](skills/authentication-flow/SKILL.md)**: Sign-in, sign-out, password reset, and API tokens with the Rails 8 authentication generator.
- **[brakeman](skills/brakeman/SKILL.md)**: Run Brakeman or bundler-audit, read a warning, and suppress a false positive.
- **[caching-strategies](skills/caching-strategies/SKILL.md)**: Cache a slow page, a value, or one prop, and find the cause of a stale cache.
- **[extraction-timing](skills/extraction-timing/SKILL.md)**: Decide whether code moves into a service, a query object, a concern, or a form object, or stays where it is.
- **[postgres-patterns](skills/postgres-patterns/SKILL.md)**: Write a migration or SQL, choose an index type, and find out why a query is slow.
- **[rails-8-idioms](skills/rails-8-idioms/SKILL.md)**: The Rails 8.1 form where older code disagrees, for example strong parameters, a redirect status, or rate limiting.
- **[rails-architecture](skills/rails-architecture/SKILL.md)**: Design a feature, choose the layer for a responsibility, and find the response mode of the project.
- **[review-ruby-code](skills/review-ruby-code/SKILL.md)**: Review a Ruby diff or a pull request for design problems, code smells, security sinks, and test coverage.
- **[rspec-let](skills/rspec-let/SKILL.md)**: Decide what goes in `let`, `let!`, `subject`, or `before` when you write or edit an RSpec spec.
- **[rspec-models](skills/rspec-models/SKILL.md)**: Write a model spec, and decide which kind of spec a behavior belongs in.
- **[rubocop](skills/rubocop/SKILL.md)**: Run RuboCop, read an offense, and change `.rubocop.yml` or `.rubocop_todo.yml`.
- **[rubycritic](skills/rubycritic/SKILL.md)**: A measured score for code smells, complexity, and duplication, for example before and after a refactor.
- **[security-audit](skills/security-audit/SKILL.md)**: A security audit of the whole application against the OWASP Top 10, with ranked findings.
- **[solid-queue-setup](skills/solid-queue-setup/SKILL.md)**: Configure Solid Queue, find out why a job does not run or retry, and move from Sidekiq.

## Skills only you can invoke

- **[accessibility-review](skills/accessibility-review/SKILL.md)**: A WCAG 2.2 Level AA audit of a page, with a fix for each finding.
- **[postgresql-rails-analyzer](skills/postgresql-rails-analyzer/SKILL.md)**: An audit of an existing application for N+1 queries, missing indexes, and database configuration.
- **[rails-generators](skills/rails-generators/SKILL.md)**: Write or test a custom Rails generator or an application template.
- **[testprof](skills/testprof/SKILL.md)**: Profile a slow RSpec suite with TestProf.

## The `rails` agent

The `rails-core:rails` agent starts with these skills in its context, and reaches for the
others only when needed:

- `extraction-timing`
- `postgres-patterns`
- `rails-8-idioms`
- `rails-architecture`
- `review-ruby-code`
- `security-audit`

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install rails-core
```

