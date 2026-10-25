# The bottlenecks worth checking, in order

Five bottlenecks, ordered by how often they apply to a Rails application and how
little surgery each fix takes. Each section gives the detection command, the mechanism,
and the code.

**Every detection command below is an environment variable on `bundle exec rspec`, and
each one needs `test-prof` in the bundle.** Without the gem the variable is inert: the
suite runs, exits green, and prints no profile at all. Check the `Gemfile` first —
`SKILL.md`, section "First: check what the project has in its bundle" — and never add
the gem yourself.

The ordering and the first four subjects come from Evil Martians'
published case study of a 30,000-example suite; **that write-up's runtime figures are
not reproducible here, so measure your own before and after rather than quoting
theirs.**

## 1. Coverage instrumentation

### How to detect

Run the suite with and without whatever gates SimpleCov — commonly `COVERAGE=1` — and
compare. Read the `SimpleCov.start` block first: which criteria a project enables
decides how much the switch below can win.

### Mechanism

Default line coverage records a count for every line, every time it executes. Almost
no workflow needs the counts; knowing whether a line ran at all is enough, and that is
what Ruby's `oneshot_line` mode measures — it records a line's first execution and then
stops tracking it.

### Fix

`enable_coverage :oneshot_line` removes only `:line` from the enabled set (simplecov
1.0.3, `configuration/coverage_criteria.rb`), so a project that also enables `:branch`
keeps paying for branch instrumentation unless you say otherwise. Executed against
simplecov 1.0.3: starting from `Set[:line, :branch]`, `enable_coverage :oneshot_line`
yields `Set[:branch, :oneshot_line]`, and only `disable_coverage :branch` gets you to
`Set[:oneshot_line]`.

```ruby
# spec/spec_helper.rb (or wherever SimpleCov.start lives)
SimpleCov.start "rails" do
  enable_coverage :oneshot_line
  primary_coverage :oneshot_line
  disable_coverage :branch    # only if the project had branch coverage enabled
end
```

`primary_coverage` raises unless the criterion it names is enabled, so set it after the
`enable_coverage` line.

### Caveat

`oneshot_line` gives line coverage without execution counts. A team that reports on
"which test hit this line most often" wants standard mode. A team enforcing branch
coverage as a threshold is choosing that guarantee over the runtime, which is a
conversation rather than a switch.

## 2. Records created that no example needs

### How to detect

```bash
FDOC=1 bundle exec rspec
```

FactoryDoctor reports examples that persist records and then never query them. Its
threshold is 0.01 seconds of database time per example by default (`FDOC_THRESHOLD`),
so lower it to see everything, and tag a deliberate case `:fd_ignore` to keep the report
honest. Output on a suite with two such examples:

```
[TEST PROF INFO] FactoryDoctor report
Total (potentially) bad examples: 2
Total wasted time: 00:00.015
```

Follow it with `FPROF=1` for which factories carry the volume, and `RD_PROF=1` to see
whether the time sits in `before` hooks or in `let` evaluation.

### Mechanism

Three shapes account for most of it: `create` where the example only asserts on
attributes in memory; a record built for the whole group but used by one example; and
association fan-out, where creating one record creates four.

### Fix

- `build` for an in-memory assertion, `build_stubbed` when even the associations can
  stay unsaved.
- `let_it_be` when most of the group's examples do need the persisted record. It is
  eager, so it earns its place by breadth of use, not by being available.
- `before_all` for multi-record setup that is not naturally one binding per record.
- `create_default` (FactoryDefault) when the same association is passed to every
  factory call in a file.

See `testprof_features.md` for the requires and the mutation options.

## 3. Encryption and blind-index parameters in the test environment

### How to detect

Look for factories that write encrypted or blind-indexed columns, then profile one
`create` with `FPROF=1` or a sampling profiler. Key-derivation frames — Argon2, PBKDF2
— in a factory call are the fingerprint.

### Mechanism

`blind_index` defaults to production-strength key derivation (Argon2id, 3 iterations,
4 MB of memory) and ships no test mode. That cost is right for real user data and
ruinous when a suite creates thousands of records.

### Fix

```ruby
# spec/rails_helper.rb
if Rails.env.test?
  BlindIndex.default_options = {
    algorithm: :pbkdf2_sha256,
    cost: { iterations: 1 }
  }
end
```

`lockbox` and `attr_encrypted` have equivalent knobs; check each gem the `Gemfile`
actually names.

**Active Record Encryption is the exception: it has no cost or iterations setting to
turn down.** Its key provider derives keys once in its own initializer, so the
per-record cost is the AES-GCM encryption itself. If a Rails 8 app is slow in factories
that write encrypted columns, the fix is creating fewer such records, not cheaper
parameters.

## 4. Individual slow example groups

### How to detect

```bash
TPS_PROF=20 bundle exec rspec
```

The report ranks example **groups** by tests per second, and the location it prints is
the group's `describe` line rather than the top of the file. The default thresholds
(`TPS_PROF_MIN_EXAMPLES=10`, `TPS_PROF_MIN_TIME=5` seconds, `TPS_PROF_TARGET_TPS=30`) drop
anything smaller or faster, which is why a quick suite prints an empty table. Override all
three to see the ranking regardless:

```bash
TPS_PROF=20 TPS_PROF_MIN_EXAMPLES=1 TPS_PROF_MIN_TIME=0 TPS_PROF_TARGET_TPS=10000 bundle exec rspec
```

### Mechanism

Varies, and `slow_spec_patterns.md` carries the three that recur:

- Work that scans the whole object space on every example
- Production retry or backoff logic sleeping for real
- Hundreds of records created to exercise a limit

## 5. `require "rubocop/rspec/support"` in `spec_helper.rb`

This one applies only to a project that develops its own cops. It is listed last for
that reason, and it is expensive where it applies.

### How to detect

```bash
TEST_MEM_PROF=gc bundle exec rspec
```

`gc` mode reports GC time per group and per example. The mode argument matters:
`alloc`, `rss` and `gc` are the three modes, and any other value — including `1` —
falls back to `rss`.

### Mechanism

Two costs, not one. `rubocop/rspec/support` loads the whole RuboCop plugin graph, so
every spec in the suite runs inside a heap holding cop classes, AST machinery, and
plugin registries. It also calls `config.include CopHelper` **and**
`config.include RuboCop::RSpec::ExpectOffense` with no metadata filter, so both modules
are mixed into every example group in the suite. Its 25 `include_context` calls *are*
metadata-filtered, so those cost nothing outside cop specs.

### Fix

Require the two modules you use and scope both includes to the cop specs:

```ruby
# spec/spec_helper.rb
require "rubocop/rspec/cop_helper"
require "rubocop/rspec/expect_offense"

RSpec.configure do |config|
  config.include CopHelper, type: :rubocop
  config.include RuboCop::RSpec::ExpectOffense, type: :rubocop
end
```

`expect_offense` lives in the second module, so a fix that includes only `CopHelper`
raises `NoMethodError` in every cop spec. Tag the cop specs `type: :rubocop`, and
re-declare any shared context they relied on — the metadata-filtered contexts that came
with `rubocop/rspec/support`, such as `:config` and `:restore_registry`, are gone once
the catch-all require is.

## Putting it together

1. Read the SimpleCov configuration → apply #1 if line counts are being collected.
2. `FDOC=1`, then `FPROF=1` and `RD_PROF=1` → apply #2 to what they name.
3. Grep the `Gemfile` for encryption gems → apply #3 to the ones with cost knobs.
4. `TPS_PROF` with the thresholds lowered → apply #4 to the top few groups.
5. `TEST_MEM_PROF=gc`, and check `spec_helper.rb` for the catch-all require → #5.
6. Re-measure after each step and keep the numbers.

Stop when the suite hits the runtime the team agreed on. Past the first few individual
groups, another fix rarely beats parallelizing — which needs a gem the project may not
have, so check the `Gemfile` and let the team choose.
