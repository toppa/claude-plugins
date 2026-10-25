# 0004 — One ordered check names a project's response mode: Hotwire, Inertia, or JSON API

## Context

`rails-core`'s `plugin.json` says that the plugin serves every Rails project. On 2026-08-25 it
did not. A survey of the plugin found 146 lines that named Inertia and 33 that named React.
Most were harmless, because a `Gemfile` check, a `render inertia:` condition, or a pointer
into `inertia-react` gated them. Eight lines were not gated, and each reached the `rails`
agent at every spawn in every project:

- Four in the agent's own file: its `description`, its scope line, its stop rule, and its
  mandatory report item.
- Two ungated Presenter clauses in `rails-architecture`.
- One bare audit item in `security-audit`.
- The render-argument rule in `extraction-timing`.

The plugin was also written as though a project renders either ERB or Inertia. A Rails
application that serves a separate React front end over JSON was nearly unserved. Every
mention of `ActionController::API`, jbuilder, or a serializer sat in the user-only
`rails-generators`.

## Decision

**A Rails project uses one of three response modes: Hotwire, Inertia, or JSON API.** Both
plugins use those three names, in those words, in every file. One mode under two names is two
modes to a reader who meets them in different files.

**One ordered check names the mode.** It lives in the `rails-core:rails-architecture` skill,
in its "Response mode" section, and it is stated once. Every other file names that skill and
section. Two statements of one check drift apart.

**The check lives in `rails-architecture` for two reasons.** That skill is preloaded into the
`rails` agent, which owns `app/controllers`, so the agent holds the check with no extra hop.
The skill also owned the thin-controller branch that the check gates.

**The order of the steps carries the logic:**

- **Step 2, the `inertia_rails` gem, runs before step 3**, because an Inertia project can also
  carry `turbo-rails`. In the other order, an Inertia project reads as Hotwire.
- **Step 3 needs `turbo-rails` and an `.html.erb` under `app/views`.** A `Gemfile` grep alone
  is wrong, because `turbo-rails` ships in the default Rails 8 `Gemfile`. A stock application
  that serves JSON then reads as Hotwire.
- **Step 3 ignores `layouts/`, `*_mailer/`, and `pwa/`**, because every mode keeps the ERB in
  those directories: the layout, the mailer layouts, and the PWA manifest. Without an
  exclusion, every project reads as Hotwire.

**Step 4 names its edge and tells the agent to ask.** An application that renders page ERB
and has no `turbo-rails` fails step 3 and lands on step 4, JSON API. The agent would then write
no template. So step 4 says: where `app/views` still holds a page template outside the three
excluded directories, ask the user which mode the project is.

**`inertia-react` does not restate the check.** A project with `inertia-react` installed at
project scope already answered it.

## The alternatives that lost

**Accept step 4's edge as narrow.** The first version of the check did, because `turbo-rails`
is a Rails 8 default. A PR review on 2026-08-28 overturned that ground. Two documented flags
drop the gem, and this house already has projects of that shape (see Evidence).

**Lead step 3 with the ERB clause.** That closes the edge, and it breaks a JSON API project
that serves one landing template to host a React bundle. Such a project would read as
Hotwire. File presence alone cannot separate the two cases. A template count would need a
threshold with no source, and this repository's rules forbid that. So the structural fix is
deferred, and the check asks.

**Two modes, ERB or Inertia.** This leaves the JSON API project with no home.

## Evidence

- `rails new --skip-hotwire` drops `turbo-rails` (`app_base.rb:82-83`), and
  `--skip-javascript` implies `--skip-hotwire` (`app_base.rb:212`). A commit message of
  2026-08-28 says "two documented generator flags" and names neither.
- Two private Inertia applications, a Rails 8.1 application and its predecessor, carry no
  `turbo-rails`, and the predecessor holds four page templates outside `layouts/`. Both resolve
  at step 2 today. Both would land on step 4 without their Inertia gem.
- `rails new` writes an active `jbuilder` line. Only `--api` comments it out:
  `app_base.rb:496-498` passes `options[:api]` as `GemfileEntry.new`'s `commented_out`
  argument (`:431`). Both reference applications carry an active `jbuilder` line. So a JSON
  API project that step 4 catches is the one most likely to hold
  `app/views/posts/index.json.jbuilder`, and "JSON API has no view" is false for it.
- An Inertia project pays at most one extra skill load, and loses nothing. The detail that
  left `rails-core` went to the `inertia-react` skill that owns it.
