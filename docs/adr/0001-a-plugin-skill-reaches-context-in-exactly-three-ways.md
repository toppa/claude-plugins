# 0001 — A plugin skill reaches context in exactly three ways

## Context

Every editing decision in this repository depends on how a skill gets into a session. The
published Claude Code docs describe more routes than a plugin skill has. A reader who trusts
the docs adds a key that does nothing, or disables a skill that another skill needs. We
settled the routes on 2026-08-11, against the binary that runs and a `--debug-file` session.

## Decision

A plugin skill reaches context in exactly three ways:

1. **It is preloaded into an agent.** The agent's `skills:` list names it, and its body
   arrives at spawn.
2. **The model invokes it through the skill index.** Its `description` and `when_to_use` are
   resident, and the model matches on them.
3. **The user invokes it** by typing `/<name>`.

The first two overlap, because a preloaded skill stays in the index. Each plugin's skills
therefore sit in one of three tiers: preload, on-demand, or user-only.

**`paths:` has no effect on a plugin skill.** There is no auto-load tier. No skill in this
repository carries `paths:`. The six that did lost it on 2026-08-11: `behavioral-guidelines`,
`rails-8-idioms`, `extraction-timing`, `solid-queue-setup`, `rspec-let`, and `rspec-models`.

**`disable-model-invocation` has two positions only.** A skill is resident and reachable by
every caller, or it is reachable by the user alone. No caller except the user reaches a
disabled skill: not the main session, not a subagent, not another skill, and not an agent's
`skills:` preload. `rails-core` disables four skills: `testprof`, `rails-generators`,
`accessibility-review`, and `postgresql-rails-analyzer`. Each fires on an intent that the
user forms before the work starts. The `rails` agent names them as out of reach. It names the
one a task calls for in its report, and it carries on.

**`rubycritic` stays in the index on purpose.** A plan or a workflow skill reaches it through
the Skill tool after a Ruby step. A disabled `rubycritic` closes that route, and it still
looks open.

**A subagent inherits the whole skill index.** A preload stays inside the subagent, but the
index reaches it too. No per-agent allowlist exists. An agent's `skills:` adds to the index
and does not narrow it. Two filters narrow the index, and both carry into a subagent:

- `skillOverrides` in a project's `.claude/settings.local.json`, with the values `"off"` and
  `"name-only"`.
- `disable-model-invocation` on the skill itself.

## The alternative that lost

The docs say that `paths:` limits a skill to matching files. A skill with `paths:` would then
be a fourth route: held out of the index, and loaded when a matching file is touched. That
route is real for a skill in a skills directory, such as `~/.claude/skills` or a project's
`.claude/skills`. It is not real for a plugin skill. A conditional skill is the only
arrangement that costs no resident tokens and also fires on its own. So it stays worth using
in a personal skill, and no plugin can use it. `rspec-let` and `rspec-models` lost a working
`paths:` when they moved out of a personal skills directory. Neither lost anything real: both fired
on their descriptions, 10 and 3 times, before anyone added a glob.

## Evidence

**Two loaders build skills, and only one reads `paths:`.** In Claude Code 2.1.228, the
skills-directory loader calls `kYd(frontmatter)` and passes `paths:` into the skill object.
That skill becomes a conditional skill. It is held out of the index, and it loads when `Read`,
`Edit`, or `Write` touches a matching file. Activation prints
`[skills] Activated conditional skill '<name>' (matched path: <file>)`. The plugin loader,
`Cfd`, has a different constructor and never calls `kYd`. It discards the key. An earlier
account, of 2026-08-10, said that no skill loader reads `paths:`. This account replaces it.

**The debug session shows both halves in one startup.** It read
`app/models/application_record.rb`, which matched the globs on three `rails-core` skills:

```
Loaded 27 unique skills (27 unconditional, 0 conditional, managed: 0, user: 25, …)
getPluginSkills: Processing 4 enabled plugins
Loaded 19 skills from plugin rails-core default directory
Sending 62 skills via attachment (initial)
```

The conditional count belongs to the skills-directory loader. No plugin line reports one, and
no activation line appeared.

**A controlled test agreed.** Two fresh sessions read one file each. A file that matched three
globs produced less context than a file that matched none: 13.2k against 13.9k. The second
file was 34 lines longer, which explains the difference. Three skill bodies of 13,846 bytes in
total did not arrive.

**Check the binary that runs.** The first reading concluded that no loader reads `paths:`. It
came from a stale npm install of `cli.js` that nothing runs. The binary that ran was
`~/.local/bin/claude`, a native binary under `~/.local/share/claude/versions/`. A launcher
script can also set `CLAUDE_CONFIG_DIR` before it runs that binary. Confirm which binary runs
before you re-check this ADR after an upgrade.

**One predicate governs the Skill tool's list:**

```
function Zot(e){ return e.type==="prompt" && !e.disableModelInvocation && … }
```

An agent's `skills:` preload reads the same filtered list. A typed `/<name>` reaches a
disabled skill through a separate list, which admits disabled skills on purpose.

**`rubycritic`'s route has a measured cost.** Its index string is 737 characters, about 184
tokens: 276 for `description` and 461 for `when_to_use`, measured 2026-08-12. The four
disabled skills were 454 tokens, 21% of `rails-core`'s index cost.

**The index reached the subagent in full.** The `rails` agent, asked with no tools, named all
66 skills of the main session. One spawn reported 41,000 tokens for a question that used no
tool. Agent frontmatter accepts `name`, `description`, `tools`, `skills`, `color`, `model`,
and `forkContext`.
