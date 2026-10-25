# 0005 — `rails-core` takes 16 of 33 upstream skills, and rejects 17 on stated tests

## Context

Two upstream packs offered 33 skills between them: `ThibautBaissac/rails_ai_agents` and
`el-feo/ai-context`'s `ruby-rails` plugin. A rejection is a decision. Without a record, the
next person to open those repositories works out all 17 rejections again.

## Decision

`rails-core` took 16 skills. 15 remain: `behavioral-guidelines` was taken and then removed on
2026-08-11. Nothing in it was specific to Ruby, so every Rails project paid to preload general
coding advice. Its `when_to_use`, "Use when you write, review, or refactor code", matched every
coding request. Three more skills were written here:
`rails-8-idioms`, `rspec-let`, and `rspec-models`. Each plugin's `NOTICE.md` names the source
of each skill.

The other 17 were read in full and rejected. Each was judged on three tests:

- **Correctness**: does it state anything false for Rails 8.1?
- **Overlap**: does a skill here already own the ground?
- **Reach**: `rails-core` installs at user scope, so it loads in every Rails project. A skill
  that needs a gem no project holds, or that prescribes a workflow nobody runs, costs resident
  tokens and returns nothing.

Three were rejected on placement: they are not Rails skills.

| Skill | Upstream | Test | Why |
|---|---|---|---|
| `rails` | ai-context | Reach | 17 reference files, up to 5,800 lines each, behind a 3,549-byte table of contents. It is a copy of the public Rails Guides. |
| `rspec` | ai-context | Correctness | Line 337 sets `disable_monkey_patching!`, which removes the bare `should`, and lines 65–71 then write `it { should validate_presence_of(:title) }`. It also uses `:unprocessable_entity`. One rule was lifted. |
| `simplecov` | ai-context | Correctness | Every code example is Minitest, and the skill fires while you write specs. See below. |
| `design-patterns-ruby` | ai-context | Correctness | 13 dangling `Ruby/src/` links in `SKILL.md`, and 24 more in its three reference files. |
| `cucumber-gherkin` | ai-context | Reach | A second acceptance framework. These projects run RSpec with Capybara. |
| `ruby` | ai-context | No-ops | Guard clauses, `%w[]`, safe navigation, `filter_map`, and the `?` and `!` conventions are in pretraining. One rule passed the tests and still did not become a skill. See below. |
| `api-versioning` | rails_ai_agents | Correctness | `respond_to :json` needs the `responders` gem, which left Rails in 4.2. Its base controller raises on a stock Rails 8 application. |
| `action-cable-patterns` | rails_ai_agents | Reach | No real-time feature is planned. Half the file is Turbo and Stimulus. |
| `active-storage-setup` | rails_ai_agents | Reach | Its glob, `app/models/**/*.rb, app/controllers/**/*.rb`, claims far more of an application than a file-upload skill covers. |
| `i18n-patterns` | rails_ai_agents | Reach | The projects are English only. |
| `rails-concern` | rails_ai_agents | Overlap | `extraction-timing` owns the decision between a concern and a service. Its five templates are the only new part, and four have a defect. See below. |
| `performance-optimization` | rails_ai_agents | Overlap | `postgresql-rails-analyzer`, `review-ruby-code`, or `postgres-patterns` covers each topic. Only `memory_profiler` and `rack-mini-profiler` are unique, and both need a gem that no project holds. |
| `mutation-testing` | rails_ai_agents | Reach | It needs the `mutant` gem and `config/mutant.yml`. Revisit it if a project adopts `mutant`. |
| `code-review` | rails_ai_agents | Overlap | 2,810 bytes against the preloaded `review-ruby-code`. Its name also collides with Claude Code's built-in `code-review` skill. |
| `dependabot-review` | rails_ai_agents | Placement | The largest and best-written of the 17. Its subject is GitHub pull-request workflow, not Rails. It became a personal skill. |
| `codex-review` | rails_ai_agents | Placement | It sends work to the OpenAI Codex CLI for a second opinion. It was extracted as a personal skill, then dropped: the maintainer would not use it. |
| `friction-review` | rails_ai_agents | Placement | It routes a design through five reviewers. Not Rails. It became a personal skill. |

### One rule lifted from `rspec`

**`rspec-models` Rule 1, spec-type routing, comes from `rspec`.** Model specs hold business
logic, calculations, and scopes. Request specs hold HTTP, authorization, and JSON responses.
System specs hold user workflows and JavaScript. Nothing else from `rspec` was taken.

`rails-architecture` already holds the full map, in the 12-row layer-to-spec-type table at the
head of `references/testing-strategy.md`. That file loads while you design a feature, and not
while you write a spec. So `rspec-models` states the three-way split at the moment a spec gets
written, and it points at `rails-architecture` for the other layers.

### `simplecov`, and the two lines worth taking

- **Every code example is Minitest:** 16 Minitest idioms and no RSpec ones. Its description
  fires while an RSpec spec is being written, and it then shows the wrong framework, the wrong
  fixtures, and the wrong mocking library.
- **Its main configuration restates the gem's `rails` profile**, which already defines the
  groups and filters.
- **Its thresholds fail the suite on adoption:** `minimum_coverage line: 90, branch: 80` and
  `minimum_coverage_by_file 80`.
- **It names validations as a unit-test target**, which contradicts `rspec-models`.

Two lines were worth taking: `enable_coverage :branch` and `primary_coverage :branch`. They
went into the `spec/spec_helper.rb` of a private Rails 8.1 application as configuration, and
not into a skill.

`refuse_coverage_drop` was not taken. Coverage runs only when `ENV["COVERAGE"]` is set, so a
partial run writes a low baseline into `.last_run.json`. Revisit it if coverage runs on every
CI build.

### A rule that passed the tests and still did not become a skill

The `ruby` skill teaches the Weirich convention: `fail` raises the first exception, and
`raise` only re-raises. Across the maintainer's Rails checkouts, line-leading `fail` leads
`raise` in almost every repository, by 122 files to 19 in the widest case. The `raise` uses
are re-raises.

A skill is the wrong instrument for it. Those repositories carry over a hundred examples
each, and a model matches the code around it. A convention that is already dense in a
codebase needs no skill. A skill earns its cost where the examples are absent, or where the
convention contradicts what the model would otherwise do.

This convention contradicts RuboCop. `Style/SignalException` ships
`EnforcedStyle: only_raise`. A project that keeps the convention needs
`EnforcedStyle: semantic` in `.rubocop.yml`, or autocorrect reverses it.

### The `rails-concern` templates

| Template | Defect |
|---|---|
| `HasUuid` | `validates :uuid, uniqueness: true` costs a `SELECT` per save and still loses a race. The unique index is the guarantee, and Postgres can default the column with `gen_random_uuid()`. |
| `SoftDeletable` | `default_scope { active }` reaches associations and other classes' queries. The escape, `unscoped`, drops every scope. |
| `Searchable` | `ILIKE "%#{query}%"` has a leading wildcard, so no btree index applies. It hardcodes `name` and `email`. |
| `Auditable` | `after_create` writes the audit row inside the transaction, so a rollback discards it. `changes` is an ActiveModel method name. |
| `Filterable` | Correct and thin, but it reads `params` inside a module mixed into `ApplicationController`. |

### A directory the survey did not cover

`rails_ai_agents` also ships `.claude_37signals/skills/`, with 15 more skills. Its README says
that pack replaces `.claude/` and does not add to it, and it targets rich models with
Minitest. These projects use RSpec and a layered design, so the 15 were not reviewed.
