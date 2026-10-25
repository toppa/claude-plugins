---
name: brakeman
description: >-
  The Brakeman binary end to end — how a Rails 8.1 project invokes it
  (`bin/brakeman`, `bin/ci`), what each exit code means, how to read a warning's
  confidence, how to suppress a false positive, and the flags and config keys
  that exist. Covers
  the companion gem-vulnerability scan, `bin/bundler-audit`.
when_to_use: >-
  Use when the user names Brakeman or bundler-audit, says `bin/ci` or the
  security step is failing, asks why a scan exits non-zero or reports Brakeman
  is outdated, asks about a warning or its confidence level, wants a security
  scan wired into CI, wants to suppress a false positive, or edits
  `config/brakeman.ignore`, `config/brakeman.yml`, or `config/bundler-audit.yml`.
  For the review procedure itself — scope, severity ranking and report format —
  use the security-audit skill.
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/brakeman/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: brakeman 8.0.5, bundler-audit 0.9.3, Rails 8.1.3.1, Ruby 3.4.5
---

# Brakeman

Brakeman is a static analysis security scanner for Rails. It reads source, traces
user input to sinks, and reports warnings with a confidence level. It needs no
running application, no database and no test suite.

This skill owns the binary: invocation, exit codes, flags, config keys, and
suppression. For the audit procedure — scope, severity ranking, report format —
use the `security-audit` skill. For triaging a specific warning type, see
`references/warning_types.md`.

## Running it on this project

**Check the `Gemfile` first, and expect to find both scanners there.** Rails 8.1
generates `brakeman` and `bundler-audit` into a new application along with
`bin/brakeman`, `bin/bundler-audit`, `config/bundler-audit.yml` and the
`config/ci.rb` steps that run them, so on a current app the answer is that they
are already installed. Older applications predate that, which is why the check is
still worth a moment: a survey of 27 existing Gemfiles found the gem in 3 of them.
Both facts hold, so read the file rather than assuming either way.

When a scanner is absent, say so and let the maintainer decide. Adding a gem to a
shared project is their call, not something to do in passing.

```bash
# Static analysis of application code
bin/brakeman

# Known CVEs in the gems the lockfile resolves
bin/bundler-audit

# Every check the project gates merges on, security steps included
bin/ci
```

`bin/ci` reads `config/ci.rb`. On a stock Rails 8.1 app that file runs setup,
RuboCop, `bin/bundler-audit`, and `bin/brakeman --quiet --no-pager
--exit-on-warn --exit-on-error`. Each step runs even after an earlier one fails;
`ActiveSupport::ContinuousIntegration` collects the results and aborts at the end
if any step failed. So read the per-step markers, not just the final line.

### `bin/brakeman` adds `--ensure-latest`

The generated binstub prepends `--ensure-latest` to `ARGV`:

```ruby
# bin/brakeman
ARGV.unshift("--ensure-latest")
```

`--ensure-latest` compares the running gem against the newest version on
rubygems.org. `commandline.rb:34` calls `check_latest` **before** `run_report` at
`:35`, and `:49-50` quits with `Brakeman::Not_Latest_Version_Exit_Code`, which
`brakeman.rb:15` sets to **5**. When the gem is behind, the whole output is one
line and **no scan runs at all**:

```
$ bin/brakeman
Brakeman 8.0.4 is not the latest version 8.0.5
$ echo $?
5
```

`bin/ci` inherits that exit code, so the security step goes red with no report
behind it. Exit 5 means "this application has not been scanned" — the fix is
`bundle update brakeman`, then run again. Reading exit 5 as "vulnerabilities
found" produces a P0 that does not exist; reading it as "clean" leaves an
unscanned application on the shelf.

### `bin/bundler-audit` carries the project's accepted-CVE list

```ruby
# bin/bundler-audit
ARGV.concat %w[ --config config/bundler-audit.yml ] if ARGV.empty? || ARGV.include?("check")
```

bundler-audit 0.9.3 defaults `--config` to `.bundler-audit.yml`, a dotfile at the
repository root that Rails does not generate (`cli.rb:44`). When the file is
absent, `scanner.rb:91` falls back to an empty configuration without a message.
So `bundle audit` run bare ignores every CVE the project has reviewed and
accepted in `config/bundler-audit.yml`, and reports a different result from CI.
Use `bin/bundler-audit`, or pass `--config config/bundler-audit.yml` yourself.

## Exit codes

Every code below was observed against brakeman 8.0.5. `brakeman.rb` defines them
at the cited lines.

| Code | Constant | Means | Raised by |
|---|---|---|---|
| 0 | — | Scan completed, nothing to report | |
| 3 | `Warnings_Found_Exit_Code` (`:9`) | Warnings survived the ignore file and the confidence filter | default; `--no-exit-on-warn` turns it off |
| 4 | `No_App_Found_Exit_Code` (`:12`) | The path is not a Rails application | `--force-scan` scans anyway |
| 5 | `Not_Latest_Version_Exit_Code` (`:15`) | The gem is behind the newest release, **and the scan did not run** | `--ensure-latest` |
| 6 | `Missing_Checks_Exit_Code` (`:18`) | A name given to `-t`/`-x`/`-E` is not a check | |
| 7 | `Errors_Found_Exit_Code` (`:22`) | A file failed to parse or a check raised | default; `--no-exit-on-error` turns it off |
| 8 | `Empty_Ignore_Note_Exit_Code` (`:26`) | An ignore entry's `note` is empty or whitespace only | `--ensure-ignore-notes` |
| 9 | `Obsolete_Ignore_Entries_Exit_Code` (`:30`) | An ignore entry matches nothing in the current code | `--ensure-no-obsolete-ignore-entries` |

Two properties of that table decide how to read a red build:

- **5 comes before the report.** Every other code is decided in
  `commandline.rb:150-165`, after the scan. Exit 5 is decided at `:34`.
- **Codes mask each other, warnings first.** `:150-165` checks warnings, then
  errors, then obsolete entries, then empty notes, and quits at the first hit.
  An application with both a warning and a parse error exits 3, so a scan that
  silently skipped a file still looks like an ordinary warning run. To see the
  errors, add `--no-exit-on-warn` and read the `Errors:` count in the overview.

Exit code 3 counts `tracker.filtered_warnings`, so warnings listed in the ignore
file do not affect it.

`--ensure-ignore-notes` tests `note.strip.empty?` (`report/ignore/config.rb:98`), so a
`note` of `""` or of spaces exits 8. An entry carrying **no** `note` key at all does not
exit 8 — it raises `NoMethodError` on `nil.strip`. Executed against brakeman 8.0.5.

## Confidence

Brakeman labels each warning `High`, `Medium`, or `Weak` — the three strings in
`TEXT_CONFIDENCE` (`warning.rb:14`). `Weak` is the word the report prints; there
is no "Low".

| Flag | Keeps | Note |
|---|---|---|
| `-w1` | High, Medium and Weak | the default |
| `-w2` | High and Medium | |
| `-w3` | High only | |

`options.rb:381-387` converts the flag with `min_confidence = 3 - level`, so the
internal scale is inverted: `-w2` sets `min_confidence: 1`. That matters for the
config file, whose key takes the internal value (see
`references/command_options.md`).

Read the whole `-w1` set once, so you know what is there, then work High first.
On a `load_defaults 7.0`-or-later application some real findings arrive at `Weak`
— `Redirect` does — so `-w3` is a triage order, not a standing filter. `Unscoped
Find` reports at `Weak` too, but it is an **optional** check, so no confidence
level surfaces it on its own. It needs `-E UnscopedFind` or `-A`.

## Reading a warning

Each warning gives a category (the `warning_type` string), a check class, a
confidence, the code, and a file and line. To triage one:

1. Read the code in context and trace the value back to its source. Brakeman
   reports reachable-looking data flow, not proven exploitability.
2. Look the category up in `references/warning_types.md`, which carries the
   check class, the warning code, whether the check is optional, and the version
   window each check applies to.
3. Decide: fix it, or record it as accepted in the ignore file with a note.

`--text-fields category,check,confidence,code,file,line` trims the text report to
those fields. `-f json` gives the same warnings with a `fingerprint` per warning,
which is what the ignore file matches on.

## Suppressing a false positive

`brakeman -I` walks the warnings and writes `config/brakeman.ignore`. The opening
menu has four choices, and the third one **prunes**: "Inspect all warnings",
"Inspect new warnings", "Prune obsolete ignored warnings", "Skip - use current
ignore configuration". Choosing 3 drops every fingerprint that no longer matches
code, and saving writes that deletion.

Per warning, the keys are (`interactive.rb:109-119`, verbatim):

```
i - Add warning to ignore list
n - Add warning to ignore list and add note
s - Skip this warning (will remain ignored or shown)
u - Remove this warning from ignore list
a - Ignore this warning and all remaining warnings
k - Skip this warning and all remaining warnings
q - Quit, do not update ignored warnings
? - Display this help
```

Use `n` and write the note. `--ensure-ignore-notes` turns "we always add notes"
into exit code 8, and `--ensure-no-obsolete-ignore-entries` turns "we review the
list" into exit code 9 — both enforce in CI what a checklist asks a human to do.

### What an ignore entry actually suppresses

`warning.rb:250-257`:

```ruby
Digest::SHA2.new(256).update(
  "#{warning_code_string}#{code_string}#{location_string}#{self.file.relative}#{self.confidence}"
).to_s
```

The line number is not an input. `location` (`warning.rb:259-274`) is the
enclosing class and method for a controller-flow warning, the view name for a
template, or the model name for a model. So one entry suppresses **any warning
with the same warning code, the same code string, the same confidence, in the
same file and the same enclosing method — at any line.**

Observed: a `File Access` warning ignored at line 32 stayed ignored after the
method moved to line 76; an identical `File.read(params[:f])` added in a
different action of the same controller produced a fresh, active warning. So the
entry follows the method it was written against, and reintroducing the same
expression inside that method is silent. `--ensure-no-obsolete-ignore-entries`
catches the entry that has stopped matching anything; nothing catches the entry
that is still matching more than you meant. Keep entries narrow and re-read the
notes when you touch the method.

## Reports

```bash
# Format is inferred from the extension; several -o flags are allowed
brakeman -o tmp/brakeman.html -o tmp/brakeman.json

# Or state it, when the destination has no useful extension
brakeman -f json -o /dev/stdout

# Compare against a saved JSON scan; prints {"new":[],"fixed":[],"obsolete":[]}
brakeman -o tmp/baseline.json
brakeman --compare tmp/baseline.json
```

`-f` accepts `text`, `plain`, `html`, `json`, `csv`, `tabs`, `table`, `markdown`,
`junit`, `codeclimate` (or `cc`), `sonar`, `sarif`, `github`, and `pdf`
(`options.rb:285`). `sarif` is the format GitHub code scanning ingests, and
`github` is the workflow-annotation format.

The JSON and HTML reports always include an `ignored_warnings` collection.
`--show-ignored` adds it to the **text** report only (`report_text.rb:24`), and
does not change the exit code.

## The workflow helper

`scripts/brakeman_helper.rb` wraps the invocations a review repeats. It takes the
workflow as a positional argument, so brakeman's own flag letters keep their
meanings, and it passes every argument as a separate array element, so no path
reaches a shell.

```bash
ruby "${CLAUDE_PLUGIN_ROOT}/skills/brakeman/scripts/brakeman_helper.rb" --help

# Full scan: HTML, JSON, and the controller listing
ruby "${CLAUDE_PLUGIN_ROOT}/skills/brakeman/scripts/brakeman_helper.rb" \
  initial-audit -p . -o tmp/brakeman

# JSON plus a per-warning-type summary, for a build log
ruby "${CLAUDE_PLUGIN_ROOT}/skills/brakeman/scripts/brakeman_helper.rb" \
  ci-check -p . --confidence 2
```

Workflows: `initial-audit`, `quick-check`, `ci-check`, `compare`, `interactive`,
`report-only`, `all-warnings`.

Three properties matter when reading its output. It resolves the project's
`bin/brakeman` first, then `bundle exec brakeman`, then `brakeman` from `PATH`,
and prints which one it chose — so the scan matches CI's rather than whichever
gem is global. It checks the scan's exit status before summarising, and names the
code: a run that ends `Scan FAILED: exit 5` lists the reports that were **not**
written instead of claiming success. And `report-only` counts warnings from the
JSON, because `--no-exit-on-warn` makes exit 0 stop meaning "clean".

On a project with `bin/ci`, use `bin/ci` for the gate and the helper for
exploratory scans.

## What Brakeman does not check

Naming these keeps a clean report from being read as a clean application.

- **SSRF.** There is no SSRF check in 8.0.5 — none of the 88 files under
  `lib/brakeman/checks/` mentions it, and `rg -in 'ssrf|server.side.request' lib/`
  returns nothing. `Net::HTTP.get(URI(params[:url]))` and
  `URI.open(params[:url])` both scan clean.
- **XML entity expansion.** No check reads Nokogiri's parse options.
  `Nokogiri::XML(untrusted) { |c| c.noent.dtdload.huge }` scans clean. Nokogiri's
  default is safe — `parse_options.rb:75-77` records `noent` as "Off by default"
  with the comment "⚠ This option enables entity substitution, contrary to what
  the name implies" — so grep for the departures from that default: `.noent`,
  `.dtdload`, `.huge`, and `Nokogiri::XSLT` given an untrusted stylesheet.
- **Missing authentication or authorization.** The `Authentication`
  `warning_type` comes from `CheckSecrets` (optional; a credential in source) and
  `CheckSkipBeforeFilter` (a `skip_before_action` naming an auth filter). Nothing
  looks for an action that should have required a session, or for a record
  fetched without scoping to the current user. The `security-audit` skill owns the scoping
  review, in its "Broken access control" section; `authentication-flow` owns whether an action
  should have required a session, in "The API you get".
- **Vulnerable gem versions.** Brakeman has no CVE database. Its
  `Unmaintained Dependency` warning compares your Rails and Ruby versions against
  end-of-life dates (`check_eol_rails.rb:16-29`), whose newest Rails entry is
  `8.0.0-8.0.99` — so it stays quiet on a Rails 8.1 app. `bin/bundler-audit` is
  the CVE scan.

## Reducing noise

Reach for these in this order, and prefer the narrowest one that works.

1. **A precise ignore entry with a note** for a warning you have examined.
2. **`--safe-methods`** to register a sanitizer Brakeman does not know. In a YAML
   config the values must be written as symbols; see
   `references/reducing_false_positives.md`.
3. **`--skip-files path/`** for generated or vendored code. Values are escaped
   into a regex (`app_tree.rb:37-55`), so give literal paths — a `*` matches a
   literal asterisk. Directories are application-relative and end in `/`.
4. **`-x CheckName`** only when a whole check is inapplicable, remembering that a
   committed exclusion also excludes future improvements to that check.

`--faster` sets `ignore_ifs` and `disable_constant_tracking`
(`options.rb:136-139`). It trades accuracy for speed; use it for a quick local
loop and let CI run the full scan.

For warnings on model attributes, `--ignore-model-output` treats every model
attribute as XSS-safe. That is a class-wide suppression, so escape at the
render site first and keep the flag for the case where you have established that
the column cannot carry markup.

## Resources

### references/command_options.md
Every flag, output format and configuration-file key at 8.0.5, with the option
names and the config keys that are easy to get wrong. It also carries the exit
codes a build reads, the Rails version mode, and a recipes section for the CI and
pre-commit runs.

### references/warning_types.md
All 37 `warning_type` strings Brakeman 8.0.5 can emit, each with its check class,
warning code, optional-or-default status, and version window.

### references/reducing_false_positives.md
Ten strategies for a warning you believe is wrong: triage by confidence, the
refactorings that make Brakeman stop flagging the code, the guarantee written into
the code itself, safe-method registration, the ignore file's real shape, and the
enforcement flags. It closes with the warnings that are never false positives.
