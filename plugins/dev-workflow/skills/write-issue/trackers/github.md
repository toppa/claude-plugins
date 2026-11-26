# GitHub Issues

Read this file where the profile says `tracker: github`. It holds what `write-issue` does
in GitHub Issues. The facts come from the help text of the GitHub CLI, `gh` 2.102.0, checked
2026-11-26, and from GitHub's docs. A test on scratch issues in a private repository on
2026-11-26 ran the create commands below, with `--parent` and `--blocked-by`.

This tracker uses the `gh` command through the shell, and not an MCP server. So the server
rules in "The tracker's tools" in `SKILL.md` do not apply. Run
`gh auth status --active --hostname github.com` once before the first call. For a
repository on GitHub Enterprise, pass its host to `--hostname`. Where the check fails, tell
the user, and carry on with no tracker file.

## The repository

The issues go to the repository of the current worktree. Run
`gh repo view --json nameWithOwner` once, and show the repository in the draft. Where the
work belongs to another repository, pass `--repo <owner>/<name>` to each command.

## Profile keys

| Key | What it means | The first-run question |
| --- | --- | --- |
| `kind_labels` | The label that each kind gets: `story`, `bug`, `task`, and `epic`. A kind with no label takes `none`. | "Which label does each kind get?" Offer the labels that `gh label list` gives. Offer `enhancement` for a story and `bug` for a bug, where the repository has them. |

```yaml
profiles:
  personal:
    tracker: github
    paths:
      - ~/src/
    kind_labels:
      story: enhancement
      bug: bug
      task: task
      epic: epic
```

GitHub Issues has no team and no status for a new issue. So the profile holds no key for
either.

## An epic is a parent issue

Create an epic as an issue, and put each of its issues under it as a **sub-issue**. GitHub
shows the progress of the sub-issues on the parent issue. Give the epic the `epic` label
from `kind_labels`, because a label is the one mark that tells an epic from an issue. This
overrides the Labels row for an epic in "Labels and defaults" in `SKILL.md`.

## The same change in two apps

Create the two issues in the two repositories. Name the first issue in the second issue's
opening line as `<owner>/<name>#<number>`. GitHub links the two issues from that reference.
GitHub has no "related" relation. So for two issues that are related only, the reference is
the whole relation.

## Labels

GitHub labels have no groups. Each issue gets the label from `kind_labels` for its kind.

1. Run `gh label list --limit 200 --json name` to read the repository's labels.
2. Where the label from `kind_labels` is not in the list, flag it in the draft. Ask whether
   to create it with `gh label create <name>`, or to skip it.

GitHub Issues has no priority field. Where the user states a priority, look for a label
that names it. Where none exists, tell the user, and leave the priority out.

## Create order

Write each body to a file in the session's scratchpad directory. Pass it with
`--body-file`, so that the body keeps each backtick and each `$` exactly as written.

Create each item with `gh issue create`. The command prints the new issue's URL. Pass these
flags, beside `--title`, `--body-file`, `--label`, and `--assignee`:

1. The epic, where the draft has one, needs no other flag.
2. An issue in the epic takes `--parent <epic number>`.
3. The second issue of a pair takes `--blocked-by <first issue URL>`, where the first issue
   must go first. A URL works across repositories. Otherwise, the reference in its opening
   line is the relation.
4. Put each link in the body, under its own heading. GitHub Issues has no field for links.

`--assignee` takes a GitHub login, or `@me` for the user. Where the user gives a name, find
the login with `gh api --paginate repos/<owner>/<name>/assignees --jq '.[].login'`, with the
repository from "The repository".

To read an existing issue, run
`gh issue view <number> --json number,title,body,labels,parent,blockedBy,subIssues,url`.

## Revise an issue or an epic

An epic is an issue here, so both take the same commands.

**Read the item.** Run
`gh issue view <number> --json number,title,body,labels,parent,blockedBy,updatedAt,url`.

**Save the change.** Run `gh issue edit <number>`. Pass only the flags that the change
alters:

| The change | Flags |
| --- | --- |
| Description | `--body-file` |
| Title | `--title` |
| Labels | `--add-label` and `--remove-label` |
| Blocked by | `--add-blocked-by` and `--remove-blocked-by` |
| Epic | `--parent` and `--remove-parent` |

**Save a description under an optimistic lock on `updatedAt`.** GitHub has no partial
update for a body, so `--body-file` replaces the whole body.

1. Read the item again, directly before the save.
2. Where `updatedAt` is the same as at the first read, save the changed body.
3. Where `updatedAt` changed, apply the change to the new body. Where a teammate changed a
   passage that the change touches, show the user both versions, and ask before you save.
