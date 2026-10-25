# Linear

Read this file where the profile says `tracker: linear`. It holds what `implement-issue` does
in Linear. Each tool below carries the last part of its name only, as the write-issue skill's
"The tracker's tools" section says. The facts come from three sources:

- Linear's docs, checked 2026-10-21.
- The tool schemas of Linear's MCP server.
- A test on a scratch issue on 2026-10-21, which ticked a box in the UI and through the API.

## Read the issue

1. Call `get_issue` with the issue's identifier, such as `ENG-123`. Pass
   `includeRelations: true`.
2. Where the issue's `project` field names a Project, call `get_project` with that name as
   `query`. Linear has no native epic, so the Project is the issue's epic.
3. For each issue in `relations.blockedBy`, read its `statusType`. Where the relation does
   not carry it, call `get_issue` for that blocker.

A blocker is open while its `statusType` is not `completed`, `canceled`, or `duplicate`. Each
team's statuses map to these types, as `list_issue_statuses` shows.

## Read a box

The API returns the description as Markdown. A box that someone ticked in the Linear UI comes
back as `- [X]`, with an uppercase `X`. Treat `- [x]` and `- [X]` as ticked, and `- [ ]` as
open.

## Tick the boxes

Tick every approved box in one `save_issue` call:

1. **Read the issue again** with `get_issue`, directly before the save. Copy each anchor from
   that read, because a teammate can change the description during the work.
2. **Call `save_issue`.** Pass the issue's identifier as `id`. Pass `patch` with one `replace`
   operation for each box:
   - `old_string` is the open line exactly as the read returned it, such as `- [ ] Second`.
   - `new_string` is the same line with `- [x]` in place of `- [ ]`.
3. **Read the issue again.** Linear stores the written `x` as `X`, so each ticked box now
   reads `- [X]`.

Pass `patch` alone, without `description`. `patch` takes the place of `description`, and it
changes only the text that each operation names. Each `old_string` must match the description
exactly once. One operation that fails stops the whole save, so the save never ticks only some
of the boxes. Where the save fails, read the issue again. Build each operation again against
the text that comes back.

## Name the issue in the PR

Write a closing word with the issue's key in the PR description, such as "Fixes ENG-123".
Linear's GitHub integration links the PR. When the PR merges, a closing word applies the
team's "On PR or commit merge" status to the issue.

- Where the PR must not close the issue, write a word that links the PR with no merge status,
  such as "Part of ENG-123".
- Linear's docs list each closing word and each word that links only
  (https://linear.app/docs/github).
- Write the line in the description, and not only in the branch name. A branch name that
  holds the issue's key also links the PR. The docs do not say whether that link applies the
  merge status.

Each team sets the status that the integration moves the issue to. So this skill sets no
status.

## A note on the epic

Send a note on the epic through the write-issue skill's "Revise an issue or an epic" section.
That section reads the Project, shows the change, and saves it after the user approves it. Do
not call `save_project` from this skill, because a direct call skips the review and the
approval.
