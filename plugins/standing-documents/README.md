# standing-documents

> A skill that sets up any software project with a comprehensive and self-maintaining
> documentation system. This is currently in an **alpha** development stage.

## Highlights

- **Each type of documentation has a specified home, and there is no duplication.**
  Systematic rules determine where everything goes.
- **For setup in an existing project, the agent does most of the work.** A person on the
  project approves the list of moves, and then checks the result.
- **The system self-maintains.** It can use CI to monitor changes and flag gaps or errors.

## Overview

[The guide](skills/adopt/references/adopt-standing-documents.md) tells an AI coding agent
how to reorganize the documentation of a project. After the reorganization, each kind of
content has one home. The agent does most of the work. You review and approve all the moves.

The adoption process also puts guidance in place for maintaining the standing documents over
time. These are the standing documents, which the guide calls *homes*:

| Home | What it holds                                                                                                                       |
|---|-------------------------------------------------------------------------------------------------------------------------------------|
| `README.md` | What this project is, and how to run it on your machine.                                                                            |
| `CLAUDE.md` | Where each other home is, what each one holds, and the development practices that apply to all work on the project.                 |
| `GLOSSARY.md` | What a word means in this project.                                                                                                  |
| The automated tests | The rules that must stay true, where a test can enforce them.                                                                       |
| `UNTESTABLE-RULES.md` | The rules that must stay true in the product, where no test can enforce them.                                                       |
| `UNTESTABLE-CONVENTIONS.md` | How we write the code and the documents, where no test can enforce it.                                                              |
| `OPERATIONS.md` | How we run the deployed system, and how we diagnose it.                                                                             |
| `docs/adr/` | Why a decision went one way, and which open questions no tracked work will settle.                                                  |
| Where the project tracks work | What to build next, and in what order (e.g. an issue tracker like Linear).                                                          |
| Evidence layers (optional), such as `docs/research/` | One-time research and measurements that inform the project (e.g. research for an ADR), but are intentionally not updated over time. |
| Code comments | Warnings about code that is easy to change wrongly, where no test would catch the mistake and no other home fits.                   |

The guide's section ["The homes"](skills/adopt/references/adopt-standing-documents.md#the-homes)
gives an example of each.

### Why adopt it

When it comes to documentation, it's common for software projects to suffer from a variety of
problems. This was true before AI, and without careful guidance AI can make those problems
worse instead of better, by proliferating existing patterns. The standing documents address
these problems:

- **Terminology:** inconsistent use of terminology is common in software projects, with one
  concept often referred to more than one way, or different concepts muddled together with
  similar terms. This is confusing for people and for AI agents. The standing documents
  clearly define every term in a glossary.
- **Decision records:** ADRs ([Architecture Decision Records](https://adr.github.io/))
  provide humans and AI agents with something the code cannot: the reasons why a specific
  solution or design was adopted. This prevents re-arguing the decisions and can reveal important
  considerations not evident in the code itself. The standing documents provide criteria for
  creating ADRs that people and AI agents can follow. ADRs are meant for "significant"
  decisions, but "significant" is highly subjective, especially to an AI agent. The bar for
  creating an ADR has two criteria: would a reasonable person argue the decision again, and
  would its reversal cost real work?
- **Tests as documentation:** the standing documents treat the test suite as a first-class
  citizen for documentation. Test descriptions are typically written from a user's
  perspective and implicitly explain why the code being tested matters. The tests also
  explain important edge cases. A good test suite provides most of the documentation a
  project actually needs, so the standing documents do not duplicate information that is
  already in them. AI agents are especially good at absorbing knowledge rapidly from tests.

An adoption lets the agent read less to learn the same rules. The context window of the agent
has a fixed size. The guide's section
["The problem, and what the pattern gives you"](skills/adopt/references/adopt-standing-documents.md#the-problem-and-what-the-pattern-gives-you)
states the full case.

### How it works

The guide states the purpose of each home, and the agent decides the edge cases. An adoption
gives the project three things:

- **The map.** `CLAUDE.md` names each home and its purpose. It also says how to determine the
  home for content that could plausibly go in more than one place. It also lists the
  development practices that apply to all work on the project, such as "Update a standing
  document in the same change that makes it false". Each project writes these practices in its
  own words. The guide's section
  ["The map"](skills/adopt/references/adopt-standing-documents.md#the-map) says what the map
  holds.
- **The sorting.** Each home holds one kind of content, so the agent moves each piece of
  content accordingly. Where two homes both seem to fit, priority notes in the map settle the
  case. The guide gives a starting set, and each project adds its own. For example, where an
  automated test can enforce a rule, the test enforces it, and no file repeats it. A word is
  defined only in `GLOSSARY.md`.
- **The checks for drift.** Drift is a gap between the documents and the project, such as a
  citation that points at nothing. The guide names four kinds of drift. Each project chooses how
  and when it checks for each kind, and the checks run before a change merges. The guide's
  section ["Drift"](skills/adopt/references/adopt-standing-documents.md#drift) names the four
  kinds.

### How to use it

Install the `standing-documents` plugin, and run `/standing-documents:adopt` in the project. The
skill looks for the map of the project in `CLAUDE.md`, and does a first adoption if it's not
already there. If it's there but is based on an earlier version, the skill upgrades the
project. So to upgrade, run `/plugin update`, and then run `/standing-documents:adopt` again.

Any agent can also use the guide with no plugin. Give it
[the guide](skills/adopt/references/adopt-standing-documents.md), and tell it to start at the
section "Adoption".

A first adoption has four steps. The agent writes the map. It then shows you the list of moves,
and after you approve the list, it moves the content into its homes. Next, it chooses the checks
for drift. Finally, you check the result. To help you do that, the agent prepares yes-or-no
questions about anything the moves left unsettled, such as two sources that disagree.

### The guide is in its alpha stage: let me know how it goes

If you run into any problems, open an issue. Please be specific (e.g. report a passage of the
guide that misled your agent, or a step that did not fit your project). A report from a project
on a stack other than Rails is the most useful, since I've only used it with Rails so far.

## Skills only you can invoke

- **[adopt](skills/adopt/SKILL.md)**: Apply the guide to a project for the first time, or upgrade a project to the newest version of the guide.

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install standing-documents
```
