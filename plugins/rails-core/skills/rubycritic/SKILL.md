---
name: rubycritic
description: Run RubyCritic to measure Ruby code smells, complexity, and duplication — the smells a tool reports, as against the ones you find by reading a diff, which belong to review-ruby-code. Wraps Reek, Flog, and Flay. The gem is absent from most projects, so this skill checks first.
when_to_use: >-
  Use when the user asks to measure code quality, to run a code analysis, or to
  check complexity or duplication, and when RubyCritic, Reek, Flog, or Flay is
  named. Also use it after a refactor you already made, where the point of the run
  is a number to set against the one before it; whether code should move at all, and
  where it goes, is the `rails-core:extraction-timing` skill's. Smells you can see by
  reading belong to the `rails-core:review-ruby-code` skill.
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/rubycritic/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: "rubycritic 5.0.0, reek 6.5.0, flog 4.9.4, flay 2.14.4, simplecov 1.1.0, Ruby 3.4.5, against a Rails 8.1.3.1 application"
---

# RubyCritic Code Quality Analysis

RubyCritic runs Reek, Flog, and Flay over Ruby source and reports, per file, a smell
list, a complexity number, a duplication number, a churn count, and a letter rating.

## Quick Start

RubyCritic only parses source files. It never loads the application, so it does not
have to be in the project's bundle. Check which case applies:

```bash
grep -E "^[[:space:]]*gem [\"']rubycritic[\"']" Gemfile
```

**In the Gemfile** — run it:

```bash
bundle exec rubycritic --format json --no-browser app
```

**Not in the Gemfile** — say so, and offer the global install rather than running it:

> RubyCritic is not in this project's bundle. `gem install rubycritic` adds it to the
> active Ruby along with its thirteen runtime dependencies — reek, flay, flog, simplecov,
> ruby_parser, virtus and the rest — after which the bare `rubycritic` command works in
> any project. Want me to install it?

Install only once the user agrees, then drop `bundle exec`. Adding the gem to the
project's `Gemfile` is the project's decision, so leave that file alone. If the user
declines, review by reading instead — see the `review-ruby-code` skill, its "Analyze each
changed file" and "Check codebase patterns" sections. Neither needs a gem, and that skill
says the two of them carry most of the value.

## Scoping a run

To analyze only the Ruby files you changed, check the list is non-empty first. Given
zero path arguments RubyCritic falls back to its default paths and analyzes the whole
project, exiting 0 with a score — so the run looks fine and measured the wrong thing:

```bash
FILES=$(git diff --name-only --diff-filter=ACMR | grep '\.rb$')
[ -n "$FILES" ] && bundle exec rubycritic --format json --no-browser $FILES
```

## Where the report lands

| Format | File | Carries |
|---|---|---|
| `--format json` | `tmp/rubycritic/report.json` | `score`, and per file `cost`, `rating`, `complexity`, `duplication`, `churn`, and every smell with its own `cost` |
| `--format console` | stdout | rating, churn, complexity, duplication, smell count and smell list per file, then one `Score:` line |
| `--format html` | `tmp/rubycritic/overview.html` | a churn-against-complexity scatter, plus `code_index.html`, `smells_index.html`, and one page per file |

Prefer `--format json`: it is the only format that carries `cost`, which is the number
the letter rating is computed from. Use `--format console` when a human is reading.
`--format html` opens a browser unless you pass `--no-browser`. `-p PATH` moves the
whole report directory, which is how you analyze a repository without writing into it.

## Reading the output: two independent signals

**The smell list and the score measure different things, and neither predicts the other.**

### The smell list is the actionable output

Every Reek and Flog smell is recorded with `cost: 0`
(`analysers/smells/reek.rb:46`, `analysers/smells/flog.rb:51` in rubycritic 5.0.0). Only
Flay contributes: a duplication smell costs `mass / 25`, integer division, so a
duplicated block of mass 34 costs 1 and one of mass 17 costs 0
(`analysers/smells/flay.rb:48,66-68`).

So a file's smell list is the part of the report worth acting on, and the score will not
confirm that you acted. Measured on a 9-smell file: fixing `IrresponsibleModule`,
`UncommunicativeMethodName`, and `UncommunicativeParameterName` took it from 9 smells to
6, and the score stayed at exactly 97.18. Count smells before and after — that count is the
signal that a smell fix landed.

### The score measures complexity and duplication

```
file cost  = sum of smell costs + complexity / 25.0     # capped at 32
rating     = A if cost <= 2, B <= 4, C <= 8, D <= 16, else F
score      = (100 - min(mean file cost, 16) * 6.25).round(2)
```

Sources in rubycritic 5.0.0: `core/analysed_module.rb:11,43-46`, `core/rating.rb:5-13`,
`core/analysed_modules_collection.rb:12-18,47-80`.

Three consequences worth holding:

- **With no duplication a file rates A until its total flog complexity passes 50**, and B
  until 100, because cost 2 is A's ceiling and complexity is divided by 25. A file can
  carry a dozen Reek smells and still rate A.
- **The score is a mean across files, so one bad file is diluted.** Measured: an F-rated
  file at cost 17.89 in a ten-file run produced `Score: 88.49`. Read the per-file ratings,
  not the project score.
- **A score of 0.0 has two causes, and the output distinguishes neither.** Mean cost reached
  16, which is where F begins, or nothing was analyzed at all. Check what the run measured
  before you report a rating. `references/error-handling.md` covers the empty run, in its
  "An empty run reports `Score: 0.0`" section.

Flog reports `HighComplexity` at a per-method flog score of 25 and `VeryHighComplexity`
at 60 (`analysers/smells/flog.rb:12-13`). The per-file `complexity` number is the sum
across the file's methods, so a file can exceed 25 in total with no method flagged.

## Responding to what it reports

Work in this order, because it is the order in which a fix removes the most:

1. **Duplication** — the only smell class that moves the score. Extract the shared code.
   Measured on one duplicated query body: extracting it took the file from rating B to A
   and the score from 82.23 to 94.88.
2. **Complexity** — split the methods flog scored highest. Expect the per-method flog score
   to fall and the score to hold or dip: measured on a four-deep method, the highest method
   went 13.3 → 5.3 while the file total went 13.33 → 14.43 and the score 96.67 → **96.39**.
   **A correct refactor can lower the score**, which is why the per-method numbers are the
   ones to read here.
3. **Reek smells** — one at a time, re-running to confirm the count dropped.

RubyCritic reports no style or formatting offenses; `core/smell.rb:56-65` knows only `reek`,
`flay`, and `flog`. Style belongs to the `rubocop` skill. Whether extracted code should
move to a new class belongs to the `extraction-timing` skill, section "Extraction
Thresholds".

## `IrresponsibleModule` on a Rails application

On a Rails app this is the majority of the output. Measured against a Rails 8.1.3.1
application with no `.reek.yml`: `Score: 97.49` over 15 files, and **all 15 carried
`IrresponsibleModule: … has no descriptive comment`** — 15 of the 21 smells reported, one
per class the framework's own generators produced.

The only thing that satisfies the detector is a class-level descriptive comment, and
comments here are reserved for clarification, warning, amplification, and agreed TODOs.
So report `IrresponsibleModule` as noise and leave the classes alone. Where the user wants
it out of the output, offer a project `.reek.yml`, which RubyCritic loads through Reek's
own default-path lookup (`analysers/helpers/reek.rb:7-9`):

```yaml
detectors:
  IrresponsibleModule:
    enabled: false
```

That is a new file in the project, so ask first.

## References

- [references/code_smells.md](references/code_smells.md) - each Reek smell, what fires it, and the fix
- [references/configuration.md](references/configuration.md) - the keys `.rubycritic.yml` actually reads, and the CLI
- [references/git-hooks.md](references/git-hooks.md) - a pre-commit hook that can fail, and GitHub Actions
- [references/error-handling.md](references/error-handling.md) - troubleshooting analysis errors
