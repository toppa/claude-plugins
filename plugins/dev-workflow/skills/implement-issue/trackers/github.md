# GitHub Issues

Read this file where the profile says `tracker: github`. It holds what `implement-issue` does
in GitHub Issues. The facts come from the help text of the GitHub CLI, `gh` 2.102.0, checked
2026-11-26, and from GitHub's docs. A test on scratch issues in a private repository on
2026-11-26 created an epic, a sub-issue, and a blocker, and ticked a box with the steps
below.

This tracker uses the `gh` command through the shell, and not an MCP server. Run
`gh auth status --active --hostname github.com` once before the first call. For a repository
on GitHub Enterprise, pass its host to `--hostname`. Where the check fails, no connected server serves the
tracker, as "Where no tracker file applies" in `SKILL.md` says.

The issue's key is its number with a `#`, such as `#123`. Each command below runs in the
repository of the current worktree. For an issue in another repository, pass
`--repo <owner>/<name>`.

## Read the issue

1. Run `gh issue view <number> --json number,title,body,state,labels,parent,blockedBy,url`.
2. Where `parent` names an issue, read that issue the same way. The parent issue is the
   issue's epic.
3. For each issue in `blockedBy`, read its `state`. Where the entry does not carry it, run
   `gh issue view <url> --json state` for that blocker.

A blocker is open while its `state` is `OPEN`. A closed issue is not a blocker, whatever its
`stateReason`.

GitHub gives no branch name for an issue. So the branch takes the issue's number and a verb
phrase, such as `123-add-order-export`.

## Read a box

The body comes back as Markdown, as the author wrote it. Treat `- [x]` and `- [X]` as
ticked, and `- [ ]` as open.

## Tick the boxes

Tick every approved box in one save of the whole body, under an optimistic lock on
`updatedAt`. GitHub has no partial update for a body.

1. **Read the issue again**, directly before the save, with
   `gh issue view <number> --json body,updatedAt`. Build the new body from that read.
2. **Change each approved line** from `- [ ]` to `- [x]`. Change no other text. Each line
   must match exactly once. Where a line does not match once, stop, and show the user the
   line.
3. **Read `updatedAt` again.** Where it changed since step 1, go back to step 1.
4. **Save the body.** Write it to a file in the session's scratchpad directory. Run
   `gh issue edit <number> --body-file <file>`.
5. **Read the issue again**, and check that each approved box reads `- [x]`.

## Name the issue in the PR

Write a closing keyword with the issue's key in the PR description, such as "Fixes #123".
When the PR merges into the default branch, GitHub closes the issue. For an issue in another
repository, write `Fixes <owner>/<name>#123`.

- Where the PR must not close the issue, write a reference with no closing keyword, such as
  "Part of #123". GitHub then links the PR on the issue, and it closes nothing.
- A closing keyword in a PR that merges into another branch closes nothing.

## A note on the epic

Send a note on the epic through the write-issue skill's "Revise an issue or an epic" section.
That section reads the parent issue, shows the change, and saves it after the user approves
it. Do not run `gh issue edit` on the epic from this skill, because a direct call skips the
review and the approval.
