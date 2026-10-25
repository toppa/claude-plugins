# 0009 — A skill checks the `Gemfile` before it prescribes a non-default gem, and never adds one

## Context

`rails-core` installs at user scope, so it loads in every Rails project. That includes shared
codebases, where one developer does not decide to add a gem. Four skills use tools that a
project may not have. Three are not Rails defaults. The fourth, `brakeman`, is in the Rails 8.1
`Gemfile` template, but only 3 of the 27 projects measured below carry it.

## Decision

**Each of those skills checks the `Gemfile` before it prescribes a command.** Each one says
not to add the gem to a project that lacks it. Where a tool is missing, the skill names the
gap once and continues without the tool. `CLAUDE.md` states the house rule.

**`testprof` and `rubycritic` are not preloaded into the `rails` agent.** Both are diagnostics
that an event triggers, and not rules that apply always. Their index entries make them
discoverable. `testprof` is also user-only, and `rubycritic` stays in the index
([0001](README.md)).

## The alternative that lost

Preload `testprof`. It cost 8,920 bytes, 22% of the `rails` agent's startup budget at the
time, to carry advice for a gem that no surveyed project had. Preloaded, it also suggested
`let_it_be` in projects where that raises `NoMethodError`, which reads as an agent that
invents an API.

## Evidence

Counts across 27 Gemfiles in one collection of shared codebases:

| Gem | Projects that have it | Skill | Can it run without the bundle? |
|---|---|---|---|
| `test-prof` | 0 of 27 | `testprof` | No. It hooks the RSpec process at run time. |
| `rubycritic` | 0 of 27 | `rubycritic`, `review-ruby-code` | Yes. It only parses source. |
| `simplecov` | 11 of 27 | `review-ruby-code` | No. It must load in the test process. |
| `brakeman` | 3 of 27 | `security-audit` | No, but Rails generates a binstub when the gem is present. |
