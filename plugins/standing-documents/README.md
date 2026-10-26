# standing-documents

> A guide that gives each kind of project documentation one home, and the skill that applies it
> to your project.

## Highlights

- **Each kind of content gets one home**, so that an agent finds one copy of each fact.
- **The agent does most of the work.** A person on the project approves the list of moves, and
  reads back the result.
- **One command does a first adoption or an upgrade:** `/standing-documents:adopt`.
- **The guide is one Markdown file.** Any agent can use it with no plugin.
- **Each version has a changelog entry**, which says what an adopting project must do.

## Overview

The guide,
[`skills/adopt/references/adopt-standing-documents.md`](skills/adopt/references/adopt-standing-documents.md),
tells an AI coding agent how to reorganize the documentation of a project. After the
reorganization, each kind of content has one home. The agent does most of the work. A person on
the project approves the moves, and reads back the result.

### Why adopt it

An adoption lets the agent read less to learn the same rules. The context window of the agent
has a fixed size. In most projects, one file mixes definitions, the reasons for past decisions,
and the work that is still to do. So one fact sits in several files, and over time the copies
disagree. After the adoption, each kind of content has one home, and a reader finds one copy
there. The guide's section
["The problem, and what the pattern gives you"](skills/adopt/references/adopt-standing-documents.md#the-problem-and-what-the-pattern-gives-you)
states the full case.

### How it works

The guide states the purpose of each home, and the agent decides the edge cases. An adoption
gives the project three things:

- **The homes.** Each home holds one kind of content. For example, `GLOSSARY.md` says what a
  word means, and `docs/adr/` says why a decision went one way. The automated tests are a home
  too. The guide's section
  ["The homes"](skills/adopt/references/adopt-standing-documents.md#the-homes) lists them.
- **The map.** `CLAUDE.md` names each home and what it answers. It also holds priority notes
  for content that seems to fit two homes, and the working rules that every task needs. Each
  project writes its working rules in its own words. The guide's section
  ["The map"](skills/adopt/references/adopt-standing-documents.md#the-map) says what the map
  holds.
- **The checks for drift.** Drift is a gap between the documents and the project, such as a
  citation that points at nothing. The guide names four kinds of drift. Each project chooses how
  and when it checks for each kind, and the checks run before a change merges. The guide's
  section ["Drift"](skills/adopt/references/adopt-standing-documents.md#drift) names the four
  kinds.

### Status: alpha

The guide has numbered versions, and a version below 1.0 is alpha. Expect the guide to change.
One version number is in three places:

- The version line of the guide, under its title.
- The `plugin.json` of this plugin.
- The git tag `standing-documents-v<version>`.

The changelog, [`CHANGELOG.md`](skills/adopt/references/CHANGELOG.md) beside the guide, has an
entry for each version. Each entry says what changed. It also says what a project that adopted
an earlier version must do.

### How to use it

Install the `standing-documents` plugin, and run `/standing-documents:adopt` in the project. The
skill reads the map of the project, `CLAUDE.md`. Where the map does not name the homes yet, the
skill does a first adoption. Where the version line of the map names an earlier version, the
skill upgrades the project from the changelog.

Any agent can also use the guide with no plugin. Give the agent the file, from a clone of this
repository or from its page on GitHub. Tell the agent to adopt the pattern, and to start at the
guide's section ["Adoption"](skills/adopt/references/adopt-standing-documents.md#adoption). To
upgrade, tell the agent to follow the upgrade in that section.

A first adoption has four steps. The agent can do the first three: it writes the map, it moves
the content into its homes, and it chooses the checks for drift. A person on the project
approves the list of moves. In the fourth step, that person reads back the result. For that
read-back, the agent prepares questions that the person answers with yes or no.

Where the project uses the `dev-workflow` plugin, its skills already defer to the pattern. So
the adoption changes nothing in them.

### Why a plugin

The guide ships in a plugin, so that a project gets each new version with `/plugin update`.
`/standing-documents:adopt` then finds the guide and its changelog with no clone of this
repository. It upgrades the project from the version that the map records.
ADR [0021](../../docs/adr/) records the decision.

The plugin takes nothing away from a reader with no plugin. The guide is still one Markdown
file. A person can read it on GitHub before they decide to adopt it, and any agent can read it.
The plugin adds nothing to the context of a session. The `adopt` skill sets
`disable-model-invocation: true`, which keeps it out of the skill index.

### How to report back

Open an issue on this repository. Report a passage of the guide that misled your agent, or a
step that did not fit your project. A report from a project on a stack other than Rails is the
most useful, because no such project has run the guide yet.

## User-invoked

- **[adopt](skills/adopt/SKILL.md)**: Apply the guide to a project for the first time, or upgrade a project to the newest version of the guide.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install standing-documents
```

The skill is out of the skill index, so it adds nothing to the context of a session until you
type it.

Any programming language.

## Usage

Run the skill in the project whose documents you want to reorganize. These are examples:

- `/standing-documents:adopt` in a project whose `CLAUDE.md` does not name the homes → a first
  adoption.
- `/standing-documents:adopt` after `/plugin update` brings a newer guide → an upgrade from the
  version that the map records.

## Feedback and Contributing

Issues are welcome. Before you open a pull request, read
[`CONTRIBUTING.md`](../../CONTRIBUTING.md).
