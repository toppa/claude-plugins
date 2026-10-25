# Divergences from upstream — rails-core

This file lists where each derived skill in `rails-core` differs from its upstream on purpose,
and why. Read a skill's section before you act on an upstream diff; `docs/upstream-sync.md`
holds the procedure. When an edit adds or removes a divergence, revise the entry in place.
This file is not a log.

## `accessibility-review`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/accessibility-review/SKILL.md`.

- **Kept: `context: fork`, `agent: Explore`, `model: opus`, `effort: high`, and
  `allowed-tools`.** The skill is user-only, so it has one entry path, and on that path each
  key does work [0001](../adr/). An audit returns a report, which is the job `fork` does.
  `Explore` is read-only. `opus` at `effort: high` buys accuracy in criterion mapping, which
  was the error that review found most often. Do not cut these keys to match
  `security-audit`, because that skill lost them only because it is preloaded.
- **Added: `disable-model-invocation: true`.** The user decides on an audit before the work
  starts, so the skill does not need a place in the resident index [0001](../adr/).
- **Cut: the WHEN NOT pointers to `viewcomponent-agent`, `stimulus-agent`, `tailwind-agent`,
  and the `code-review` skill.** This plugin ships none of them.
- **Cut: the anti-pattern lists in `references/aria-patterns.md`.** Each pattern opens with
  the markup to ship, native HTML first. A list of wrong ARIA markup does the most harm here,
  because readers copy markup from this file. Do not restore the lists on a re-sync.
- **Changed: the legal floor for each law.** Upstream called WCAG 2.2 AA the enforceable
  baseline for ADA Title II, Section 508, and the EAA. None of the three adopts 2.2. The skill
  keeps 2.2 AA as the engineering target and states each floor with its rule text.
- **Changed: the review paths.** Upstream's `app/components/` and
  `app/javascript/controllers/` are gated on the `Gemfile`, and a glob that matches nothing is
  a finding about the audit, not a clean result.
- **Changed: the stack.** The Hotwire checks apply only where `turbo-rails` is in the
  `Gemfile`. Inertia analogues sit beside them: `<Head title>`, a route announcer, flash
  announcement, and `eslint-plugin-jsx-a11y`.
- **Cut: the automated-coverage percentages.** They had no primary source.

## `authentication-flow`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/authentication-flow/SKILL.md`.

- **Cut: upstream's code for the generator's output.** About 280 lines did not match what
  `bin/rails generate authentication` writes. It had four defects that a re-sync would bring
  back:
  - It read `cookies.signed[:session_token]` and called `Session.find_by_token`, but the
    generator creates no token column, so the code raised `NoMethodError`.
  - `authenticated?` returned `Current.session.present?` instead of calling `resume_session`,
    so it reported `false` before the session resumed.
  - `request_authentication` dropped `return_to_after_authenticating`, so the user lost the
    redirect after sign-in.
  - It had no `after_authentication_url`.
- **Changed: the skill states the generator's real contract,** read from the railties 8.1
  templates. It points at the generated code rather than restating it, because a restated copy
  drifts with each Rails release.
- **Changed: "Devise" is out of `when_to_use`.** The field reads "between the built-in
  generator and an authentication gem". Devise is in neither railties 8.1 nor a generated
  application. A gem name in the resident field makes it a more available completion in every
  authentication conversation.
- **Added: password reset through `has_secure_password`'s `reset_token:`, session expiry on
  `last_seen_at`, API tokens, and an RSpec sign-in helper.** Upstream named these topics and
  did not cover them.
- **Changed: upstream's opaque session token is kept as a labelled deviation from the
  generated contract,** in `references/sessions.md`. Do not present it as the generator's
  output, because the generated code does not have it.

## `brakeman`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/brakeman/SKILL.md`.

- **Changed: the triggers name the tool only.** Upstream claimed "running security audits"
  and "reviewing code for vulnerabilities". `security-audit` owns the audit procedure and
  OWASP. This skill owns the binary, its warnings, its configuration, and its CI wiring.
- **Changed: upstream's Installation section is a `Gemfile` check, in "Running it on this
  project"** [0009](../adr/). Upstream said
  to run `gem install brakeman` and to add the gem. Rails 8.1 generates both scanners, their
  binstubs, and the CI steps.
- **Cut: the OWASP prose in `references/warning_types.md`.** `security-audit` owns that
  prose. The file is now a table of each `warning_type` string, its check class, its code, and
  its version window.
- **Cut: the XXE material.** Brakeman has no XXE check, and Nokogiri's default is safe. Only
  the grep list for departures from that default stays.
- **Cut: the flags, options, and environment variables that Brakeman 8.0.5 does not have.**
  A table in `references/command_options.md` maps eleven wrong or old names to the real ones.
- **Changed: the bundled `scripts/brakeman_helper.rb`.** Upstream called a
  `--report-routes` flag that does not exist, and it joined arguments into one shell string.
  Do not restore the joined string, because a crafted argument then runs a shell command.
- **Changed: `public_send` is not the fix for `send`.** Brakeman warns on both at High
  confidence. The fix is a dispatch table.

## `caching-strategies`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/caching-strategies/SKILL.md`.

- **Cut: `paths: app/views/**/*.erb, app/controllers/**/*.rb`.** A plugin skill never receives
  the key [0001](../adr/). The decision holds even as a personal skill: controllers are the
  most-edited files, so the glob would load the skill in nearly every session.
- **Cut: the WHEN NOT pointer to `performance-optimization`**, in the body and in the
  description. This plugin does not take that skill.
- **Changed: the N+1 pointer is in "Related skills" and is not a precondition.** The
  `postgresql-rails-analyzer` skill is user-only. A "fix the queries first" rule in the
  resident field blocks on work the model cannot start.
- **Changed: fragment caching comes first, and the prop section is named for no response
  mode** [0004](../adr/). "Caching one piece of a response the action builds" covers an
  Inertia props hash and a JSON API payload together.
- **Cut: three Inertia mechanics, which moved to `inertia-react:inertia-rails-performance`.**
  These are `InertiaRails::RawJson`, the `cache_store` fallback, and the per-prop key-suffix
  advice. Do not restore them here, because two copies then drift apart.
- **Changed: `delete_matched` is a table of support by store, not a recommendation.** Solid
  Cache does not implement it, so the call raises in production.
- **Changed: the Redis store is gated on the `Gemfile`, and Solid Cache leads the store
  table** [0009](../adr/).
- **Changed: the caching specs swap in a `MemoryStore`.** The generated test environment uses
  `:null_store`, so upstream's assertions passed on an empty store and could not fail.

## `extraction-timing`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/extraction-timing/SKILL.md`.

- **Cut: `user-invocable: false`.** The user can invoke the skill directly too.
- **Cut: the WHEN NOT pointers to `service-agent`, `query-agent`, `model-agent`, and
  `rspec-agent`.** This plugin ships none of them.
- **Cut: the closing pointer to `@docs/rails-development-principles.md`.** The path is wrong
  upstream, because the file is under `docs/archive/`. Upstream's install also never copies
  `docs/`. Do not restore the pointer, because it resolves to nothing.
- **Changed: counted triggers became conditions.** "2+ models → concern" is now "will both
  models change for the same reason?" A count of 2 cannot tell shared behaviour from a
  coincidence, and a concern is a cross-file refactor. "5+ implementations → base class" is
  now shared behaviour, not shared shape. Do not restore the counts, because they are a
  rejected rule, not a missing number.
- **Cut: the anti-pattern labels "Service Graveyard", "Kitchen Sink Concern", and "YAGNI
  violation".** The checklist is now "Before You Extract", four checks that describe the
  extraction worth making. A named prohibition makes the behaviour more available.
- **Changed: every number states a source, a unit, and a role.** A tool's default governs its
  own number, and a number with no source is labelled a house heuristic.
- **Changed: the description defines "component" in place.** Component means a Rails
  ViewComponent here. A pointer to `inertia-react` for the definition spends an index slot on
  a plugin that a Hotwire project does not have.
- **Changed: the ViewComponent row is gated on the `Gemfile`,** with a logic-free partial as
  the fallback [0009](../adr/).
- **Changed: the render-argument rule cites all three Rails 8.1 scaffolds** [0004](../adr/).
  The argument to `render` does not count as business logic in any response mode.

## `postgres-patterns`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/postgres-patterns/SKILL.md`.

- **Cut: the footer links to the `clickhouse-io` and `backend-patterns` skills.** Neither
  exists in upstream's own repository, so the footer came from another collection.
- **Cut: both references to a `database-reviewer` agent.** This plugin does not ship one.
- **Cut: the Row Level Security example.** It called `auth.uid()`, which is a Supabase
  function, not PostgreSQL and not Rails. Do not restore it on a re-sync.
- **Cut: the "Configuration Template" block.** Its `ALTER SYSTEM` settings are server
  administration, not Rails work. Its `REVOKE ALL ON SCHEMA public FROM public` is risky to
  paste without context. Do not restore it on a re-sync.
- **Changed: the "When to Activate" section became `when_to_use`.**
- **Added: the `add_index` form beside every index pattern.** Without the Rails half, an agent
  writes `execute "CREATE INDEX …"` and loses reversibility and `algorithm: :concurrently`.
- **Cut: the `Avoid` column and the "Anti-Pattern Detection" heading.** The type table states
  the form to use.
- **Changed: the unindexed-foreign-key query tests the leading index column and
  `indisvalid`.** Upstream's `attnum = ANY(i.indkey)` counts a column at any position in an
  index. It then reports a key as covered by an index that cannot serve it.

## `postgresql-rails-analyzer`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/postgresql-rails-analyzer/SKILL.md`.

- **Changed: every script invocation uses `${CLAUDE_PLUGIN_ROOT}`.** Upstream's relative
  `ruby scripts/...` paths resolve against the Rails root, where the scripts do not exist.
- **Changed: `ActiveRecord::Migration[7.0]` to `[8.1]`.**
- **Added: `disable-model-invocation: true`.** A database audit is an intent the user forms
  before the work starts [0001](../adr/).
- **Changed: the description states one trigger once.** Upstream wrote the same branch as
  five synonyms.
- **Cut: the N+1 heuristic for ERB views.** The script reads Ruby under `app/controllers`
  only. A template N+1 routes to `strict_loading_by_default`.
- **Changed: `counter_cache: true` on a table that holds rows is a three-step rollout.** In
  one step the column starts at zero, so `size` and `any?` read wrong values.
- **Changed: `algorithm: :concurrently` and `disable_ddl_transaction!` are stated as one
  unit.** Do not verify the pairing by a direct call to `migration.migrate(:up)`, because that
  call skips the migrator's transaction. The unpaired form then appears to work, and an editor
  could remove `disable_ddl_transaction!` on that wrong result.
- **Changed: `analyze_indexes.rb` reads `schema.rb` line by line.** Only a line that holds
  only `end` closes a table. Upstream's regex closed a table at the letters "end" anywhere,
  so a column such as `trial_ends_at` hid every column after it, and a real unindexed key
  went unreported. The script also reads `t.index` inside `create_table`, which Rails dumps
  since 5.0. Upstream read only `add_index`, so it warned about columns that had an index.
  It reports a polymorphic `_id` column as covered where a `[type, id]` index exists.
- **Changed: `analyze_config.rb` parses YAML aliases.** Upstream aborted on every stock
  `database.yml`, because that file uses `<<: *default`.
- **Changed: the N+1 script reads the associations that the models declare.** Upstream's
  warning tier could never fire.

## `rails-architecture`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/rails-architecture/SKILL.md`.

- **Cut: `model: sonnet` and `effort: high`.** Both are inert when the skill is preloaded into
  an agent, so the skill would act differently by the route that fired it
  [0001](../adr/). Do not restore them on a re-sync.
- **Cut: every `@agent` reference.** Upstream pointed at 11 specialist agents that this plugin
  does not ship.
- **Cut: the `/` prefix on the pointers to `solid-queue-setup`, `authentication-flow`, and
  `caching-strategies`.** The prefix reads as a slash command, and none of the four pointers
  resolved to one. A pointer names the skill.
- **Cut: the "When TO Abstract" table.** It contradicted `extraction-timing` on four rules.
  "When NOT to Abstract" became "When to keep it simple", and it points at `extraction-timing`
  for every number.
- **Cut: the pointers to the `rails-concern` and `action-cable-patterns` skills.** This plugin
  does not take them.
- **Added: the "Response mode" section and its ordered check** [0004](../adr/). The thin
  controller has a branch for each of Hotwire, Inertia, and JSON API.
- **Added: "What Needs a Gem", a gate for each non-default gem** [0009](../adr/). Upstream
  presented Pundit as the authorization layer with no `Gemfile` check. The fallback is a PORO
  policy that the controller calls explicitly.
- **Changed: the model-spec example in `references/testing-strategy.md`.** Upstream tested
  `validate_presence_of` and `belong_to` with `shoulda-matchers`, which `rspec-models` says to
  skip. The example shows a scope and an instance method.
- **Cut: the per-layer coverage percentages.** The skill states no threshold of its own.
- **Added: the `type: :component` and `ViewComponent::TestHelpers` statement** in
  `references/testing-strategy.md`. It comes from the gem's documented install, not from its
  source, because `view_component` was not installed. It is the one unverified claim in the
  skill, so re-check it first in a project that has the gem.

## `rails-generators`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/rails-generators/SKILL.md`.

- **Added: `disable-model-invocation: true`.** A user decides to write a generator before the
  work starts [0001](../adr/).
- **Changed: the generator namespace.** Upstream wrapped the class in `module Generators`,
  which gives the Thor namespace `generators:service`. Then `rails generate service` fails.
- **Changed: the multi-tenant template.** Upstream's template had two cross-tenant leaks and
  a migration that aborted. The template sets `require_tenant = true`, and it reaches exempt
  models through the tenant.
- **Cut: four blocks with no correct version.** These are `--paranoid` soft deletes through
  `default_scope`, `--scopes=name:condition`, `include AASM` on a service object, and a
  `Dir.chdir` dummy-app spec. Each reference file keeps the reason at the place of the cut.
  Do not restore the blocks on a re-sync.
- **Changed: the API generator emits `require_authentication` behind `--authenticate`.**
  Upstream emitted Devise's `authenticate_user!`, so every generated controller raised on its
  first request. Each serializer outside Rails is gated on the `Gemfile`.
- **Changed: the API generator's default serializer is `none`, not
  `active_model_serializers`.** The controller template renders JSON directly. Upstream's
  default writes a class from a gem that the app may not have.
- **Changed: `source_paths` is `super + [__dir__]`.** The bare `[__dir__]` replaces the
  generator's own source paths, so a later installer in `rails new` cannot find its templates.
- **Changed: an RSpec generator spec includes `ActiveSupport::Testing::Assertions`.** The
  block form of `assert_file` calls `assert_nothing_raised`, which RSpec does not define.
- **Changed: `:unprocessable_entity` to `:unprocessable_content`.**

## `review-ruby-code`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/review-ruby-code/SKILL.md`.

- **Kept: the Sandi Metz review inside this skill.** Upstream `ruby-rails` 0.4.0 deleted the
  separate `sandi-metz-reviewer` skill and folded part of it into this one. Do not add
  `sandi-metz-reviewer` back on a re-sync, because this skill owns its subject.
- **Cut: the `REVIEW.md` output template and the link-validation checklist.** Both are
  scaffolding for a slash command. This skill is preloaded into an agent that reports in
  conversation. The one-line VS Code link format stays.
- **Cut: `scripts/code_reviewer.rb` and the line that ran it.** It reimplemented Reek with
  hand-written Ripper parsing and no tests. Reek runs through `rubycritic`.
- **Changed: step 2 checks the `Gemfile` for `rubycritic` and `simplecov`** [0009](../adr/).
  Without them the review goes on by reading. Every `rubycritic` call carries `bundle exec`.
- **Changed: Sandi Metz's rules are four, from Ruby Rogues episode 87, and rule zero is
  added.** Upstream announced five rules and sourced them to her books. The fifth was rule 4
  split in two.
- **Changed: the instance-variable cap of 4 is Reek's `TooManyInstanceVariables` default.**
  Metz published no such cap.
- **Cut: every violation code block in `references/solid-principles.md`.** Each principle
  leads with the correct form, and the signals of a violation are in prose. Upstream's LSP
  example labelled a violation as compliant.
- **Changed: `ActiveRecord::Migration[7.0]` to `[8.1]`, and `:unprocessable_entity` to
  `:unprocessable_content`.**

### `references/security-checklist.md`

- **Cut: every vulnerable-code block.** Each sink class states the safe form and a grep
  pattern.
- **Cut: the CarrierWave upload block.** It used pre-3.0 vocabulary, and the gem is not in
  this stack.
- **Cut: the Pundit section.** It had no `Gemfile` check, and its example omitted
  `include Pundit::Authorization`.
- **Cut: the password-composition regex,** because NIST guidance is contrary to it, **and
  `ActiveRecord::Base.sanitize`,** because the method does not exist at Rails 8.1.
- **Cut: the auth, session, and configuration content.** `security-audit`,
  `authentication-flow`, and `brakeman` own it, and the file points at them.
- **Added: unsafe reflection, path traversal, open redirect, and SSRF.** No security file in
  this plugin covered them before.
- **Kept: the command-injection and uploaded-file-type sections.** They go past the per-diff
  brief on purpose. The old file had a shell sink inside its own countermeasure. The uploads
  section carries Active Storage's 4 KB content-type check. Do not cut them in a trim to the
  brief.
- **Kept: the placeholder host `api.example.com` in the SSRF example.** It does not resolve, so
  as written the allowlist rejects every URL. The prose claims only the rejections. Do not
  report the example as broken.

## `rubocop`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/rubocop/SKILL.md`.

- **Changed: the description and `when_to_use` name triggers.** Upstream's description named
  no trigger, so the skill would almost never fire.
- **Added: what `rubocop-rails-omakase` does.** It is the Rails 8 default and disables every
  `Metrics` cop. Upstream did not mention it, so its `Metrics` recipes configured cops that
  were off.
- **Changed: the thresholds are the installed defaults, as review ceilings.** Upstream's four
  conflicting values are gone, with its fictional "Temporarily increased from 15".
- **Changed: plain `rubocop` is the CI gate.** Upstream's `--fail-level warning` exits 0 on a
  convention offense, which is the severity of nearly every cop.
- **Cut: every Bad/Good pair.** Each Security cop has one safe form that runs.
- **Cut: the passage "Claude automatically uses this skill when users:".** The index string is
  the only route in.
- **Changed: the extensions guide does not tell the reader to add gems.** Three of upstream's
  four arrive through omakase, and the fourth is reported, not added [0009](../adr/).
- **Added: six cop names that do not resolve, on purpose.** Each one is named as absent,
  renamed, or illustrative, for example `Naming/ClassName` and `RSpec/FilePath`. Do not
  "correct" them to real cops, because the text then loses its point.

## `rubycritic`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/rubycritic/SKILL.md`.

- **Cut: `scripts/check_quality.sh`.** It edited the user's `Gemfile` with `sed -i` and ran
  `bundle install` with no prompt. Its BSD `sed` call also fails on macOS, and its exit-code
  branch was dead under `set -e`. The Quick Start is two plain commands.
- **Changed: every `rubycritic` call carries `bundle exec`.** RubyCritic is a `Gemfile` gem,
  so a bare call can resolve to a different version or to nothing.
- **Changed: the skill checks the `Gemfile`, and offers a global install only with the user's
  consent** [0009](../adr/). RubyCritic only parses source, so a global gem works without a
  `Gemfile` change.
- **Cut: the score weighting and the score bands.** Neither exists in rubycritic 5.0.0.
- **Changed: the trigger is an explicit request to measure.** Upstream fired after every new
  class, after every refactor, and before every task completed.
- **Changed: the Reek and Flay examples.** Two of upstream's four Reek examples did not fire
  their own smell, and the Flay example had no duplication. Each block in the file now
  produces exactly the smell it names.
- **Cut: the GitLab CI block.** This stack has no GitLab, and its `before_script:` parsed to
  `!!null`.

## `security-audit`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/security-audit/SKILL.md`.

- **Cut: `context: fork`, `agent: Explore`, `model: opus`, `effort: high`, and
  `argument-hint`.** The skill is preloaded into the `rails` agent. These keys would make it
  act one way when preloaded and another way when invoked [0001](../adr/).
- **Cut: `allowed-tools: Read, Grep, Glob, Bash`.** The list has no Edit or Write. Do not
  restore it on a re-sync, because it then takes those tools from the preloaded agent.
- **Cut: the Pundit guidance.** Upstream ran `bundle exec rspec spec/policies/` and required
  "Pundit authorize on all actions". Pundit is not a Rails default. The skill states the
  principle and leaves the library to the project.
- **Changed: step 1 reads the `Gemfile` for Brakeman and bundler-audit** [0009](../adr/).
- **Cut: every Bad/Good code pair.** Upstream's XXE "Good" line enabled XXE.
- **Changed: each configuration item is a property, not a config line.** A line makes a false
  finding: Rails 8.1 comments `force_ssl` out under Kamal, so a stock application fails a
  `force_ssl` item by design.
- **Changed: the triggers.** Brakeman went to the `brakeman` skill. The clause "when you write
  code that handles user input, sessions, tokens, or file uploads" fired on nearly all Rails
  work. It now fires on an action that loads a record by an ID from `params`. The dead 2017
  labels "XXE" and "unsafe deserialization" are gone.
- **Changed: the serialization item names where each response mode leaks a whole record**
  [0004](../adr/). One resident line on Inertia prop breadth earns its place. The Inertia
  install generator writes `use_script_element_for_initial_page: true`, so the initial page
  is a script element. Every prop is still in the HTML document, readable from view-source. The
  body names no carrier, so it holds for either setting. The canonical rule is in
  `inertia-react:inertia-rails-controllers`.
- **Cut: the OWASP category list.** The list left with the code pairs. Do not add a 2025
  renumbering of it, because the file no longer orders itself by OWASP number. Do not add
  SSRF or `constantize` content, because `security-checklist.md` in `review-ruby-code` owns
  it. A reviewer reads that file with each diff.

## `solid-queue-setup`

Upstream: `ThibautBaissac/rails_ai_agents`, `.claude/skills/solid-queue-setup/SKILL.md`.

- **Cut: `paths:`.** A plugin skill never receives the key [0001](../adr/). Upstream also
  wrote it as one comma-joined string, which matches no file.
- **Changed: the error handling.** Upstream put `rescue_from(StandardError)` below `retry_on`
  and `discard_on`. The last declaration matches first, so retries never ran. The skill
  reports errors through `retry_on … report: true`, `discard_on … report: true`, and
  `after_discard`.
- **Cut: the `have_retry_on` matcher.** It does not exist. RSpec reports
  `expected FixedRetryJob to respond to has_retry_on?`. A job spec asserts the reschedule.
- **Changed: `config/solid_queue.yml` to `config/queue.yml`, and `bundle add solid_queue` to
  a read of what the app generator installed.**
- **Added: `limits_concurrency`, the Puma plugin, `bin/jobs`, a Kamal role in place of the
  Procfile, and Mission Control's default auth.** The file is longer than upstream on purpose.
  It is never preloaded, so its length costs only a session that asks for Solid Queue. Do not
  cut it back in a pruning pass.
- **Changed: the trigger "writes a job" is gone.** It matched every file in `app/jobs/`. The
  triggers name Solid Queue's own subjects and "why a job is not running".

## `testprof`

Upstream: `el-feo/ai-context`, `plugins/ruby-rails/skills/testprof/SKILL.md`.

- **Changed: every command uses `bundle exec rspec`, not `bin/rspec`.** Rails 8.1 generates
  no `bin/rspec`, and rspec-rails does not add one. Do not change the commands to `bin/rspec`,
  because each one then fails in a stock application.
- **Changed: upstream's Quick install section is a `Gemfile` check, in "First: check what the
  project has in its bundle", with RSpec's `--profile` as the fallback** [0009](../adr/). The skill does not add the gem.
- **Added: `disable-model-invocation: true`.** A slow suite is an intent the user forms before
  the work starts [0001](../adr/).
- **Changed: `RUBY_PROF=1` to `TEST_RUBY_PROF=1`.** The old variable does nothing.
- **Changed: the `let_it_be` require goes in `spec/rails_helper.rb`.** In `spec_helper.rb` it
  loads before Active Record, so `reload:` raises `KeyError`.
- **Changed: the `rubocop/rspec/support` section moved from first to fifth** in
  `references/bottlenecks.md`. Only a project that develops its own cops can reach it.
- **Cut: the Evil Martians runtime figures.** The skill names the case study as the source of
  the order only, and tells the reader to measure their own suite.
- **Cut: the claim that TestProf 1.6 ships recommendations for AI or human PR review.** The
  gem ships no such document.
