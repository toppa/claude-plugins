# Running rubycritic and SimpleCov over a review's scope

`SKILL.md` step 2 holds the rules: check the `Gemfile`, run only what the project already has, scope
rubycritic to the changed files, and review without a tool that is absent. This file holds the invocations
and the mechanism behind them. Verified against rubycritic 5.0.0 and simplecov 1.1.0.

## rubycritic, scoped to the changed files

Given zero file arguments RubyCritic falls back to its default paths and analyzes the whole application,
exiting 0 with a score — so the run looks fine and is scoped to the wrong thing. Guard on a non-empty list:

```bash
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | cut -d/ -f2)
BASE=${BASE:-$(git rev-parse --verify --quiet main >/dev/null && echo main || echo master)}
FILES=$(git diff --name-only --diff-filter=ACMR "$BASE...HEAD" | grep '\.rb$')
[ -n "$FILES" ] && bundle exec rubycritic --format json --no-browser $FILES
```

Both lines of the `BASE` resolution belong in the same call as the `git diff`, because shell state does not
persist between calls. A one-liner like `$(git symbolic-ref … | cut -d/ -f2 || echo main)` does **not**
work: the `||` binds to `cut`, which succeeds with empty output whenever `git symbolic-ref` fails, so the
fallback never fires and the range collapses to `HEAD...HEAD` — an empty diff with exit status 0.

RubyCritic writes to `tmp/rubycritic/`, and `--format json` puts the report at `tmp/rubycritic/report.json`.
If the gem is not in the bundle it still works from a global install, because it only parses source and
never loads the application: drop `bundle exec`, or skip the tool.

## SimpleCov

Read `spec/spec_helper.rb` before running anything. **SimpleCov reads no `COVERAGE` environment variable** —
the only variables it consults are `SIMPLECOV_NO_DEFAULTS`, `SIMPLECOV_CLI` and `PARALLEL_TEST_GROUPS`.
`COVERAGE=true` is a per-project convention that a `spec_helper.rb` has to implement, and where it does
not, the suite passes, no `coverage/` directory appears, and the coverage step silently reviews nothing. Use
whatever gate the project actually wired up; the results land in `coverage/.resultset.json`.
