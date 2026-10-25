# TestProf feature reference

Verified against test-prof 1.6.3 on rspec-rails 8.0.4, rspec-core 3.13.6 and Ruby
3.4.5. Most profilers activate through an environment variable; the optimization
primitives need a require, and `spec/rails_helper.rb` is where it goes.

Artifacts land in `tmp/test_prof` by default. To send them elsewhere — profiling a
checkout you do not want to write into, for instance:

```ruby
TestProf.configure { |config| config.output_dir = "/tmp/test_prof" }
```

## Profilers

### TPS_PROF — tests per second, per example group

```bash
TPS_PROF=20 bundle exec rspec

# Override all three thresholds when you want the ranking on a suite that is not slow
TPS_PROF=20 TPS_PROF_MIN_EXAMPLES=1 TPS_PROF_MIN_TIME=0 TPS_PROF_TARGET_TPS=10000 bundle exec rspec
```

TPS is a group's example count divided by its runtime. Low TPS with many examples is the
high-payoff target.

Three defaults drop groups from the report, and together they are why a healthy suite
prints an empty table: `TPS_PROF_MIN_EXAMPLES` (10 examples),
`TPS_PROF_MIN_TIME` (5 seconds of group time), and `TPS_PROF_TARGET_TPS` (30 — groups
*above* the target are treated as fast enough to ignore, which is the threshold that
silences a quick suite). `TPS_PROF=strict` with `TPS_PROF_MIN_TPS` reports violations as
errors, for CI.

The rows are example groups, so a file with five `describe` blocks yields five rows and
each row's location is that group's `describe` line.

### FPROF — FactoryProf

```bash
FPROF=1 bundle exec rspec              # which factories run, how often, how long
FPROF=flamegraph bundle exec rspec     # writes factory-flame.html to the output dir
```

Needs no require: `lib/test_prof.rb` loads FactoryProf and the env var activates it.
The text report separates total calls from top-level calls, which is how association
fan-out shows up — six total against one top-level means five records came along for
the ride.

### FDOC — FactoryDoctor

```bash
FDOC=1 bundle exec rspec
FDOC=1 FDOC_THRESHOLD=0 bundle exec rspec   # report every offender, not just slow ones
```

Reports examples that persist records and then never query them, with a record count
and the wasted time per example. Defaults: event `sql.active_record`, threshold 0.01
seconds (`FDOC_THRESHOLD`), and `FDOC_EVENT` to change the event. Tag an example
`:fd_ignore` when the creation is deliberate. `FDOC_STAMP` writes the tag into the spec
files for you.

### RD_PROF — RSpecDissect

```bash
RD_PROF=1 bundle exec rspec
```

Splits each group's setup time into `before` hooks, eager `let` evaluation, and lazy
`let` evaluation. This is the profiler that answers whether converting `let` to
`let_it_be` will help, before you convert anything.

### TEST_MEM_PROF — memory and GC

```bash
TEST_MEM_PROF=gc bundle exec rspec       # GC time per group and per example
TEST_MEM_PROF=alloc bundle exec rspec    # total allocations
TEST_MEM_PROF=rss bundle exec rspec      # resident-set growth
```

The three modes are `alloc`, `rss` and `gc`; **any other value falls back to `rss`**
(`memory_prof.rb:29,38-40`), so `TEST_MEM_PROF=1` reports resident-set data whatever you
expected. GC time in the region of 5% of runtime is unremarkable; 15% or more is worth
chasing.

### TAG_PROF — aggregate by tag

```bash
TAG_PROF=type bundle exec rspec
TAG_PROF=type TAG_PROF_FORMAT=html bundle exec rspec
```

Groups time by a metadata key. With `type` it answers "are the system specs eating the
suite?" — but only for specs that *carry* a type. An example group with no `type:`
metadata lands in a single `__unknown__` bucket, and since rspec-rails 7.1 the generated
`rails_helper.rb` ships `infer_spec_type_from_file_location!` commented out. Verified
both ways: a group declaring `type: :model` reports as `model`, and the same group
without it reports as `__unknown__`. If the whole report is one `__unknown__` row, the
project either states types in its specs or has that line commented out.

### EVENT_PROF — profile one instrumented event

```bash
EVENT_PROF=sql.active_record bundle exec rspec
EVENT_PROF=factory.create bundle exec rspec
```

Any `ActiveSupport::Notifications` event works. The report gives the event's share of
total runtime and the worst groups, which makes it the cheapest way to answer "how much
of this suite is database time?"

### Sampling and line-level profilers — each needs its own gem

```bash
TEST_STACK_PROF=1 bundle exec rspec         # whole suite
TEST_STACK_PROF=boot bundle exec rspec      # boot phase only
TEST_VERNIER=1 bundle exec rspec
TEST_RUBY_PROF=1 bundle exec rspec spec/models/slow_thing_spec.rb
```

**The variable for RubyProf is `TEST_RUBY_PROF`.** A bare `RUBY_PROF=1` is not a
TestProf variable at all: the suite runs and prints nothing, which reads as "the code is
fast."

These three need `stackprof >= 0.2.9`, `vernier >= 0.3.0` and `ruby-prof >= 1.4.0`
respectively, in addition to `test-prof`. When the gem is missing, the run prints one
line and then continues:

```
[TEST PROF ERROR] Please, install 'stackprof' first:
   # Gemfile
  gem 'stackprof', '>= 0.2.9', require: false
```

StackProf's artifact name carries its settings: mode defaults to `wall` and raw mode is
**on** unless `TEST_STACK_PROF_RAW=0`, so a default run writes
`tmp/test_prof/stack-prof-report-wall-raw-total.dump`. Read it with
`stackprof --text <path>`. Raw mode also produces a `…-total.json` beside it, and that
JSON — not the `.dump` — is what Speedscope loads.

### Sample modes — needs a require

```ruby
# spec/rails_helper.rb
require "test_prof/recipes/rspec/sample"
```

```bash
SAMPLE=100 bundle exec rspec          # a random 100 examples
SAMPLE_GROUPS=10 bundle exec rspec    # a random 10 example groups
```

The recipe reads the variables at require time, so **without the require both commands
run the entire suite and say nothing about it.** Verified: 5 examples with the require
absent, 2 with it present under `SAMPLE=2`.

## Optimization primitives

### `let_it_be` — one record per example group

```ruby
# spec/rails_helper.rb — this file, not spec_helper.rb
require "test_prof/recipes/rspec/let_it_be"
```

```ruby
RSpec.describe Post, type: :model do
  let_it_be(:author) { create(:user) }
  let_it_be(:post) { create(:post, author: author) }

  it "has an author" do
    expect(post.author).to eq(author)
  end
end
```

**The require belongs in `rails_helper.rb` because the recipe registers its `reload:`,
`refind:` and `freeze:` modifiers only `if defined?(::ActiveRecord::Base)`, evaluated
once at require time (`let_it_be.rb:220`).** In the standard rspec-rails layout
`spec_helper.rb` loads before `config/environment`, so requiring it there leaves the
modifier registry empty and the first `let_it_be(:user, reload: true)` in the suite
raises at load time:

```
let_it_be.rb:58:in 'Hash#fetch': key not found: :reload (KeyError)
```

**`let_it_be` is eager, not lazily memoized.** It registers an unconditional
`before_all` (`let_it_be.rb:118`), so the block runs for the group whether or not any
example calls the reader. Verified: a group whose single example never touches the helper
still finds the record in the database. That is what makes it fast for records many
examples share, and what makes it a cost in a group where one example out of ten needs
the record.

**Mutation options.** All three depend on the project running with
`use_transactional_fixtures = true`; without a per-example transaction the record's
mutation is committed and there is nothing to undo.

- `let_it_be(:user, reload: true)` — calls `reload`, so attributes come back fresh and
  **the object stays the same instance**, carrying any memoized instance state with it.
- `let_it_be(:user, refind: true)` — re-fetches, returning **a new instance**, which is
  the only one of the two that clears memoized state. Verified across two examples: the
  `reload:` helper kept one object id, the `refind:` helper's changed.
- `let_it_be(:user, freeze: true)` — freezes the record so an accidental mutation raises
  instead of leaking into the next example.

Start with `refind: true` when a group mutates the record and you are unsure what it
mutates; drop to `reload: true` or nothing once you know.

### `before_all` — shared setup inside a transaction

```ruby
# spec/rails_helper.rb
require "test_prof/recipes/rspec/before_all"
```

```ruby
RSpec.describe Organization, type: :model do
  before_all do
    @org = create(:organization)
    create_list(:user, 5, organization: @org)
  end
end
```

Like `before(:all)`, except the group is wrapped in a transaction that rolls back
afterwards. Reach for it when the setup is several records that do not read naturally as
one binding each.

### `AnyFixture` — setup that runs once for the whole test run

```ruby
# spec/rails_helper.rb
require "test_prof/recipes/rspec/any_fixture"
```

`AnyFixture.register(id) { … }` runs the block the first time that `id` is seen, caches
the result under `id`, and **returns the block's value**. **Register it where no
per-example transaction is open** — `before(:suite)` — and read it back with the
`fixture` DSL, which refinds cached records:

```ruby
# spec/rails_helper.rb
require "test_prof/recipes/rspec/any_fixture"
require "test_prof/any_fixture/dsl"

RSpec.configure do |config|
  config.include TestProf::AnyFixture::DSL

  config.before(:suite) do
    TestProf::AnyFixture.register(:seeded_plans) { FactoryBot.create_list(:plan, 3) }
  end
end
```

```ruby
RSpec.describe Subscription, type: :model do
  let(:plans) { fixture(:seeded_plans) }

  it "prices against the seeded plans" do
    expect(plans.size).to eq(3)
  end
end
```

Verified across three examples: the seeded records are visible in every example, a record
an example creates itself rolls back around them, and the seeded rows are deleted at the
end of the run.

Three properties to hold onto:

- **Registering from inside an example rolls the data back and leaves the cache
  pointing at rows that no longer exist.** Executed: a `let` that called `register`
  seeded three records in the first example, and the second example got the cached
  objects back with an empty table behind them. Registration belongs in
  `before(:suite)`, where no example transaction is open.
- **AnyFixture data registered that way is not rolled back per example.** Cleanup is a
  `DELETE FROM` at the end of the run. That is the point — it survives across groups —
  and it is also why it is the wrong home for data an example mutates.
- A group that must not see it opts out with the `with_clean_fixture: true` metadata,
  which the recipe wires to a shared context that cleans and disables AnyFixture for
  that group.

Since test-prof 1.5.0 the `fixture` DSL is a module to include rather than a refinement
to activate, which is what the `config.include TestProf::AnyFixture::DSL` line above is
for on Rails 7.2 and up.

### `FactoryDefault` — stop passing the same association everywhere

```ruby
# spec/rails_helper.rb
require "test_prof/recipes/rspec/factory_default"
```

```ruby
RSpec.describe Post, type: :model do
  let_it_be(:user) { create_default(:user) }
  let_it_be(:post) { create(:post) }  # uses the default user
end
```

`create_default` registers the record as the default for its type, so every later
factory call that needs a `user` association reuses it instead of creating another.
`FPROF=1`'s gap between total and top-level calls is what tells you this will help.
