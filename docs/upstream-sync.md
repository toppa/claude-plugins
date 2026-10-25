# Syncing a skill from upstream

This file holds the one procedure for checking a derived skill against its upstream, and for
taking an upstream change. A **derived skill** has an `upstream_repo:` other than `none` in
its `metadata:`. `CLAUDE.md` defines each `metadata:` key, under "Skill metadata".

## Clone the upstreams once

The clones sit outside this repository, in `~/Projects/claude-plugins-upstreams`. Each local
directory is the upstream's `owner/repo` with the slash replaced by a hyphen, and the drift
check below depends on that name.

```bash
mkdir -p ~/Projects/claude-plugins-upstreams
cd ~/Projects/claude-plugins-upstreams
git clone https://github.com/ThibautBaissac/rails_ai_agents.git ThibautBaissac-rails_ai_agents
git clone https://github.com/el-feo/ai-context.git el-feo-ai-context
git clone https://github.com/inertia-rails/skills.git inertia-rails-skills
git clone https://github.com/cole-robertson/inertia-rails-skills.git cole-robertson-inertia-rails-skills
git clone https://github.com/vercel-labs/agent-skills.git vercel-labs-agent-skills
git clone https://github.com/jbarrieault/claude-marketplace.git jbarrieault-claude-marketplace
```

Each upstream's branch is `main`.

## Check one skill for drift

The skill's `metadata:` holds the ref we copied from. The check diffs that ref against the
upstream's current `main`, for the whole directory that holds `upstream_path`. Most
`upstream_path` values name a `SKILL.md`, and a skill's `references/` and `rules/` files
change too.

```bash
skill=plugins/rails-core/skills/extraction-timing/SKILL.md
repo=$(yq --front-matter=extract '.metadata.upstream_repo' "$skill")
ref=$(yq --front-matter=extract '.metadata.upstream_ref' "$skill")
upstream_path=$(yq --front-matter=extract '.metadata.upstream_path' "$skill")
clone=~/Projects/claude-plugins-upstreams/${repo/\//-}
git -C "$clone" fetch origin
git -C "$clone" diff "$ref"..origin/main -- "${upstream_path%SKILL.md}"
```

Run it from the repository root. An empty diff means the upstream directory has not changed
since we copied it. A non-empty diff is the work list. The `vercel-labs/agent-skills` ref is
the repository head at the time of the copy, so an empty diff there is common: the two
directories we take change less often than the repository.

For `vercel-labs/agent-skills`, also check whether a `LICENSE` file now exists at the
repository root. `plugins/inertia-react/NOTICE.md` says why, under "The Vercel license is
asserted, not filed". Where one exists, copy its notice into that `NOTICE.md`.

## Before you act on a diff

Read the skill's section in `docs/upstream-divergences/<plugin>.md` first. Do not apply a
diff mechanically, because each of these risks is real in this repository:

- **Upstream deletes things we depend on.** `ruby-rails` 0.4.0 deleted the
  `sandi-metz-reviewer` skill and folded part of it into `review-ruby-code`. A blind re-sync
  removes content that we chose on purpose.
- **Upstream fixes by deletion, and not by correction.** Six of the eight factual errors in
  `ruby-rails` 0.1.1 are gone in 0.4.0, and each went with the section that held it. A diff
  that only removes lines is not always an improvement for us.
- **Upstream still holds defects that we reproduced.** A merge that takes upstream's side on a
  line that the divergence file names brings that defect back. Treat the skill's
  `verified_against:` as the list of facts you would have to check again.
- **We cut passages on purpose.** The divergence file lists each cut and its reason. An
  upstream change to a passage we cut is not a change to take.
- **Upstream ships `paths:`, and we delete it.** The key has no effect on a plugin skill, and a
  skill that carries it tells a reader about scoping that does not happen
  ([0001](adr/)).
- **The two Inertia sets give opposite advice on forms.** Forms come from
  `inertia-rails/skills` only ([0006](adr/)). Do not let a `cole-robertson/inertia-rails-skills`
  file overwrite one of ours with the same name, because its advice contradicts ours.
- **Four `inertia-react` skills carry hand-written Inertia 3 sections.** `inertia-rails/skills`
  targets `inertia_rails` 3.17 and `@inertiajs/react` 2.3. Where an upstream adopts version 3,
  its text replaces our section. Do not keep both, because two copies drift apart.

## After you act on a diff

1. Set `upstream_ref:` to the commit you took the change from.
2. Set `synced:` to the date of that sync.
3. Where the skill carries `upstream_version:`, set it to the upstream's new version.
4. Revise the skill's section in `docs/upstream-divergences/<plugin>.md`, where the sync adds
   or removes a divergence.
5. Run `ruby scripts/check-skills.rb`.

## Schedule

Check every upstream once a quarter. None of the six moves quickly.

The `inertia_rails` gem moves faster than these upstreams. On every minor version of
`inertia_rails`, re-read the Inertia 3 sections that `docs/upstream-divergences/inertia-react.md`
lists. Then update `verified_against:` in each skill you checked.
