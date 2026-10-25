---
name: testprof
description: Diagnose and fix a slow RSpec suite with TestProf. Covers profiler selection (TPS, TagProf, FactoryProf, FactoryDoctor, RSpecDissect, memory, StackProf, RubyProf, Vernier), the bottlenecks that account for most lost time, and let_it_be versus let.
when_to_use: >-
  Use when the user asks why an RSpec suite is slow, which profiler to run, or how
  `let_it_be` compares with `let`.
disable-model-invocation: true
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/testprof/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: test-prof 1.6.3, rspec-rails 8.0.4, rspec-core 3.13.6, rspec-mocks 3.13.8, simplecov 1.0.3, Ruby 3.4.5
---

# TestProf: RSpec performance optimization

Guidance for diagnosing and fixing slow RSpec test suites. Verified against
test-prof 1.6.3, rspec-rails 8.0.4, rspec-core 3.13.6 and Ruby 3.4.5.

The technique ordering comes from Evil Martians' published case study of a
30,000-example Rails suite. **Its runtime figures are that write-up's and are not
reproducible here, so this skill states mechanisms and leaves you to measure your own
numbers.** Slow suites are rarely slow for one reason; they are slow for a handful of
fixable reasons, stacked.

## How to use this skill

Investigate the user's actual codebase before prescribing anything. The value is in
mapping a known pattern onto their specific code, so do the reading first and quote
what you found.

1. **Characterize the problem** — total runtime, example count, and whether it is
   "slow everywhere" or "slow in specific groups". That choice picks the first
   profiler.
2. **Read before profiling**:
   - `spec/spec_helper.rb` and `spec/rails_helper.rb`, for global hooks, SimpleCov
     configuration, and heavy requires.
   - The `Gemfile`, for SimpleCov, `blind_index`, `lockbox`, any encryption gem, and
     retry gems (`retriable`, Faraday retry middleware).
   - The service under test in a slow file — grep for `sleep`, `retry`,
     `ObjectSpace`, and `create_list(:thing, <large number>)`.
   - The factories for the types involved. Association fan-out is a common cause.
3. **Run the profiler the symptom points at** — see the table below. If you cannot run
   it, write the exact command and say how to read the output.
4. **Apply fixes in order of payoff.** Coverage and factory waste usually cost the
   least to change, so check them before rewriting specs. Work the ordered list in
   `references/bottlenecks.md`, section "Putting it together": its first five steps
   are each gated on what a detector reported, so a bottleneck no detector named
   is not yours to fix. This step ends when every named bottleneck has either a fix
   applied or a written reason for leaving it.
5. **Measure after each change**, and keep the before and after numbers.

A grounded answer reads like: "I read `app/services/your_service.rb` — the retry is
hand-rolled at line 42 (`sleep(2 ** attempt)`), not delegated to a gem, so injection
is the fix rather than gem config. Here is the diff." One `Read` and one `Grep` buys
that.

## Diagnostic decision tree

Every command in this table needs `test-prof` in the bundle. "First: check what the project has
in its bundle" below carries the check, and it is worth running before any of these: without the
gem the suite goes green and prints nothing.

Start with the profiler the symptom points at rather than running all of them.

| Symptom | First thing to run | What it tells you |
|---|---|---|
| "Specific groups are slow" | `TPS_PROF=20 bundle exec rspec` | Tests-per-second per example group; surfaces low-TPS groups |
| "Factories dominate setup" | `FPROF=1 bundle exec rspec` | Which factories are called, how often, and how long they take |
| "Records get created that nothing reads" | `FDOC=1 bundle exec rspec` | Examples that persist records and then never query them |
| "Is the time in `before` hooks or in `let`?" | `RD_PROF=1 bundle exec rspec` | Splits each group's setup between hooks and `let` evaluation |
| "GC time looks high" | `TEST_MEM_PROF=gc bundle exec rspec` | Per-group and per-example GC time |
| "Which spec *types* cost the most?" | `TAG_PROF=type bundle exec rspec` | Time aggregated by tag — needs specs that carry `type:` |
| "Slow everywhere, no hotspot" | `TEST_STACK_PROF=1 bundle exec rspec` | Global costs: boot, autoloading, coverage, heavy hooks |
| "One slow spec, want a method-level view" | `TEST_RUBY_PROF=1 bundle exec rspec path/to/spec.rb` | Method-level hotspots inside those examples |

Two notes that decide whether these print anything:

- **`TPS_PROF` reports only the groups its three thresholds admit.**
  `TPS_PROF_MIN_EXAMPLES` defaults to 10 examples, `TPS_PROF_MIN_TIME` to 5 seconds of
  group time, and `TPS_PROF_TARGET_TPS` to 30 — groups **above** the target are treated as
  fast enough to ignore. On a suite that is already quick the report is therefore empty,
  which is a pass rather than a failure. Override all three when you want to see the
  ranking anyway:
  `TPS_PROF=20 TPS_PROF_MIN_EXAMPLES=1 TPS_PROF_MIN_TIME=0 TPS_PROF_TARGET_TPS=10000 bundle exec rspec`.
- **`TEST_STACK_PROF`, `TEST_RUBY_PROF` and `TEST_VERNIER` each need their own gem**
  on top of `test-prof`. Without it the run prints one line —
  `[TEST PROF ERROR] Please, install 'stackprof' first:` — and then the suite proceeds
  normally, which is easy to miss in a long run. The floors test-prof asks for are
  `stackprof >= 0.2.9`, `ruby-prof >= 1.4.0`, and `vernier >= 0.3.0`.

## First: check what the project has in its bundle

`test-prof` hooks into the RSpec process at runtime, so it must be in the bundle;
there is no way to run it from a global gem install.

```bash
grep -E "^[[:space:]]*gem [\"']test-prof[\"']" Gemfile
grep -E "^[[:space:]]*gem [\"'](stackprof|ruby-prof|vernier)[\"']" Gemfile
```

The first command gates every profiler and primitive on this page. The second gates
the three sampling and line-level profilers only; everything else in the table above
ships inside `test-prof` itself.

**If a gem is absent, do not add it.** Adding a gem to a project's `Gemfile` is that
project's decision, and on a shared codebase it may not be yours to make. Say which
gem is missing, then either:

- Offer the one-line `Gemfile` change for the user to take to their team, or
- Diagnose with what is there. `--profile` is built into RSpec and prints both
  `slowest_examples` and `slowest_example_groups` — the group ranking is the closer
  substitute for TPS_PROF, and it appears whenever more than one top-level group ran.
  Reading `spec_helper.rb` and the factories still finds the causes in
  `references/bottlenecks.md`. You lose the measurements, not the diagnosis.

This is the `Gemfile` change to offer, and the user decides whether it lands:

```ruby
# Gemfile
group :test do
  gem "test-prof", "~> 1.6"
end
```

Once `test-prof` is in the bundle, most profilers activate through environment variables. The optimization primitives —
`let_it_be`, `before_all`, `AnyFixture`, `FactoryDefault` — and the `SAMPLE` modes each
need a require, and it belongs in `spec/rails_helper.rb`, the file that loads after
`config/environment`, because the recipes inspect ActiveRecord at require time. See
`references/testprof_features.md`.

Artifacts (StackProf dumps, the FactoryProf flamegraph) land in `tmp/test_prof`.
`TestProf.configure { |config| config.output_dir = "…" }` moves them, which is how you
profile a project without writing inside it.

## The bottlenecks, in the order worth checking on a Rails app

`references/bottlenecks.md` carries the detection steps and the code for each.

1. **Coverage instrumentation** — SimpleCov's default line tracking counts every hit.
   `oneshot_line` records the first hit and stops, and the switch has to remove the
   modes already enabled, not just add one.
2. **Records created that no example needs** — `FDOC=1` names them; `let_it_be`,
   `before_all` and `FactoryDefault` are the fixes.
3. **Encryption and blind-index parameters** — `blind_index` and `lockbox` default to
   production-strength key derivation, which is per-record cost in factories. Active
   Record Encryption has no equivalent knob.
4. **Individual slow groups** — found via `TPS_PROF`, then diagnosed with
   `references/slow_spec_patterns.md`.
5. **`require "rubocop/rspec/support"` in `spec_helper.rb`** — only reachable in a
   project that develops custom cops, and expensive there.

## When to reach for `let_it_be` vs `let`

`let_it_be` creates the record once for the whole example group instead of once per
example. **It is eager, not lazily memoized:** it registers an unconditional
`before(:all)` (`let_it_be.rb:118`), so the block runs for the group whether or not any
example calls the reader.

```ruby
# One user per example
let(:user) { create(:user) }

# One user for the whole group, created before the first example runs
let_it_be(:user) { create(:user) }
```

Reach for it when most of the group's examples use the record. Two consequences of
eagerness to hold onto:

- A `let_it_be` in a group whose examples mostly ignore the record is a cost, not a
  saving, so "this `let` could be a `let_it_be`" is a question, not a rule.
- Hoisting a declaration up the nesting tree to share it is worth doing against the
  `rails-core:rspec-let` skill's Rule 4, because Rule 4's cost is paid per example and
  `let_it_be`'s is paid once per group. State that tradeoff when you make the change,
  and let Rule 4 still decide the placement of ordinary `let`s.

When examples mutate the record, `reload: true` re-reads its attributes and keeps the
same object, while `refind: true` returns a new instance and is the only one that
clears memoized instance state. Both depend on the project running with
`use_transactional_fixtures = true`; without a per-example transaction they just
re-read the mutation. See `references/testprof_features.md` for the require, the
options, and what each one resets.

## Tests-per-second (TPS): the metric that ranks the work

Total runtime hides where the payoff is. TPS is a group's examples divided by its
runtime, so it favours groups where high runtime meets a high example count — the
groups where a single fix repays itself many times.

```bash
# The 20 worst groups on a slow suite
TPS_PROF=20 bundle exec rspec

# The same, with all three thresholds overridden so nothing is hidden
TPS_PROF=20 TPS_PROF_MIN_EXAMPLES=1 TPS_PROF_MIN_TIME=0 TPS_PROF_TARGET_TPS=10000 bundle exec rspec
```

The report is per **example group**, and the location it prints is the group's
`describe` line. A file with five `describe` blocks produces five rows, and a nested
group's location is not the top of the file. Take a row to
`references/slow_spec_patterns.md` for the common root causes.

## Preventing regressions

- **In review**, ask three questions: does this `let` create a record most of the
  group's examples use (then `let_it_be` earns its eagerness); does this example create
  more than a handful of records to test a limit or a page boundary (then the limit
  wants to be injectable); and has `require "rubocop/rspec/support"` reappeared in
  `spec_helper.rb`.
- **Track the number over time.** A periodic `TPS_PROF` run, or `--profile`'s group
  ranking, shows regressions arriving.
- **CI budget**: pick a target runtime and fail CI when it slips.
- **Parallelization is a separate decision.** It needs a gem (`test-queue`,
  `parallel_tests`, or Rails' own parallel test runner) that the project may not have,
  so check the `Gemfile` first, name the option, and let the team choose.

## References

- `references/bottlenecks.md` — the five bottlenecks above, with detection steps and code
- `references/testprof_features.md` — the full primitive and profiler reference
  (`let_it_be`, `before_all`, `AnyFixture`, `FactoryDefault`, FactoryProf,
  FactoryDoctor, RSpecDissect, EventProf, sample modes)
- `references/slow_spec_patterns.md` — root causes inside one slow group, with before
  and after code
- `references/diagnostic_scripts.md` — drop-in snippets when no profiler is available:
  GC tracker, per-file timing, factory counter, boot timing
