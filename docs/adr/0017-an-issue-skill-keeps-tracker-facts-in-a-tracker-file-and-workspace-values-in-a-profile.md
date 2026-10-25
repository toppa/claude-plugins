# 0017 — An issue skill keeps tracker facts in a tracker file, and workspace values in a profile

## Context

Before 2026-10-21, a personal skill, `linear-issue`, drafted a Linear issue to a template, and
it created the issue after approval. Most of its content applies to any tracker: the kinds, the
templates, INVEST, the titles, the acceptance criteria, and privacy. The rest mixed two other
kinds of content:

1. **Facts about Linear.** An epic is a Project. One label per group is a Linear rule. Two
   apps get peer issues, because a team setting can close a child issue when its parent
   closes.
2. **Values of one workspace.** These were one team's name, its starting statuses, and the
   names of its label groups and labels.

The skill moved into `dev-workflow` as `write-issue`, so it must work for any user who installs
the plugin, with any tracker or with none. The plan for this move adds `implement-issue` too,
and that skill reads the same tracker.

## Decision

**Each kind of content has its own home.**

1. **Generic** content goes in each skill's `SKILL.md` and its `references/`.
2. **Tracker** content goes in a `trackers/<tracker>.md` file inside each skill, such as
   `write-issue`'s `trackers/linear.md`. A skill reads that file only where the profile names
   that tracker.
3. **Instance** content goes in a per-user profile file,
   `~/.claude/data/dev-workflow/issue-trackers.yml`. Each profile covers one tracker
   workspace, and it lists the directories that it covers.

**Each skill has its own tracker file**, with only what that skill does. A skill cannot share a
reference file with another skill. `scripts/check-skills.rb` resolves a bare `trackers/…md`
against the skill that cites it, so a pointer into the other skill's folder can pass the check
and still be wrong.

**The skill owns two keys of a profile, `tracker` and `paths`.** The tracker file owns every
other key, and it lists the question that the first run asks for each one. `tracker: none` is a
real value, so a project with no tracker gets no question on each run. Where no tracker file
applies, the skill ends with Markdown for the user to paste.

**No key holds an MCP tool prefix.** The prefix comes from the name that each user gives the
server, so a tracker file names each tool by the last part of its name. For the same reason, no
skill carries `allowed-tools`.

## The alternatives that lost

**A separate `linear` plugin, with a `write-linear-issue` skill and an `implement-linear-issue`
skill.** It lost for two reasons:

- A tracker skill puts its description into the index of each user who installs it. A Jira
  user would then carry two Linear skills that match the word "issue".
- A tracker file costs nothing in the index, because a skill reads it only after it loads. A
  new tracker then needs one new file in each skill, and no new skill.

**A profile file with no tracker files.** Much of the Linear content is rules with reasons,
such as "an epic is a Project" and "two apps get peer issues". In YAML, each rule becomes a
string of prose. A user who writes the YAML for a new tracker must then already know those
facts, and the skill could not teach them.
