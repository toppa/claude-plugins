# toppa/claude-plugins

A personal Claude Code plugin marketplace. It holds curated Rails, Inertia, and React
guidance, drawn from several public skill packs and edited for correctness, plus the
language-agnostic planning and commit workflow that surrounds all of it. It also holds the
standing-documents guide, a documentation pattern for a project, and an output style for the
English that Claude writes.

## Why this exists

Installed skill packs went unused, because conversation drifts past a skill and nothing
forces the match. These plugins fix that by putting every skill in one of three tiers.

1. **Preloaded into an agent.** A skill named in an agent's `skills:` list has its whole
   `SKILL.md` body injected when that agent spawns. Six preload into `rails-core:rails`,
   five into `inertia-react:frontend`.
2. **Model-invocable.** Every skill except the eight in tier 3 keeps its `description` and
   `when_to_use` resident in the skill index, and Claude reaches for it when the work
   matches. This tier carries the most: 31 of the 39 skills sit here, the eleven preloaded
   ones included, because preloading does not hold a skill out of the index.
3. **User-invoked only.** Eight skills set `disable-model-invocation: true`, which holds
   them out of the index and out of reach of every caller except you typing
   `/rails-core:testprof`. Each runs a long analysis or writes files, so the moment to run
   it is yours to pick.

Tier 2 is what finds a skill without anyone remembering its name, which makes a skill's
`description` and `when_to_use` the load-bearing lines in the file.

**`paths:` is not a fourth mechanism, though the published docs read as though it is.** A
`paths:` glob on a *plugin* skill is parsed and then silently discarded; the conditional
loading it promises happens only for skills in a skills directory such as `~/.claude/skills`.
No skill here carries one. ADR [0001](docs/adr/) records how that was settled.

## Plugins

| Plugin | Install scope | What it covers |
|---|---|---|
| `rails-core` | user | Rails and Ruby work in every Rails project |
| `inertia-react` | project | Inertia Rails and React work, for projects that use them |
| `dev-workflow` | user | Issues, plan documents, commits, pull request descriptions, pull request review, and Sentry triage, in any language |
| `standing-documents` | user | The standing-documents guide, and the skill that applies it to a project |
| `ste-writing` | user | An output style for the English that Claude writes, based on ASD-STE100 Simplified Technical English |

`rails-core` serves three response modes — **Hotwire**, **Inertia**, and **JSON API** — and one
ordered check names which one a project uses. The check lives in the
`rails-core:rails-architecture` skill, in its "Response mode" section. Every skill that
branches on the mode points at that section rather than restating the check.

`inertia-react` installs at project scope on purpose. Many Rails projects use Hotwire,
and its skills must not load in those projects.

`dev-workflow` names no language and reads no `Gemfile`. It installs at user scope for the
same reason `rails-core` does: every project gets plans and commits.

`ste-writing` holds no skill. It holds one output style, which sets the shape of each English
sentence that Claude writes. An install does not turn the style on. Select it in `/config`, as
the output style `ste-writing:ASD-STE100`.

## Install

```bash
# Once, per Claude Code installation:
/plugin marketplace add toppa/claude-plugins

# Every Rails project:
/plugin install rails-core        # choose user scope

# Every project:
/plugin install dev-workflow      # choose user scope
/plugin install standing-documents  # choose user scope
/plugin install ste-writing       # choose user scope, then select the style in /config

# From inside an Inertia project only:
/plugin install inertia-react     # choose project scope
```

A project-scoped install is recorded in `installed_plugins.json` with a `projectPath`. It is
local to one machine and does not travel with a clone of the project.

## The standing-documents guide

`plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md` tells an AI
coding agent how to reorganize the documentation of a project, so that each kind of content has
one home. The agent does most of the work. A person on the project approves the moves, and reads
back the result.

### Why adopt it

An adoption lets the agent read less to learn the same rules. The agent's context window has a
fixed size. In most projects, one file mixes definitions, the reasons for past decisions, and the
work still to do. So one fact sits in several files, and over time the copies disagree. After the
adoption, each kind of content has one home, and a reader finds one copy there. The guide's
section "The problem, and what the pattern gives you" states the full case.

### How it works

The guide states the purpose of each home, and the agent judges the edge cases. An adoption
gives the project three things:

- **The homes.** Each home holds one kind of content. For example, `GLOSSARY.md` says what a
  word means, and `docs/adr/` says why a decision went one way. The automated tests are a home
  too. The guide's section "The homes" lists them.
- **The map.** `CLAUDE.md` names each home and what it answers. It also holds priority notes for
  content that seems to fit two homes, and the working rules that every task needs. Each project
  writes its working rules in its own words. The guide's section "The map" says what it holds.
- **The checks for drift.** The guide names four kinds of drift, such as a citation that points
  at nothing. Each project chooses how and when it checks for each kind, and the checks run
  before a change merges. The guide's section "Drift" names the four kinds.

### Status: alpha

The guide has numbered versions, and a version below 1.0 is alpha. Expect the guide to change.
One version number sits in three places: the guide's version line under its title, the
plugin's `plugin.json`, and the git tag `standing-documents-v<version>`. `CHANGELOG.md`, beside
the guide, has an entry for each version. Each entry says what changed, and what a project that
adopted an earlier version does about it.

### How to use it

Install the `standing-documents` plugin, and run `/standing-documents:adopt` in the project. The
skill reads the project's map, `CLAUDE.md`. Where the map does not name the homes yet, the skill
does a first adoption. Where the map's version line names an earlier version, the skill upgrades
the project from the changelog.

Any agent can also use the guide with no plugin. Give it the file, from a clone of this
repository or from its page on GitHub. Tell the agent to adopt the pattern, starting at the
guide's section "Adoption". To upgrade, tell the agent to follow the upgrade in that section.

A first adoption has four steps. The agent can do the first three: it writes the map, moves the
content into its homes, and chooses the checks for drift. A person on the project approves the
list of moves, and reads back the result in the fourth step. For that read-back, the agent
prepares yes-or-no questions.

Where the project uses the `dev-workflow` plugin, its skills already defer to the pattern, so
the adoption changes nothing in them.

### Why a plugin

The guide ships in a plugin, so that a project gets each new version with `/plugin update`.
`/standing-documents:adopt` then finds the guide and its changelog with no clone of this
repository, and it upgrades the project from the version that the map records.
ADR [0021](docs/adr/) records the decision.

The plugin takes nothing away from a reader with no plugin. The guide is still one markdown
file. A person reads it on GitHub before they decide to adopt it, and any agent reads it. The
cost in context is nothing. The `adopt` skill sets `disable-model-invocation: true`, which keeps
it out of the skill index.

### How to report back

Open an issue on this repository. Report a passage of the guide that misled your agent, or a
step that did not fit your project. A project on a stack other than Rails is the most useful
report, because no such project has run the guide.

## Where the content came from

Each plugin carries a `NOTICE.md`. It names the source of each skill, either an upstream
repository or "written here", and it holds the third-party copyright and permission notices.
In `dev-workflow`, only `pr-descriptions` is third-party. The other nine skills were
written here.

Each `SKILL.md` carries a `metadata:` block with its pinned upstream ref and the versions the
file's facts were checked against. It costs nothing at run time: frontmatter is never injected
into a prompt, and only `description` and `when_to_use` are read out of it for the index.

The maintainer's records live in `docs/`, which ships with no plugin:

- `docs/adr/` holds the decisions, each with the alternative that lost.
- `docs/upstream-divergences/` lists what each derived skill cut, changed, or added on
  purpose, and why.
- `docs/upstream-sync.md` holds the clone commands and the drift check. The clones live
  outside this repository, at `~/Projects/claude-plugins-upstreams`.
