# claude-plugins

A personal Claude Code plugin marketplace: `rails-core` (18 skills), `inertia-react` (10),
`dev-workflow` (10), `standing-documents` (1), and `ste-writing` (one output style and no
skill), plus an integrity checker. The root `README.md` pitches the marketplace to a new user.
Each plugin's `README.md` describes that plugin. `CONTRIBUTING.md` says how to contribute, and
it maps the maintainer's homes.
Each plugin's `NOTICE.md` names the source of each skill. The guide,
`plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md`, carries the
documentation pattern this house applies to a project, and the plugin's `adopt` skill applies
it. A change that an adopting project must act on gets a new version: its number goes in the
guide's version line and in `plugin.json`, and its action goes in `CHANGELOG.md` beside the
guide. Each version gets the git tag `standing-documents-v<version>`. ADR [0021](docs/adr/)
records the scheme.
A finding from a project that adopted the guide goes into that project's own documents by
default. The guide changes only where its own text caused the mistake, or where any project
would meet the same case. ADR [0018](docs/adr/) records the guide's target of about 300 lines,
and a change past it says why in its commit message.
Before you change a decision that `docs/adr/README.md` lists, read its ADR. The ADR holds the
alternative that lost, and why.
Before you edit a skill whose `upstream_repo:` is not `none`, read its section in
`docs/upstream-divergences/<plugin>.md`. It lists what we cut, changed, or added on purpose.

## This repository is public

**This repository is public.** Write nothing that names or describes a private person, an
employer, or a private project. This covers a name, a path, a repository, an issue ID, and
a measured case from one, because a commit here publishes it at once. The maintainer's
name in an attribution is the exception: a copyright line, an author or owner field, and
the marketplace description. Where evidence comes from a private project, describe the
project in general terms, such as "a private Rails 8.1 application", and keep the numbers.

## Before you commit

Run `ruby scripts/check-skills.rb`. It asserts eight properties that cannot fail loudly at
run time — paths, names, agents, anchors, estimates, index, versions, readmes — and all
eight must pass.

**Know its blind spot.** It validates markdown *anchors*, not prose section names. A
sentence claiming "`rails-architecture` covers this in its 'When NOT to Abstract' section"
keeps passing forever after that heading is renamed or its content deleted. Three rounds of
this project were spent on that one defect class. When you cite another file's content,
verify with `rg` that the target still holds it.

**Re-read what you just wrote, before the pass closes.** A sweep is not done when its edits
are made. It is done when someone reads them back. The 2026-08-13 sanity check attributed
every finding it accepted: 69% were introduced by this project's own earlier passes, and only
31% came in with the sources. The pointer sweep built to remove the blind spot above had the
worst rate of any pass — one edit in five later needed a fix.

**Keep the divergence file current.** When an edit to a derived skill adds or removes a
divergence from upstream, revise that skill's section in `docs/upstream-divergences/` in the
same commit. A re-sync reads that section to learn what not to bring back.

## How a skill reaches context

**A plugin skill reaches context in exactly three ways.** It is preloaded into an agent,
the model invokes it through the skill index, or the user invokes it. The first two
overlap, because a preloaded skill stays in the index. ADR [0001](docs/adr/) records how we
settled this against the Claude Code binary.

**Claude Code puts only `description` and `when_to_use` into context**, through the skill
index. It never puts the rest of the frontmatter into context. So a `metadata:` block costs
nothing at run time, and a skill's body costs context only when the skill loads.
ADR [0002](docs/adr/) records the evidence.

**`paths:` has no effect on a plugin skill.** The published docs say that it limits a skill
to matching files. Claude Code 2.1.228 discards it on a plugin skill. So a skill that
carries it tells a reader about scoping that does not happen. ADR [0001](docs/adr/) has the
evidence.

Every `description` and `when_to_use` of a skill that the model can invoke is in the
context of every session. Weigh each change to them. Where you quote a size, measure it.

## Voice

Write every document in plain, direct sentences. Say the thing itself. Where a metaphor or a
bare phrase would stand for a point, state the point in full, and add a short example list
where one helps. Older files here carry a compressed idiom ("the part that pays", "a third
of an answer"), which readers found hard to follow. When you edit one of them, rewrite the
passage in plain sentences rather than match the text around it. ASD-STE100 is the baseline,
and this rule sits on top of it.

## House rules for skill content

- **Write a rule as its purpose and a one-sentence reason.** Add a procedure, a defined term,
  a completion check, or a format only where an agent that knows the purpose still makes a
  mistake that nothing shows. A fact that the agent cannot work out alone, and that a test
  found, also stays. ADR [0018](docs/adr/) records why, for the guide.
- **A threshold or a limit that a reader acts on says where it comes from: an external
  source, or a house heuristic.** A reader applies the two differently. `rspec-let` is
  the model: Rule 1 labels 3 a house heuristic with no external source, and Rule 2
  attributes 5 to `RSpec/MultipleMemoizedHelpers`' default.
- **Lead with the correct form.** Naming a banned behaviour makes it more available.
  Prefer "`<Form>` takes `defaultValue`" to "never use controlled inputs". Keep a
  prohibition where no positive phrasing carries it, after the form to write rather than
  instead of it.
- **A cross-skill pointer names the skill; where it points at specific content it names the
  section too**, never a relative path — the `inertia-react:inertia-rails-performance`
  skill, its "Server-side pagination props" section. `check-skills.rb` resolves a bare
  `references/…md` against the *citing* skill's own root, so a relative path can point
  somewhere real and wrong while passing.
- **Name the plugin when the target sits in another plugin**, either as `plugin:skill` or
  in words. `description` and `when_to_use` always carry the plugin, because a resident field
  is read with no body around it.
- **Name a project's response mode Hotwire, Inertia, or JSON API**, in those words. The
  `rails-core:rails-architecture` skill owns the ordered check that names which one, in its
  "Response mode" section. Every other file points at that section rather than restating the
  check, because a second copy is a second thing to keep true.
- **Check the `Gemfile` before prescribing a non-default gem's command**, and never
  instruct anyone to add a gem to a shared project.
- **A user-only skill is named, not required.** Say that the user invokes it and carry on.
  It cannot be a blocking precondition, because nothing except the user can reach it.

## Skill metadata

Each `SKILL.md` carries a `metadata:` block for the maintainer. Claude Code never reads it.
When you sync a skill from upstream, follow `docs/upstream-sync.md`. The keys:

- `upstream_repo:` is the `owner/repo` the skill came from, or `none` for a skill written here.
- `upstream_path:` is the file or directory we copied, inside that repository.
- `upstream_ref:` is the commit we copied from. It is the only pinned ref for a sync. It
  moves only at a sync.
- `upstream_version:` is the upstream plugin's own version at that ref, where it has one.
  It moves with `upstream_ref:`.
- `synced:` dates the copy from `upstream_ref:`, or the day a skill written here arrived. A
  local edit does not move it.
- `verified_against:` names the exact versions that some statement in the skill rests on,
  such as `inertia_rails 3.22.0`. Never a range: "React 19" cannot be shown false, and 3.0
  and 3.6.1 differ where corrections landed. It moves at each re-check, whether or not the
  upstream moved.
- `verification_method:` says how the facts were checked, where that is not obvious.
- `reference_guides:` lists the published guides that a skill written here draws on.
- `origin:` says where a skill written here came from.
