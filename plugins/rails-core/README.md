# rails-core

`rails-core` gives Claude guidance for Ruby and Rails work in a Rails 8.1 application. It covers
the architecture of a feature, the Rails 8.1 forms of older idioms, PostgreSQL, caching,
background jobs, authentication, security, RSpec, RuboCop, and code review. It is for a
developer who uses Claude Code in one or more Rails projects.

The plugin serves three response modes: Hotwire, Inertia, and JSON API. The response mode is
the way that a controller action answers a request. The ordered check that names the mode is in
the `rails-architecture` skill, in its
["Response mode"](skills/rails-architecture/SKILL.md#response-mode) section. Each other skill
points at that section and does not restate the check. ADR [0004](../../docs/adr/) records
this decision.

A skill checks your `Gemfile` before it tells Claude to run a gem that Rails does not ship. A
skill never adds a gem to your project. ADR [0009](../../docs/adr/) records this rule.

Most skills in this plugin started in public skill packs, and I edited them for correctness.
[`NOTICE.md`](NOTICE.md) names the source of each skill.

The plugin does not cover these subjects:

- **Inertia and React.** The `inertia-react` plugin covers them.
- **Turbo and Stimulus code.** No skill is about them. The `rails` agent still writes the ERB
  views of a Hotwire project.
- **Action Cable, Active Storage, and internationalization (I18n).** No skill is about them.

## Model-invoked

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

## User-invoked

- **[accessibility-review](skills/accessibility-review/SKILL.md)**: A WCAG 2.2 Level AA audit of a page, with a fix for each finding.
- **[postgresql-rails-analyzer](skills/postgresql-rails-analyzer/SKILL.md)**: An audit of an existing application for N+1 queries, missing indexes, and database configuration.
- **[rails-generators](skills/rails-generators/SKILL.md)**: Write or test a custom Rails generator or an application template.
- **[testprof](skills/testprof/SKILL.md)**: Profile a slow RSpec suite with TestProf.

## Agents

### The `rails` agent

The `rails-core:rails` agent does Ruby and Rails work in a Rails 8 application, and it starts with
these skills in its context:

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

Written for Rails 8.1 applications on Ruby 3.4 and PostgreSQL 17. The `metadata:` block of each
skill names the exact versions that its facts were checked against.
