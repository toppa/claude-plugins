# 0022 — A stop is a review, publish, or blocking stop, and the approval mode names where the user approves

## Context

The `dev-workflow` plan skills had three approval modes: `each step`, `none`, and
`unattended`. A plan set the mode in its `**Approvals required:**` line. A new user could not
tell from the names what `none` and `unattended` do, or how the two modes differ.

The skills listed each stop alone, and each mode repeated that list with exceptions. A plan
marked a stop in free prose. So a session spent effort to decide which stops a mode removed, and
it had to guess whether a stop in the plan was a routine approval or a decision that the work
needed.

The `none` mode also had a defect. It skipped every stop that the plan's text marked. So a plan
that said "stop after the data analysis, so the user can pick an option" lost that stop under
`none`. The user wants the opposite from that mode: it keeps each stop where the user must
decide.

## Decision

**1. A stop is one of three kinds.** A stop is a point where the run waits for the user. The
`dev-workflow:implement-plan` skill defines the kinds in its "Approval mode" section, and every
other file uses their names:

- **Review stop.** The user checks work that stays on the user's machine. Examples are the code
  review, the commit message, the fold of fixes before the push, and a stop in the plan that
  only asks the user to look.
- **Publish stop.** The user approves a write that other people see. Examples are the ticks on
  the issue, the note on the epic, the push, and the PR. A plan adds no publish stop, because
  the skills own each one.
- **Blocking stop.** The run cannot go on without the user. Examples are a decision that the
  plan marks, a real question that the run cannot settle alone, a problem that remains after
  two rounds of fixes, a permission block, and the first-run questions.

A stop that is both a blocking stop and a publish stop is a blocking stop. An example is the
revise draft for an unready issue: the work cannot start, and the revise is a write that others
see. A drift finding that is not clearly drift is a review stop, because the run can finish
without the answer and name the finding in the final report. The approval of the plan in the
`dev-workflow:write-plan` skill comes before the run, so it is not one of these kinds.

**2. Each mode acts on each kind as this table shows.**

| Kind | `each step` | `before push` | `draft PR` |
|---|---|---|---|
| Review stop | stop | skip | skip |
| Publish stop | ask during the run | ask during the run | make the draft PR, then put the rest into the one final question |
| Blocking stop | stop | stop | stop |

No mode skips a blocking stop. This fixes the defect in the `none` mode.

**3. The plan marks each stop with a label,** as a line under the step, in one of two forms:

- `**Review stop:** <what the user looks at>`
- `**Blocking stop:** <what the user decides, and what the run must have before the question>`

A stop in a plan is any text in a step that tells the run to wait for the user. A stop with no
label is a blocking stop, so an omission never removes a stop. A missing mode line already
follows the same rule: it means `each step`.

**4. The axis keeps the name "approval mode",** and the plan line is `**Approval mode:**`.
Each value names the point where the user approves:

- `each step` keeps its name and its meaning.
- `none` becomes `before push`. The user approves before anything leaves the machine.
- `unattended` becomes `draft PR`. The user approves after the draft PR exists.

**5. One mode has one name everywhere.** The `dev-workflow:implement-issue` argument is
`draft-pr`, as in `/dev-workflow:implement-issue ENG-123 draft-pr`. Prose says "the `draft PR`
mode", always with the backticks, so that a reader does not read the mode as "a draft PR". The
reference file for the mode is
`plugins/dev-workflow/skills/implement-plan/references/draft-pr-mode.md`, and each section named
for the mode takes the new name.

**6. Where a plan has a blocking stop, the approval request names each one** beside the
question about the mode: "This plan has a blocking stop at step N, so a `draft PR` run stops
there." The user can then pick `before push`. The warning comes before the pick, because an
approval with `draft PR` starts the run at once. The `dev-workflow:write-plan` skill holds this
rule in its "Approval, then stop" section.

**7. The skills do not read the old names.** They do not read `Approvals required:`, `none`, or
`unattended`. The user edits the mode line of an existing plan by hand. This change gives
`dev-workflow` the version 0.18.0, because a plan with an old mode line needs that edit.

ADR [0011](0011-a-subagent-implements-each-plan-step-and-the-main-session-closes-it.md) says "approval mode", and that name stays, so ADR 0011 needs no change.

## The alternatives that lost

**Two kinds of stop, routine and essential.** The ticks on the issue then count as routine. But
the `none` mode kept the approval of the ticks, because teammates see a tick at once. So the
ticks stay an exception that each mode states again.

**A stop in free prose, with a definition to classify it against.** The session still has to
judge each stop. A label turns the judgment into a lookup.

**A stop with no label counts as a review stop.** A decision that the plan forgot to label then
gets skipped under `before push` and `draft PR`. That is the defect in the `none` mode again.

**For a plan with a blocking stop, refuse `draft PR`.** Refusal fails for the
`dev-workflow:implement-issue` skill, because that skill writes its own plan in the `draft PR`
mode.

**For a plan with a blocking stop, let the run pick an option and defer the question.** A pick
after a data analysis can change every later step. So a wrong pick costs a large rework.

**The axis named "implementation mode".** The name says what the mode applies to, and not the
thing that changes between the modes. The new values name the approval point, so "approval
mode" fits again.

**"Supervision", with the values `full`, `partial`, and `none`.** "Supervision: none" is false,
because a blocking stop holds in every mode. `partial` does not say which part. The last two
modes differ in where the run ends, and not in an amount of supervision.

**`attended`, `on call`, and `unattended`.** The `draft PR` mode also calls the user for a
blocking stop. So the names `on call` and `unattended` do not tell the two modes apart.

**`final commits` for the middle mode.** No stop asks the user to approve the commits. So the
name claims an approval that the mode does not have.

**Keep `unattended` as the `dev-workflow:implement-issue` argument.** One mode then has two
names.
