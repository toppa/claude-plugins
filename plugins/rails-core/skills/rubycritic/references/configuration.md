# RubyCritic Configuration

Every key and flag below was read from rubycritic 5.0.0's source and confirmed by running
the gem.

**The commands below are written `bundle exec rubycritic`, which assumes the gem is in the
project's `Gemfile`.** Check that first — `SKILL.md`, section "Quick Start". Where the gem
is absent, offer the global install for the user to accept, then drop the `bundle exec`
prefix. Never add the gem to the project's `Gemfile` yourself.

A key RubyCritic does not read is dropped from `.rubycritic.yml` silently —
`cli/options/file.rb:17` is a bare `YAML.load_file`, and `to_h` at `:21-36` picks out the
eleven keys it knows — so an inert key looks exactly like a working one.

## The keys `.rubycritic.yml` reads

Enumerated from `cli/options/file.rb:41-97`.

| Key | Type | Effect |
|---|---|---|
| `paths` | list | Directories or files to analyze. This is how you scope a run. |
| `path` | string | Where the report is written. Default `tmp/rubycritic`. |
| `formats` | list | Any of `html`, `json`, `console`, `lint`. Unknown values are dropped. |
| `no_browser` | bool | Leave the HTML report closed. |
| `minimum_score` | number | Exit 1 when the project score falls below it. |
| `suppress_ratings` | bool | Omit the letter ratings from the report. |
| `deduplicate_symlinks` | bool | Count a symlink and its target once. |
| `coverage_path` | string | Where to find SimpleCov's `.resultset.json`. Default `./coverage`. |
| `threshold_score` | number | Largest score drop tolerated against the base branch. |
| `branch` | string | Base branch to compare against; setting it selects compare mode. |
| `mode_ci` | map | `enabled: true` plus optional `branch:`. Selects CI mode. |

`mode_ci` is a nested map, not a scalar. `mode: ci` is not a key the gem reads.

## A working configuration

```yaml
paths:
  - app
  - lib
formats:
  - console
no_browser: true
minimum_score: 90
```

Confirmed by running `rubycritic` with no arguments in a directory holding that file: only
`app` was analyzed, output went to the console, no browser opened, and a project score of
88.49 against `minimum_score: 90` exited 1 with
`Score (88.49) is below the minimum 90`.

## Scoping a run

**Name what to include.** Pass paths as arguments, or list them under `paths:`. Both were
confirmed to restrict the run; there is no `exclude_paths` key in `.rubycritic.yml`, and
`rg exclude lib/` over the gem returns nothing.

For a Rails application, `app` and `lib` are the directories worth measuring. Leaving
`db/`, `config/`, `bin/`, and `spec/fixtures/` out of `paths:` keeps generated and fixture
code out of the score average, which matters because the score is a mean across files.

**Reek exclusions are separate and narrower.** RubyCritic drops a file from *Reek* when
Reek's own configuration excludes it (`analysers/smells/reek.rb:13-16`), and
`Reek::Configuration::AppConfiguration#path_excluded?` compares expanded paths for
equality. So through RubyCritic a `.reek.yml` entry has to name the file exactly:

```yaml
# .reek.yml — silences Reek for one file
exclude_paths:
  - vendor/junk.rb
```

Confirmed: with that entry the file reported 0 smells; with `- vendor` it reported all 9.
And an excluded file is still flogged, still flayed, still rated, and still counted in the
score average — Reek exclusion removes smells from the list, not the file from the run.
To keep a file out of the run entirely, leave it out of `paths:`.

## Choosing a `minimum_score`

`minimum_score` is the only thing that makes the exit status meaningful.
`commands/status_reporter.rb:32-33` compares `score >= options[:minimum_score].to_f`, and
with the option unset `nil.to_f` is `0.0`, so **every run exits 0 no matter what it
found.** Confirmed: a file rated F with `Score: 0.0` exited 0 with no `minimum_score` set,
and the same file exited 1 once one was.

Pick the number from a first measured run rather than from a table. Set it just under the
score the project has today, so the gate catches a regression instead of failing on day
one. A Rails 8.1 application measured here scored 97.49 with 15 files analyzed, which
makes 95 a gate and 99 a wish.

Remember what the score is made of before you read a threshold into it: it moves on
complexity and duplication, and Reek smells cost zero. See the SKILL's section "Reading
the output: two independent signals".

## CLI options

Every flag below appears in `rubycritic --help` and was run individually.

```bash
# Scope, format, and where the report goes
bundle exec rubycritic --format console --no-browser app lib
bundle exec rubycritic --format json --no-browser -p tmp/quality app

# Gate on a score
bundle exec rubycritic --minimum-score 95 --no-browser app

# Fold SimpleCov coverage into the report
bundle exec rubycritic --coverage-path coverage --format html --no-browser app

# Only count churn since a date
bundle exec rubycritic --churn-after 2026-01-01 --format console --no-browser app
```

`--format` accumulates, so `--format console --format json` produces both. `-p PATH`
relocates the whole report directory, which is how you analyze a repository without
writing into it.

## Compare and CI modes

`--branch BRANCH` compares two branches. `--mode-ci [BASE_BRANCH]` is the same command:
`commands/ci.rb` is `class Ci < Compare; end`. Both check out the other branch and analyze
it in full before analyzing yours (`commands/compare.rb:34-59`), which is roughly three
times the work of a plain run and moves the working tree. Use them from CI on a clean
checkout, and use a plain run everywhere else. `--maximum-decrease N` gates the comparison
on how far the score may fall.

Compare mode needs an HTML generator in the format list to create its report directory
first; with `--format console` alone it raises `Errno::ENOENT` on
`tmp/rubycritic/compare/build_details.txt`.

## SimpleCov coverage

`--coverage-path` points the coverage analyser at SimpleCov's `.resultset.json`
(`analysers/coverage.rb:51-54`), which gives each file a coverage percentage and a separate
coverage rating.

Two things to know before you reach for it. Coverage surfaces in the HTML report only, on
`simple_cov_index.html`; the keys in `report.json` are `churn`, `committed_at`,
`complexity`, `cost`, `duplication`, `methods_count`, `name`, `path`, `rating`, and
`smells`, with no coverage among them. And coverage is not part of `cost`
(`core/analysed_module.rb:43-46`), so it does not move the score. `simplecov` is a
RubyCritic dependency, so it is installed wherever RubyCritic is, but the resultset only
exists once the project's own suite has run under SimpleCov. A missing coverage directory
is not an error: the run completes and reports zero coverage.
