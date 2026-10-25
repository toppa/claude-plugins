# Decisions

Each file here records one decision about this repository's plugins or documents, with the
alternative that lost. The decision passes the bar, which has two tests: a reasonable person
would otherwise argue the decision again, and its reversal costs real work. The cost of a
reversal is the change that undoes the decision, and not the work that the change then triggers.
A decision that one edit reverses gets no ADR.

Cite an ADR by its number, linked to this directory: `[0001](docs/adr/)` from the repository
root. In a code comment, write the bare number.

An ADR cites no commit SHA, because a rebase, a squash, or a fresh history leaves a SHA that
points at nothing. So an ADR states the fact that the commit holds, or it cites a file or a URL.

## Accepted

| ADR | Title | Date |
|---|---|---|
| [0001](0001-a-plugin-skill-reaches-context-in-exactly-three-ways.md) | A plugin skill reaches context in exactly three ways | 2026-08-11 |
| [0002](0002-claude-code-puts-only-description-and-when-to-use-into-context.md) | Claude Code puts only `description` and `when_to_use` into context | 2026-08-12 |
| [0003](0003-a-plugin-ships-its-license-notices-and-its-maintainer-records-live-in-docs.md) | A plugin ships its license notices, and its maintainer records live in `docs/` | 2026-10-01 |
| [0004](0004-one-ordered-check-names-a-projects-response-mode.md) | One ordered check names a project's response mode: Hotwire, Inertia, or JSON API | 2026-08-25 |
| [0005](0005-rails-core-takes-16-of-33-upstream-skills.md) | `rails-core` takes 16 of 33 upstream skills, and rejects 17 on stated tests | |
| [0006](0006-inertia-react-is-react-only.md) | `inertia-react` is React only, and takes 10 skills from three upstream sets | |
| [0007](0007-dev-workflow-holds-four-skills-written-here-and-one-from-upstream.md) | `dev-workflow` holds four skills written here and one from `jbarrieault/claude-marketplace` | 2026-08-15 |
| [0008](0008-the-rails-agent-owns-app-controllers.md) | The `rails` agent owns `app/controllers`, and the `frontend` agent writes no Ruby | 2026-08-11 |
| [0009](0009-a-skill-checks-the-gemfile-before-it-prescribes-a-non-default-gem.md) | A skill checks the `Gemfile` before it prescribes a non-default gem, and never adds one | |
| [0010](0010-the-guides-rule-files-are-untestable-rules-and-untestable-conventions.md) | The guide's rule files are `UNTESTABLE-RULES.md` and `UNTESTABLE-CONVENTIONS.md` | 2026-10-09 |
| [0011](0011-a-subagent-implements-each-plan-step-and-the-main-session-closes-it.md) | A subagent implements each plan step, and the main session closes it | 2026-10-11 |
| [0017](0017-an-issue-skill-keeps-tracker-facts-in-a-tracker-file-and-workspace-values-in-a-profile.md) | An issue skill keeps tracker facts in a tracker file, and workspace values in a profile | 2026-10-21 |
| [0018](0018-the-guide-states-each-homes-purpose-and-trusts-the-agents-judgment.md) | The guide states each home's purpose, and trusts the agent's judgment. [0019](0019-the-adr-bar-tests-the-cost-of-a-reversal-and-an-open-question-waits-in-its-work.md) narrows its decision 8, and [0021](0021-the-guide-ships-in-the-standing-documents-plugin-with-one-version-in-the-guide-plugin-json-and-the-tag.md) replaces its decision 11 | 2026-10-23 |
| [0019](0019-the-adr-bar-tests-the-cost-of-a-reversal-and-an-open-question-waits-in-its-work.md) | The ADR bar tests the cost of a reversal, and an open question waits in its work | 2026-10-25 |
| [0020](0020-the-public-repository-starts-with-one-commit-and-the-plans-live-in-a-private-repository.md) | The public repository starts with one commit, and the plans live in a private repository | 2026-10-25 |
| [0021](0021-the-guide-ships-in-the-standing-documents-plugin-with-one-version-in-the-guide-plugin-json-and-the-tag.md) | The guide ships in the `standing-documents` plugin, with one version in the guide, `plugin.json`, and the tag | 2026-10-25 |

An empty date means the record never gave one.

## Proposed

None.

## How an ADR moves

The status lives in this index and in the file name, and never inside the ADR. An accepted
ADR's file name has no prefix, and its title states what holds. A proposed ADR's file name
starts with `proposed-`, as in `<number>-proposed-<slug>.md`, and its title asks a question.
One number sequence covers both groups, and a number is never reused.

An open question waits in the plan that will settle it, and a decision to wait for a later
measurement is an open question. A decision about a part of this repository that does not exist
yet waits in the plan that builds that part, and the bar applies to it when that plan finishes.
Two amendments to the usual ADR rules make room for an open question that no plan will settle,
where its answer will pass the bar:

1. **A proposed ADR is mutable. Acceptance freezes it once `main` holds it as accepted.**
   Immutability belongs to an ADR that `main` holds as accepted, and not to the file. Before
   the branch that accepts the ADR merges, no reader outside the branch acted on the decision,
   so change the ADR in place.
2. **The core of an ADR applies at acceptance, and not at proposal.** The core is the opening
   paragraph of this index: one decision that passes both tests, with the alternative that lost.
   So a proposed ADR may be one sentence, with its argument still unmade.

Acceptance drops the prefix and turns the title into a statement. A citation names the number
and links to this directory, so no citation changes. Once `main` holds an ADR as accepted, its
decision is frozen, and a pointer in it is not: repoint the pointer when its target moves. A
reversed ADR is deleted, and the ADR that reverses it names the deleted file's path, because
`git log --diff-filter=D -- <path>` finds the file.
