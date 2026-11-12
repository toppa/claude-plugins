---
name: implement-issue
description: >-
  Implement an issue from the team's tracker: check that it is ready, plan the
  work where it needs a plan, and close it with each acceptance criterion
  proven and ticked.
when_to_use: >-
  Use when you start work on an issue in a tracker such as Linear, Jira, or
  GitHub Issues, and when a plan that names an issue reaches its close. To
  draft or revise an issue, use the `dev-workflow:write-issue` skill.
argument-hint: "[issue key] [unattended]"
metadata:
  upstream_repo: none
  origin: >-
    A house convention, written here on 2026-10-21 as the pair of the
    write-issue skill, so that the implementer of an issue ticks each
    acceptance criterion that the work proves.
  synced: 2026-10-21
---

# Implement an issue

The skill takes one issue from the tracker, through the work, to its close. The close proves
each acceptance criterion, ticks each proven box, and names the issue in the PR. Where the
argument `unattended` follows the issue's key, also follow "Unattended mode".

The write-issue skill defines the **tracker**, the **epic**, and the **profile**. This skill
reads the profile. It writes a profile only through the write-issue skill's "The first run"
section.

## Workflow

1. **Find the profile.** Match it as the write-issue skill's "The profile file" section says.
   Where no profile matches, run that skill's "The first run" section with write-issue's own
   tracker file, because that file lists the profile keys and their questions. For the rest
   of the run, look for the tracker file in this skill, and not in write-issue, because each
   skill's tracker file holds only what that skill does. Its path is `trackers/<tracker>.md`,
   such as `trackers/linear.md` for Linear. Find each tool as the write-issue skill's "The
   tracker's tools" section says.
2. **Read the issue, its epic, and its relations.** The tracker file names the calls. Read
   these items:
   - The issue's description, with its acceptance criteria.
   - The epic's description, where the issue belongs to an epic.
   - The status of each issue that blocks this issue.

   Where an open issue blocks this issue, stop. Name the blocker to the user, and ask
   whether to wait for it or to start now.
3. **Read the standing documents.** Read the project's CLAUDE.md, and each standing document
   that it names. The write-plan skill's "Standing documents outrank the plan" section says
   what makes a document standing. Do the work against the terms and the rules that these
   documents hold.
4. **Check that the issue is ready.** Run the write-issue skill's "Cold-read review" section
   on the issue as it is. The issue's current text takes the place of the draft. The check in
   this context tests that each fact that the user gave about the work is in the issue. Give
   each finding its verdict, as that section says.

   The issue is unready only where a Defect or a Decision blocks the work. Four kinds of
   finding block the work:
   - A fact about the code that fails, where a criterion, the scope, or the fix depends on it.
   - A criterion with no clear pass or fail, which fails the INVEST letter Testable.
   - An item that fails the INVEST letter Small.
   - A question from the open read that would make the implementer stop and ask.

   Apply these rules to the findings:
   - A finding about form only does not make the issue unready. Form is the template's
     sections, the title, and the wording of a criterion whose pass or fail is clear. The
     author of the issue agreed to that text.
     List each such finding to the user, and propose no revise for it alone.
   - A fact about the code that fails, where no criterion, scope, or fix depends on it, does
     not make the issue unready. It still misleads the next reader of the issue. So propose a
     revise that corrects it, with the finding as the reason, as for an unready issue. Where
     the issue is also unready, add the finding to the reason of that revise instead. Carry
     on with the work while the user decides.
   - A missing implementation design does not make an issue unready, because the INVEST
     letter Negotiable leaves the implementation open. Give such a finding the verdict Wrong.
   - Where the issue is unready, propose a refinement. Run the write-issue skill's "Revise an
     issue or an epic" section. Pass the findings that block the work as the reason for the
     revise. That section then skips its own subagent, because this review already read the
     item's current text.
   - Where the user declines the revise, carry on with the issue as it is.
5. **Decide whether the work needs a plan.** The work needs a plan where it takes several
   commits. It also needs one where it holds a design decision that a reviewer should see
   first.
   - Where the work needs a plan, write the plan with the write-plan skill. Give the plan the
     `**Issue:**` line from the write-plan skill's "File structure" section. The plan then
     runs the work in place of step 6. Run "Close the issue" after the plan's final step.
   - Otherwise, go to step 6.
6. **Do the work.** Split it into commits with the organize-commits skill. Write each commit
   message with the commit-messages skill. Where a criterion turns out wrong, follow "A wrong
   criterion".
7. **Close the issue.** Follow "Close the issue".

## A wrong criterion

Propose the change to a wrong criterion to the user. Name the criterion, what is wrong with
it, and the new text. Where the user agrees, run the write-issue skill's "Revise an issue or
an epic" section, with the proposal as the reason for the revise. Do not change a criterion
silently, because the author of the issue agreed to its text. A wrong criterion that the user
keeps stays open at the close, with its reason.

## Close the issue

The close starts after the last commit of the work. Its ticks come before the PR opens, so
each tick rests on the code that the PR opens with. A tick after the merge needs a session
that is still open after the merge, and usually none is. The unattended mode moves the ticks
after the PR, as "Unattended mode" says.

1. **Prove each criterion.** Give each acceptance criterion its proof, or an open item with its
   reason. A **proof** is evidence that someone can check again, such as a spec that passes, a
   command with its output, or a behavior seen in the running app. Run each proof against the
   code that the PR opens with.
   - A box that the issue already shows ticked gets a proof too. Where its proof fails, list
     it as an open item, and leave the box as it is.
2. **Ask for one approval of the ticks.** Show each criterion with its proof or its open
   item. Ask the user to approve the whole batch of ticks in one answer. Where an open item
   remains, ask in the same message whether the PR closes the issue. A PR that closes the
   issue closes it at the merge, with the open box still open. A box that the user takes out
   of the batch stays open.

   This approval applies in every approval mode of a plan, `none` included. A plan's `none`
   removes the stops for work that stays on the user's machine. A tick is a write that
   teammates see at once. The unattended mode keeps this approval, and moves it into the
   final report.
3. **Tick the approved boxes, in one write.** Follow the tracker file.
4. **Open the PR, and name the issue in it.** Read
   `${CLAUDE_PLUGIN_ROOT}/skills/implement-plan/references/finish-with-a-draft-pr.md` and
   follow it, with the line that names the issue. The pr-descriptions skill's
   "A PR that implements an issue" passage ends the description with that line, which names
   the issue's key. Give that line the closing form that the tracker file gives, such as
   "Fixes ENG-123". Where the user does not want the PR to close the issue, use the tracker
   file's form that links only.
   - The PR description does not copy the criteria, because two copies drift. The one
     exception is the unattended mode's "Acceptance criteria as I read them", which stays only
     until the criteria move into the issue.
   - Where a CI fix changes the code that a proof ran against, run that proof again. Where the
     proof now fails, name its box to the user, and propose to untick it. A tick is a write
     that teammates see, so the user decides.
5. **Propose a note on the epic.** Propose a note where the work deferred something. Also
   propose one where the work settled a constraint that a later issue must respect. Run the
   write-issue skill's "Revise an issue or an epic" section on the epic, with the note as the
   reason for the revise. Where the issue belongs to no epic, put the note in the report.
6. **Report** each ticked box, each open item with its reason, and the PR's URL. Also report
   the note on the epic, where one was saved. Add the items that
   `finish-with-a-draft-pr.md` reports. Tell the user that a review change to the
   behavior of a ticked criterion needs that criterion's proof to run again.

Leave the issue's status to the tracker's integration with the code host. Set no status from
this skill. The tracker file says what moves the status.

## Unattended mode

The argument `unattended` after the issue's key, as in
`/dev-workflow:implement-issue ENG-123 unattended`, runs the issue to a draft PR whose checks
pass. The user reviews the work once, at the end. Before step 1 of "Workflow", read
`${CLAUDE_PLUGIN_ROOT}/skills/implement-plan/references/unattended-mode.md` and follow it. That
file holds the rules that this mode shares with a plan: the stops that stay, the worktree, and
the decision list. This section adds the rules that are about the issue.

**These stops stay, beside the shared ones,** because each one needs the user:

- The first run, at step 1 of "Workflow", which asks its setup questions once.
- An open blocker, at step 2.
- An unready issue, at step 4. Show the revise draft with the stop, so that one approval
  answers it.
- A Decision that the plan review leaves.
- The paste of the issue at step 2, where no tracker file applies.

**Each other stop makes its own decision:**

- A finding about form only, at step 4, goes into the decision list.
- A fact about the code that fails, where nothing depends on it, at step 4: its revise goes
  into the final question, unless the stop for an unready issue carries it.
- Criteria that are clear but are not boxes do not stop the run. Leave the issue as it is.
  Write your reading of the criteria into the PR description, under "Acceptance criteria as I
  read them". Do not revise the issue first, because the readiness check would then judge
  criteria that the run wrote, and the author of the issue never agreed to them.
- At step 6, commit without the approval of the message. On this one rule, this skill
  overrides the commit-messages skill. A split that you would propose goes into the decision
  list.
- A wrong criterion stays an open item with its reason, and its proposed text goes into the
  final report.
- The note on the epic goes into the final report.

**The plan** that step 5 writes carries `**Approvals required:** unattended`.

**The branch** takes the name that the tracker file gives for the issue, where it gives one.
Otherwise it takes the issue's key and a verb phrase.

**The close** runs these steps in place of "Close the issue". The ticks come after the PR
opens, because the user's review of the draft is the one point where a person checks the
work.

1. Prove each criterion, as step 1 of "Close the issue" says.
2. Read `${CLAUDE_PLUGIN_ROOT}/skills/implement-plan/references/finish-with-a-draft-pr.md` and
   follow it. Name the issue with the closing form where every criterion has a proof. Use the
   form that links only where an open item remains. Where a fix changes the code that a proof
   ran against, run the proof again. A failed proof becomes an open item.
3. Add the issue's items to the final report: each criterion with its proof or its open item,
   and one question. The question lists each write that waits for the user, with its exact
   text, and asks for one approval of the batch:
   - The ticks.
   - The criteria to save into the issue as ticked boxes, where the issue held them as prose.
   - Each proposed change to a wrong criterion.
   - Each revise from step 4 that corrects a fact about the code.
   - The note on the epic.
   - Whether the PR closes the issue, where an open item remains.

   The user can take an item out of the batch. Where a review Decision is open, the writes
   wait for its answer as well.
4. After the approval, make each approved write. Tick the approved boxes in one write, as the
   tracker file says. Save each approved text through the write-issue skill's "Save a revise"
   section, with no review and no approval of its own, because the user approved the exact
   text in the report. Where the criteria moved into the issue, delete "Acceptance criteria as
   I read them" from the PR description. Where the user says that the PR closes the issue,
   change its line to the closing form.

**Where no tracker file applies,** the close differs from that section at three points:

- The PR opens with no closing line.
- The question of the closing word joins the final question, and the list of results to copy
  goes into the final report.
- After the answer, add the closing line to the PR description, where the issue has a key.

## Where no tracker file applies

No tracker file applies in three cases:

- The profile says `tracker: none`.
- The profile names a tracker with no tracker file in this skill. Tell the user so.
- No connected server serves the tracker.

The run then changes at three points:

1. **At step 2 of "Workflow"**, ask the user to paste the issue's text. Also ask for the
   epic's text, where the issue belongs to an epic. Ask whether an open issue blocks it.
2. **Each revise** ends with Markdown for the user to paste, as the write-issue skill's "Save
   a revise" section says.
3. **The close writes nothing to a tracker.** It skips steps 2 and 3 of "Close the issue",
   because no tick reaches a tracker. At step 4, the PR names the issue only where the issue
   has a key. Then ask the user which closing word their tracker reads, because this skill
   knows none for it. The close ends with a list of results for the user to copy:
   - Each criterion as `- [x]`, where it has a proof.
   - Each other criterion as `- [ ]`, with its reason.
   - The line for the PR that names the issue, where the issue has a key.
