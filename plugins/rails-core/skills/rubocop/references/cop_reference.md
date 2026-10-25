# RuboCop Cop Reference

The departments, the cops worth naming, and the defaults worth quoting. Verified
against rubocop 1.89.0, rubocop-rails 2.36.0, rubocop-rspec 3.7.0 and
rubocop-performance 1.26.1.

**Confirm before you cite.** `rubocop --show-cops <Cop/Name>` prints the cop's
effective configuration after all inheritance — its `Enabled:`, its parameters
and its defaults. It takes cop names only; `--show-cops Style` prints nothing.

**On a `rubocop-rails-omakase` project, most of what follows is switched off.**
Omakase disables every department and re-enables 43 individual cops: 30 in
`Layout`, 9 in `Style`, 3 in `Lint`, 1 in `Performance`. Nothing from `Metrics`,
`Naming`, `Security`, `Bundler`, `Gemspec` or `Rails`. Read the project's
`.rubocop.yml` first.

## Core departments

### Gemspec

Applies to `.gemspec` files, so a Rails app never sees it.

- `Gemspec/DuplicatedAssignment` — the same attribute assigned twice
- `Gemspec/OrderedDependencies` — dependencies in alphabetical order
- `Gemspec/RequiredRubyVersion` — `required_ruby_version` present and matching
  `AllCops: TargetRubyVersion`

### Layout

Whitespace and formatting. The largest group omakase keeps, and the one where
`-a` is genuinely uneventful.

- `Layout/LineLength` — maximum line length, **default 120 characters**; omakase disables the
  `Layout` department and never re-enables this cop, so it does not run
- `Layout/IndentationWidth`, `Layout/IndentationConsistency` — omakase disables
  both, so an omakase project has no indentation-width check
- `Layout/TrailingWhitespace`, `Layout/TrailingEmptyLines`
- `Layout/SpaceAroundOperators`, `Layout/SpaceInsideHashLiteralBraces`
- `Layout/HashAlignment`, `Layout/EndAlignment`, `Layout/ElseAlignment`
- `Layout/EmptyLineAfterMagicComment` — a blank line after
  `# frozen_string_literal: true`

```bash
rubocop --only Layout
rubocop -x               # the same set, with safe autocorrection on
```

### Lint

Probable bugs and genuinely ambiguous code. The department with the best
signal-to-noise ratio, and one omakase leaves almost entirely off.

- `Lint/Debugger` — a leftover `debugger` or `binding.irb`
- `Lint/UselessAssignment` — a local variable assigned and never read
- `Lint/UnusedMethodArgument`, `Lint/UnusedBlockArgument`
- `Lint/ShadowingOuterLocalVariable` — a block parameter hiding an outer local
- `Lint/DuplicateMethods` — two definitions of one method in a class
- `Lint/Void` — an expression whose value is discarded
- `Lint/AmbiguousOperator` — `foo -bar` parsed as a call with a negative argument
- `Lint/Syntax` — reported at `F` severity; nothing else runs on that file

```ruby
# Lint/UselessAssignment
def total(items)
  count = items.size   # assigned, never read
  items.sum(&:price)
end

# Lint/ShadowingOuterLocalVariable
name = "Alice"
users.each { |user| puts "#{name}: #{user}" }   # a distinct name, no shadowing
```

### Metrics

Size and complexity. **All nine ship enabled in core and all nine are disabled
by omakase**, which is the single most important thing to know before quoting a
number from this table.

Each `Max:` below is the default at 1.89.0. They are ceilings that earn a review
comment, in the unit named — not design targets. For the smaller number to aim
at while writing, and for deciding when a long method should become a new
object, the `rails-core:extraction-timing` skill owns the extraction triggers in
its "Extraction Thresholds" section.

| Cop | Default `Max` | Unit |
|---|---|---|
| `Metrics/MethodLength` | 10 | lines of method body; `CountComments: false` |
| `Metrics/ClassLength` | 100 | lines |
| `Metrics/ModuleLength` | 100 | lines |
| `Metrics/BlockLength` | 25 | lines |
| `Metrics/BlockNesting` | 3 | levels of nesting |
| `Metrics/ParameterLists` | 5 | parameters; `CountKeywordArgs: true`, `MaxOptionalParameters: 3` |
| `Metrics/AbcSize` | 17 | assignments + branches + conditions, as a magnitude |
| `Metrics/CyclomaticComplexity` | 7 | independent paths |
| `Metrics/PerceivedComplexity` | 8 | paths, weighted for how they read |

Two parameters change what the numbers mean:

- `CountComments: false` (the default) means a documented method is not penalised
  for its documentation.
- `CountAsOne: ['array', 'hash', 'heredoc']` counts a multi-line literal as one
  line, which is what stops a long `permitted_classes` array from reading as
  complexity.

```yaml
# Enabling one Metrics cop on an omakase project
Metrics/MethodLength:
  Enabled: true
  CountAsOne: ['array', 'hash', 'heredoc']

Metrics/BlockLength:
  Enabled: true
  Exclude:
    - 'spec/**/*'        # a describe block is not a long method
    - 'config/routes.rb'
```

To measure once without changing the config, `--only` overrides the inherited
disable: `rubocop --only Metrics/MethodLength`.

### Naming

- `Naming/MethodName` — `snake_case` methods
- `Naming/ClassAndModuleCamelCase` — `CamelCase` classes and modules. **There is
  no `Naming/ClassName`**; configuring that name aborts the run with exit 2, and
  it is not an alias RuboCop will translate either
- `Naming/ConstantName` — `SCREAMING_SNAKE_CASE`
- `Naming/VariableName` — `snake_case`
- `Naming/PredicateMethod` and `Naming/PredicatePrefix` — a boolean method ends
  in `?` rather than starting with `is_`
- `Naming/AccessorMethodName` — no `get_`/`set_` prefixes
- `Naming/BinaryOperatorParameterName` — `def ==(other)`

```ruby
class UserProfile
  MAXIMUM_AGE = 120

  def full_name
    "#{first_name} #{last_name}"
  end

  def active?
    status == :active
  end
end
```

### Security

Seven cops. Five ship `Enabled: true`; `Security/CompoundHash` and
`Security/IoMethods` ship `pending`, so `AllCops: NewCops: enable` is what turns
them on. The safe form for each, all verified by invocation:

```ruby
# Security/Eval — fires on eval with a non-literal argument.
# There is no safe eval of outside input. Dispatch through an allowlist instead.
HANDLERS = { "csv" => CsvHandler, "json" => JsonHandler }.freeze
HANDLERS.fetch(params[:format]).new.call

# Security/JSONLoad
JSON.parse(untrusted_data)

# Security/MarshalLoad — no autocorrect, and no safe options hash.
# Marshal is for data this process wrote. For anything else, use JSON.
JSON.parse(payload)

# Security/Open — fires only on dynamic data, because open("| ls") runs a
# subprocess. Name the operation you actually want.
File.open(path)
IO.popen(command)
URI.parse(url).open

# Security/IoMethods (pending)
File.read(path)

# Security/CompoundHash — delegate to Array#hash rather than combining members
def hash
  [x, y].hash
end
```

**`Security/YAMLLoad` cannot fire on this stack.** It carries
`maximum_target_ruby_version 3.0`, because Psych 4 made `YAML.load` behave as
`safe_load`. Verified: with `TargetRubyVersion: 3.0` the cop flags
`YAML.load(File.read(path))`; with `3.4` it does not. On Ruby 3.1 and later,
`YAML.load` already refuses arbitrary object types and aliases, and the way to
permit specific ones is the keyword:

```ruby
YAML.load(text, permitted_classes: [Date, Time], aliases: true)
```

### Style

Community style conventions, and the department where the project's own taste
governs. omakase keeps nine and drops the rest.

- `Style/StringLiterals` — quote style
- `Style/HashSyntax` — `{ key: value }` versus hash rockets
- `Style/FrozenStringLiteralComment` — the magic comment
- `Style/Documentation` — a top-level comment on every class and module. Off in
  omakase, and off in any project whose convention is that explanations live in
  commit messages
- `Style/GuardClause` — an early return rather than a wrapping conditional
- `Style/TrailingCommaInArrayLiteral`, `Style/TrailingCommaInHashLiteral`
- `Style/SymbolArray` — `%i[a b]`
- `Style/CollectionMethods` — `Enabled: false`, `Safe: false`, and its
  `PreferredMethods` map is what `Performance/Detect` reads when it corrects.
  The shipped map contains `detect: find`, `collect: map`, `inject: reduce`,
  `find_all: select`, `member?: include?`

**Quote style on this stack is double quotes.** Core's default for
`Style/StringLiterals` is `single_quotes`, but `rubocop-rails-omakase` sets
`EnforcedStyle: double_quotes` — so on a Rails 8 app, double quotes are correct
and single quotes are the offense. Omakase also scopes the cop with
`Include: app/**/*, config/**/*, lib/**/*, test/**/*, Gemfile`, so **an RSpec
project's `spec/` directory has no quote-style check at all.**

```yaml
Style/StringLiterals:
  EnforcedStyle: double_quotes   # omakase's setting

Style/HashSyntax:
  EnforcedStyle: ruby19          # { key: value }

Style/TrailingCommaInArrayLiteral:
  EnforcedStyleForMultiline: consistent_comma
```

```ruby
# Style/StringLiterals (double_quotes)
message = "Hello"
message = "Hello #{name}"

# Style/GuardClause
def process(user)
  return unless user.present?

  user.update(status: :active)
end
```

## Extension departments

### Rails — rubocop-rails 2.36.0

Arrives transitively with `rubocop-rails-omakase`, which loads it as a plugin
and then disables the whole department. Enable the cops you want by name.

```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

Rails/ApplicationRecord:
  Enabled: true
```

Standalone, the plugin line is `plugins: [rubocop-rails]`. **A `Rails:` or
`Rails/*` key with no plugin loaded aborts the run with exit 2.** Leave
`TargetRailsVersion` unset; rubocop-rails reads it from `Gemfile.lock`.

**ActiveRecord:**
- `Rails/FindBy` — `find_by` rather than `where(...).first`. Ships
  `IgnoreWhereFirst: true`, so `where(...).first` is **not** flagged by default;
  what it flags is `where(...).take`
- `Rails/FindEach` — `find_each` for a full-table iteration
- `Rails/HasManyOrHasOneDependent` — an association states `dependent:`
- `Rails/ReversibleMigration` — the migration can be rolled back
- `Rails/BulkChangeTable` — combine several `change_table` operations
- `Rails/ApplicationRecord` — models inherit from `ApplicationRecord`. Already
  ships `Exclude: db/**/*.rb`, so a migrations exclude duplicates the default

**Controllers:**
- `Rails/ActionOrder` — actions in the conventional order
- `Rails/ApplicationController` — controllers inherit from
  `ApplicationController`
- `Rails/HttpStatus` — symbolic status codes

**Views and helpers:**
- `Rails/OutputSafety` — escaping decisions are explicit
- `Rails/ContentTag` — `tag.div` rather than `content_tag(:div)`
- `Rails/LinkToBlank` — `target="_blank"` carries `rel="noopener"`

`Rails/MigratedSchemaVersion` is **not a cop** — it is an `AllCops` parameter.

```ruby
# Rails/FindBy
User.find_by(email: email)

# Rails/FindEach
User.find_each { |user| user.process }

# Rails/HasManyOrHasOneDependent
has_many :posts, dependent: :destroy

# Rails/HttpStatus
render status: :ok
redirect_to root_path, status: :moved_permanently
```

### RSpec — rubocop-rspec 3.7.0

A separate gem, and **not** an omakase dependency. Check the `Gemfile` before
writing any `RSpec/*` key.

```yaml
plugins:
  - rubocop-rspec
```

**Structure:**
- `RSpec/DescribeClass` — the top-level `describe` names a constant. Already
  excludes `spec/features`, `spec/requests`, `spec/routing`, `spec/system` and
  `spec/views`; a shorter user `Exclude:` **replaces** that list and re-enables
  the cop for the paths it drops
- `RSpec/SpecFilePathFormat` and `RSpec/SpecFilePathSuffix` — **`RSpec/FilePath`
  was split into these two at 3.0 and no longer exists.** Configuring the old
  name aborts the run
- `RSpec/MultipleDescribes` — one top-level `describe` per file
- `RSpec/NestedGroups` — `Max: 3` nested groups

**Examples:**
- `RSpec/ExampleLength` — `Max: 5` lines per example
- `RSpec/MultipleExpectations` — `Max: 1` expectation per example
- `RSpec/MultipleMemoizedHelpers` — `Max: 5` `let` declarations per context;
  this is the number the `rails-core:rspec-let` skill cites in its
  "Rule 2: 1 to 3 `let` calls per context" section
- `RSpec/NamedSubject` — a bare `subject` is referred to by name. It does **not**
  flag `is_expected`, which reads the implicit subject legitimately

**Matchers:**
- `RSpec/PredicateMatcher` — `be_active` rather than `active?` plus `be_truthy`
- `RSpec/ExpectChange` — a consistent `change` form

```ruby
RSpec.describe User, type: :model do
  describe "#authenticate" do
    it "returns the user for the right password" do
      expect(user.authenticate("secret")).to eq(user)
    end
  end
end

# RSpec/PredicateMatcher
expect(user).to be_active

# RSpec/MultipleExpectations (Max: 1) — one assertion per example
it { is_expected.to be_valid }
it { expect(user.name).to eq("Alice") }
```

### Performance — rubocop-performance 1.26.1

Arrives transitively with omakase, which enables exactly one of its cops,
`Performance/FlatMap`.

**Strings:**
- `Performance/StringInclude` — `string.include?("foo")` rather than
  `/foo/.match?(string)`
- `Performance/StringReplacement` — `tr` for single-character replacement
- `Performance/RegexpMatch` — `match?` when only the boolean is used
- `Performance/FixedSize` — **write the size a statically sized object already
  has.** `"foo".size` is a constant; write `3`, or move it into a constant.
  Nothing to do with slicing

**Collections:**
- `Performance/Size` — `size` rather than `count` on an Array or Hash
- `Performance/CompareWithBlock` — `sort_by(&:name)`
- `Performance/Detect` — `find` rather than `select { }.first`.
  `SafeAutoCorrect: false`
- `Performance/ReverseEach` — `reverse_each`
- `Performance/FlatMap` — `flat_map`. Ships
  `EnabledForFlattenWithoutParams: false`, so `map { }.flatten` with no argument
  is **not** flagged; what it flags is `map { }.flatten(1)`
- `Performance/Count` — the one with the `ActiveRecord` warning: before Rails
  5.1 `count` ignored a block, so its correction is unsafe on a relation

```ruby
# Performance/StringInclude
string.include?("foo")

# Performance/Size
array.size

# Performance/CompareWithBlock
array.sort_by(&:name)

# Performance/Detect — note the method name is find, from
# Style/CollectionMethods' PreferredMethods map
users.find { |u| u.admin? }

# Performance/FlatMap
array.flat_map { |x| [x, x * 2] }
```

## Severity

- `I` info — a suggestion
- `R` refactor — a refactoring opportunity
- `C` convention — a style violation. **The severity of the overwhelming
  majority of cops**
- `W` warning — a probable problem
- `E` error — a definite problem
- `F` fatal — a syntax error; nothing else runs on that file

```yaml
Style/StringLiterals:
  Severity: warning
```

Because convention dominates, `--fail-level warning` excludes nearly every cop
from the exit code. See the Configuration Guide's Severity section.

## Cop status

- **enabled** — runs by default
- **disabled** — runs only when explicitly enabled, or named in `--only`
- **pending** — a cop new since your RuboCop version's baseline. Runs only with
  `AllCops: NewCops: enable`, or when named explicitly. Until then RuboCop lists
  it in the output as `Cop/Name: # new in 1.28`

```yaml
AllCops:
  NewCops: enable   # or: pending, disable
```

## Autocorrection categories

- **safe** — applied by `-a`. Indentation, spacing, quote style
- **unsafe correction** — `SafeAutoCorrect: false`; applied by `-A` only. May
  change behaviour, so review it. `Performance/Detect` and
  `Style/FrozenStringLiteralComment` are both in this group
- **unsafe cop** — `Safe: false`; the *detection* itself can be wrong, so the
  cop is skipped by `--safe`
- **manual** — no correction exists. Every `Metrics` cop is here

## Department-level commands

```bash
rubocop --only Layout
rubocop --only Style,Naming
rubocop --except Metrics
```

`--only` and `--except` accept department names; `--show-cops` does not.

## Custom cops

A project cop lives under `lib/` and is loaded with `require:`, not `plugins:`.

```ruby
# lib/rubocop/cop/custom/prefer_new_method.rb
module RuboCop
  module Cop
    module Custom
      class PreferNewMethod < Base
        # cop implementation
      end
    end
  end
end
```

```yaml
require:
  - ./lib/rubocop/cop/custom/prefer_new_method.rb

Custom/PreferNewMethod:
  Description: 'Use new_method instead of old_method'
  Enabled: true
```

See the [Custom Cops Guide](custom_cops_guide.md) for the node pattern and the
spec.
