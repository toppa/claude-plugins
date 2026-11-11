# Finish with a draft PR

This file ends the work at a draft PR whose checks pass, and whose description agrees with
CI. It runs at the end of a plan with no issue where the user agrees, at the close of an
issue, and where the user asks for it. In the unattended mode, it runs after the final step
with no offer first, and "In the unattended mode" below adds its rules.

- **A draft PR, written with the pr-descriptions skill.** Where an issue's close runs this
  file, the close gives the line that names the issue.
- **Every check finished and passed.** A local pass does not prove a CI pass, because the CI
  environment can differ. Directly after a push, CI can list no checks yet, and an empty list
  is not a pass. Where no check registers within 5 minutes, report that the PR has no CI. Each
  wait has a ceiling of 30 minutes, unless the project's CLAUDE.md or CLAUDE.local.md sets
  another value. Rerun a job that is still pending at the ceiling once, and then report it.
  **5 minutes and 30 minutes are house heuristics with no external source.**
- **No code change for a failure that the diff did not cause,** such as a check that also
  fails on the base branch, or a job that touches no changed code. Rerun it once, because a
  flaky test can cause it. Then report it with the evidence. Where you cannot tell, treat the
  failure as the diff's, because the other guess can leave a defect in the PR.
- **Each fix folded into the commit that it belongs to, and seen by the user before the
  push.** A `fixup!` commit has no message to approve, so without this stop a fix reaches the
  PR unseen. Where the approval mode is `none` or `unattended`, skip the stop, because the
  user chose there not to review code. Where the session's permissions block the force-push,
  stop, and give the user the force-push command to run with `!`. Do not push the `fixup!`
  commits instead, because a squash before the merge then costs a second force-push, and a
  CI check can fail on a `fixup!` commit. Where a failure remains after two rounds of fixes,
  stop and ask the user. **Two is a house heuristic with no external source.**
- **A description that agrees with CI.** You wrote it before CI ran, so correct each claim
  that CI disproves, such as a count of passing examples.
- **A report** of the PR's URL, the state of each check, and each item that a bullet above
  says to report. Where an issue's close runs this file, the close's "Report" step holds
  these items, so that the user gets one report.

## In the unattended mode

[unattended-mode.md](unattended-mode.md) defines the mode, the decision list, and the report
file.

- **A cold review of the PR, in a subagent that starts when the PR opens,** in parallel with
  the CI wait. The subagent reads [the pr-review skill](../../pr-review/SKILL.md) and
  follows it on the PR's URL. It reads the skill by path because only the user can invoke the
  skill, and the pr-review-queue skill reads it the same way. The brief changes four defaults
  of the skill:
  - The run's worktree is the review directory, and it sits on the PR head. Review it in
    place: build no worktree, and move no branch.
  - The PR is the run's own work, so the scope is the whole diff, with no question.
  - Post nothing, and return the report.
  - The subagent cannot ask the user, so a question that the skill stops for goes into the
    report.
- **No commit until the review returns,** so that the worktree stays on the PR head while
  the subagent reads it. Where CI fails before then, diagnose the failure, and hold its fix.
- **One verdict for each finding.** A Wrong finding goes into the decision list with its
  reason. A Defect gets its fix. A Decision goes into the final report with its options and a
  recommendation. Ignore the report's advice to a reviewer of another person's PR, such
  as a verdict to approve.
- **One push for the review fixes and the held CI fixes.** That push is the first round of
  fixes. Wait for CI on its head, because that head is the one the user reviews. The fix loop
  above then runs as usual. The cold review runs one round only.
- **The report above is the final report.** It also holds the decision list, and each review
  Decision as a question. Copy it into the report file, because the user can review in a later
  session. Where an issue's close runs this file, the close adds its own items to this report.
