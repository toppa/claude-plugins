# Divergences from upstream — dev-workflow

This file lists where each derived skill in `dev-workflow` differs from its upstream on
purpose, and why. Read a skill's section before you act on an upstream diff;
`docs/upstream-sync.md` holds the procedure. When an edit adds or removes a divergence, revise
the entry in place. This file is not a log.

## `pr-descriptions`

Upstream: `jbarrieault/claude-marketplace`, `plugins/ruthless-pr-edit/skills/ruthless-pr-edit/SKILL.md`.

The method stays the upstream's: five passes of subtraction, then a short add-back.

- **Changed: the name, from `ruthless-pr-edit`.** The other `dev-workflow` skills name their
  subject. "Edit" also undersold a skill that writes new pull requests too. "Reducer" and
  "subtraction" stay in the body as leading words.
- **Cut: the Rick Rubin name and his three quotes.** Each quote persuaded a human reader and
  changed nothing that the model does. A named person can also pull the model toward a voice.
  Pass 4 keeps its stop condition in plain words: stop at the first cut that breaks
  understanding, and restore that cut. Do not restore the quotes on a re-sync.
- **Changed: the premise.** Upstream said that the pull request says what changes, the commits
  say how, and the diff says where. In this house the commit body carries the why, and the
  diff carries the where and the how. The premise now names two jobs, **decide** and
  **place**, and the Summary states the **effect**: what a user, a caller, or an operator
  sees differently after the merge.
- **Added: the place test in pass 5, and `examples.md` example 4.** The test is tied to
  `git log`. "Give the big picture" was rejected as the test, because it is the same
  reasoning that justifies every section that pass 1 cuts. Example 4 teaches the test,
  because a model copies an example more closely than it follows a rule.
- **Changed: every title uses Conventional Commits.** Upstream used the prefix only where a
  repository uses it, and gave no way to tell. A count of recent merged titles was rejected
  as too complex. The skill names the standard and points at no other skill, so it works for
  a person who installs it without `commit-messages`. Do not add a pointer to
  `commit-messages`, because a standalone install then has a dead pointer.
- **Kept: the draft-PR rule.** A user's global CLAUDE.md may state it too, but a person who
  installs the skill may not have that rule. Do not cut it as a duplicate under the "state a
  rule once" rule.
- **Kept: the pass 3 list of fluff words, as a prohibition.** The agent must look for those
  words to delete them, so no positive form carries the rule.
- **Changed: the "After" text and the commentary in `examples.md` are ASD-STE100.** The
  "Before" bodies stay as upstream wrote them, because they are the bad input.
  `examples.md` stays a separate file, and the step that reads it has no condition.
- **Changed: `when_to_use` has two triggers, not three.** There is one trigger for each party
  that starts the work: Claude opens a pull request, or the user asks for a title or a body.
  Upstream's "tightening an existing PR" restated the rewrite trigger.
- **Added: the two checks on the effect govern Details as well.** Upstream has no source for
  this, and neither check existed there. They first landed under the premise, which the skill
  uses for the Summary alone, so a body passed every pass with Details in flat present tense.
  The reader could then not tell new behavior from old. Stating them where Details is defined
  costs one restatement, and it puts the rule where it fires.
- **Added: a PR that implements an issue names the issue key with a closing word, and points
  to the issue for its acceptance criteria.** Upstream has no source for this. The closing
  word lets a tracker's integration close the issue when the PR merges, as Linear's GitHub
  integration does (https://linear.app/docs/github). A PR that delivers only part of the
  issue names the key with a word that links only, such as "Part of ENG-123". The person who
  writes the issue may have no access to the code host, so the criteria stay in the tracker,
  and a copy in the body drifts.
