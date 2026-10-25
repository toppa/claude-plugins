---
name: implement-plan
description: >-
  The workflow that runs while a plan document is implemented — one step at a
  time, each closed by checks, a review by the user where the plan asks for one,
  an update to the plan, and a commit.
when_to_use: >-
  Use when you implement a plan document, when you pick up a plan that is part
  done, and when you finish a step and need to know what closes it. For writing
  the plan in the first place, use the `dev-workflow:write-plan` skill.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here on 2026-08-15 so it travels with the
    rest of the planning and commit workflow.
  synced: 2026-08-15
---

# Implementing a plan

Work the plan one step at a time. An agent does the work of each step, and the main session
closes the step. Finish the current step's completion workflow before you start the next step.

## Before the first step

- Where the plan carries a **Move pending** block, run the move first. The write-plan
  skill defines the move in its "In plan mode" section.
- Set the plan's Status line to `in progress`.
- **Find out whether the commits include the plan**, once, before the first step. Commit the
  plan where git tracks it. Do not commit it where it is outside the repo or where git
  ignores it. Otherwise, commit it where git tracks a dated plan in the same directory. In
  every other case, ask the user whether the project commits its plans, because a private
  plan in a shared repo is hard to take back. Where the user says no, suggest an exclusion
  such as `.git/info/exclude`.

## Approval mode

The plan's `**Approvals required:**` line sets the approval mode. The value is `each step` or
`none`. A missing line means `each step`, so an omission never removes a stop.

Under `none`, the main session skips these stops for the user:

- The code review by the user, in step 2 of the "Step completion workflow".
- The approval of the commit message, in step 5.
- Every stop that the plan's text marks, such as a step that says to stop for the user.

Under `none`, the main session still stops for a real question that it cannot settle alone.
Examples are an ambiguity in the plan, a departure from the plan that the main session cannot
settle, and a problem that remains after two rounds of fixes.

Under `none`, the main session also stops for the approval of the ticks in the implement-issue
skill's "Close the issue" section. That section says why `none` does not remove this stop.

Where the user changes the mode during the run, edit the line in the plan. The mode then
survives a cleared context.

## Run each step in an agent

Each step runs in an agent with a fresh context. The main session then holds each agent's
report, and not all the work of every step, so its own context stays small. The main
session closes each step, because the close holds the stops for the user. An agent cannot
ask the user a question, and the user sees only its report.

1. **Start the agent that the step names.** The `**Agent:**` or `**Agents:**` line under the
   step's heading names it. Use that name, and do not choose again. Where the user asks for
   a step to run in the main session, do that step's work there, and skip the brief.
2. **Write the brief.** Give the agent these items:
   - The plan's path and the step's number. The agent reads the whole plan. Without the
     Context, an agent can bring back an alternative that the plan rejected.
   - The rule that the plan file is read-only for the agent.
   - The rule that the agent does not commit.
   - The brief rules from the project's CLAUDE.md, where it has some.
   - In a step with several agents, the report of the agent before.
   - The report that the agent returns, in the form below.
3. **Run several agents in order.** Where the line names several agents, start them in the
   order it gives. Each agent's brief carries the report of the agent before it. The step
   closes once, after the last agent. The last agent proves the outcome of the whole step.

The agent's report carries four items:

1. The files that it changed.
2. Each departure from the plan, with the reason.
3. What it measured to prove the outcome.
4. Each open question.

## Step completion workflow

The main session runs this after the step's last agent returns, for every step that produces
code to commit.

1. **Run the checks.** Run the tests and the linters over the changed files. The project's
   CLAUDE.md names the commands.
2. **Ask for a review.** Where the project's CLAUDE.md routes a change to a reviewer, send
   the changed files there first, and act on the report before you ask the user. Where
   CLAUDE.md routes none, skip that. Ask the user to review the code. Name where the code
   departed from the plan. Wait for them to confirm that the review is finished and the code
   is approved. Until they confirm, leave the plan unchanged and draft no commit message.
   Under `none`, skip the review by the user. Go on to step 3 after the checks pass and you
   act on any report from the reviewer.

   The main session makes a fix that adds little to its context, such as a fix whose exact
   text a review wrote, or a change of a few lines of prose. A new agent of the kind that
   wrote the file makes a larger fix, with a brief, because the main session's context must
   stay small for the rest of the run. Do not send a fix back to the agent that wrote the
   file, because its context is large by the time the fix comes.

   Run the checks again after each fix. Then send the change to the review. A step that ran in
   the main session at the user's request is the exception, and the main session makes its
   fixes. Where the problem remains after two rounds of fixes, stop and ask the user. **Two is
   a house heuristic with no external source.**
3. **Update the plan document.** Mark the step ✅. Where the implementation departed from
   the plan, edit the step to match what you built. Edit every later step the departure
   changes. The plan holds no historical record.
4. **Update the standing documents.** Where the step settled a term, a rule, or a
   decision, edit the document that owns it — the glossary, the rules file, an ADR. The
   write-plan skill's "Standing documents outrank the plan" section names them. The
   closing pass below is the backstop, and not the first opportunity.
5. **Commit.** Draft the message with the commit-messages skill, which also covers the
   approval the message needs before `git commit` runs. Under `none`, run `git commit`
   without that approval. On this one rule, this skill overrides the commit-messages skill.
   Include every standing document this step changed in the commit. Include the plan where
   "Before the first step" found that the commits include it.

## After the final step

- Read the project's CLAUDE.md and README.md, and every standing document CLAUDE.md names.
  Update whatever this work made stale.
- **Find what cites the plan, before you trim it.** A plan is where the reasoning gets written
  while the work runs, so other documents end up pointing at it for detail none of them copied.
  Send that detail to a document that owns it, then repoint each pointer. Search two ways: for
  the plan's path, and for the words the project uses to name a plan in prose. A pointer that
  reads "the known gap from the plan" carries no path, and a search for the filename will not
  find it.
- Keep the plan file. Trim it to its Context and a short record per step. The Context is
  the handoff to the plan that follows it, and it is what earns the file its keep.
- **Run the checks for drift that the project's CLAUDE.md names.** Fix each finding that is
  drift. Route the fix of each finding as step 2 of the "Step completion workflow" says. Ask
  the user about each finding that is not clearly drift. Where CLAUDE.md names no check, skip
  this bullet.

  Under `none`, fix each finding that is clearly drift. Name every other finding in the final
  report. Do not record an exemption, such as an entry in a check's list of exceptions,
  because an exemption hides the finding from every later run.
- **Close the issue, where the plan carries an `**Issue:**` line.** Load the implement-issue
  skill. Run its "Close the issue" section for the issue that the line names. The close stops
  for one approval of its ticks, and this stop holds under `none` too.
- Set the plan's Status line to `done`. Under `none`, a finding in the final report does not
  hold it back.
- **Under `none`, end with a report to the user.** The report names three things:
  1. Each stop that the plan's text marks, and that the run skipped.
  2. What the user can still review. Each commit of the run is open to review, because no
     step stopped for a code review.
  3. Each finding from a check for drift that the run did not fix.
