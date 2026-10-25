# RuboCop Extensions Guide

Which extension gems a project already has, how they get loaded, and the ways
extension configuration differs from core. Cop-by-cop detail is in
[Cop Reference](cop_reference.md); config mechanics are in
[Configuration Guide](configuration_guide.md).

## What a Rails 8 project already has

`rubocop-rails-omakase` is a Rails 8 default, and its gemspec depends on
`rubocop`, `rubocop-rails` and `rubocop-performance`. So a `Gemfile` with only:

```ruby
group :development, :test do
  gem "rubocop-rails-omakase", require: false
end
```

already resolves all four gems. **Do not add `rubocop`, `rubocop-rails` or
`rubocop-performance` to a project that has omakase** — they are already there,
and pinning them separately invites a version conflict with omakase's own
constraints (`rubocop >= 1.72`, `rubocop-rails >= 2.30`,
`rubocop-performance >= 1.24`).

`rubocop-rspec` is **not** an omakase dependency and is the one extension a
project may genuinely lack. Check the `Gemfile` before writing any `RSpec/*`
config, and never add a gem to a shared project on your own initiative — report
that it is missing and let the maintainer decide.

Confirm what is loaded rather than inferring it:

```bash
bin/rubocop -V
# 1.89.0 (using Parser ..., analyzing as Ruby 3.4, running on ruby 3.4.5)
#   - rubocop-performance 1.26.1
#   - rubocop-rails 2.36.0
```

That listing is the loaded plugins, and the `analyzing as Ruby` clause is the
inferred `TargetRubyVersion`.

## Loading: `plugins:` versus `require:`

```yaml
# A gem extension — the current key since RuboCop 1.72
plugins:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance
```

`require:` still works for gems but emits a deprecation warning. **For a cop
defined inside the project, `require:` is the correct key and `plugins:` is an
error** — `plugins:` expects a lint_roller plugin class, and given a file path it
fails with *"the corresponding plugin class could not be determined for
instantiation"*.

```yaml
require:
  - ./lib/rubocop/cop/custom/prefer_new_method.rb
```

When the config inherits from omakase, the plugin lines are already in omakase's
own `rubocop.yml`, so add only what omakase does not bring:

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

plugins:
  - rubocop-rspec        # the one omakase does not include
```

**A department key with no plugin loaded is a hard error, not a warning.** A
`Rails:` or `RSpec:` or `Performance:` block on its own aborts the run with exit
2 and inspects nothing:

```
Error: `Rails` cops have been extracted to the `rubocop-rails` gem.
(obsolete configuration found in .rubocop.yml, please update it)
```

## Version targeting

Both target versions default to nil and are inferred. Leave them unset.

- **`TargetRubyVersion`** — read from `.ruby-version`, `mise.toml`,
  `.tool-versions`, the gemspec, then `Gemfile.lock`, in that order, falling back
  to 2.7. On a project whose `.ruby-version` is `3.4.5`, `rubocop -V` reports
  `analyzing as Ruby 3.4` with nothing configured. Pinning `3.2` downgrades the
  parser to 3.2, which suppresses the 3.3-and-3.4-only cops and lets the syntax
  they exist to check pass unexamined.
- **`TargetRailsVersion`** — `rubocop-rails` parses `Gemfile.lock` or
  `gems.locked` for the bound Rails version, falling back to 5.0. Hardcoding
  `7.0` on a Rails 8.1 app disables every cop gated on 7.1, 7.2, 8.0 and 8.1.

Version targeting also gates cops in the other direction. `Security/YAMLLoad`
carries `maximum_target_ruby_version 3.0`, so on Ruby 3.1+ it never fires —
Psych 4 made `YAML.load` behave as `safe_load`.

## Where extension configuration behaves differently from core

**Extension defaults are richer, so a user value replaces more.** Core cops
mostly ship a bare `Enabled:` and a `Max:`. Extension cops frequently ship long
`Exclude:` and `AllowedMethods:` arrays — and an array in a user config
**replaces** the inherited one. The standard casualty is
`RSpec/DescribeClass`, which already excludes five spec directories; a
three-entry user `Exclude:` re-enables the cop for the two it dropped. Declare
`inherit_mode: merge: [Exclude]` to add instead of replace.

**Extensions rename and split cops more often than core does.** Three outcomes,
which behave differently:

| In the extension's `obsoletion.yml` | Result |
|---|---|
| `renamed` | Warning; the run continues and your settings apply to the new name |
| `split` | **Hard error, exit 2.** `RSpec/FilePath` became `RSpec/SpecFilePathFormat` plus `RSpec/SpecFilePathSuffix`, and RuboCop cannot guess which you meant |
| `removed` | Hard error, exit 2 |

A name that was never a cop is also a hard error, with a "Did you mean" suggestion.

**Some extension parameters live on `AllCops`, not on a cop.**
`rubocop-rails` contributes `TargetRailsVersion`,
`ActiveSupportExtensionsEnabled` and `MigratedSchemaVersion` to `AllCops`.
Writing `Rails/MigratedSchemaVersion:` aborts the run; the working form is an
`AllCops` key **in a config where rubocop-rails is loaded**:

```yaml
plugins:
  - rubocop-rails        # or inherit_gem from omakase, which loads it

AllCops:
  MigratedSchemaVersion: '20240101000000'
```

Without the plugin the same key produces
`Warning: AllCops does not support MigratedSchemaVersion parameter.` and is
discarded — the parameter only exists because the plugin added it. That is the
general rule for `AllCops`: its supported-parameter list grows with the plugins
you load, so "unsupported" can mean "you forgot the plugin" rather than "no such
setting".

## What each extension is for

- **rubocop-rails** — Rails idiom and safety: association options, migration
  reversibility, `find_each`, symbolic HTTP statuses, output-escaping decisions.
  Omakase loads it and disables all 138 of its cops, so on a stock Rails 8 app
  none of this runs until you name a cop.
- **rubocop-rspec** — spec structure and matcher choice. Its numeric defaults are
  the ones worth quoting, because they encode a testing opinion:
  `RSpec/ExampleLength` 5, `RSpec/MultipleExpectations` 1, `RSpec/NestedGroups` 3,
  `RSpec/MultipleMemoizedHelpers` 5.
- **rubocop-performance** — allocation and iteration costs that are invisible in
  review: `flat_map` over `map.flatten(1)`, `find` over `select.first`, `size`
  over `count`, `match?` over `match`. Several of its corrections are
  `SafeAutoCorrect: false`, so it is an `-A --only` department.

## Keeping versions together

Extensions declare a floor on `rubocop` itself (`rubocop-rails` 2.36.0 requires
`rubocop >= 1.75.0, < 2.0`), so `bundle update` them as a group. A cop that
vanishes or renames after an update surfaces as the exit-2 error above on the
next run rather than silently, which is the useful behaviour.
