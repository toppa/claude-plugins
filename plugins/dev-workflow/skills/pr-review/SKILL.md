---
name: pr-review
description: Review one pull request from its URL and produce a triaged report.
disable-model-invocation: true
allowed-tools:
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
  - Bash(gh api:*)
  - Bash(git:*)
  - Bash(test:*)
  - Read
  - Grep
  - Glob
  - WebFetch
  - AskUserQuestion
metadata:
  upstream_repo: none
  origin: >-
    Written in a personal skills directory, and moved here on 2026-10-25. It
    began as a copy of the review skill in another plugin, and a rewrite kept
    almost nothing of that copy.
  synced: 2026-10-25
---

# Review one PR

Input is exactly one PR URL. Without one, ask for it before anything else.

The report is the deliverable. Post to the PR only on the user's request: a comment, a reply, a review, or an approval. Post exactly what the request names, on the PR it names. Each PR needs its own request, because an approval of one PR says nothing about the next. The user decides when to post, so a report or a draft ends without an offer to post. Asked to draft a comment, print it in chat.

## Step 1 — Put the review on the PR head

Parse `<owner>`, `<repo>`, and `<num>` from the URL.

The review reads whole files, so it needs a local clone. There is no diff-only fallback — see [Citations](#citations).

**Gather the PR first.** The checks below need its head.

```bash
gh pr view <url> --json title,body,author,url,headRefName,headRefOid,isCrossRepository,additions,deletions,changedFiles,files,commits,comments,reviews
gh pr diff <url>
gh api repos/<owner>/<repo>/pulls/<num>/comments --paginate
```

The third call returns the inline review comments, which `comments` and `reviews` leave
out. Step 5 compares each finding with them.

**Find the clone.** A directory qualifies when one of its remotes points at `<owner>/<repo>`, which `git -C <dir> remote -v` reports. Match on the remote and never on the directory name: a checkout need not carry the repository's name, and a fork's `origin` points elsewhere. Work down this list, and stop at the first directory that qualifies.

1. The repository holding the working directory, which `git rev-parse --show-toplevel` names.
2. A sibling of it, at `<repo>` under that repository's parent directory.
3. A project root named in the user's `CLAUDE.md` or `AGENTS.md`, where one names it.
4. Nothing qualified. Stop, and ask the user where the clone is.

Call the result `<clone>`, its parent directory `<parent>`, and the remote that matched `<remote>`.

**Find `<review-dir>`, or build it.** The review reads one directory, called
`<review-dir>`. You **find** it where a directory already sits on the PR head, and you
**build** it as a worktree otherwise. Step 8 tears down a built one and leaves a found
one alone, so carry the word through.

`git -C <clone> worktree list` names every directory `<clone>` has, itself included. A
candidate is one whose branch is `headRefName`. You have **found** `<review-dir>` when
`git -C <candidate> rev-parse HEAD` equals `headRefOid`.

Compare against `headRefOid` and never against `<remote>/<branch>`. That ref is local,
and it moves only on a fetch, so a stale one reports agreement with code that moved on.

**Build** instead where any of these holds:

1. `isCrossRepository` is true. A fork's head branch is often `main` or `patch-1`, and a
   local branch of that name is a different branch.
2. No candidate sits on `headRefName`.
3. `git -C <candidate> status --porcelain --untracked-files=no` returns a line. The
   review would read the user's edits and not the PR. Step 5 reads outside the diff, so
   a dirty caller breaks a steelman as surely as a dirty hunk does.
4. The candidate is ahead of the PR head, or diverged from it.
5. The candidate is behind the PR head, and the user declines the fast-forward.

Check them in that order, and stop at the first that holds. A found `<review-dir>`
settles conditions 4 and 5 already, because a HEAD equal to `headRefOid` is neither
ahead of it nor behind it. So a found one reaches no fetch at all.

The first three need no network, and a dirty candidate is out before any sync is
considered. Conditions 4 and 5 need the PR head locally, so fetch it and measure the
gap:

```bash
git -C <candidate> fetch <remote> refs/pull/<num>/head
git -C <candidate> rev-list --left-right --count HEAD...FETCH_HEAD
```

The counts read `<ahead> <behind>`. Report them, because a diverged candidate usually
means the author force-pushed. Offer `git -C <candidate> merge --ff-only FETCH_HEAD`
where the candidate is behind only. Do not offer a sync for an ahead or a diverged
candidate, because only `git reset --hard` closes that gap, and it destroys the user's
commits.

`FETCH_HEAD` holds no ref, so this path creates nothing that Step 8 has to remove.

**Build the worktree beside the clone.** `<parent>` keeps the worktree on
the clone's filesystem, so the two share an object store. Beside, and not inside: a
worktree in the clone's working tree lands in `git status`, in every grep this review
runs, and in what `git clean -fdx` deletes. `.pr-reviews/` goes into `<parent>`, which
this skill does not own, so name that directory to the user the first time you create
it.

Fetch `<remote>` by name rather than `origin`. `refs/pull/<num>/head` lives on the base
repository, and a contributor's `origin` may be their fork.

```bash
git -C <clone> fetch <remote> +refs/pull/<num>/head:refs/pr-review/<num>
git -C <clone> worktree add --detach <parent>/.pr-reviews/<repo>-pr-<num> refs/pr-review/<num>
```

The fetch is idempotent. A retry reuses the worktree directory when it already exists. In that case, replace the second command with this one, which moves the worktree onto the fetched ref:

```bash
git -C <parent>/.pr-reviews/<repo>-pr-<num> checkout --detach refs/pr-review/<num>
```

A worktree does not follow a moved ref. So a reused one holds the head from the earlier run, while `gh pr diff` reports the current head. The checkout exits 1 when the worktree carries a local edit. Stop there and tell the user: a review worktree holds no work of ours, so an edit in one means something else is wrong.

That worktree is `<review-dir>`.

The diff tells you what changed; `<review-dir>` tells you what surrounds it. Every file you cite is read from `<review-dir>`, never from another directory.

Name `<review-dir>` to the user, and say whether you found it or built it. They then know where to open a file themselves.

**Done when:** `<review-dir>` sits at the PR head, you told the user where it is and whether you found it, and you hold the diff, the PR metadata, and the inline comments.

## Step 2 — Settle the review's scope

A repository can assign part of itself to another team. Where the diff touches code
another team owns, the user is often on the PR for the rest of it only. Settle the
scope before the review starts.

**Read the owners file.** GitHub reads it from `.github/CODEOWNERS`, from `CODEOWNERS`,
or from `docs/CODEOWNERS`. Read it in `<review-dir>`. Where the repository has none, the
scope is the whole diff. Go to Step 3.

**Find the user's teams.** One call names every team the user belongs to in the
repository's organization:

```bash
gh api graphql -f query='{ organization(login: "<owner>") { teams(first: 100, userLogins: ["<viewer>"]) { nodes { slug } } } }'
```

`<viewer>` is the user's GitHub login, which `gh api user --jq .login` returns.

Do not use `gh api orgs/<owner>/teams/<slug>/memberships/<user>`. That endpoint answers
404 for a non-member and 404 for a team the token cannot read, so a 404 settles nothing.

A secret team stays out of the GraphQL result. So where the answer contradicts what the
user tells you, the query is wrong and the user is right.

**Map each changed file to its owners.** The last pattern that matches a path wins, and
every earlier match is discarded. A repository-wide `*` line is therefore a fallback
only, and any specific line below it overrides that fallback. One line can name several
owners.

**Split the changed files.** A file is the user's where its winning line names a team
the user belongs to, or names the user. Every other changed file belongs to another
team.

Where no changed file belongs to another team, the scope is the whole diff. Say so in
one line. Go to Step 3.

The same holds where the split leaves the user no files at all. A repository whose
owners file names one person, or names a team the user is not on, produces that result.
A review of nothing is no review, and a request that names the user is a request for the
whole diff. So take the whole diff, say why in one line, and go to Step 3.

**Otherwise, ask the user.** Name the other team. Give the number of files on each side.
Offer two scopes:

1. The whole diff.
2. The files the user's own team owns, and no others.

Do not choose for them. Do not start the review before they answer.

Call the files their answer keeps `<in-scope>`. Steps 3 to 6 raise findings about
`<in-scope>` only. Those steps still read the other files, because a finding about an
in-scope file can depend on one.

**Done when:** you know `<in-scope>`, and the user chose it wherever the diff crosses a
team boundary.

## Step 3 — Establish what the change is

Derive this from the diff and the code in `<review-dir>`, not from the PR description. Where the description misstates what the diff does, that gap is itself a finding.

For a dependency bump, read the upstream changelog for minor and major version changes and summarise the behavioural differences. Skip the changelog on patch-only bumps.

**Done when:** you can state Today / This PR / Why in your own words, without leaning on the description.

## Step 4 — Evaluate against the criteria

Work the closed list in [Criteria](#criteria). Every finding you keep carries one of those prefixes.

This review only reads. Run no formatters, linters, typecheckers, or tests.

A formatter rewrites the files you are about to cite. On a found `<review-dir>`, those
edits land in the user's own working directory. A test run costs minutes, and it can
write to a database. A red test is the author's signal, not your finding.

Check every claim before you write it into a finding. A claim is checkable when one
command, one query, or one file read settles it. Run that check now, not after the user
questions the finding. A **Fix** is part of its finding, so check the claims in the Fix
too. This includes any replacement text the Fix proposes.

Three kinds of claim are checkable by definition:

- **A magnitude.** "Frequent", "hot path", "a firehose", "a lot of" — a number exists
  for each one. Produce the number, or cut the word.
- **A location.** Grep settles it. Confirm that the other place you name holds what you
  say it holds.
- **An absence.** "No caller", "none of the calls", "never" — the search must also
  match a call that spans several lines. Use `rg -U`, and put `\s*` between the
  tokens of the pattern, as in `rg -U 'find_by\(\s*id:'`. The `-U` flag alone
  changes nothing for a pattern with no `\s` or `\n` in it.

**Done when:** every file in `<in-scope>` has been read in `<review-dir>` and weighed against all seven criteria — not merely the files where something caught your eye. Every checkable claim in every finding carries its check.

## Step 5 — Steelman every finding but a nit

Roughly half of blocking concerns dissolve under investigation. So every finding but a
nit earns the steelman. A finding in prose takes the steelman in its own form,
under [A finding in prose](#a-finding-in-prose). The user posts comments based on these
findings, either as drafts from Step 7 or in their own words, so a finding that does not
hold can reach the author.

**A nit does not put the code's behaviour in question.** Style, naming, formatting, a
typo, a stray line, a clearer phrasing. A finding that asserts what the code does — what
it returns, when it runs, what it touches, what it costs — is not a nit. Read the test
off the finding's own sentence. "This method name is misleading" is a nit. "This method
name is misleading, so a caller passes the wrong argument" is not.

A nit goes to 🟡, and it skips the six points below.

Build the strongest case that the code is **correct**:

1. Read the whole file in `<review-dir>`, not the hunk — the guard often sits above it.
2. Read the callers — the bad state may be unreachable.
3. Look for a test that already covers it.
4. Check the base class, concern, or framework default.
5. Check `git log` for why the code is the way it is.
6. Trace the failing state's lifecycle — a job, an observer, or another app may clear the state before the code runs.

Then name the failing scenario: `<how the state arises> → <wrong outcome>`. "This looks unsafe" is not a scenario; "an account with two active subscriptions is returned twice, so the renewal job charges it twice" is.

| Outcome of the steelman | Where the finding goes |
| --- | --- |
| The scenario holds up | 🔴 Blocking |
| You can't settle it either way | 🟠 Non-blocking, phrased as a question |
| The concern dissolves | 🟢 Verified, stating why it's fine |

Those three are the only exits. A concern you noticed and did not chase is not a finding.
Chase it, or drop it.

### A finding in prose

Prose is text that a developer, a reviewer, or an agent reads and then acts on, wherever
it lives. Examples are a skill, a `CLAUDE.md`, a README, a guide, and the PR body that a
workflow writes from a string in its YAML. A claim in prose has no guard, no caller, and no
lifecycle, so the six points cannot dissolve the claim. A claim that disagrees with the
code always holds up, and the table above then sends every such finding to 🔴. So a
finding in prose takes this procedure instead of the six points and the table above.

1. Check the claim against the code, and cite the `file:line` that settles it.
2. Name what a reader does when they follow the text: the code they write, or the
   command they run. Name what that code or that command does.
3. Place the finding by the outcome of that code or that command:

| Outcome of what the reader does | Where the finding goes |
| --- | --- |
| It reaches production, and there it writes or exposes data, crosses a tenant or a permission, moves money, or changes what a user sees | 🔴 Blocking |
| It is wrong, but it fails before production, or it changes none of those four things | 🟠 Non-blocking, stated as fact |
| You can't settle the claim | 🟠 Non-blocking, phrased as a question |
| The claim is right | 🟢 Verified, stating why it's fine |

A spec that fails, a build that goes red, and a lint error all fail before production.
The nit rule still applies: wording that makes no claim about behaviour goes to 🟡.

### A finding another reviewer raised

Compare each finding with every comment from Step 1. Count comments from people and
from bots alike. A finding **overlaps** a comment that raises the same problem. A
resolved thread still counts, because the steelman already settled whether the problem
is in the code at the head.

An overlapping finding carries two more lines:

- **Raised by**: the comment's author and its URL.
- **Adds**: what the finding says that the comment does not. Where it says nothing
  more, write "nothing; the steelman confirms the comment". The finding keeps its
  section, because a confirmed problem still needs action.

Where the comment suggests a fix, the finding carries a third line, **Their fix**, with
one of three values:

- "fixes it"
- "fixes part of it: <the problem that remains>, so <its consequence>"
- "does not fix it, because <reason>"

Where the comment is inline, its line is the finding's anchor, because a reply belongs
in that thread.

**Done when:** every finding in code went through the six points, every finding
in prose went through the procedure above, every 🔴 names a concrete failing
scenario, and the concerns you raised and dropped appear under 🟢, up to the cap the
[Report](#report) sets. Every finding was compared with every comment from Step 1, and
each overlapping finding carries its **Raised by** and **Adds** lines.

## Step 6 — Deliver

Write the report to the file path you were given. With no path, print it in chat.

**Done when:** the report is delivered.

## Step 7 — Draft the comments the user names

The report carries no drafts. The user reads it, then names the findings they mean to
post. Write a draft for each finding they named, and for no other.

In the reply that holds the drafts, read `DRAFTS.md` before you write a draft. It sits in
the same directory as this file. Read it in one Read call, with no offset and no limit.
Read it even where you read it earlier in the session, because an earlier read can drop
out of the context before the user names the findings.

**Done when:** every finding the user named carries a draft, or a reaction offer where
its **Adds** is "nothing", and every draft passes each rule in `DRAFTS.md`.

## Step 8 — Close the review

Where you **built** `<review-dir>`, remove it once the user says the review is finished:

```bash
git -C <clone> worktree remove <parent>/.pr-reviews/<repo>-pr-<num>
git -C <clone> update-ref -d refs/pr-review/<num>
```

Where you **found** `<review-dir>`, remove nothing, and say so. Name the branch and the
two SHAs where a fast-forward ran, because that moved a branch of theirs.

**Done when:** you either removed a built `<review-dir>` or told the user that a found one
needed no removal.

## Criteria

A closed list. Every finding takes one of these as its prefix:

- **correctness** — logic, edge cases, error paths that are actually reachable
- **conventions** — project patterns, existing base classes and concerns, the conventions in `CLAUDE.md`
- **test coverage** — new and changed code carries appropriate tests
- **security** — authorisation, injection, secrets, and multi-tenant scoping (an unscoped query is a cross-tenant read)
- **performance** — N+1s, unindexed queries, work that belongs in a background job
- **deploy safety** — migrations, backfills, live sessions, feature flags, rollback
- **dependencies** — version bumps and the behavioural changes in their changelogs

## Citations

Line numbers come from reading the file in `<review-dir>`. Never count lines in a diff: a unified diff carries numbers only in its hunk headers, so a line derived by counting forward past added and removed lines drifts, and drifts further with each hunk. Before writing `path:line`, confirm that line holds the code you are describing.

Cite as `app/services/renew_subscription.rb:42-51`.

A finding that reports two sources in disagreement cites a `file:line` for each side.
Name what each side says, so the reader does not have to open either file to learn
which one is wrong.

GitHub accepts an inline comment on any line of a file the PR changes. A line outside
a hunk needs the reader to expand the context arrows first, so prefer a line inside a
hunk where one serves equally well. Do not rule out a line merely because no hunk
covers it.

A file the PR does not touch at all accepts no inline comment. The decisive evidence
often sits in such a file — the caller that makes a bad state reachable, the legacy
method the new code has to agree with. Cite that location in the finding's text, and
see [Report](#report) for choosing the anchor.

## Report

Order findings within each section most consequential first. Omit 🔴, 🟠, and 🟡 entirely when empty — the verdict already carries that news.

Number the findings, and keep one run of numbers across all four sections rather
than restarting at each heading, so "finding 4" names exactly one thing when the user
comes back to discuss it. That means writing the start number explicitly on the first
item of every section after the first. Leave a blank line between items.

Give every 🔴, 🟠, and 🟡 finding an **Anchor** — the single `file:line` a comment about it
belongs on. A finding usually cites several locations, and deciding which one a comment
hangs off is review work: you traced the code, so make that call rather than leaving
the user to pick from your citations. 🟢 findings take no anchor, since a risk you
cleared needs no comment.

Choose among candidates by counting. Write the finding's observation as one sentence.
Where that sentence cites no line number besides the anchor, the anchor is right.
Where the sentence has to cite a second location before the problem makes sense,
prefer a candidate that needs none. Where no candidate passes, keep the nearest line
in a changed file and cite the rest in the finding's text.

A finding in prose follows two more rules:

- Where only part of a line is wrong, quote the wrong part exactly, and name the part
  that stays. A reader who sees a whole line flagged takes all of it as wrong.
- Give a **Fix** in every section but 🟢, and write the replacement text in full. A
  direction such as "say that most models are not scoped" leaves the author to guess
  the words. Read the replacement text from where its reader meets it, with only what
  that reader sees there. For example, a Fix can change a string in a workflow's YAML
  that becomes a PR body. In the YAML, the steps around the string make "this branch"
  clear. On the PR page, the reader sees a head branch and a base branch, so "this
  branch" can mean either one.

```markdown
# <repo>#<num> — <title>
<url>
**Scope** — <the part of the diff this review covers>

## What this PR does
**Today** — <1–2 sentences on the status quo this replaces>
**This PR** — <1–2 sentences on what changes>
**Why** — <1–2 sentences on the motivating problem, verified against the code or ticket>

## Existing discussion
- @<author>: <the substance, one line>
- @<reviewer>: <the substance, one line>

## 🔴 Blocking
1. **<criteria>** — <what is wrong> (`file:line`), so <the concrete consequence>.
   **Fix** — <the remedy, pointing at an existing pattern where one exists>.
   **Anchor** — `file:line`

2. **<criteria>** — <what is wrong> (`file:line`), so <the concrete consequence>.
   **Fix** — <the remedy, pointing at an existing pattern where one exists>.
   **Anchor** — `file:line`

## 🟠 Non-blocking
3. **<criteria>** — <what is off> (`file:line`), so <the consequence>.
   **Raised by** — @<reviewer>, <comment URL>
   **Adds** — <what this finding says that the comment does not>
   **Their fix** — <fixes it | fixes part of it: …, so … | does not fix it, because …>
   **Fix** — <for prose, the replacement text in full>.
   **Anchor** — `file:line`

4. **<criteria>** — <what is off> (`file:line`), so <the consequence>.
   **Fix** — <for prose, the replacement text in full>.
   **Anchor** — `file:line`

## 🟡 Nits
5. **<criteria>** — <what is off> (`file:line`).
   **Fix** — <for prose, the replacement text in full>.
   **Anchor** — `file:line`

## 🟢 Verified
6. **<criteria>** — <the risk you checked and why it holds> (`file:line`).

## <emoji> Verdict
<the deciding factor, and what the user should do next>
```

Assume no familiarity with the PR's domain: define jargon inline on first use — "a straddling trial (one that began on the old plan and ends after the new one starts)".

Include **Scope** only where Step 2 narrowed the review. Name the team that owns the rest, and the number of files left out. Omit the line for a full review.

Include **Existing discussion** only when the PR has comments, reviews, or inline comments; prior reviewers often supply the context you lack.

Include **Raised by**, **Adds**, and **Their fix** only where [A finding another reviewer raised](#a-finding-another-reviewer-raised) calls for them.

Cap 🟢 at four items, and keep it to risks you investigated and cleared — praise for its own sake is the noise this format exists to remove. Where more than four dissolved, keep the four you came closest to raising.

The verdict's emoji is mechanical: any 🔴 makes it 🔴, otherwise any 🟠 makes it 🟠, otherwise any 🟡 makes it 🟡, otherwise 🟢. Keep it to two sentences, around 40 words, ending in a recommendation to the user — approve as-is, comment first, or ask the author a question.
