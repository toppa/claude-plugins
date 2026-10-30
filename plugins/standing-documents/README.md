# standing-documents

> A skill that sets up any software project with a comprehensive and self-maintaining
> documentation system. This is currently in an **alpha** development stage.

## Highlights

- **Each type of documentation has a specified home, and there is no duplication**.
  Systematic rules determine where everything goes.
- **For setup in an existing project, the agent does most of the work.** A person on the
  project approves each step of the reorganization.
- **The system self-maintains.** It can use CI to monitor changes and flag gaps or errors.
  

## Overview

[The guide](skills/adopt/references/adopt-standing-documents.md) tells an AI coding agent
how to reorganize the documentation of a project. After the reorganization, each kind of
content has one home. The agent does most of the work. A person on the project approves the
moves. Going forward... TODO

### Why adopt it

When it comes to documentation, its common for software projects to suffer from a variety of
problems. This was true before AI, and without careful guidance AI can make those problems 
worse instead of better, by proliferating existing patterns. The standing documents address
these problems:

- **Terminology:** inconsistent use of terminology is common in software projects, with one
  concept often referred to more than one way, or different concepts muddled together with
  similar terms. This is confusing for people and for AI agents. The standing documents
  clearly define every term in a glossary, including words to avoid for them.
- **Decision records:** ADRs ([Architecture Decision Records](https://adr.github.io/))
  provide humans and AI agents with something the code cannot: the reasons why a specific
  solution or design was adopted. This prevents re-arguing them and can reveal important
  considerations not evident in the code itself. The standing documents provide criteria for
  creating ADRs that people and AI agents can follow. ADRs are meant for "significant"
  decisions, but "significant" is highly subjective, especially to an AI agent. The bar for
  creating an ADR has 2 criteria: would a reasonable person argue the decision again, and
  would its reversal cost real work?
- **Tests as documentation:** the standing documents treat the test suite as a first class
  citizen for documentation. Test descriptions are typically written from a user's
  perspective and implicitly explain why the code being tested matters. The tests also
  explain important edge cases. A good test suite provides most of the documentation a
  project actually needs, so the standing documents do not duplicate information that is
  already in them. AI agents are especially good at absorbing knowledge rapidly from tests.

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
