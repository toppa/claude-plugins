# Finish with a draft PR

This file ends the work at a draft PR whose checks pass, and whose description agrees with
CI. It runs at the end of a plan with no issue where the user agrees, at the close of an
issue, and where the user asks for it.

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
  PR unseen. Where the plan says `**Approvals required:** none`, skip the stop, because the
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
