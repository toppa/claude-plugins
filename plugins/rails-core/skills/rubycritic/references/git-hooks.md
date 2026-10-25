# Git Hooks and CI Integration

A hook or a CI step is a change to how the project builds, so propose it and let the user
decide. Both patterns below assume the gem is in the project's `Gemfile`; a global install
serves an interactive analysis, not a shared build.

## The one thing that makes a gate work

`--minimum-score` is what gives RubyCritic a meaningful exit status.
`commands/status_reporter.rb:32-33` compares `score >= options[:minimum_score].to_f`, and
with the option unset `nil.to_f` is `0.0`, so **every run exits 0.** Confirmed: a file
rated F with `Score: 0.0` exited 0 with no minimum set, and exited 1 once one was.

A hook that reads only `$?` without passing `--minimum-score` therefore always passes. Pass
the flag and let RubyCritic decide, rather than parsing the score out of the output —
the printed forms differ (`Score: 97.18` when passing, `Score (97.18) is below the minimum
99.0` when failing), so a regex tuned to one silently matches nothing on the other.

## Pre-commit hook

`.git/hooks/pre-commit`, made executable with `chmod +x`:

```bash
#!/bin/bash
set -u

RUBY_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.rb$')
[ -z "$RUBY_FILES" ] && exit 0

if ! grep -qE "^[[:space:]]*gem [\"']rubycritic[\"']" Gemfile; then
  echo "rubycritic is not in this Gemfile; skipping the quality check."
  exit 0
fi

echo "Running RubyCritic on staged files..."
if bundle exec rubycritic --format console --no-browser --minimum-score 60 $RUBY_FILES; then
  exit 0
fi

echo "The staged files score below 60 — look at the DuplicateCode and HighComplexity"
echo "entries above. To commit anyway: git commit --no-verify"
exit 1
```

The `Gemfile` check matters: `bundle exec rubycritic` outside a bundle carrying the gem
fails, and without the guard the hook reports a missing gem as bad code. Confirmed on the
three paths — no Ruby files staged, gem absent, and gem present.

**Set the threshold low, because a hook scores only the staged files.** The score is a mean
over what was analyzed, so a commit of one complex file is judged on that file alone.
Measured on a two-file fixture: staged together the pair scored **42.69**; inside the
ten-file project the same two files contributed to a score of **88.49**. A hook threshold near the
project's score will block ordinary commits on one busy file.

**60 inverts to a mean file cost of 6.4, which is mid-C on rubycritic's own rating scale.**
The scale and the formula are in `SKILL.md`, section "The score measures complexity and
duplication". The band boundaries land on round scores: C starts at 50, B at 75, A at 87.5.
So 60 blocks a staged set whose mean rates D or F, and passes anything C or better. The
two-file fixture above scored 42.69, a mean cost of 9.17, which is D — the hook rejects it by
design. Raise the floor to 75 or 87.5 to demand B or A.

Keep `--mode-ci` and `--branch` out of hooks. Both check out the base branch
(`commands/compare.rb:34-59`), which moves the working tree mid-commit.

## GitHub Actions

This job matches the shape of the workflow that Rails 8.1 generates. `ruby/setup-ruby@v1` with
no `ruby-version:` reads `.ruby-version`, so CI cannot drift from local.

```yaml
name: Code Quality

on:
  pull_request:
  push:
    branches: [main]

jobs:
  rubycritic:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Measure code quality
        run: |
          bundle exec rubycritic --format console --format json \
            --minimum-score 95 --no-browser app lib

      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: rubycritic-report
          path: tmp/rubycritic/
          retention-days: 30
```

`fetch-depth: 0` is what gives the churn column real numbers; churn comes from revision
counts (`analysers/churn.rb:19`), and a shallow clone has almost no history to count.
`--format` accumulates, so console output lands in the log and `report.json` in the
artifact.

**Set `--minimum-score` from a first measured run on `main`.** A Rails 8.1 application
measured here scored 97.49 over 15 files, which makes 95 a gate that catches a regression
and 99 a build that fails on arrival. Raise it as the number improves.

The action major versions above are the only thing on this page not confirmed by running
the tool: `actions/checkout@v6` and `ruby/setup-ruby@v1` are taken from a working workflow
in this stack, and `actions/upload-artifact@v4` is not. Check it against the marketplace
before committing.

## Sharing hooks across a team

`.git/hooks/` is not tracked, so keep the scripts in the repository and link them in.

1. Put the hook scripts in `.git-hooks/`.
2. Add `bin/setup-git-hooks`:

```bash
#!/bin/bash
for hook in .git-hooks/*; do
  ln -sf "../../$hook" ".git/hooks/$(basename $hook)"
  chmod +x "$hook"
done
```

3. Run `bin/setup-git-hooks` as part of project setup.

Confirmed by running it: the symlink resolves, the target stays executable, and the hook
fires. `ln -sf` makes this safe to re-run.
