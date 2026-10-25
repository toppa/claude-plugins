# Common slow-spec patterns

When `TPS_PROF` surfaces a slow example group, the cause is usually one of these three.
Each section gives the fingerprint, the mechanism, and a fix that has been executed
against rspec-core 3.13.6, rspec-mocks 3.13.8 and Ruby 3.4.5.

## Pattern 1: scanning the object space on every example

### Fingerprint

Runtime scales with the size of the application rather than the size of the test.
`ObjectSpace.each_object`, `Module#descendants` or `Class#subclasses` show up in hot
frames, usually inside a helper that wants "every class that responds to X".

### Mechanism

```ruby
before do
  ObjectSpace.each_object(Class) do |klass|
    next unless klass < SomeBase
    stub_method_on(klass)
  end
end
```

A mature Rails app has tens of thousands of loaded modules, and walking all of them for
every example repeats work whose answer does not change: 1,000 examples across 50,000
modules is 50 million operations after the first pass produced the answer.

### Fix

Two separate changes. Discover the classes once per process, and apply the test
behaviour with a per-example stub, which rspec-mocks removes after each example:

```ruby
# spec/support/probe_targets.rb
module ProbeTargets
  def self.all
    @all ||= ObjectSpace.each_object(Class).select { |klass| klass < SomeBase }
  end
end
```

```ruby
before do
  ProbeTargets.all.each do |klass|
    allow_any_instance_of(klass).to receive(:the_method).and_return(:test_mode)
  end
end
```

The expensive walk now happens on the first example and never again, and the stub is
undone when the example ends. Executed: the memoized list found both subclasses, both
examples in the group saw the stubbed value, and a later group saw the production
value.

**Keep the change reversible: stub in a `before`, as above.** A `Module#prepend` in
`before(:all)` is process-global and cannot be undone, and there is no `after(:all)` that
would put it back — so every spec file that runs later in the same process inherits the
patch, in an order that depends on RSpec's random seed. That trades a slow suite for an
unreliable one, which is a worse trade than the runtime it buys.

## Pattern 2: production retry and backoff sleeping for real

### Fingerprint

```bash
TEST_RUBY_PROF=1 bundle exec rspec path/to/spec.rb
```

Time concentrated in `Kernel#sleep`. It also shows as long wall-clock time with low CPU
time — the process is waiting, not computing. (`TEST_RUBY_PROF`, not `RUBY_PROF`, and it
needs `ruby-prof >= 1.4.0` in the bundle.)

### Mechanism

Production code retries with a backoff, which is correct in production:

```ruby
# lib/discovery_service.rb
def fetch_with_retries(url, attempts: 3)
  attempts.times do |i|
    return http.get(url)
  rescue TransientError
    sleep(2 ** i)  # 1s, 2s, 4s… in production
  end
end
```

A test that exercises the retry path then waits through those real backoffs.

### Fix

Make the delay injectable, defaulting to the production value:

```ruby
# lib/discovery_service.rb
def fetch_with_retries(url, attempts: 3, base_delay: 1.0)
  attempts.times do |i|
    return http.get(url)
  rescue TransientError
    sleep(base_delay * (2 ** i))
  end
end

# spec/services/discovery_service_spec.rb
subject(:service) { DiscoveryService.new(base_delay: 0.01) }
```

This is the one case where a production parameter earns its place: the delay is a policy
the caller legitimately owns, and a scheduled job or a latency-sensitive path may want a
different one. Prefer it to stubbing `Kernel#sleep` globally, which reaches code you did
not mean to change.

## Pattern 3: hundreds of records to exercise a limit

### Fingerprint

A file creates hundreds or thousands of records to check behaviour at a boundary, and
shared setup time dwarfs the examples. Grep for `create_list(:thing, 600)` and
`500.times { create(:thing) }`.

### Mechanism

```ruby
# app/services/fraud_manager.rb
MAX_LIMIT = 500

def recent_transactions
  Transaction.order(created_at: :desc).limit(MAX_LIMIT)
end

# spec/services/fraud_manager_spec.rb
before { create_list(:transaction, 600) }
```

### Fix

Lower the boundary for the duration of the example with `stub_const`, then use a handful
of records:

```ruby
it 'returns at most the limit' do
  stub_const('FraudManager::MAX_LIMIT', 2)
  create_list(:transaction, 3)

  expect(FraudManager.new.recent_transactions.size).to eq(2)
end
```

The method reads the constant when it runs, so the stub reaches it, and rspec-mocks
restores the real value after the example. Executed: the limit held at 2 with three
records, and the next example saw 500 again.

`stub_const` is what makes this a test-only change. Adding `max_limit:` to the
constructor would work too, but nothing in production would ever pass it — a production
API existing only for test speed, where the constant plus a stub already gives you the
same three-record example.

## A quick mental check

1. Does anything in setup run per example without needing to? → `let_it_be`,
   `before_all`, or memoize the discovery once.
2. Is real time being spent waiting? → make the wait injectable, or stub the call that
   waits rather than the sleeping primitive.
3. Is the test creating more data than the behaviour needs? → `stub_const` the threshold
   and test with a handful.

In that order. It is almost always one of the three.
