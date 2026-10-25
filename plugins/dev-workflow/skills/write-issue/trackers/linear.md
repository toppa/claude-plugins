# Linear

Read this file where the profile says `tracker: linear`. It holds what `write-issue` does
in Linear. The facts come from Linear's docs, checked 2026-10-12, and from the tool schemas
of Linear's MCP server. Each tool below carries the last part of its name only, as "The
tracker's tools" in `SKILL.md` says.

## Profile keys

| Key | What it means | The first-run question |
| --- | --- | --- |
| `team` | The team that gets each new issue and each new Project. | "Which Linear team gets new issues?" Offer the team names from `list_teams`. |
| `issue_status` | The status of a new issue. | "Which status does a new issue start in?" Offer the status names that `list_issue_statuses` gives for the team. |
| `project_status` | The status of a new Project. | "Which status does a new Project start in?" Offer `Backlog`. |
| `required_label_groups` | The label groups from which each issue gets one label. | "Which label groups need a label on each issue?" Offer the groups that `list_issue_labels` gives for the team. An empty list is a valid answer. |

```yaml
profiles:
  acme:
    tracker: linear
    paths:
      - ~/work/
    team: Platform
    issue_status: To Do
    project_status: Backlog
    required_label_groups:
      - Product
      - Category
```

## An epic is a Project

Linear has no native epic. Create an epic as a Linear Project, and not as a parent issue.
A Project shows progress, and it spans teams. Linear's own import from Jira maps a Jira
Epic to a Project (https://linear.app/docs/jira-to-linear).

| `save_project` field | Value |
| --- | --- |
| `name` | The epic's name |
| `summary` | One line, 255 characters at most. The limit comes from the `save_project` schema. |
| `description` | The epic template |
| `addTeams` | A list that holds the profile's `team` |
| `lead` | The answer to "who leads the epic" |
| `state` | The profile's `project_status` |

To find an existing Project by name, call `list_projects`. To read one Project, call
`get_project`.

## One issue, one PR

A PR moves the status of its Linear issue. Linear's GitHub integration does this, and each
team sets it (https://linear.app/docs/github). By default, an open PR moves the issue to
"In Progress", and a merged PR moves it to "Done". So two PRs on one issue move its status
against each other. This is a second reason for one PR per issue.

## The same change in two apps

Make the two issues **peer issues**, joined by a relation from "Create order" below. Do not
make one issue the parent of the other. Parent auto-close and sub-issue auto-close are team
settings, so a team can close one issue when the other closes. Linear's docs do not confirm
the default of either setting (https://linear.app/docs/parent-and-sub-issues).

Where a required label group names the app, each issue gets the label of its own app. One
issue cannot carry both apps' labels, because Linear allows one label from each group.

## Labels

An issue carries at most one label from each label group. This is a Linear rule, and no
setting changes it (https://linear.app/docs/issue-property). Each workspace creates its own
groups.

1. Call `list_issue_labels` with the profile's `team`. Follow `cursor` while `hasNextPage`
   is true, because one page holds 50 labels by default.
2. For each group in `required_label_groups`, take the labels whose `parent` names that
   group. Skip a label that carries `retiredAt`, because a retired label cannot go on a new
   issue.
3. Pick one label from each group, as "Labels and defaults" in `SKILL.md` says.

Pass each label by its exact name in `labels`.

A priority that the user states goes in `priority`: 1 is Urgent, 2 is High, 3 is Medium,
and 4 is Low. The default, None, is 0. The values come from the `save_issue` schema.

## Create order

1. Create the Project with `save_project`, where the draft has one.
2. Create each issue with `save_issue`. Pass `team`, `title`, `description`, `labels`, and
   `assignee`, and pass the profile's `issue_status` as `state`. Set `project` where the
   issue belongs to a Project.
3. Set the relation on the second issue of a pair: `blockedBy` with the first issue's
   identifier where the first must go first, and `relatedTo` otherwise.
4. Put each link in `links`, as a `url` and a `title`. Where the workspace has the Sentry
   integration, leave each Sentry URL out of `links`, because the integration link then
   adds a second Sentry attachment. A Sentry issue syncs with its Linear issue through the
   integration link only. Where the caller does not make that link, tell the user to use
   "Link Linear issue" in the Sentry sidebar.

`assignee` and `lead` take a name, an email, or `me`. Where a name matches more than one
person, find the person with `list_users`.

To read an existing issue, call `get_issue` with its identifier.

## Revise an issue or an epic

**Read the item.** For an issue, call `get_issue` with its identifier, and pass
`includeRelations: true`. For an epic, call `get_project` with the Project's name or
identifier.

**Save the change.** For an issue, call `save_issue`, and pass the issue's identifier as
`id`. For an epic, call `save_project`, and pass the Project's name or identifier as
`id`. Pass only the fields that the change alters:

| The change | `save_issue` | `save_project` |
| --- | --- | --- |
| Description | `patch` | `patch` |
| Title or name | `title` | `name` |
| Labels | `addLabels` and `removeLabels` | None, because an epic gets no labels |
| Relations | `blockedBy`, `relatedTo`, `removeBlockedBy`, and `removeRelatedTo` | None |

Do not pass `labels` on a revise, because it replaces the whole label set. A label that a
teammate added since the read then goes away.

**Send the change to a description in `patch`.** `patch` takes the place of `description`,
so pass only one of the two in a call. A `patch` is a list of operations, which run in
order:

- `replace` changes `old_string` to `new_string`. An empty `new_string` deletes the match.
- `insert_before` and `insert_after` put `text` directly before or after `anchor`.
- `append` adds `text` at the end, and `prepend` adds it at the start.
- `replace_range` changes the text from `from` up to `to` into `new_string`. The `to` text
  stays in place.

Each anchor (`old_string`, `anchor`, `from`, and `to`) must match the current text exactly
once. Copy each anchor from the text that the read returned, and not from the draft.
Linear stores a ticked box as `- [X]`, with an uppercase `X`, so an anchor with `- [x]`
does not match it. One operation that fails stops the whole save, and nothing changes.

Where the save fails, read the item again. Build each operation again against the text
that comes back, with anchors that each match once. Where a teammate changed a passage
that the change touches, show the user both versions, and ask before you save again.
