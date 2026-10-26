# Contributing

Thank you for your interest in these plugins. Issues are welcome. A pull request is welcome
after we agree on its issue.

## Open an issue first

Open an issue for each bug, each wrong fact in a skill, and each change you want to propose.
Say which plugin and which skill it concerns. For a skill that gave Claude the wrong advice,
give the request you made and what Claude did.

## Then open a pull request

Open a pull request only after the issue has an agreed change. A pull request with no agreed
issue gets closed, with a link back to this file. The pull request template asks for the issue
that the pull request closes.

Before you open the pull request, do these things:

1. Read `CLAUDE.md`, and follow its rules. It holds the rules for skill content, and for the
   prose of every document here.
2. Run `ruby scripts/check-skills.rb`. All its checks must pass.

## Where the maintainer's files are

| File | What it answers |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Which rules apply to each change, and which checks to run before a commit. |
| [`docs/adr/`](docs/adr/) | Why a decision went one way, and which alternative lost. |
| [`docs/upstream-divergences/`](docs/upstream-divergences/) | What a derived skill cut, changed, or added on purpose, compared with its upstream. |
| [`docs/upstream-sync.md`](docs/upstream-sync.md) | How to check a derived skill against its upstream, and how to take an upstream change. |
| [`scripts/check-skills.rb`](scripts/check-skills.rb) | Which properties the checker asserts. |
