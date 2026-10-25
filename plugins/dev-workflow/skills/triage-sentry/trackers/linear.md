# Linear

Read this file where the profile says `tracker: linear`. It holds what `triage-sentry`
does in Linear, and how Sentry links one of its issues to a Linear issue. Each Linear tool
below carries the last part of its name only, as the write-issue skill's "The tracker's
tools" section says. The facts come from the tool schemas, and from the triage runs that
each measured case dates.

## What a run needs

**The Linear integration installed in Sentry.** The skill makes its links through that
integration. The interview checks for it, under "The integration" below.

## Config keys

This file owns the config keys below. `references/configuration.md` owns the other keys,
and it runs the interview that asks these questions.

| Key | What it means | The interview question |
| --- | --- | --- |
| `tracker.team` | The Linear team that gets each task from the rotation. It overrides the profile's `team`. | "Which Linear team gets a triage task?" Offer the team names from `list_teams`. |
| `tracker.status` | The issue status for a new task. It overrides the profile's `issue_status`. | "Which status does a new triage task start in?" Offer the status names that `list_issue_statuses` gives for the team. |
| `tracker.assignee` | The assignee of a new task, or `null` for nobody. | "Who gets each new triage task?" Recommend no assignee, because a triage task belongs to nobody until somebody picks it up. |
| `tracker.labels` | The labels that every task from this rotation carries. | Under "The labels" below. |
| `product_label`, in each entry of `projects` | The product label of the project. | Under "The labels" below. |

### The labels

Call `list_issue_labels` for the team from `tracker.team`. Take two answers from one list:

- The product label per project, from the Product group. Two projects often share one
  label, as a backend and a browser half of one application do.
- The labels that every task from this rotation carries, for `tracker.labels`. A team that
  tracks work by category has one, such as a bug label or a security label. **Ask for
  these, because the tracker may reject an issue that omits a required label.**

### The integration

Run this check after the questions above. Call `get_alert_options` through
`execute_sentry_tool` for the organization, with `section: "actions"` and
`actionTypes: ["sentry_app"]`. Look for a `sentryApp` whose `name` is `Linear`, and ask
nothing. Where the organization has no Linear app, stop the interview and tell the user,
because the skill links every task through that app.

## Build the tracker map

`SKILL.md`'s section "The tracker map" says when to build the map, what each row holds, and
how to match a queued issue against it.

List the issues with `list_issues`, filtered by every label in `tracker.labels`. Where
`tracker.labels` is empty, run one listing per product label of the projects in scope.
**Page until the response reports no further page, because a capped list misses in
silence.** Measured 2026-09-22: a label-filtered list returned 88 rows, while a
recency-ordered list of 250 missed two issues that mattered.
**Pass `includeArchived: true`, because `list_issues` drops an archived issue whatever its
status.** Measured 2026-10-15: an issue in To Do was archived on purpose, and it still
owned a live error. The map held 118 rows without the flag, and 119 with it.

Pass `fields` to `list_issues`, with `url`, `statusType`, `completedAt` and `canceledAt`.
**`list_issues` cuts each description at about 500 characters, so a Sentry id after the
cut does not appear.** Read a row with no Sentry id as unproven, and not as untracked.

**An integration link shows as a `create_issue` entry with `provider: "Linear"` in
`get_issue_activity`.** Its `data.location` holds the Linear URL. That entry is the
reliable signal for a link. Run item 4 of `SKILL.md` already reads the activity. **Do
not read a missing External Issue Links section as "no link".** `get_issue_details` prints
that section only for a list that is not empty, and it hides a failed fetch.

## After the issue exists

Do these two things after `write-issue` creates the issue, as `SKILL.md`'s section "The
tracker" says:

- **Where the issue is in `Triage`, read `triageIntel` from `get_issue`.** Linear
  returns that field only for an issue in `Triage`. A `relatedIssue` entry is a
  suggestion, and not a verdict. **Match it on the error class and the culprit, as "The
  tracker map" in `SKILL.md` says, before you call it a duplicate.** Where it matches, ask
  the user before the link. Measured 2026-09-30: `triageIntel` named REL-408 as the
  duplicate of REL-409. The map and the search before filing both missed it.
- **Make the integration link**, under "The integration link" below.

## The integration link

The Linear integration syncs state through an integration link only. When the Linear
issue goes to Done, Sentry resolves each linked Sentry issue in the next release. A
Sentry URL in the Linear issue syncs nothing, and a Linear URL in a Sentry note syncs
nothing.

Make the link with `link_issue`, a Sentry catalog tool. Run it through
`execute_sentry_tool`. `search_sentry_tools` returns its schema.

**Do not call `link_issue` or `unlink_issue` in a subagent, because the permission
classifier of auto mode can block the link there.** A move needs both calls in one place.
A blocked link after an unlink leaves the Sentry issue with no link. Make each call in
the main session, after the user confirms the write. Measured 2026-10-21: the classifier
blocked `link_issue` in a subagent as an external system write, although the brief of the
subagent quoted the user's approval. The same call passed in the main session after the
user approved it there. `unlink_issue` passed once in a subagent. The blocked link that
followed left CHECKOUT-7 with no link.

Pass these arguments:

- `organizationSlug`: `organization_slug` from the config.
- `issueId`: the Sentry short id, such as `CHECKOUT-7`. `issueUrl` takes the Sentry issue
  URL instead.
- `externalIssueUrl`: the `url` of the Linear issue, from the `save_issue` response or
  from the tracker map.

Leave out `appSlug`, because the tool infers it from a Linear URL.

Read `status` in the result:

| `status` | Meaning |
| --- | --- |
| `linked` | Sentry made the link. Linear then adds the Sentry attachment to the Linear issue by itself. |
| `already_linked` | The link already exists. So a retry is safe. |
| Any other | Read the issue's links, as below. |

Measured 2026-10-21 on CHECKOUT-7: the result held `"status":"linked"`, and its
`externalIssue` held `"provider":"linear"`. Linear then added the attachment. The
`externalIssueUrl` was the `url` from Linear, with the slug of the title in it.

**A Sentry issue holds one Linear link at most.** The tool description says that a
different App association must be unlinked first. So `link_issue` makes no link where the
Sentry issue links another Linear issue. No run has measured the result for that case.

**To read the issue's links, use `get_sentry_resource` and `get_issue_activity`.** The
first lists the links in its External Issue Links section. The second lists each link
event, under "Build the tracker map" above. Where the issue links another Linear issue, do
not retry, because the answer does not change. Where the other Linear issue is a Duplicate
of this one, move the link, under "Move a link" below. Otherwise report both Linear issues,
because a person decides which one owns the error.

**Where the link fails, tell the user to use "Link Linear issue" in the Sentry sidebar.**
Put the result of the call in the report.

### Move a link

Remove the old link first. Then make the new link. The order matters, because Sentry
refuses a second Linear link on one issue.

1. Call `unlink_issue` with the arguments of `link_issue`. Pass the URL of the old Linear
   issue as `externalIssueUrl`.
2. Read the issue's links. **`unlink_issue` returns `not_linked` both where it removed
   the link and where no link existed, so the result proves nothing.** Where the old
   Linear issue still shows in the links, the unlink failed. Report it, and stop.
3. Make the new link, under the steps above. A `linked` result also proves that the old
   link is gone.
4. Where the old Linear issue still shows the Sentry attachment, delete that attachment
   with `delete_attachment`. The Sentry unlink does not remove it.

Where step 3 fails, the Sentry issue has no link. So report the unlinked Sentry issue at
once, with the fallback above. Measured 2026-09-30 on STOREFRONT-3F, with the Sentry REST
unlink: Linear added no attachment to REL-408, the surviving issue. Measured 2026-10-07 on
three links moved from REL-157 to REL-405, with the Sentry REST unlink: Linear added the
attachments to REL-405, and the REST unlink left them on REL-157. The 2026-09-30 case was a
Duplicate, where Linear moves the attachment itself. Measured 2026-10-21: `unlink_issue`
also left the attachment on the old Linear issue.

## Reconcile the tracker with Sentry

The integration syncs Done to resolved, and nothing else. So each run compares the two
systems. It fixes a mismatch that has one correct answer, and it reports a mismatch
that needs a person.

**The set.** Take the tracker map rows that name a Sentry id, and keep two groups:

- Every open row.
- Every row closed in the last 30 days: Done, Canceled or Duplicate.

**The window replaces a "since the last run" date, because the skill keeps no local
state.** A closed row gets a mismatch only at the time it closes. A regression reopens
the Linear issue, so the open group covers it. So the window must cover the longest gap
between two runs. A mismatch that closes outside the window is lost for good.

**Read the Sentry side.** Three reads cover the set:

1. **The status, in one call.** Call `search_issues` with
   `query: "issue:[<id>,<id>,...]"`, `period: "90d"` and `limit: 100`. One call returns
   every issue in the list, with its status. Measured 2026-09-29: three short ids in one
   call returned all three, in about 1.5 KB. An issue quiet for more than 90 days does
   not appear. Read each missing id with `get_sentry_resource`.
2. **The link, per issue.** Read `get_issue_activity`. A `create_issue` entry with
   `provider: "Linear"` is a link, and its `data.location` holds the Linear URL. The
   read is about 3 KB for an issue with a few notes.
3. **The last event, per Done row that Sentry did not resolve.** `search_issues` gives
   the last seen time as relative text, such as "9 hours ago", and that cannot settle
   the order of two times. So call `search_issues` with
   `query: "issue:<id> lastSeen:>2026-09-22T20:26:31"`, the close time in UTC. One
   result means an event came after the close time. No result means none did.

A link belongs to a Linear issue when its URL holds `/issue/<identifier>/`.
**Match the identifier, and not the whole URL, because Linear changes the slug when the
title changes.**

For each Duplicate in the set, call `get_issue` with `includeRelations: true`. Its
`duplicateOf` names the surviving issue. `list_issues` does not return it.

**Classify each row.** The Linear close time is `completedAt` for Done, and
`canceledAt` for Canceled and Duplicate. Read 3 above compares it with the last event.
An archived Sentry issue has the status `ignored`.

| Linear | Sentry | The run does this |
| --- | --- | --- |
| Open | No link to this Linear issue | Makes the link, under "The integration link" |
| Canceled | `unresolved` | Archives at `untilEscalating`, with a `reason` that names the Linear issue |
| Done | Not `resolved`, and last seen before the close time | Makes the link where it is absent, then resolves the issue, with a `reason` that names the Linear issue |
| Done | Last seen after the close time | Reports both times. The fix may not work |
| Duplicate | Links the Duplicate | Moves the link to the surviving issue, under "Move a link" |
| Duplicate | No link | Makes the link to the surviving issue |
| Duplicate | Links a third Linear issue | Reports the three Linear issues. A person decides which one owns the error |

**Linear moves a Duplicate's attachment to the surviving issue, and Sentry keeps its
link to the Duplicate.** Measured 2026-09-30: after REL-409 became a Duplicate of REL-408,
REL-409 held no attachment, and STOREFRONT-3F still linked REL-409 only. So read the Sentry
side to classify a Duplicate, and never the Linear attachments.

A row that matches no line of the table is in step, and the run reports only its count.

**The last seen time covers every environment.** A staging event after the close time
therefore reports a Done row rather than resolves it. That is the safe direction, so
read the event before you call the fix broken.

**Report the reconciliation in run item 7 of `SKILL.md`**, as its own table beside the
queue. List each proposed fix and each reported mismatch, with both URLs. Give the count
per table row, the count of rows in step, and the cost: the count of Sentry ids read, and
the count of calls per tool.
