# Contributing

Thank you for your interest in these plugins. Issues are welcome. A pull request is welcome
after we agree on its issue. A pull request that adds support for another tracker needs no
issue first.

## Open an issue first

Open an issue for each bug, each wrong fact in a skill, and each change you want to propose.
Say which plugin and which skill it concerns. For a skill that gave Claude the wrong advice,
give the request you made and what Claude did.

## Then open a pull request

Open a pull request only after the issue has an agreed change. A pull request with no agreed
issue gets closed, with a link back to this file. The one exception is support for another
tracker, in the next section. The pull request template asks for the issue that the pull
request closes.

Before you open the pull request, do these things:

1. Read `CLAUDE.md`, and follow its rules. It holds the rules for skill content, and for the
   prose of every document here.
2. Run `ruby scripts/check-skills.rb`. All its checks must pass.

## Add support for another tracker

A pull request that adds support for another tracker needs no issue first. The tracker skills
in `dev-workflow` already define the shape of that work, so we agree on it before you start.

The maintainer has no account for most trackers, and so cannot test your tracker file. Your
pull request carries the evidence instead:

1. Add a tracker file for your tracker to each skill that you support. The `write-issue`,
   `implement-issue`, and `triage-sentry` skills each keep a `trackers/` folder. Use the
   Linear file in that folder as the model, such as
   `plugins/dev-workflow/skills/write-issue/trackers/linear.md`. You can support
   `write-issue` only.
2. In the pull request, include a transcript of a real run of each skill that you support,
   such as the file that `/export` writes. The run of `write-issue` must create an issue in
   the tracker. Remove private data from each transcript first, because this repository is
   public.

Do the two things under "Then open a pull request" too.

## Where the maintainer's files are

| File | What it answers |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Which rules apply to each change, and which checks to run before a commit. |
| [`docs/adr/`](docs/adr/) | Why a decision went one way, and which alternative lost. |
| [`docs/upstream-divergences/`](docs/upstream-divergences/) | What a derived skill cut, changed, or added on purpose, compared with its upstream. |
| [`docs/upstream-sync.md`](docs/upstream-sync.md) | How to check a derived skill against its upstream, and how to take an upstream change. |
| [`scripts/check-skills.rb`](scripts/check-skills.rb) | Which properties the checker asserts. |
