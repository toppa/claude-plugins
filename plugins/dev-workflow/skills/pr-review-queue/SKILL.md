---
name: pr-review-queue
description: Work down the queue of PRs awaiting the user's review, one at a time.
disable-model-invocation: true
allowed-tools:
  - Bash(gh api:*)
  - Bash(gh pr view:*)
  - Bash(gh pr diff:*)
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
    Written in a personal skills directory, and moved here on 2026-10-25 with
    the `pr-review` skill, whose method it applies to each PR in the queue.
  synced: 2026-10-25
---

# Work down the PR review queue

## Step 1 — Build the queue, then wait for the go-ahead

```bash
gh api graphql -f query='
{
  viewer { login }
  search(query: "is:pr is:open draft:false review-requested:@me sort:created-asc", type: ISSUE, first: 50) {
    nodes {
      ... on PullRequest {
        number title url createdAt additions deletions changedFiles headRefOid
        repository { name }
        author { login }
        reviewRequests(first: 20) {
          nodes { requestedReviewer { __typename ... on User { login } ... on Team { slug } } }
        }
        latestOpinionatedReviews(first: 20) {
          nodes { state commit { oid } author { __typename login } }
        }
      }
    }
  }
}'
```

Use GraphQL, because the table needs `additions`, `deletions`, and `changedFiles`.
`gh search prs` returns none of the three. A draft PR stays out, because its author is
still at work on it. Include one only when the user names it.

### Sort each PR into one of two tables

Other people already cover some of these PRs. Those rows go in a second table, so the
first table holds only the PRs that need the user.

Set a PR aside when either condition holds:

- **It has 2 or more qualifying approvals.** A node of `latestOpinionatedReviews`
  qualifies when its `state` is `APPROVED`, its `author.__typename` is `User`, and its
  `commit.oid` equals `headRefOid`. This condition fails when any node has the state
  `CHANGES_REQUESTED`.
- **A team carried the request.** No node of `reviewRequests` is a `User` whose `login`
  equals `viewer.login`.

A bot is not another person, so a `Bot` approval does not count. A stale approval
describes code that no longer exists, so an approval below the head does not count. A
contested PR is the opposite of a covered one, so a request for changes cancels the
approval count. It does not cancel the team condition, because a request for changes
does not make the request yours.

Count the approvals rather than read `reviewDecision`. A repo that requires one approval
reports `APPROVED` after one person looks at the PR. So that field marks most open PRs
and separates none of them, and the query does not fetch it.

### Mark the `#` cell

Three marks exist. Put them in the `#` cell after the number, in this order: `⚠️✅👥`.

| Mark | Meaning |
| --- | --- |
| ⚠️ | The repo has no local clone. |
| ✅ | The PR has 2 or more qualifying approvals. |
| 👥 | A team carried the request. |

A row with more cells than the header breaks the whole table, so add no column for a
mark. Keep the number first, so the column still sorts by eye. Give each mark's reason
in prose under its table.

✅ and 👥 are the two set-aside conditions, so a set-aside row states its own reason:
✅ alone means the approvals, 👥 alone means the team, and both marks mean both. Neither
mark reaches a row in the first table.

### Number the rows, and confirm the clones

Number the first table from 1, oldest first. Continue the same run through the set-aside
table, oldest first. These numbers hold for the whole session, so "#7" names one PR every
time either of you says it.

Confirm each repo has a local clone, using the lookup in the `pr-review` skill's Step 1.
Run this for every row of both tables. Every review needs a local clone, so a missing
clone stops that PR. Keep its row, and mark it ⚠️.

```markdown
### Needs your review

| # | PR | Title | Age | Author | Files | ± |
|---|----|-------|-----|--------|-------|---|
| 1 | [example-shop#101](url) | chore(deps): bump example-logger 2.3→2.4 | 6d | dependabot | 2 | +4/-4 |
| 2 | [example-shop#103](url) | feat(Wishlist): add a share link to saved lists | 4d | alice-example | 7 | +182/-11 |
| 3 ⚠️ | [example-action#104](url) | chore: set the Node version for CI | 2d | alice-example | 1 | +3/-1 |
```

```markdown
### Already covered

| # | PR | Title | Age | Author | Files | ± |
|---|----|-------|-----|--------|-------|---|
| 4 ✅ | [example-shop#102](url) | fix(Invoices): handle a missing tax rate | 5d | bob-example | 4 | +31/-6 |
| 5 👥 | [example-auth#105](url) | feat(Sessions): list signed-in devices | 3d | carol-example | 11 | +264/-18 |
```

Omit the set-aside table when nothing is set aside. Where every PR is set aside, say the
first table is empty, and print no empty table.

Then stop. The user sets the order, and names any set-aside PR they still want. They may
take the first table as it stands, skip rows, or move one to the front. Keep the Step 1
numbers whatever order they pick.

A set-aside PR the user declines returns next session. Step 1 rebuilds the queue from
GitHub, and it keeps no record of the decision.

**Done when:** every PR the query returned has a row in one of the two tables, every mark
carries a reason, and the user named the order.

## Step 2 — Work the queue, one PR at a time

The `dev-workflow:pr-review` skill's `SKILL.md` holds the review method, and that method
governs every PR in this queue. It sits in this plugin, at
`${CLAUDE_PLUGIN_ROOT}/skills/pr-review/SKILL.md`.

Take the PRs in the order the user set, one at a time:

1. Name the PR. Print its URL, so the user can open it and follow along.
2. Read all of the `pr-review` skill's `SKILL.md` in one Read call, with no offset and no
   limit. Read it again for every PR, because an earlier read can drop out of the
   context in a long queue.
3. Apply the method. Print the report in chat.
4. Wait. The user asks their questions. The user posts their review, or asks you to
   post it.
5. Read their move to the next PR as the signal that this review is finished. Close the
   review down as the `pr-review` skill's Step 8 says.
6. Name the next PR with its file count and ±.

The queue prunes itself. A submitted review clears GitHub's review request, so a PR the
user acted on drops out of the Step 1 query. A PR the user deferred stays in it, and
they say to skip that one.

So a restart loses no queue state. Re-running Step 1 rebuilds the queue from GitHub.
Offer the user a fresh session at any pause, and offer it again whenever the session
runs long.

**Done when:** every PR the user kept in the queue has a report in chat, or the user
ended the session.
