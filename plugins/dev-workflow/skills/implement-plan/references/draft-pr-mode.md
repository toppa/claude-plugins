# The `draft PR` mode

The `draft PR` mode runs the work to a draft PR whose checks pass, and the user reviews the
work once, at the end. A plan's `**Approval mode:** draft PR` line sets the mode, and so
does the argument `draft-pr` to the implement-issue skill. This file holds the rules that a
plan run and an issue run share in the mode.

- **Each removed stop makes its own decision, and the decision list records it.** In a plan
  run, the table in the implement-plan skill's "Approval mode" section says which kinds of
  stop the mode removes. Each other rule for `before push` in that skill holds here too,
  except where a rule names `draft PR`. For an issue with no plan, the implement-issue skill's
  "The `draft PR` mode" section names the stops that the mode removes.
- **A stop only where the user must act.** These are the blocking stops, which the
  implement-plan skill's "Approval mode" section defines. The definition does not hold these
  details:
  - The question whether the project commits its plans, in the implement-plan skill's "Before
    the first step" section, comes once for each project.
  - A permission block counts only where the run cannot work around it. The stop gives the
    command for the user to run with `!`.
- **Work that the session's permissions let through.** Run each test the way the project's
  instructions say, so that no process stays behind, such as with an environment variable
  that turns off a preloader. Where a leftover process still blocks a test, stop as for a
  permission block, and name the process. Report through the final report, and post no
  comment. Push only as [finish-with-a-draft-pr.md](finish-with-a-draft-pr.md) says.
- **A new git worktree for the work,** made before the first edit to the repository, because
  sessions that share a checkout can switch its branch under each other. Where the commits
  include the plan and it is not committed yet, move it into the worktree at the same path
  before the first step. Set it up as the project's CLAUDE.md and CLAUDE.local.md say. Where
  they say nothing about worktrees, set up what the checks need when the need appears. Record
  each setup step in the decision list, so that the user can add it to the project's
  instructions. For a plan with no issue, name the branch after the verb phrase in the plan's
  file name. For an issue, the implement-issue skill's "The `draft PR` mode" section names the
  branch.
- **A decision list in the run's report file, written from the first decision on.** A run
  that starts again after a cleared context reads the list back from the file. The file's name
  is the issue's key, or else the plan's file name without `.md`, followed by
  `-run-report.md`. A restarted run finds the file from the plan's Issue line or its file name,
  so no line in the plan names it. Put it in the main worktree's `tmp/` where git ignores that
  directory, or else in `~/tmp/`. Each entry names the decision, the stop or the finding that
  it replaced, and the reason.
