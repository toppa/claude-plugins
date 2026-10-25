# RuboCop Configuration Guide

Configuring RuboCop, verified against rubocop 1.89.0, rubocop-rails 2.36.0,
rubocop-rspec 3.7.0, rubocop-performance 1.26.1 and rubocop-rails-omakase 1.1.0
on Ruby 3.4.5 / Rails 8.1.3.1.

## Which config file RuboCop uses

`ConfigFinder#find_config_path` tries these in order and takes the first that
exists (`config_finder.rb:21-23`):

1. `.rubocop.yml`, searching from the inspected directory upwards, stopping at
   the project root
2. `<project root>/.config/.rubocop.yml`, then
   `<project root>/.config/rubocop/config.yml`
3. `~/.rubocop.yml`
4. `$XDG_CONFIG_HOME/rubocop/config.yml`, defaulting to
   `~/.config/rubocop/config.yml`
5. RuboCop's bundled `config/default.yml`

**The home dotfile outranks the XDG config**, which is the reverse of what most
tools do.

### How the project root is found

`find_project_root` looks for the outermost **`Gemfile`** or **`gems.rb`** above
the working directory and takes its directory (`config_finder.rb:31-37`).
**`.git` is never consulted**, and there is no `AllCops: RootDirectory:`
parameter — writing one produces
`Warning: AllCops does not support RootDirectory parameter.` and is ignored. A
Ruby directory with no `Gemfile` therefore has no project root, and the upward
search for `.rubocop.yml` does not happen at all.

Use `--config path/to/file.yml` to bypass discovery entirely; that is what Rails
8's `bin/rubocop` binstub does.

## `AllCops`

```yaml
AllCops:
  # Leave TargetRubyVersion unset. RuboCop reads it from .ruby-version,
  # mise.toml, .tool-versions, the gemspec or Gemfile.lock, in that order.
  # Pinning it below the project's real version downgrades the parser and
  # silently disables the cops that only apply to newer syntax.

  # Opt new cops in rather than leaving them pending.
  NewCops: enable  # enable | disable | pending

  Exclude:
    - 'db/schema.rb'
    - 'vendor/**/*'
    - 'node_modules/**/*'
    - 'tmp/**/*'

  Include:
    - '**/*.rb'
    - '**/*.rake'
    - '**/Gemfile'
    - '**/Rakefile'

  DisplayStyleGuide: false
  StyleGuideBaseURL: https://rubystyle.guide
  ExtraDetails: false
```

`AllCops` accepts a fixed set of parameters, and RuboCop warns and ignores
anything else. Ask it for the current list rather than guessing: put a nonsense
key under `AllCops` and the warning prints every supported parameter. At 1.89.0
they are `RubyInterpreters`, `Include`, `Exclude`, `DefaultFormatter`,
`DisplayCopNames`, `DisplayStyleGuide`, `StyleGuideBaseURL`,
`DocumentationBaseURL`, `DocumentationExtension`, `ExtraDetails`,
`StyleGuideCopsOnly`, `EnabledByDefault`, `DisabledByDefault`, `NewCops`,
`UseProjectIndex`, `ProjectIndexIncludesGems`, `UseCache`, `MaxFilesInCache`,
`CacheRootDirectory`, `AllowSymlinksInCacheRootDirectory`, `TargetRubyVersion`,
`ParserEngine`, `SuggestExtensions`, `ActiveSupportExtensionsEnabled`,
`StringLiteralsFrozenByDefault`, `TargetRailsVersion` and
`MigratedSchemaVersion`.

**The list grows with the plugins you load.** The last three of those come from
`rubocop-rails`; in a config without it, `AllCops: MigratedSchemaVersion:`
produces `Warning: AllCops does not support MigratedSchemaVersion parameter.` So
that warning can mean "the plugin is missing" as easily as "no such setting".

**Caching is already on.** `UseCache: true` and `MaxFilesInCache: 20000` are the
defaults (`default.yml:121,124`), so writing them changes nothing.
`MaxFilesInCache` is the number of result-cache entries kept before pruning —
*lowering* it makes runs slower, not faster. `CacheRootDirectory` defaults to
nil, which means `$XDG_CACHE_HOME` or `$HOME/.cache/`.

**Selecting cops is a command-line job.** There is no `AllCops: Only:` or
`AllCops: Except:`; both produce
`Warning: AllCops does not support Only parameter.` and are discarded. Use
`--only` and `--except`.

## Inheritance

```yaml
# Local files, applied in order
inherit_from:
  - .rubocop_todo.yml
  - config/rubocop_base.yml

# A remote URL
inherit_from:
  - https://example.com/rubocop-config.yml

# A gem's shipped config — this is what Rails 8 generates
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
```

### Merge rules

- A child setting **overrides** the parent's for the same key.
- Hash parameters such as `PreferredMethods` are **merged** key by key.
- **Array parameters, including `Exclude` and `Include`, are replaced, not
  merged.** This is the rule most often got wrong; see the `RSpec/DescribeClass`
  example below.
- `~` (nil) cancels an inherited value:

```yaml
Style/CollectionMethods:
  PreferredMethods:
    collect: ~ # drop the parent's preference for this one method
```

To add to an inherited array instead of replacing it, declare `inherit_mode`:

```yaml
plugins:
  - rubocop-rspec

inherit_mode:
  merge:
    - Exclude

RSpec/DescribeClass:
  Exclude:
    - 'spec/support/**/*'   # added to the five paths rubocop-rspec already excludes
```

**Declare each cop exactly once per file.** YAML discards a repeated key before
RuboCop parses it, so only the last block survives. RuboCop notices and prints
`your.yml:3: 'Style/StringLiterals' is concealed by line 8`, but the earlier
block is already gone. To vary one cop by path, use per-directory config files
(below) rather than two blocks in one file.

## Enabling and disabling cops

```yaml
Style/StringLiterals:
  Enabled: true

Style/Documentation:
  Enabled: false

# Department-wide
Metrics:
  Enabled: false
```

**A cop-level `Enabled:` beats a department-level one, whichever config each came
from.** That is the whole mechanism `rubocop-rails-omakase` runs on: it disables
every department, then names 43 cops as `Enabled: true`. It is also how you
re-enable one cop on an omakase project without switching on the other 61 that
ship enabled in its department:

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

Metrics/MethodLength:
  Enabled: true          # this cop only; the rest of Metrics stays off
```

`--only` overrides an inherited disable for a single run, without editing
anything: `bin/rubocop --only Metrics/MethodLength` reports offenses even when
`Metrics: Enabled: false` is in force.

## Excluding files

```yaml
plugins:
  - rubocop-rails   # required before any Rails/* key below

# Globally
AllCops:
  Exclude:
    - 'db/**/*'
    - 'script/**/*'

# Per cop — replaces any inherited Exclude for that cop
Style/StringLiterals:
  Exclude:
    - 'lib/legacy/**/*'
    - 'app/models/old.rb'

# Re-including a path the defaults exclude
Rails/FilePath:
  Include:
    - '**/Gemfile'
    - '**/config.ru'
```

Paths named explicitly on the command line ignore `Exclude` unless you pass
`--force-exclusion`. That flag is what makes a pre-commit hook agree with a full
run.

## Cop-specific configuration

**Enforced styles:**
```yaml
Style/StringLiterals:
  EnforcedStyle: double_quotes  # or: single_quotes

Style/ClassAndModuleChildren:
  EnforcedStyle: nested  # or: compact

Layout/HashAlignment:
  EnforcedHashRocketStyle: key  # or: separator, table
  EnforcedColonStyle: key       # or: separator, table
```

**Thresholds.** Every `Max:` below is RuboCop's own default at 1.89.0, in the
unit named. Write one only to *deviate*, and say why in the same commit.

```yaml
Metrics/MethodLength:
  Max: 10                    # lines of method body; the default
  CountComments: false       # already the default
  AllowedMethods: []

Metrics/ClassLength:
  Max: 100                   # lines; the default
  CountAsOne: ['array', 'hash', 'heredoc']  # count a multi-line literal as 1

Metrics/AbcSize:
  Max: 17                    # assignments + branches + conditions; the default

Metrics/ParameterLists:
  Max: 5                     # the default; keyword args count (CountKeywordArgs: true)
```

**Lists and preferences:**
```yaml
Naming/PredicatePrefix:
  ForbiddenPrefixes:
    - is_
    - has_
    - have_
    - does_        # all four are already the default
  AllowedMethods:
    - is_a?
```

That cop was called `Naming/PredicateName` until it was renamed. RuboCop lists
renames in its own `config/obsoletion.yml` and handles the two cases
differently: a **renamed** cop produces
`Warning: The 'Naming/PredicateName' cop has been renamed to
'Naming/PredicatePrefix'.` and the run continues with your settings applied to
the new name, while a name that was never a cop — `Naming/ClassName`, say — is a
hard error and exit 2. So a warning here means stale but working; an error means
nothing was inspected.

`Style/CollectionMethods` is worth knowing about even though it ships
`Enabled: false` and `Safe: false`: its `PreferredMethods` map is what
`Performance/Detect` consults when it autocorrects, and the shipped map contains
`detect: find`. Reversing it changes what that correction writes.

```yaml
Style/CollectionMethods:
  PreferredMethods:
    detect: find   # the shipped default
```

## Rails configuration

`rubocop-rails` must be loaded before any `Rails` key is legal. **A `Rails:` or
`Rails/*` block with no plugin loaded aborts the run with exit 2 and inspects
nothing:** `Error: 'Rails' cops have been extracted to the 'rubocop-rails' gem.`

On a Rails 8 app, omakase already loads it, so inherit and then name cops:

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

# Leave TargetRailsVersion unset — rubocop-rails reads it from Gemfile.lock,
# and hardcoding an older value disables the cops gated on newer Rails.

# Ignore migrations already run. This is an AllCops parameter, not a cop;
# writing `Rails/MigratedSchemaVersion:` aborts the run with exit 2.
AllCops:
  MigratedSchemaVersion: '20240101000000'

Rails/ApplicationRecord:
  Enabled: true   # one cop, not the whole department

Rails/HasManyOrHasOneDependent:
  Enabled: true

Rails/SkipsModelValidations:
  Enabled: true
  AllowedMethods:
    - touch
```

Without an `inherit_gem` or `plugins:` line, the standalone form is:

```yaml
plugins:
  - rubocop-rails
```

`Rails/ApplicationRecord` already ships `Exclude: db/**/*.rb`, so adding a
migrations exclude to it duplicates the default.

## RSpec configuration

`rubocop-rspec` is a separate gem and is **not** an omakase dependency, so check
the `Gemfile` before writing any `RSpec/*` key.

```yaml
plugins:
  - rubocop-rspec

RSpec/ExampleLength:
  Max: 5                     # the default
  CountAsOne: ['array', 'hash', 'heredoc']

RSpec/MultipleExpectations:
  Max: 1                     # the default

RSpec/NestedGroups:
  Max: 3                     # the default
```

`RSpec/DescribeClass` is the standard illustration of the array-replacement
rule. rubocop-rspec 3.7.0 already excludes `**/spec/features/**/*`,
`**/spec/requests/**/*`, `**/spec/routing/**/*`, `**/spec/system/**/*` and
`**/spec/views/**/*`. Writing a shorter list **narrows** the exclusions:

```yaml
plugins:
  - rubocop-rspec

# Measured: this re-enables the cop for spec/features, spec/routing and
# spec/views, and produces offenses the defaults suppressed.
RSpec/DescribeClass:
  Exclude:
    - 'spec/requests/**/*'
    - 'spec/system/**/*'
```

Add to the defaults instead:

```yaml
plugins:
  - rubocop-rspec

inherit_mode:
  merge:
    - Exclude

RSpec/DescribeClass:
  Exclude:
    - 'spec/support/**/*'
```

`RSpec/FilePath` no longer exists at rubocop-rspec 3.x. Configuring it aborts
the run: `Error: The 'RSpec/FilePath' cop has been split into
'RSpec/SpecFilePathFormat' and 'RSpec/SpecFilePathSuffix'.`

## Performance configuration

```yaml
plugins:
  - rubocop-performance

Performance/Casecmp:
  Enabled: false  # correction only holds for ASCII strings
```

`rubocop-performance` arrives transitively with `rubocop-rails-omakase`, but
omakase disables the department and re-enables only `Performance/FlatMap`.

## Safety annotations

Both are real settings on real cops, shipped in `default.yml`:

```yaml
plugins:
  - rubocop-performance

# The detection itself can be wrong — Style/CollectionMethods ships this
Style/CollectionMethods:
  Safe: false             # skipped by --safe

# The detection is reliable but the correction can change behaviour —
# Performance/Detect ships this
Performance/Detect:
  SafeAutoCorrect: false  # skipped by -a, applied by -A
```

- `rubocop` — every enabled cop
- `rubocop --safe` — only cops without `Safe: false`
- `rubocop -a` — corrections that are not `SafeAutoCorrect: false`
- `rubocop -A` — every available correction

## Severity

```yaml
Style/StringLiterals:
  Severity: warning  # info | refactor | convention | warning | error | fatal
```

The default fail level is **convention**, and convention is the severity of the
overwhelming majority of cops. So `--fail-level warning` *relaxes* CI to the
point of ignoring nearly everything; `--fail-level refactor` or
`--fail-level info` tightens it. Measured against one convention offense:
`--fail-level info`, `refactor` and `convention` all exit 1; `warning` and
`error` exit 0.

## The todo file

```bash
rubocop --auto-gen-config       # write .rubocop_todo.yml
rubocop -a --auto-gen-config    # fix the safely fixable first, record the rest
```

```yaml
# .rubocop.yml
inherit_from: .rubocop_todo.yml
```

The generated file lists each offending file per cop, so the cop stays live for
new code:

```yaml
# Offense count: 2
# This cop supports safe autocorrection (--autocorrect).
Layout/SpaceInsideArrayLiteralBrackets:
  Exclude:
    - 'app/long.rb'
```

For a `Metrics` cop it may instead record the highest value it observed:

```yaml
# Offense count: 1
# Configuration parameters: CountComments, CountAsOne, AllowedMethods, AllowedPatterns.
Metrics/MethodLength:
  Max: 12
```

That number describes the code on the day the file was generated and has no
other source. Shrink it toward the cop's default rather than treating it as the
project's standard.

## Per-directory configuration

This is the supported way to apply one cop differently by path.

```
project/
├── .rubocop.yml          # root
├── app/
│   └── .rubocop.yml
└── spec/
    └── .rubocop.yml
```

**spec/.rubocop.yml:**
```yaml
inherit_from: ../.rubocop.yml

Metrics/BlockLength:
  Enabled: false
```

RuboCop searches upward from each inspected file, so `spec/foo_spec.rb` picks up
`spec/.rubocop.yml` and files elsewhere do not.

## Custom cop metadata

A cop defined in the project is loaded with `require:`, not `plugins:` —
`plugins:` expects a lint_roller plugin class and errors on a plain file path.

```yaml
require:
  - ./lib/rubocop/cop/custom/prefer_new_method.rb

Custom/PreferNewMethod:
  Description: 'Use new_method instead of old_method'
  Enabled: true
  Safe: true
  SafeAutoCorrect: true
```

## Inspecting configuration

There is no `--validate` flag; validation happens on every run, and an invalid
config exits 2 before any file is inspected.

```bash
# Effective config for one cop, after all inheritance
rubocop --show-cops Metrics/MethodLength

# Several at once, comma-separated
rubocop --show-cops Style/StringLiterals,Metrics/AbcSize

# Every cop and its config — around 7,500 lines
rubocop --show-cops

# The inheritance chain, in order, before any inspection
rubocop --debug

# Documentation URL for a cop
rubocop --show-docs-url Style/StringLiterals
```

`--show-cops` takes **cop names only**. `rubocop --show-cops Style` prints
nothing, which reads like "no such department" and is not.

## Recipes

### Rails 8 default, plus the metrics you want measured

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

AllCops:
  NewCops: enable

# omakase disables all of Metrics; name the cops you want back.
Metrics/MethodLength:
  Enabled: true
Metrics/ClassLength:
  Enabled: true
Metrics/AbcSize:
  Enabled: true

Metrics/BlockLength:
  Enabled: true
  Exclude:
    - 'spec/**/*'
    - 'config/routes.rb'
    - 'config/environments/*'
```

### Stricter than omakase

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

AllCops:
  NewCops: enable

Lint:
  Enabled: true      # Lint cops report real bugs; the whole department is worth it
Security:
  Enabled: true      # seven cops in core; NewCops: enable is what picks up the
                     # two that ship pending, Security/CompoundHash and
                     # Security/IoMethods
Metrics:
  Enabled: true      # accepts the nine defaults as written
```

Turning a whole department back on is the one case where the department-level
key is the right tool: you are accepting every default rather than choosing
numbers. Do it in its own commit, because the first `-a` afterwards will be
large.

### Looser for a legacy directory

```yaml
# lib/legacy/.rubocop.yml
inherit_from: ../../.rubocop.yml

Style/Documentation:
  Enabled: false
Metrics:
  Enabled: false
```

Prefer this to a project-wide relaxation, and prefer `.rubocop_todo.yml` to
either: it is the only option that keeps the cop live for new code.

`Style/Documentation` requires a top-level comment on every class and module.
omakase leaves it off, and a project whose convention is that explanations live
in commit messages should leave it off too.

## Troubleshooting

**A cop is not firing.** `rubocop --show-cops <Cop/Name>` and read `Enabled:`.
On an omakase project the answer is usually that its department is disabled.

**`Warning: <X> does not support <Y> parameter.`** Either the key is not real for
that cop, or the plugin that defines it is not loaded — the "`AllCops`" section
above gives `MigratedSchemaVersion` without `rubocop-rails` as that second case.
The warning lists the keys the cop does support. RuboCop continues with the key
ignored, so this is silent in every sense that matters.

**`Error: unrecognized cop or department X`** — exit 2, nothing inspected.
Either a missing plugin, a typo, or not a cop; RuboCop suggests the nearest real
name.

**`'X' is concealed by line N`** — the same cop declared twice in one file.

**Conflicting inheritance** — `rubocop --debug` prints the chain in order.

**Slow runs** — the cache is already on. Exclude generated files, scope the run
to paths, and leave `MaxFilesInCache` alone.
