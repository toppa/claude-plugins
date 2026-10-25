# 0021 — The guide ships in the `standing-documents` plugin, with one version in the guide, `plugin.json`, and the tag

## Context

Before 2026-10-25, the standing-documents guide was a markdown file in `docs/guides/`. `docs/`
ships with no plugin, so no installed skill could point at the guide. The README was the only
route to it.

ADR [0018](README.md) left two questions open in its decision 11: how the guide gets versions,
and how a project upgrades. Under that decision, a project recorded no edition of the guide. So a
project that adopted the guide could not tell which text it followed, or what changed after that
text.

The repository goes public at version 0.1.0 of the guide, with a fresh history, as ADR
[0020](README.md) records. The public history holds no text of the guide from before that
version.

The README gave three reasons for a document and not a skill:

1. A skill ties the guide to Claude Code's plugin system.
2. A person can read a document on GitHub, with no install, before they decide to adopt it.
3. The one thing a skill adds is `/plugin update`, and the public git history already records
   each change to the guide.

## Decision

**The guide ships in the `standing-documents` plugin, as a reference file of its one skill,
`adopt`.** The path is
`plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md`. The skill sets
`disable-model-invocation: true`, so the user runs `/standing-documents:adopt`. The skill reads
the project's map, and it does a first adoption or an upgrade.

**One version number sits in three places:** the guide's version line under its title, the
`version` in the plugin's `plugin.json`, and the git tag `standing-documents-v<version>`. The
`versions` check in `scripts/check-skills.rb` asserts that the first two are equal. A version
below 1.0 is alpha.

**`CHANGELOG.md` sits beside the guide, with one entry for each version.** Each entry says what
changed, and what a project that adopted an earlier version does about it.

**The map records the guide's version in one line, with the URL.** The guide holds the upgrade:
read each changelog entry for a version later than the one in the map, do their actions oldest
first, and then change the version line. The upgrade is in the guide and not in the skill,
because an agent with no plugin needs it too.

This decision replaces decision 11 of ADR 0018, and it changes nothing else in it. ADR 0018 is
accepted, so its text stays as it is. Where the two disagree, this ADR holds.

## The alternatives that lost

**A document only, as the README argued.** Each of its three reasons turned out weak:

1. The guide in the plugin is still one plain markdown file, and any agent reads it. The plugin
   adds a route to the guide, and it removes no route.
2. A person still reads the file on GitHub with no install.
3. The git history gives a project no version to record, so an upgrade has no point to start
   from. An agent then needs a clone of this repository and a diff. Decision 11 of ADR 0018
   dropped that mechanism, which needed a commit SHA, git commands, and a clone. Also, the
   public history starts at 0.1.0, so it holds no earlier text to diff against.

**The guide inside `dev-workflow`.** That plugin has its own version, 0.14.0 at this decision,
and the version moves with each change to its skills. One `plugin.json` cannot carry two
versions. So the guide's version would move with changes that need no action from an adopting
project, or the guide would carry a second number that no release and no check ties to anything.
Also, the guide dictates no way to manage the work, and `dev-workflow` is one such way. A guide
inside it reads as tied to it.
