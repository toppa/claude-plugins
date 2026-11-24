---
name: worktrees
description: >-
  A git worktree beside the repository — its base, the setup that lets the
  project's checks run in it, the commands that run in it, and its removal
  after the merge.
when_to_use: >-
  Use when you start work in a new worktree, when another skill asks for one,
  when a check in a worktree fails because a file is missing, and when the user
  asks to clean up a worktree.
metadata:
  upstream_repo: none
  origin: >-
    Written here on 2026-11-23, from the setup and cleanup mistakes of several
    sessions that worked in worktrees of private Rails applications.
  synced: 2026-11-23
  verified_against: git 2.50.1, Claude Code 2.1.331
---

# Worktrees

A worktree gives the work its own checkout. Sessions that share one checkout can switch its
branch under each other. A check then runs against code that nobody meant to test.

## Create the worktree

- **Beside the repository**, at `../<repo>-<verb-phrase>`, made with `git worktree add`. A
  worktree inside the repository shows in `git status` and in each search of the repository.
  An IDE also shows it as new files with no diff. The `EnterWorktree` tool puts each new
  worktree inside the repository, so make the worktree with git.
- **On a fresh base.** Fetch the remote that the pull request merges into: `origin` in most
  clones, and `upstream` in a fork. Then branch from `<remote>/<default branch>`, because the
  pull request merges into the remote branch. The local default branch can fall behind the
  remote, and another session can switch it. Add `--no-track`, because otherwise the new
  branch takes the default branch as its upstream. The first push with `-u` sets the
  upstream. Work that continues an existing branch checks out that branch, with no new base.

## Make the worktree ready

The worktree is ready when a check that loads the application runs to its result. A new
worktree has none of the files that git ignores. So it has no installed dependencies, no
keys, and no local configuration.

- **The project's instructions come first.** Follow what the project's `CLAUDE.md` or
  `CLAUDE.local.md` says about worktrees, and also a file in a parent directory. These
  instructions can name one setup command that does the whole job.
- **Where the instructions say nothing,** do the setup in this order:
  1. Install each dependency that the project installs per checkout, such as `node_modules`,
     before the first check. A missing dependency can fail quietly: a test that expects text
     to be absent passes against an error page.
  2. Run the checks. Copy each ignored file that a failure names from the main checkout. Copy
     a missing key or secret too. Do not generate a new one where the error suggests it,
     because a new key cannot decrypt the existing data.
  3. Where the source of a missing file is not clear, ask the user.
- **Suggest that the user save the setup steps** in the project's instructions. The next
  session then skips the trial and error. Give the text. The user decides whether to save it,
  and where. In the `draft PR` mode of the `dev-workflow:implement-plan` skill, the
  suggestion goes into the decision list.

## Work in the worktree

- **Start each command for the worktree with `cd <worktree> &&`,** or use the form that the
  project's instructions give for that command. The session stays in the main checkout. After
  a `cd` outside the project, the Bash tool resets its working directory to the main
  checkout. So a command without the `cd` runs in the main checkout, on another branch.
- **Keep each command in the exact form that a permission rule allows.** A rule matches the
  text of the command. Run a command such as a force-push from the main checkout where its
  allow rule has no `cd`. The worktree and the main checkout share their branches, so the
  push sends the worktree's commits.

## Remove the worktree

Remove a worktree when the user asks, or after its pull request merges. A worktree that stays
costs disk space only. A worktree removed too soon loses work.

1. **Confirm the merge, and that the merge holds the branch.**
   `gh pr view <branch> --json state,headRefOid` gives the state and the head that merged.
   `git rev-parse <branch>` gives the local head. Where the two heads differ, the branch
   holds commits that the merge did not include, so report them to the user, and stop. Where
   no pull request exists, ask the user.
2. **Stop each process that runs from the worktree,** such as a preloader or a development
   server.
3. **Run `git worktree remove <path>` alone in its command, without `--force`.** Git refuses
   to remove a worktree that holds uncommitted changes or untracked files. That refusal
   protects the work, so report what remains to the user, and stop. Ignored files, such as
   `node_modules`, do not block the removal. Keep the command alone, because an auto-mode
   classifier can block a removal that is chained with another command.
4. **Delete the local branch with `git branch -D`.** After a squash merge, `git branch -d` can
   refuse merged work. Step 1 is the evidence that `-D` loses nothing, because it showed that
   the merged pull request holds each commit of the branch.
5. **Delete the remote branch only where it remains.** `git ls-remote --heads origin <branch>`
   shows it. A host can delete it at the merge.

Report the other worktrees whose pull requests merged. Remove them only when the user asks.
