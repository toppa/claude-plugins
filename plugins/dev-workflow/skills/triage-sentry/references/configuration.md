# The config file

The skill reads its team facts from `~/.claude/data/dev-workflow/triage-sentry/config.yml`.
That file lives outside the skill, so a skill update never overwrites it and nobody edits a
file that ships with the skill.

**The config holds values only.** Every rule, reason and warning belongs in the skill,
where an update improves it. **Do not write a comment into the config, because a comment
invites prose that the skill should own.**

## What a run needs

1. **A Sentry connection in the session**, with write access to each project that the user
   triages. The skill reads issues, it changes their status, it posts comments, and it
   links tracker issues.
2. **A connection to the tracker in the session**, where the profile names a tracker
   that has a tracker file in this skill. The profile is the one that the
   `dev-workflow:write-issue` skill reads, in its section "The profile file". With no
   tracker file, the run still triages, and each task ends as Markdown for the user to
   paste.
3. **What the tracker file lists in its section "What a run needs".** For Linear, that is
   the Linear integration installed in Sentry.
4. **`yq`**, which reads and validates the config file.

`/mcp` lists the connections of the current session.

### A missing Sentry connection

A run that reports absent Sentry tools has a connection problem, and not a Sentry outage.
Confirm it with `/mcp`.

Sentry reaches a session in two ways. **Choose one, because two servers offer two copies
of every tool, and a call then goes to whichever one answers first.**

- **A connector on claude.ai.** Turn Sentry on there.
- **A local MCP server**, added with `claude mcp add`. Sentry's own MCP documentation
  names the endpoint.

A connection that the user adds during a session is not live in that session. Start a new
session after either change.

## Read the config at the start of a run

```bash
yq -e '.' ~/.claude/data/dev-workflow/triage-sentry/config.yml
```

The command exits non-zero on a parse error, and on a file that does not exist. Read the
output, then check for these keys:

- `organization_slug`
- `projects`, and a `slug` in each entry
- Where a tracker file applies, each key that it lists in its section "Config keys"

A missing file and a missing key take the same branch: run the interview below. **Ask
only for what is absent**, so a skill update that adds a key costs the user one question.

**Test for the `assignee` key rather than for its value, because `null` is a valid
setting.** `yq '.tracker | has("assignee")'` returns false for an absent key and true for
an explicit null. A plain read of the value prints `null` in both cases.

## The interview

Ask one question at a time. Look a fact up rather than ask for it.

1. **The Sentry organization.** Call `find_organizations` and offer the results. **Do not
   accept a slug derived from the company name, because a wrong slug returns a 404 that
   names the organization, the project and the issue together.** That message does not
   say which of the three is wrong.
2. **The projects.** Call `find_projects` for the chosen organization. A busy
   organization holds many, so let the user pick the projects the rotation owns.
3. **The tracker keys.** `SKILL.md`'s section "The profile and the tracker file" finds
   the tracker file. Where a tracker file applies, ask each question that it lists in its
   section "Config keys". Where no tracker file applies, ask none.

## Write the file

```yaml
organization_slug: "acme"

projects:
  - slug: "storefront"
    product_label: "Storefront"
  - slug: "checkout"
    product_label: "Checkout"

tracker:
  team: "Reliability"
  status: "Backlog"
  assignee: null
  labels: ["bug-fix"]
```

- **Quote every string value, because an unquoted value that holds a colon and a space
  fails the parse.** A team named `Platform: Core` is not unusual.
- Write `assignee: null` for no assignee.
- Write `labels: []` where a task carries the product label alone.
- Leave out `tracker` and each `product_label` where no tracker file applies.
- Validate the result with `yq -e '.'` after the write.

Then tell the user where the application notes live:
`~/.claude/data/dev-workflow/triage-sentry/apps/<project-slug>.md`. A note holds the
architecture, the known noise patterns and the error-handling conventions of one
application. It grows across runs. A run works without one, and it needs fewer detail
fetches with one.

Close the interview with a pointer to "Change the config later" below.

## Change the config later

The user invokes the skill and states the change in the same message:

```
/dev-workflow:triage-sentry add the inventory project
/dev-workflow:triage-sentry stop triaging checkout
/dev-workflow:triage-sentry set the status for a new task to Triage
```

**To add a project:**

1. Confirm the slug with `find_projects`.
2. Add an entry to `projects`, with its `slug`. Where a tracker file applies, ask its
   question for `product_label`, and add the answer to the entry.
3. Write the application note at
   `~/.claude/data/dev-workflow/triage-sentry/apps/<slug>.md`. Copy the headings of an
   existing note, and mark each one `(derived)`, `(open)` or `(closed)`. **Do not leave
   a heading unmarked, because the maintenance rules in `SKILL.md` read that marker.**
4. Check `playbook.md` against the new platform.

Step 4 matters for a platform the playbook does not cover. The playbook's rules come
from the triage of a web backend and of one browser project. A mobile application or a
queue-only service needs its own noise patterns first.

**To remove a project**, delete its entry from `projects`. Leave its application note on
disk. The project may return, and the note costs nothing where it sits.

**To change a tracker default**, edit the one key the user names.

Validate the result with `yq -e '.'` after any of these writes.
