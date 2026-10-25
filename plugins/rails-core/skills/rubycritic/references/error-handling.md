# RubyCritic Troubleshooting

Every command here was run against rubycritic 5.0.0 on Ruby 3.4.5. Before running any of
them, know which invocation the project supports — see the SKILL's Quick Start. `bundle
exec rubycritic` outside a bundle that carries the gem fails with a bundler error, and a
wrapper that reads only the exit status will report that as a quality failure.

## "rubycritic: command not found"

The gem is not on this Ruby's path. Which fix applies depends on the project:

```bash
# Is it in the project's bundle?
grep -E "^[[:space:]]*gem [\"']rubycritic[\"']" Gemfile

# In the bundle but not installed — install the bundle the project already declares:
bundle install
```

If it is **not** in the Gemfile, offer `gem install rubycritic` and install it once the
user agrees. It needs no Gemfile change, because RubyCritic only parses source. Leave the
project's `Gemfile` alone either way — adding a gem to a shared project is the project's
decision, not this analysis's.

Where a `gem install` is not wanted, review by reading instead: the `review-ruby-code`
skill, its "Analyze each changed file" and "Check codebase patterns" sections. Neither
needs a gem, and that skill says the two of them carry most of the value.

## Permission errors on `gem install`

Install into the user's own gem directory:

```bash
gem install --user-install rubycritic
```

With rbenv or asdf managing the Ruby, a plain `gem install rubycritic` writes inside the
version's own gem directory and needs no elevation.

## "LoadError: cannot load such file"

RubyCritic 5.0.0 requires **Ruby >= 3.2.0** (`required_ruby_version` in the gemspec) and
pins `reek ~> 6.5.0`. Check the Ruby first:

```bash
ruby --version           # 3.2.0 or newer
rubycritic --version     # or: bundle exec rubycritic --version
```

A LoadError under a bundle usually means the lockfile predates the installed gem. `bundle
install` resolves it; `bundle update rubycritic` changes the lockfile, so ask first.

## An empty run reports `Score: 0.0`

**This is the failure mode most likely to go unnoticed.** With no Ruby files to analyze,
`AnalysedModulesCollection#score` returns `0.0` (`core/analysed_modules_collection.rb:47-52`),
and the run exits 0. Confirmed: an empty directory produced `Score: 0.0` with exit status 0
and no warning. A score of 0.0 therefore means either "nothing was analyzed" or "mean cost
reached 16", and nothing in the output distinguishes them.

So check what was analyzed rather than reading 0.0 as a verdict:

```bash
# Name the files explicitly, and check the list is non-empty first.
FILES=$(git diff --name-only --diff-filter=ACMR | grep '\.rb$')
[ -n "$FILES" ] && bundle exec rubycritic --format json --no-browser $FILES
```

Given zero path arguments RubyCritic falls back to its configured paths, or to `.`
(`commands/default.rb:14`), so an empty substitution silently analyzes the whole project —
the opposite failure, and it also exits 0 with a plausible score.

`--minimum-score` catches the empty case as a side effect, because 0.0 is below every
threshold.

## The run aborts on a file with an invalid byte

Flay and flog print `skipping <file>` and carry on; Reek raises and takes the whole run
with it. Confirmed on a file containing byte `0xE9`:

```
app/bad.rb:2 :: invalid multibyte character 0xE9
skipping app/bad.rb
ERROR: parsing ruby file app/bad.rb
RubyParser::SyntaxError: app/bad.rb:2 :: invalid multibyte character 0xE9
```

Exit status 1, with a backtrace and no score.

**A `# encoding: UTF-8` magic comment does not fix this.** Ruby source has defaulted to
UTF-8 since 2.0, so the comment restates the default while the byte stays invalid;
confirmed by `ruby -c` still failing with the comment in place. Re-encode the file instead:

```bash
ruby -c app/bad.rb                                        # confirm which file and line
iconv -f ISO-8859-1 -t UTF-8 app/bad.rb > app/bad.utf8.rb # then review and replace
```

macOS `iconv` has no `-o` flag, so redirect to a new path and swap it in once you have read
the result — that way the original survives a wrong guess about the source encoding.

## "SyntaxError: unexpected token"

RubyCritic parses with `ruby_parser` and `prism`, not with the running Ruby, so it can
reject syntax the interpreter accepts. Establish which it is:

```bash
ruby -c app/models/user.rb    # valid Ruby?
rubycritic --version          # which rubycritic saw it
```

Valid Ruby that RubyCritic rejects is a parser-version gap. Skip the file for now by
narrowing the paths you pass, and report it rather than reshaping working code to satisfy
the analyser.

## "Invalid YAML in .rubycritic.yml"

```bash
ruby -e "require 'yaml'; p YAML.load_file('.rubycritic.yml')"
```

Tabs instead of spaces and a missing space after `-` are the usual causes. Printing the
parsed hash also catches the quieter problem: **a key RubyCritic does not read parses
cleanly and does nothing.** `cli/options/file.rb:21-36` lists the eleven keys it acts on;
`exclude_paths` and `mode` are not among them. See the section "The keys `.rubycritic.yml`
reads" in this skill's configuration reference.

The file must sit in the directory you run from — `cli/options/file.rb:11` defaults to
`./.rubycritic.yml` with no upward search.

## "Score unexpectedly low"

Read the per-file ratings before the project score. The score is a mean, so one bad file
moves it a little and a small project moves it a lot.

```bash
bundle exec rubycritic --format json --no-browser app
# then sort by cost, highest first
jq -r '.analysed_modules | sort_by(-.cost) | .[] | "\(.rating) \(.cost) \(.path)"' tmp/rubycritic/report.json
```

The HTML entry point is `tmp/rubycritic/overview.html`, and its headline is a churn-against-
complexity scatter. There is no `index.html`; the other pages are `code_index.html`,
`smells_index.html`, `simple_cov_index.html`, and one page per source file.

```bash
bundle exec rubycritic --format html --no-browser app
open tmp/rubycritic/overview.html
```

Before concluding a file is bad, check what the number is made of: Reek smells cost zero,
so a file with a dozen of them can rate A. See the SKILL's section "Reading the output: two
independent signals".

## "Score changes between runs"

Pass the same paths each run — a run scoped to changed files and a run scoped to `app` are
not comparable, because the score averages over whatever was analyzed. Then check the
version, which differs between machines more often than the code does:

```bash
bundle exec rubycritic --version
```

If the project carries the gem, its `Gemfile` should pin `gem "rubycritic", "~> 5.0",
require: false`, and a committed `.rubycritic.yml` keeps `paths:` identical everywhere.
Both are the project's calls.

## A run that takes too long

Narrow the paths. `app` and `lib` are what is worth measuring in a Rails application, and
passing the changed files is faster still.

**CI mode is not the fix.** `--mode-ci` and `--branch` are the same command —
`commands/ci.rb` is `class Ci < Compare; end` — and `commands/compare.rb:34-59` checks out
the base branch, analyzes it in full, then analyzes yours, then builds a third report. That
is roughly three times the work of a plain run, and it moves the working tree, so it does
not belong in a pre-commit hook or on a dirty tree. The gem's own `--help` text calls it
"faster"; the source does not bear that out.
