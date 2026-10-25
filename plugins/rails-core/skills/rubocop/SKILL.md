---
name: rubocop
description: >-
  RuboCop, the Ruby static analyzer and formatter — how to run it, read an
  offense, configure `.rubocop.yml`, and apply safe autocorrection. Covers
  `rubocop-rails-omakase` (the Rails 8 default), `.rubocop_todo.yml` and
  `--auto-gen-config`, and the Rails, RSpec, and Performance extensions.
when_to_use: >-
  Use when the user names RuboCop or omakase, asks to lint or format Ruby, asks
  about a cop or an offense, wants to edit `.rubocop.yml`, wants to disable a
  rule, wants to generate or shrink a `.rubocop_todo.yml`, or wants a style
  check in CI.
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/rubocop/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against:
    rubocop: 1.89.0
    rubocop-ast: 1.50.0
    rubocop-rails: 2.36.0
    rubocop-rspec: 3.7.0
    rubocop-performance: 1.26.1
    rubocop-rails-omakase: 1.1.0
    ruby: 3.4.5
    rails: 8.1.3.1
---

# RuboCop

RuboCop is Ruby's static analyzer and formatter. Cops are grouped into
departments (`Style`, `Layout`, `Lint`, `Metrics`, `Naming`, `Security`,
`Gemspec`, `Bundler`) and extensions add more (`Rails`, `RSpec`,
`Performance`).

## Start here: what is actually enabled

**Read the project's `.rubocop.yml` before advising anything.** Which cops run
is decided by that file, and on a Rails 8 app it is almost always this, in full:

```yaml
# Omakase Ruby styling for Rails
inherit_gem: { rubocop-rails-omakase: rubocop.yml }
```

`rubocop-rails-omakase` 1.1.0 disables **every department** and then re-enables
**43 individual cops** — 30 `Layout`, 9 `Style`, 3 `Lint`, 1 `Performance`. Four
consequences follow, all verified by invocation at rubocop 1.89.0:

- **Every `Metrics` cop is off.** `rubocop.yml:23-24` is `Metrics:` /
  `Enabled: false`, and no `Metrics` cop is among the 43. A `Max:` you write for
  one changes nothing until you also enable it.
- **Every `Rails` cop is off**, even though omakase loads `rubocop-rails` as a
  plugin. Two `Rails/*` cops carry an `Include:` in omakase but no
  `Enabled: true`, so they stay off too.
- **Double quotes, not single.** `Style/StringLiterals` is
  `EnforcedStyle: double_quotes`.
- **`Style/StringLiterals` does not reach `spec/`.** Its `Include:` is
  `app/**/*`, `config/**/*`, `lib/**/*`, `test/**/*`, `Gemfile` — omakase is
  written for Minitest, so an RSpec project's `spec/` directory is outside every
  quote-style check.

**Invoke it through the project.** Rails 8 ships `bin/rubocop`, which prepends
`--config <app root>/.rubocop.yml` and loads the bundled gem. Use `bin/rubocop`
when it exists, otherwise `bundle exec rubocop`. A bare `rubocop` resolves
whichever version is first on `PATH`, which is frequently not the bundle's.

```bash
bin/rubocop            # the project's config, the bundle's rubocop
bin/rubocop app spec   # scoped to paths
bundle exec rubocop    # when there is no binstub
```

Rails 8's `bin/ci` runs `bin/rubocop` as its `Style: Ruby` step, so its exit
code is a merge gate.

### Re-enabling cops one at a time

Cop-level settings beat the inherited department-level disable, so name the cops
you want rather than re-enabling a department:

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

# Enable one cop at a time; each states its own reason to exist.
Metrics/MethodLength:
  Enabled: true
Rails/ApplicationRecord:
  Enabled: true
```

Writing `Metrics: Enabled: true` or `Rails: Enabled: true` instead switches on
every cop in the department that ships enabled, which lands a large unreviewed
diff on the next `-a`. For `Rails` that is 62 cops, measured — the 62 of
rubocop-rails' 138 that carry `Enabled: true`. It does not reach the 64 marked
`pending`; those need `AllCops: NewCops: enable`.

For a one-off measurement without changing any file, `--only` overrides the
inherited disable:

```bash
# The cop runs even though Metrics: Enabled: false is in force, and reports
# each offense as [actual/Max] — "Method has too many lines. [12/10]".
bin/rubocop --only Metrics/MethodLength
```

`--only` overrides a per-directory disable the same way, so it is a measurement
tool rather than a way to preview what the project's config does.

## Running it

```bash
bin/rubocop                                   # whole project
bin/rubocop app spec lib/important_file.rb    # scoped
bin/rubocop --only Style/StringLiterals       # one cop
bin/rubocop --only Layout                     # one department
bin/rubocop --except Metrics/MethodLength     # all but one cop
bin/rubocop --lint                            # Lint department only
bin/rubocop --display-only-correctable        # only what -a or -A could fix
```

`--only` and `--except` are command-line flags. There is no `AllCops: Only:` or
`AllCops: Except:` config key; RuboCop prints
`Warning: AllCops does not support Only parameter.` and then ignores it.

**Confirm a department name resolves before trusting a clean result.** With no
`rubocop-rails` plugin loaded, `rubocop --only Rails` writes
`Unrecognized cop or department: Rails.` to **stderr** while **stdout** reads
`0 files inspected, no offenses detected`. The exit code is 2, so a shell `if`
catches it, but a reader who has captured only stdout sees a clean run. Check
the exit code, or run `--show-cops Rails/ApplicationRecord` first.

Parallelism is on by default (`-P`). `PARALLEL_PROCESSOR_COUNT=2 bin/rubocop`
limits it.

## Reading an offense

```
app/models/user.rb:15:3: C: [Correctable] Style/StringLiterals: Prefer double-quoted strings...
  name = 'John Doe'
         ^^^^^^^^^^
```

- `app/models/user.rb:15:3` — file, line, column.
- `C:` — severity: `I` info, `R` refactor, `C` convention, `W` warning,
  `E` error, `F` fatal.
- `[Correctable]` — `-a` or `-A` can fix it.
- `Style/StringLiterals` — department and cop.

**Convention is the severity of the overwhelming majority of cops**, including
almost every cop omakase enables. That matters for `--fail-level`; see CI below.

## Autocorrection

```bash
bin/rubocop -a                              # safe corrections only
bin/rubocop -x                              # Layout department, safe only
bin/rubocop -A --only Performance/Detect    # one unsafe cop, deliberately
```

`-a` applies corrections marked `SafeAutoCorrect: true`. `-A` additionally
applies corrections RuboCop itself marks as able to change behaviour.

**Run `-A` one cop at a time, with a clean working tree, and read the diff
before you keep it.** `bin/rubocop -A` across a project rewrites semantics in
files nobody asked you to touch. The safe sequence is: `-a` first, read every hunk
of `git diff`, run the tests, then `-A --only <one cop>`, read every hunk again,
and run the tests again. A red run after either correction means
`git checkout -- .`, not a fix layered on top.

Per-cop `AutoCorrect: false` stops a cop being corrected while still reporting
it. `AllCops: AutoCorrect: false` does **not** work — it passes validation and
has no effect, because `AllCops` is never merged into per-cop config.

```yaml
Style/StringLiterals:
  Enabled: true       # keep reporting
  AutoCorrect: false  # but never rewrite
```

Details, and the individual cops whose corrections need review, are in
[Autocorrect Guide](references/autocorrect_guide.md) (~270 lines).

## Configuring `.rubocop.yml`

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

AllCops:
  NewCops: enable       # opt new cops in rather than leaving them pending
  Exclude:
    - 'db/schema.rb'
    - 'vendor/**/*'
    - 'node_modules/**/*'

Style/StringLiterals:
  EnforcedStyle: double_quotes
```

**Leave `TargetRubyVersion` unset.** RuboCop reads it from
`.ruby-version`, `mise.toml`, `.tool-versions`, the gemspec or `Gemfile.lock`,
in that order. On a project whose `.ruby-version` is `3.4.5` it reports
`analyzing as Ruby 3.4` with nothing configured; pinning `3.2` downgrades the
parser to 3.2, which both suppresses the 3.3-and-3.4-only cops and lets syntax
through that those cops exist to flag. `TargetRailsVersion` behaves the same
way, read from `Gemfile.lock`.

`inherit_from:` composes local files, `inherit_gem:` composes a gem's config,
and a child setting overrides its parent. **A per-cop `Exclude:` replaces the
inherited array rather than adding to it** — see
[Configuration Guide](references/configuration_guide.md) (~610 lines) for
`inherit_mode`, discovery order, per-directory configs, and the full `AllCops`
parameter list.

### `rubocop --init`

`--init` writes a starter `.rubocop.yml` **into the current working directory**,
unconditionally, with no prompt. Run it from the app root and nowhere else, and
skip it entirely on a Rails 8 app, which already generated one.

## Thresholds

RuboCop's defaults are the source for every number below, at 1.89.0, and they
are **ceilings that earn a review comment** — not design targets. For the
smaller number you aim at while writing, and for deciding when a long method
should become a new object, the `rails-core:extraction-timing` skill owns the
extraction triggers in its "Extraction Thresholds" section; this skill owns what the
tool measures.

| Cop | Default | Unit |
|---|---|---|
| `Metrics/MethodLength` | 10 | lines of method body, comments not counted (`CountComments: false`) |
| `Metrics/ClassLength` | 100 | lines |
| `Metrics/ModuleLength` | 100 | lines |
| `Metrics/BlockLength` | 25 | lines |
| `Metrics/BlockNesting` | 3 | levels |
| `Metrics/ParameterLists` | 5 | parameters, **keyword arguments included** (`CountKeywordArgs: true`) |
| `Metrics/AbcSize` | 17 | assignments + branches + conditions, as a magnitude |
| `Metrics/CyclomaticComplexity` | 7 | independent paths |
| `Metrics/PerceivedComplexity` | 8 | paths, weighted for how they read |
| `Layout/LineLength` | 120 | characters |
| `RSpec/ExampleLength` | 5 | lines per example (rubocop-rspec 3.7.0) |

Two things to say out loud when you cite one of these. First, **all nine
`Metrics` cops are disabled on an omakase project**, so the numbers describe a
review standard rather than a gate until the cops are enabled. Second, raise a
`Max:` only with a reason in the same commit; a raised threshold with no stated
reason is indistinguishable from an unmeasured one.

## The todo-file workflow

This is the thing RuboCop does that reading the code cannot: it partitions
existing offenses from new ones, so a project can adopt a cop today and fix its
backlog later.

```bash
bin/rubocop --auto-gen-config       # writes .rubocop_todo.yml
bin/rubocop -a --auto-gen-config    # fix what is safely fixable first, then record the rest
```

```yaml
# .rubocop.yml
inherit_from: .rubocop_todo.yml
```

The generated file excludes the offending files per cop, so the cop is live for
every new file immediately. Shrink it one cop at a time:

```bash
bin/rubocop -a --only Style/StringLiterals
# review, test, commit, delete that cop's entry from .rubocop_todo.yml
```

`--auto-gen-config` also writes a `Max:` for a `Metrics` cop when raising the
threshold removes fewer offenses than excluding the files. Treat any such `Max:`
as a number with no source — it records the code as it happened to be on the day
the file was generated.

## CI

**Plain `rubocop` already exits 1 when any offense is found.** That is the
gate; you do not need a flag for it.

```bash
bin/rubocop                                        # exit 1 on any offense
bin/rubocop --format json --out tmp/rubocop.json   # machine-readable report
bin/rubocop --format html --out tmp/rubocop.html
```

`--fail-level warning` **raises** the bar to warning severity, so every
convention offense stops counting. Measured on a real app with one
`Style/TrailingCommaInHashLiteral` offense: plain `bin/rubocop` exits 1, and
`bin/rubocop --format progress --fail-level warning` exits 0 while printing the
same offense. Since convention is the severity of nearly every cop, adding that
flag turns the step green on almost everything it was added to catch. Use
`--fail-level` only to make CI *stricter* — `--fail-level refactor` or
`--fail-level info` — or leave it off.

To check only staged Ruby files in a hook:

```bash
staged=$(git diff --name-only --cached -- '*.rb')
[ -n "$staged" ] && bin/rubocop --force-exclusion $staged
```

`--force-exclusion` makes RuboCop honour `AllCops: Exclude:` for paths named
explicitly on the command line, which it otherwise ignores.

## Troubleshooting

**`Error: unrecognized cop or department X found in .rubocop.yml`** — RuboCop
exits 2 and inspects nothing. Either the cop's plugin is not loaded (add it to
`plugins:`), or the name is wrong, or it is not a cop at all. RuboCop suggests
the nearest real name; `Rails/MigratedSchemaVersion`, for instance, is an
`AllCops` parameter rather than a cop.

**`Error: 'X' cops have been extracted to the 'rubocop-X' gem`** — same exit 2.
A `Rails:` or `RSpec:` or `Performance:` key in your config requires the
matching plugin be loaded, and omakase already loads `rubocop-rails` and
`rubocop-performance` for you.

**`Error: The 'X' cop has been split into ...`** or **`... has been removed`** —
exit 2. Replace the key with the names in the message; RuboCop will not guess
which of a split cop's successors you meant.

**`Warning: The 'X' cop has been renamed to 'Y'`** — a warning, not an error.
The run continues and your settings are applied to the new name, so this is stale
config that still works. Rename it anyway.

**`'X' is concealed by line N`** — you declared the same cop twice in one YAML
file, and only the last block survives. YAML discards the earlier key before
RuboCop sees it.

**A cop you configured is not firing** — check whether it is enabled, not just
present: `bin/rubocop --show-cops Metrics/MethodLength` prints the effective
config after inheritance. `--show-cops` takes cop names, not department names;
`--show-cops Style` prints nothing at all.

**Which config is in effect** — `bin/rubocop --debug` prints the full
inheritance chain, each file in order, before it inspects anything.

**Slow runs** — `UseCache: true` and `MaxFilesInCache: 20000` are already the
defaults, so setting them changes nothing; *lowering* `MaxFilesInCache` prunes
the cache sooner and makes runs slower. What helps is excluding generated files
and scoping the run to paths.

## References

- [Configuration Guide](references/configuration_guide.md) (~610 lines) —
  discovery order, inheritance and merge rules, `AllCops`, per-directory
  configs, recipes.
- [Cop Reference](references/cop_reference.md) (~470 lines) — the departments,
  their notable cops, and the defaults worth quoting.
- [Autocorrect Guide](references/autocorrect_guide.md) (~270 lines) — safe
  versus unsafe corrections, and the specific cops whose corrections need
  review.
- [Extensions Guide](references/extensions_guide.md) (~160 lines) — which
  extension gems a Rails 8 project already has, and how their config differs
  from core.
- [Custom Cops Guide](references/custom_cops_guide.md) (~180 lines) — writing a
  project cop, its node pattern, and its spec.
