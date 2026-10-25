# Brakeman command options — brakeman 8.0.5

Every option below is present in `brakeman --help` at 8.0.5 and was confirmed by
invocation. `options.rb` line numbers are given where the behaviour is not
obvious from the name. When in doubt, `brakeman --help` is the authority for this
gem version, and `brakeman <your flags> -C` prints the configuration-file
equivalent of whatever you just typed.

Exit codes have one home: `SKILL.md`.

## Paths and what gets scanned

| Option | Effect |
|---|---|
| `-p, --path PATH` | Application root. Defaults to the last bare argument, else `.` |
| `--force-scan` | Scan even when Rails is not detected, instead of exiting 4 |
| `--gemfile GEMFILE` | Use this Gemfile for version detection. `BUNDLE_GEMFILE` sets it too (`brakeman.rb:160`) |
| `--only-files p1,p2` | Scan only these files and directories. Directories are application-relative and end in `/` |
| `--skip-files p1,p2` | Skip these. Same directory rule |
| `--[no-]skip-vendor` | `vendor/` is skipped by default |
| `--add-libs-path p1,p2` | Treat an extra application-relative directory as library code, e.g. `app/mailers` |
| `--add-engines-path p1,p2` | Include these engines. Default is `engines/*` |
| `--[no-]follow-symlinks` | Off by default |

`--only-files` and `--skip-files` values go through `Regexp.escape`
(`app_tree.rb:37-55`), so write literal paths. A `*` matches a literal asterisk;
give the directory prefix instead of a glob.

## Which checks run

| Option | Effect |
|---|---|
| `-t, --test Check1,Check2` | Run only these checks |
| `-x, --except Check1,Check2` | Skip these checks |
| `-E, --enable Check1,Check2` | Add these optional checks to the default set |
| `-A, --run-all-checks` | Run every default and optional check |
| `-k, --checks` | List all checks and exit |
| `--optional-checks` | List the optional checks and exit |
| `--add-checks-path p1,p2` | Load extra out-of-tree checks from these directories |

Names given to `-t`, `-x` and `-E` are written **without** the `Check` prefix —
`SQL`, `CrossSiteScripting`, `Execute` — and the option parser adds it
(`options.rb:245-262`). A name that resolves to nothing exits 6 with
`Could not find specified check`. In a YAML config the same names need the
prefix; see the configuration section.

The seven optional checks at 8.0.5, from `--optional-checks`:
`CheckDivideByZero`, `CheckForceSSL`, `CheckReverseTabnabbing`, `CheckSecrets`,
`CheckSymbolDoS`, `CheckUnscopedFind`, `CheckWeakHash`.

`warning_types.md` (beside this file) maps every `warning_type` string to its check
class, which is what these options take.

## Confidence

| Option | Effect |
|---|---|
| `-w, --confidence-level LEVEL` | `1` keeps High, Medium and Weak (the default); `2` keeps High and Medium; `3` keeps High |

`options.rb:381-387` stores `min_confidence = 3 - level`, so the config-file key
`:min_confidence:` takes the inverted value: `-w2` is `:min_confidence: 1`, and
`:min_confidence: 2` is the default, meaning every warning.

The report prints the three levels as `High`, `Medium` and `Weak`
(`report_text.rb:220`). Grep for `Weak`.

## Reducing false positives

| Option | Effect |
|---|---|
| `-s, --safe-methods m1,m2` | These methods return output safe to render unescaped |
| `--url-safe-methods m1,m2` | These methods return a URL safe for `link_to`'s href |
| `--sql-safe-methods m1,m2` | Input wrapped in these is safe in a SQL fragment |
| `--ignore-model-output` | Treat every model attribute as XSS-safe |
| `--ignore-protected` | Treat models using `attr_protected` as mass-assignment safe |
| `-r, --report-direct` | Report **only** direct use of untrusted data. Sets `check_arguments = false`, so it reports strictly less |
| `-e, --escape-html` | Assume the application escapes HTML by default |
| `-a, --[no-]assume-routes` | Assume every public controller method is an action. On by default |

`-s` is `--safe-methods`. `--summary` has no short form, so `brakeman -s` on its
own reports a missing argument (`options.rb:185` and `:349`).

## Ignore configuration

| Option | Effect |
|---|---|
| `-i, --ignore-config FILE` | Ignore file to apply. Defaults to `config/brakeman.ignore` |
| `-I, --interactive-ignore` | Walk the warnings and write the ignore file. Needs a TTY |
| `--show-ignored` | Add the ignored warnings to the **text** report (`report_text.rb:24`). Does not change the exit code |
| `--ensure-ignore-notes` | Exit 8 when an ignore entry's `note` is empty or whitespace only. A missing `note` key raises `NoMethodError` instead |
| `--ensure-no-obsolete-ignore-entries` | Exit 9 when an entry matches nothing in the current code |

`-I` uses HighLine, which is vendored inside the gem under
`brakeman-8.0.5/bundle/` and loaded by `Brakeman.load_brakeman_dependency`, so it
needs no extra gem. The JSON and HTML reports carry `ignored_warnings` whether or
not `--show-ignored` is given, so the flag is only useful with the text report.

`SKILL.md` covers what a single ignore entry actually suppresses.

## Exit behaviour and version

| Option | Effect |
|---|---|
| `-z, --[no-]exit-on-warn` | Non-zero exit when warnings remain. On by default |
| `--[no-]exit-on-error` | Non-zero exit when a file fails to parse or a check raises. On by default |
| `--ensure-latest [DAYS]` | Exit 5 **before scanning** when a newer gem exists. `DAYS` requires the newer release to be at least that old (`options.rb:71`, `brakeman.rb:422-439`) |

`--ensure-latest 7` is the useful form for CI: it fails the build a week after a
release rather than the hour it lands.

`--no-exit-on-error` makes a parse failure or a timeout produce a passing build,
which is the case where the scan told you least. Prefer leaving it on and fixing
the file, or excluding just that file with `--skip-files`.

## Output and reports

| Option | Effect |
|---|---|
| `-o, --output FILE` | Destination. Repeatable; format inferred from the extension |
| `-f, --format TYPE` | State the format explicitly |
| `--text-fields f1,f2` | Choose the fields the text report prints, e.g. `category,check,confidence,code,file,line` |
| `--[no-]color` | ANSI colour. On by default when the output is a terminal; `--color` forces it on |
| `--[no-]pager` | Page terminal output. On by default; `CI=true` also disables it (`pager.rb:71-75`) |
| `-q, --[no-]quiet` | Drop the informational messages. The report still prints |
| `--[no-]summary` | Print only the warning-count summary |
| `--table-width WIDTH` | Cap the text report's table width |
| `--message-limit LENGTH` | Cap message length in the HTML report. Default 100 |
| `--absolute-paths` | Absolute file paths in reports |
| `--github-repo USER/REPO[/PATH][@REF]` | Link warnings to GitHub in markdown and HTML output. There is no negated form |
| `--css-file FILE` | CSS for HTML output |
| `--[no-]highlights` | Highlight the user input inside the reported code. On by default |
| `-m, --routes` | Add the controller listing to the report |
| `-l, --[no-]combine-locations` | Combine warning locations. On by default |
| `--[no-]separate-models` | Warn once per model without `attr_accessible`. On by default |
| `--compare FILE` | Diff against a previous JSON scan; prints `{"new":[],"fixed":[],"obsolete":[]}` |

Accepted `-f` values (`options.rb:285`): `text`, `plain`, `html`, `csv`, `tabs`,
`table`, `json`, `markdown`, `junit`, `codeclimate`, `cc`, `sonar`, `sarif`,
`github`, `pdf`. Anything the dispatcher does not recognise falls through to text
(`brakeman.rb:275-306`).

`-m` is `--routes`, and it reports **controller** information — which controllers
and actions Brakeman found — not the route table.

Passing `-f` together with more than one `-o` raises
`Cannot specify output format if multiple output files specified`
(`brakeman.rb:257-259`). Use one `-o` per format and let the extension decide.

## Speed and diagnostics

| Option | Effect |
|---|---|
| `--faster` | Sets `ignore_ifs` and `disable_constant_tracking` (`options.rb:136-139`) |
| `--no-branching` | Sets `ignore_ifs` alone |
| `--branch-limit LIMIT` | Depth of values tracked through branches, not a count of branches (`alias_processor.rb:32`, `@or_depth_limit`). Default 5; `-1` removes the limit |
| `--interprocedural` | Follow calls into known methods. More thorough, so it usually produces **more** warnings |
| `--parser-timeout SECONDS` | Per-file parse timeout. Default 10 |
| `--[no-]prism` | Use the Prism parser. On by default |
| `-n, --no-threads` | Run checks and parsing sequentially |
| `--[no-]progress` | Progress reporting |
| `--timing` | Print how long each scan step took (`options.rb:279`) |
| `-d, --debug` | Verbose internals |
| `-v, --version` | Print the version and exit |
| `-h, --help` | Print the options and exit |

To find a slow step, use `--timing`. For a slow file, raise `--parser-timeout`
before excluding the file.

## Rails version mode

`-3`, `-4`, `-5`, `-6`, `-7`, `-8` force Rails 3 through Rails 8 mode
(`options.rb:112-119`). The version is normally read from the Gemfile or lockfile,
so reach for these only when detection fails. `-8`/`--rails8` is the mode for
this stack.

`-r` is `--report-direct`, not a Rails-3 switch. It runs a quieter scan without
complaint, so a stray `-r` reduces coverage silently.

## Configuration files

Search order (`brakeman.rb:206-222`), first hit wins:

1. the path given to `-c, --config-file FILE`
2. `<app>/config/brakeman.yml`
3. `~/.brakeman/config.yml`
4. `/etc/brakeman/config.yml`

Command-line options override the file.

**Generate the file rather than writing it.** `-C, --create-config [FILE]` prints
the exact config for the flags you just gave, so the keys, the inversion of `-w`,
and the symbol-vs-string question all resolve themselves:

```bash
$ brakeman -w2 -s scrub_html --skip-files vendor/ -C
---
:app_path: "/path/to/app"
:min_confidence: 1
:safe_methods:
- :scrub_html
:skip_files:
- vendor/
```

With no argument `-C` writes to stdout; with a path it writes that file.

### Keys, and the two that fail quietly

`brakeman.rb:168-182` merges the loaded YAML into the options hash without
validating it, so an unrecognised key is accepted and ignored.

| Key | Value shape |
|---|---|
| `:app_path:` | string |
| `:min_confidence:` | `0` High only, `1` High and Medium, `2` everything (the default) |
| `:output_files:` | list of paths; format inferred per extension |
| `:output_format:` | a **symbol**, e.g. `:json` |
| `:run_checks:` / `:skip_checks:` | check class names **with** the `Check` prefix |
| `:safe_methods:` / `:url_safe_methods:` / `:sql_safe_methods:` | lists of **symbols**, e.g. `- :scrub_html` |
| `:skip_files:` / `:only_files:` | list of literal paths; directories end in `/` |
| `:ignore_file:` | path to the ignore file |
| `:exit_on_warn:` / `:exit_on_error:` | booleans, both `true` by default |
| `:quiet:` / `:pager:` / `:report_progress:` | booleans |
| `:parser_timeout:` / `:branch_limit:` / `:message_limit:` | integers |
| `:ignore_model_output:` / `:ignore_attr_protected:` | booleans. `--ignore-protected` sets the second one |
| `:skip_vendor:` | boolean, `true` by default |
| `:interprocedural:` / `:ignore_ifs:` | booleans |

The defaults live in `Brakeman.default_options` (`brakeman.rb:225-252`).

Two keys need care because getting them wrong produces no message:

- **Confidence is `:min_confidence:`.** `:confidence_level:` is not an option —
  `rg confidence_level lib/` returns nothing — so it is merged, ignored, and the
  default `:min_confidence: 2` stands, which is every warning. Verified: a config
  of `:confidence_level: 2` still reported the Weak warnings that
  `:min_confidence: 1` removed.
- **`:output_format:` takes a symbol.** `get_formats_from_output_format` cases on
  symbols (`brakeman.rb:275-306`), and YAML `json` loads as a String, so it falls
  through to `[:to_text]`. Verified: `:output_format: json` printed a text
  report and `:output_format: :json` printed JSON. `safe_load_file` permits
  `Symbol` (`brakeman.rb:175`), so write `:json`.

Check names have the same asymmetry: `-t SQL` works because the parser adds the
prefix, while `:run_checks: [SQL]` exits 6 with
`Could not find specified checks: 'SQL', 'CrossSiteScripting'`. Verified:
`:run_checks: [CheckSQL, CheckCrossSiteScripting]` runs those two.

## Environment variables

Brakeman 8.0.5 reads exactly two:

| Variable | Effect |
|---|---|
| `BUNDLE_GEMFILE` | Used as `--gemfile` when `--gemfile` is not given (`brakeman.rb:160-161`) |
| `CI` | The string `true` disables the pager (`pager.rb:71-75`) |

There is no environment variable for debug, for skipping libraries, or for any
other option. Pass flags, or use a config file.

## Option names that changed or never existed

Older notes and blog posts carry these. The right-hand column is what 8.0.5
accepts.

| If you have seen | Use |
|---|---|
| `--skip-libs` | `--faster`, which sets `ignore_ifs` and `disable_constant_tracking`, or `--skip-files lib/` |
| `--print-config` | `-C, --create-config [FILE]` |
| `--compare-branch`, `--compare-base` | `--compare FILE` against a JSON report you saved from the base commit |
| `--report-routes` | `-m, --routes`, which reports controllers |
| `--no-github-repo` | omit `--github-repo` |
| `-r` for Rails 3 mode | `-3, --rails3`. `-r` is `--report-direct` |
| `-s` for summary | `--summary`. `-s` is `--safe-methods` |
| `BRAKEMAN_DEBUG`, `BRAKEMAN_SKIP_LIBS` | `-d`, and `--faster` |
| `CommandInjection` as a check name | `Execute`. The `warning_type` string is `Command Injection` |
| `Authentication` or `Authorization` as a check name | `Secrets` and `SkipBeforeFilter` emit the `Authentication` warning type; there is no authorization check |
| `grep "Check time"` | `--timing` |

## Recipes

```bash
# Local pass, everything visible
brakeman -A -w1 --no-pager

# What the Rails 8.1 config/ci.rb step runs
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error

# HTML to read plus JSON to diff against later
brakeman -o tmp/brakeman.html -o tmp/brakeman.json

# GitHub code scanning
brakeman -f sarif -o tmp/brakeman.sarif

# Fast inner loop
brakeman --faster -w2 -q

# Enforce the ignore-file hygiene the team agreed to
brakeman --ensure-ignore-notes --ensure-no-obsolete-ignore-entries

# Fail once a newer release has been out a week
brakeman --ensure-latest 7
```
