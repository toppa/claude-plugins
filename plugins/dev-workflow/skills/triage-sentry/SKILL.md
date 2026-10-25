---
name: triage-sentry
description: Triage the Sentry review queue for one rotation run, across every project the user's config names. Also maintains that config, so use it to add a project, remove a project, or change a tracker default.
disable-model-invocation: true
metadata:
  upstream_repo: none
  origin: >-
    Written in a personal skills directory, and moved here on 2026-10-25. Its
    playbook began as the playbook of an earlier skill that triaged Bugsnag
    errors, and it was adapted to Sentry.
  synced: 2026-10-25
---

# Triage Sentry

Triage decides and routes. It never fixes code.

**Recommend first, and act on confirmation.** Do not change a Sentry issue, and do not
create a tracker issue, before the user confirms that action.

## The run

0. **Read the invocation argument, find the profile, then read the config.** Find the
   profile under "The profile and the tracker file" below. The config lives at
   `~/.claude/data/dev-workflow/triage-sentry/config.yml`.
   - Where the argument asks for a config change, follow `references/configuration.md`
     and pull no queue.
   - Where the argument carries a Sentry query, such as `is:unresolved timesSeen:>50`,
     that query replaces the queue pull in item 3.
   - Otherwise treat the argument as the scope of this run.
   - Run the checks in "Read the config at the start of a run", in
     `references/configuration.md`. **Do not skip them for a config that parses, because
     a missing key then stops the run at item 8, after the queue work.** Where the file
     or a key is absent, run the interview there. Ask only for what is absent.
1. **Load the rules, and build the tracker map.** Read `references/playbook.md`. Read
   the application note for each project in scope, at
   `~/.claude/data/dev-workflow/triage-sentry/apps/<project-slug>.md`. Then build the
   tracker map, under "The tracker map" below.
2. **Reconcile the tracker with Sentry.** Follow the tracker file's section "Reconcile
   the tracker with Sentry". It uses the tracker map, and its fixes wait for item 8 like
   every other write.
3. **Pull the queue, per project.** Take the union of `is:for_review`, `is:escalating`
   and `is:regressed`, each with `environment:production`. **Always pass `period` and
   `limit`, because each default truncates the result in silence.** A reported count is
   capped by `limit`, so it is never a total.
4. **Run the recurrence search for each queued issue.** Search `error.type` plus
   `culprit`. **Pass no `is:` filter, because `search_issues` defaults to
   `is:unresolved` and an archived sibling then stays hidden.** Read
   `get_issue_activity` on the issue, and on every sibling the search returns. That
   history feeds rule 1 of the playbook, which counts archives.
5. **Fetch detail only where it changes the decision.** `get_sentry_resource` returns
   the issue, at about 20 KB, and it lands inline. Work in the main context, and start
   no subagent. **Read application code at `origin/main`, and not in the working tree,
   because a local checkout can lag.** Measured 2026-09-30: a checkout 283 commits
   behind still held the initializer of the error monitor that the application used
   before Sentry. Run `git fetch`, then read a file with `git show origin/main:<path>`.
6. **Classify against the playbook.** Match every issue against the tracker map before
   you propose a task.
7. **Report, grouped by proposed action.** Put the Sentry URL on every row. Name any
   sibling group that the recurrence search found. **Count the rows in your own tables,
   and compare that count with the count pulled.** Grouped tables lose an issue in
   silence. Measured 2026-09-30: a report stated "21 pulled, 21 reported", and its tables
   held 20 rows.
8. **Act on confirmation only.**
9. **Record every decision on the issue.** `update_issue` takes a `reason`, and Sentry
   posts that text to the activity feed, so one call applies the status and records why.
   Use `add_issue_note` where the decision changes no status, as for a decision to leave
   an issue alone. A task that waits for the user to file it changes no status either.
   See "Where no tracker file applies" below.
10. **Report the backlog per project, then offer a sweep.** Query
    `is:unresolved environment:production !is:for_review` at `limit: 25` and
    `period: 90d`, sorted by frequency. **Ask at the end of the run, because a prompt
    at the start blocks the rotation.**
11. **Offer the application-note edits this run earned, and the retirements the proof
    rules found.** See "The notes are living documents" below.

## Privacy

An event payload can carry customer data, such as a business name, a person's name, or a
payment-provider account id.

**Describe the shape of a value, and never quote the value, because the report and the
Sentry note both persist.**

## The profile and the tracker file

**Find the profile as the `dev-workflow:write-issue` skill's "The profile file" section
says.** That skill reads the same profile when it files a task, so both skills write to one
tracker workspace. Where no profile matches, run that skill's "The first run" section with
write-issue's own tracker file, because that file lists the profile keys and their
questions.

Where the profile names a tracker, look for its tracker file in this skill, at
`trackers/<tracker>.md`, such as `trackers/linear.md` for Linear. Read that file, because it
holds each fact about the tracker that a run uses. Find each tool of the tracker as the
write-issue skill's "The tracker's tools" section says. Where no tracker file applies,
follow "Where no tracker file applies" below.

## The tracker

Read the team, the status, the assignee and the labels from the config. **Pass all
four to the `dev-workflow:write-issue` skill, because that skill otherwise takes the
status from its own profile and asks for an assignee.** The team, the status and the
assignee that you pass override that profile. The labels that you pass add to the labels
that `write-issue` picks. Pass the priority from rule 7 of the playbook too, because
that skill files a task at No priority otherwise. Where an application note carries a
`Where a Task Goes` section, its status overrides `tracker.status` for the tasks that
section names.

File each task as a Bug with the `write-issue` skill. That skill owns the title and
the description. Supply these facts for its bug template:

- **The impact**: who sees the error, and what it costs them.
- **The current behavior and the expected behavior.**
- **The steps to reproduce**, or the repro hypothesis where nobody reproduced it.
- **The evidence**: the Sentry short id, the event count, the count of people affected,
  and the first and last seen dates.
- **The labels**: the product label of the project, plus every label in
  `tracker.labels`.
- **Any second application** that the fix touches.

After `write-issue` creates the issue:

- **Follow the tracker file's section "After the issue exists".** It checks the
  tracker's own suggestion of a duplicate, and it links the Sentry issue to the tracker
  issue.
- **Name the tracker issue in the `reason` of the `update_issue` call from run item 9.**
  Where the link failed, put the URL of the tracker issue in the `reason` instead.
- **Archive the issue at `untilEscalating` in the same call**, under rule 3 of the
  playbook. **Sentry clears `is:for_review` on a status change only, and no tool marks
  an issue reviewed, so an unresolved task returns to the queue on every later run.**

### The tracker map

**Build this at run item 1, before you classify anything.** A check at filing time
misses two groups: an issue the rotation filed on an earlier run, and an issue somebody
else already tracks.

List the error-derived issues of the tracker, as the tracker file's section "Build the
tracker map" says. Run the listing in a subagent where the descriptions are long. Have it
return one row per issue and nothing else, with the tracker id, the URL, the title, the
state type, the closure time, the error class, the culprit, and each Sentry id the issue
names. A Sentry id is a short id, or the numeric id in a Sentry URL.

**A Sentry id in a description is a mention, and not ownership.** Before you treat a row
as the owner of a Sentry id, read the sentence that names the id. Keep the id on the row
only where that sentence says the tracker issue covers the error. Where the description
names another tracker issue as the holder of the Sentry link, keep the id on that issue
only. Measured 2026-10-07: 5 of the 10 rows that the reconciliation with Sentry reported
were mentions, as evidence for another cause or as an exclusion. Two fixes linked the
wrong issue, and both were reverted.

Then match each queued issue against the map:

1. Match the short id, as exact text. Only an issue this rotation filed carries one.
2. **Match the error class exactly. Match the culprit on the controller and the action,
   or on the job class, and never as exact text**, because an issue filed from an
   earlier vendor writes the culprit in that vendor's format. This is the key that works
   for most issues, and it usually sits in the description rather than the title.
   Measured 2026-09-22: of three tracked issues the run had to find, none carried a
   Sentry short id, and each one named its class and its culprit.
3. **A title match is a reason to read the issue, and never a reason to close one.**
4. **A closed tracker issue whose error still fires is a finding, and not a duplicate.**
   Give the closure date beside the date of the latest event. Recommend that the user
   reopens that issue.

A tracker search for the short id is a weaker check, and it settles nothing on its own.
It found 2 of 3 known answers, so read a blank result as unproven.

**Search the tracker for the error class and the culprit just before you file each
task, because the map misses two kinds of issue:**

- **An issue with no rotation label.** Measured 2026-09-30: the 3 issues that owned the
  largest cluster carried no `Exceptions` label. A search on the symptom found them.
- **An issue that somebody filed after the map was built.** Measured 2026-09-30: a
  colleague filed REL-408 at 18:49 UTC. The run built its map hours before, and it filed
  the duplicate REL-409 at 18:54 UTC.

## Where no tracker file applies

No tracker file applies in three cases:

- The profile says `tracker: none`.
- The profile names a tracker with no tracker file in this skill. Tell the user so.
- No connected server serves the tracker.

The run then changes at four points:

1. **The config holds no tracker keys.** A tracker file owns them, so the interview in
   `references/configuration.md` asks no question for them.
2. **Run items 1 and 2 build no tracker map, and they reconcile nothing.** Say so in the
   report, because the run did not check for an existing tracker issue.
3. **Each task ends as Markdown for the user to paste**, as the write-issue skill's
   "Where no tracker file applies" section says. Above each task, name its error class
   and its culprit. Tell the user to search the tracker for both before they file the
   task, because the run could not search the tracker.
4. **Leave the Sentry issue in the queue, because no tracker issue owns the error yet.**
   The next run then drafts the task again, until the user files it. Run item 9 records
   the decision with `add_issue_note`, and the note says that the task waits for the user
   to file it. Where the user says in this run that they filed the task, archive the issue
   at `untilEscalating` in the `update_issue` call of run item 9. Name the tracker issue in
   the `reason`. Tell the user to link the new tracker issue to the Sentry issue, where
   Sentry has an integration for that tracker.

## Sentry cautions

- **To move an issue from one ignore mode to another, set `unresolved` first.** A direct
  mode change does not apply.
- Seer analysis is available through `analyze_issue_with_seer`. **Do not run it unasked,
  because it takes two to five minutes and it consumes credits.** Offer it instead.
- **`get_issue_activity` and `add_issue_note` are catalog tools, and not top-level
  tools. Reach each one through `execute_sentry_tool`, because `ToolSearch` returns
  nothing for either name.** `search_sentry_tools` returns the schema of a catalog tool.
  `add_issue_note` takes the note as `text`.
- **An `issue:` filter overrides the `is:unresolved` default of `search_issues`.**
  Measured 2026-09-30: `issue:STOREFRONT-D` returned the issue while it was archived, and
  again after it was resolved. So an empty result for an `issue:` query is a real
  negative, inside the `period` of the call.
- The top-level Sentry tools may be deferred in a session. Load them with `ToolSearch`
  first. Where `search_sentry_tools` also finds nothing, report a missing connection
  rather than a Sentry outage, and point the user at "What a run needs", in
  `references/configuration.md`.

## The notes are living documents

**Every gate below is a yes/no that the user checks by reading the proposed line. None of
them asks whether the fact is useful.** That question has one answer in the moment, so it
decides nothing.

1. **The kind of the section permits the edit.** Every heading in a note carries its
   kind: `derived`, `open` or `closed`. **Edit under a heading the note already carries,
   because a new heading grows a shape nobody planned.** The rules per kind are below.
2. **It names a class, and not an instance.** A line that carries a Sentry short id fails
   this gate, because that fact belongs on the issue. The "History That Did Not Migrate"
   table is the one exception, and it is closed to new rows.
3. **It carries a source.** A file path, the query that measured it, or a date with a
   count. A line with no source fails.
4. **It fits in 60 words.** A bullet that a run adds or replaces holds at most 60
   words, and its source counts toward them. Count with `wc -w`, and not by estimate.
   The cap covers the open and the closed sections. "Where a Task Goes" records the
   user's own words, so it is exempt.

Two rules hold the rest together:

- **The default is silence.** Where no candidate passes all four gates, say nothing.
  **Do not list the candidates you rejected, because that returns the judgment the gates
  removed.**
- **Propose a diff.** Show the old line, the new line, the source, and the word count of
  each line, as in `40 → 58 words`.

### A derived section

A derived section mirrors the repository: the controller hierarchy, the domains, the
jobs, the auth flows, the integrations, and the error-handling conventions. Its failure
is staleness, and not noise. So it is re-derived from code rather than edited from what a
run saw.

- **Re-derive on a contradiction, and not on a schedule.** A contradiction is a `culprit`
  that names a controller or a job the note does not list, or an error the conventions do
  not explain. A run that hits none touches no derived section.
- A re-derivation reconciles the whole section. It adds, it replaces, and it deletes.
- Each derived heading carries a provenance line, as `Derived from <path> at <commit>,
  <date>`. Update it with the section.
- **Do not edit a derived section from Sentry data alone, because the result is a guess
  dressed as a code fact.** Where the repository is not checked out on this machine,
  report the contradiction and change nothing.

### An open section

Common Noise Patterns is the one open section. No code reading produces it, so it
accumulates across runs. **It holds at most 10 bullets.** A new bullet is allowed, under
three more rules.

- **A single observation is not a source.** A new bullet needs a repository artifact, or
  a second sighting that a prior decision on a sibling issue proves. A pattern seen once
  waits for the next run.
- **A bullet is a tell, a reading and a source, in that order.** The tell is how a run
  recognises the class: the error class, the culprit, the message, or a property of the
  event. The reading is what the class means, and what the run does with it. Write the
  three parts as plain sentences, with no labels. Name a tracker issue in a bullet only
  where it owns the class, because proof rule 2 retires the bullet when that issue is
  Done.
- **No near-duplicate.** A new bullet fails where a bullet in that section already names
  the same error class with the same culprit type. The note's "How to Read a Sentry
  Issue Here" section defines the culprit types. Replace the existing bullet instead.

#### Retire a bullet

A noise bullet goes stale when its class stops reaching Sentry. A stale bullet still
steers the classification, so retire it. Each retirement is a note edit with its
evidence, and it waits for run item 11.

**Check every bullet against the two proof rules on each run.** Each rule proves that the
class no longer arrives:

1. **A filter drops the class.** The application's Sentry filter at `origin/main` names
   it, such as a list of ignored exceptions in the SDK's configuration, or a
   `before_send` callback.
2. **The fix shipped.** The bullet names a tracker issue that is Done, and the recurrence
   search of run item 4, with `lastSeen:>` the close time in UTC, returns nothing.

**Count events only when an addition would make an 11th bullet.** A class with no event
in 90 days is dormant, and that is not proof. An episodic class, such as a timeout during
a vendor degradation, stays quiet for months and still matters when it returns.

- Count the events of each bullet's class with `search_errors`, with
  `fields: ["count()"]` and `period: "90d"`.
- Where a count is zero, propose to retire that bullet beside the new one.
- Where no count is zero, propose a trade. Name the bullet with the lowest count, and
  show the count. Where the user rejects the trade, the new bullet waits.

### A closed section

**Change a closed section by replacement only.** "Where a Task Goes" records the user's
own routing rule. "How to Read a Sentry Issue Here" records Sentry's own behaviour.
"History That Did Not Migrate", where a note carries it, holds the history from the
error monitor that the application used before Sentry. It is frozen, because that error
monitor gets no new errors.
