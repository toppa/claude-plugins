---
name: write-issue
description: >-
  Draft an issue for the team's tracker as a story, a bug, or a task with
  acceptance criteria, or draft an epic, then create it after approval.
when_to_use: >-
  Use to file an issue in a tracker such as Linear, Jira, or GitHub Issues, to
  write a user story, to file a bug or an exception, to plan an epic, or to
  revise an existing issue or epic.
argument-hint: "[what the work is] [label:<name>] [assignee:<name|nobody>] [link]"
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin as the `linear-issue` skill
    in a personal skills directory, and moved here on 2026-10-21 so it travels
    with the rest of the planning workflow.
  synced: 2026-10-21
  reference_guides:
    - https://linear.app/docs/issue-property
    - https://linear.app/docs/github
    - https://linear.app/docs/parent-and-sub-issues
    - https://linear.app/docs/jira-to-linear
---

# Draft and create an issue

The skill writes a **draft**: the kind, the title, the description, the labels, and any
split into more than one issue. The user approves the draft before anything reaches
the tracker.

A **tracker** is the system outside the repository where a team keeps its issues, such as
Linear, Jira, or GitHub Issues. An **epic** is a tracker item that groups issues, with its
own identifier, URL, and description.

A caller, such as a skill that triages errors, supplies facts. The skill puts those facts
into the template for the kind. A team, a status, or an assignee that the caller supplies
overrides the value in the profile. Labels that the caller supplies add to the labels that
the skill picks.

## Workflow

The workflow has two entry points:

- **A new draft** starts at step 1, and it runs every step below.
- **A revise** changes an issue or an epic that exists in the tracker. It starts at step 1.
  Then it runs the steps of "Revise an issue or an epic" in place of steps 2 to 6.

The two paths join at step 7. Steps 8 to 10 say where a revise differs.

1. **Find the profile.** Follow "The profile file". Where the profile names a tracker
   that has a tracker file, read that file, such as `trackers/linear.md` for Linear.
2. **Collect the facts.** Read them from the conversation and from the caller. Where the
   work names an existing issue or epic, read it.
3. **Pick the kind.** Use the table in "The kinds". The kind decides the template.
4. **Check for a split.** Apply "One issue, one PR". Where a signal fires, the draft
   proposes the split.
5. **Ask for what is missing, in one message.** Ask only for the items in "What to ask".
6. **Write the draft.** Read the template file for the kind, and fill it. Apply "Titles",
   "Acceptance criteria", and "Labels and defaults".
7. **Run the cold-read review.** Follow "Cold-read review".
8. **Show the draft, and wait for approval.** Show every issue and epic in full, with
   its fields, its relations, and the INVEST exceptions. On a revise, show the change in
   place of the full item: each changed passage and each changed field, before and after.
   Below the draft, list each fix from the review in one line. Ask about each Decision as
   a question. List each dropped finding in one line, with the reason, so that the user
   can overrule the verdict. Where the user asks for a change, edit the draft and show it
   again.
9. **Create it.** Where a tracker file applies, follow "Create order". Otherwise, follow
   "Where no tracker file applies". On a revise, follow "Save a revise" instead.
10. **Report** the identifier and the URL of each issue and epic that you created or
    revised.

## Revise an issue or an epic

A **revise** changes one issue or one epic that exists in the tracker. The caller or the
user gives the item's identifier and the **reason for the revise**. The reason holds the
facts that the revise must put into the item. Two examples:

- The findings of a readiness check, which the implement-issue skill runs before it
  starts the work.
- A note for an epic, such as a constraint that the work settled for a later issue.

Where the user asks for a revise directly, the request is the reason.

On a revise, the **draft** is the item with the change in it.

Run these steps after step 1 of "Workflow":

1. **Read the item.** Read its title, its description, its labels, and its relations
   from the tracker. The tracker file names the call. Where no tracker file applies, ask
   the user to paste the item's current text.
2. **Name its kind.** Use the table in "The kinds". The review checks the item against
   the template for its kind.
3. **Write the change.** Change only the passages and the fields that the reason for the
   revise calls for. Apply "Titles", "Acceptance criteria", "Labels and defaults", and
   "Privacy" to each passage and field that you change. Leave every other passage as it
   is, because the author of the item agreed to that text.
4. **Go to step 7 of "Workflow".** Sometimes the caller already ran the cold-read review
   on the item's current text. Where the change fixes only those findings, skip the
   subagent part of "Cold-read review", because a cold read of that text already ran.
   The check in this context still runs.

A revise creates no new item. Where the fix for a finding needs a new issue, such as
where the item fails the INVEST letter Small, give the finding the verdict Decision. Ask
about it at step 8. Where the user agrees, run a new draft for the new issue after the
revise saves.

### Save a revise

Where a tracker file applies, save the change with the update call that the tracker file
names. Send only the change, where the call allows it. Then an edit that a teammate made
since the read survives.

Where no tracker file applies, end with the revised item as Markdown for the user to
paste, as "Where no tracker file applies" does for a new draft. Give the whole revised
description in one block, because the user pastes it over the old one. Above the block,
list each changed field.

## The profile file

A **profile** holds one user's settings for one tracker workspace. The profiles live in a
per-user file, `~/.claude/data/dev-workflow/issue-trackers.yml`. Each machine keeps its own
copy.

```yaml
profiles:
  acme:
    tracker: linear
    paths:
      - ~/work/
    team: Platform
  personal:
    tracker: none
    paths:
      - ~/src/
```

This skill owns two keys in each profile:

- **`tracker`** is the tracker's name in lower case, such as `linear`. Its tracker file is
  `trackers/<tracker>.md` in this skill. The value `none` records that the projects under
  the profile's paths have no tracker.
- **`paths`** lists the directories that the profile covers. A path can start with `~`.

The tracker file owns every other key of the profile. It lists each key, what the key
means, and the question that the first run asks for it.

**Match the profile by the path of the project's main worktree**, so a linked worktree
in another directory still finds the profile of its main worktree. Outside a git repo,
use the current directory. A profile matches where that path is one of its paths, or
sits under one of them.

- **Where two profiles match, the longest matching path wins.**
- **Where the profile says `tracker: none`**, no tracker file applies. Ask no question
  about a tracker, because `none` records the user's answer.
- **Where the profile names a tracker with no tracker file in this skill**, tell the user
  that this skill has no tracker file for that tracker. Then carry on with no tracker file.
- **Where no profile matches**, run "The first run".

### The first run

Ask each question with `AskUserQuestion`. Ask which tracker the project uses, and which
directory the profile covers. Where a profile already names the same tracker, offer to add
the directory to that profile. Otherwise, name a new profile. Ask each question that the
tracker file lists. Write the profile. Leave every other profile as it is. Show the user
what you wrote.

### The tracker's tools

A tracker file names each tool by the last part of its name, such as `save_issue`. The
full name starts with a prefix from the name that the user gave the server, such as
`mcp__linear-server__save_issue`. Find the full name in the session's tool list.

- Where two connected servers serve one tracker, ask the user which one to use.
- Where no connected server serves the tracker, tell the user. Then carry on with no
  tracker file.

## The kinds

| Kind | The work | Template |
| --- | --- | --- |
| Story | A change in behavior that a person can see or use | [story](references/story.md) |
| Bug | Current behavior that is wrong, including an exception that an error monitor reports | [bug](references/bug.md) |
| Task | Technical work with no direct change for a person | [task](references/task.md) |
| Epic | A group of stories, created as the tracker's epic item | [epic](references/epic.md) |

An **error monitor** is a service that collects the exceptions that an app raises.

The nature of the work decides the kind, and the label does not. A Bug is behavior that
fails what its design intends. A Story changes the design. A performance or security
change is a Story where the draft can name the role that benefits. Otherwise it is a
Task. A Task exists so that no story names "a developer" as its role.

Read only the template for the kind you draft.

## What to ask

The skill infers the kind, the title, the labels, and any split. It asks for the
**value**, because an invented value passes the format and fails the purpose:

- For a Story or an Epic: the role, and the benefit.
- For a Task: the reason for the work.
- For a Bug: the impact, which is who sees it and what it costs them.

Ask only for the value that the conversation or the caller does not state.

Also ask about an ambiguity where the answer changes the kind, the split, or an
acceptance criterion. An example is whether a rename also moves every call site.

Also ask **who to assign** each issue to, and who leads an epic. "Nobody" is a valid
answer. A caller that supplies an assignee, including an explicit null, gets no
question.

## One issue, one PR

One issue maps to one PR. This is the INVEST letter Small, in "INVEST check": one PR
delivers the whole issue.

Propose a split where one of these **hard signals** fires:

- The work changes more than one repository.
- The work has steps that must deploy in order.

Propose a split where one of these **soft signals** fires, and say why:

- The issue has more than about 6 or 7 acceptance criteria. **6 or 7 is a house
  heuristic with no external source.**
- The story sentence or the title joins two goals with "and".

A split that leaves an issue with no value of its own is not a split. Combine the parts
again, or turn the enabling part into a Task.

### The same change in two apps

The same change in two apps becomes two issues, one for each app's repository. The tracker
file says how the two issues relate in that tracker.

- The first issue holds the full description from the template.
- The second issue opens with "The same change as ENG-123, in the billing app." Then it
  lists only its own acceptance criteria.
- Where one app must go first, the first issue **blocks** the second. Otherwise the two
  issues are **related**.
- Both titles carry an app suffix, as in "Rename ErrorReporter.notify to .call (Billing)".

## Titles

- Write the title as an imperative outcome: "Show staff the reason a refund fails".
- Keep it near 60 characters. **60 characters is a house heuristic with no external
  source.**
- Put no product prefix and no kind prefix in the title. The labels carry both.
- A Bug title states the wrong behavior, because people search for the symptom: "A
  refused refund shows staff a 500". A title from an error monitor's report names the
  symptom, and not the exception class.
- An epic's name follows the same rules.

## Acceptance criteria

A Story, a Bug, and a Task each end with acceptance criteria. An Epic has none, because
no PR closes it.

- Write each criterion as a Markdown checkbox: `- [ ] ...`.
- State one behavior per criterion, which someone can observe from outside the code.
- State the behavior, not the implementation. The implementer chooses the
  implementation.
- Write a plain statement by default. Use Given / When / Then where a precondition
  matters.

The criteria live in the tracker only. The person who writes the issue often has no
access to the code host, such as GitHub, and the implementer checks the boxes against
their own work.

## INVEST check

Check each issue against the letters for its kind:

| Letter | The test |
| --- | --- |
| Independent | The issue ships without another issue in the draft. |
| Negotiable | The description states the outcome, and leaves the implementation open. |
| Valuable | The "so that" clause names a real benefit, not the goal in other words. |
| Estimable | The implementer has what they need to estimate the work. |
| Small | One PR delivers the whole issue. |
| Testable | Each acceptance criterion has a clear pass or fail. |

- A Story gets all six letters.
- A Bug or a Task gets Independent, Small, and Testable. Its Impact or Why section stands
  in for Valuable.
- An Epic gets Valuable only. Its stories get the check.

In the draft, report only the letters that still fail, or that needed a judgment call.
Give the reason for each. Where all letters pass, write "INVEST: no exceptions".

- A **blocks** relation is a known exception to Independent. Report it as known.
- Where an unknown blocks an estimate for an issue in the draft, propose a spike: a Task
  to find the answer, which blocks that issue. Its one criterion is that the answer is
  recorded on the issue.
- Where the whole deliverable is a decision, draft one Task, and make the decision its
  criterion. Draft only issues whose scope is known today. Where the decision leads to
  more work, a criterion of the Task is to file that work.

## Labels and defaults

Give each issue the labels that the tracker requires. The tracker file says which labels
those are, and how to read them from the tracker.

- Where a required label group sorts the work by its type, pick the label that fits the
  kind. For example, a feature label fits a Story, and a bug-fix label fits a Bug.
- Where a required label group names the product or the app, pick the label for the app
  that the issue changes.
- Show each pick in the draft.
- Where the user or the caller names a label that does not fit the kind, keep their label
  and flag the mismatch in the draft.
- Where a label name does not match a label in the tracker exactly, pick the closest
  match, and show it in the draft.

| Field | Issue | Epic |
| --- | --- | --- |
| Team | From the profile | From the profile |
| Status | From the profile | From the profile |
| Priority | None | None |
| Assignee or lead | Ask | Ask |
| Target date | None | None |
| Labels | As above | None |

A priority that the user states maps to the tracker's priority field. The tracker file
gives its values.

## Privacy

An issue persists, and many people read it. Describe the shape of a credential, a code,
a token, or a person's data, and write no value. For example, write "a 6-digit reset
code" and not the code.

## Cold-read review

Review the draft after you write it, and before you show it for approval. The review has
two parts, and each part runs where it can see what it checks. A **cold read** is a read
by someone who did not write the text and did not see the conversation.

**In this context**, check that every fact from the user or the caller is in the draft.
On a revise, check that every fact of the reason for the revise is in the change. Only
this context holds the conversation and the facts that the caller supplied.

**In a subagent**, run the other four checks as a cold read. Give the subagent the draft
text, the current worktree's root directory, and the four checks, and nothing from the
conversation. The subagent then reads the draft as its **implementer** does. Tell it to
return a report. Tell it to write nothing: no file, and no change in the tracker.

1. **Every fact about the code holds.**
2. **Every rule of the write-issue skill holds,** in the template for the kind from its
   table in "The kinds", and in its "Titles", "Acceptance criteria", and "Privacy" sections.
3. **The INVEST letters for the kind hold,** as the write-issue skill's "INVEST check"
   section gives them.
4. **An open read of the draft as its implementer.**

Judge each finding against the conversation and the code, because the subagent did not
see the conversation. Give each finding one verdict:

- **Wrong.** The conversation or the code disproves it. Drop it.
- **Defect.** It has one correct fix. Fix it in the draft.
- **Decision.** It belongs to the user. Ask about it when you show the draft for approval.

Run one round, with one subagent for each draft. One draft can hold several issues and an
epic, and that one subagent reviews them all. A change that the user asks for before
approval gets no second review, because the user's request is itself a review.

The draft reports the INVEST letters that remain after the fixes, as "INVEST check" says.

## Create order

1. Create the epic first, where the draft has one.
2. Create each issue. Put the issue in the epic where it belongs to one.
3. Create the first issue of a pair before the second, because the second needs the
   first issue's identifier. Put that identifier in the second issue's opening line. Set
   the relation on the second issue.
4. Put each link on the issue.

The tracker file names the tool for each step, the field for each relation, and its rules
for links.

### Where no tracker file applies

End with the draft as Markdown for the user to paste. Give one block for each item, in
create order. Above each block, list its fields: the title, the kind, the labels, the
assignee, the epic, and the relations. Where the second issue of a pair names the first,
write the placeholder `<first issue>`, because the first issue has no identifier yet.
