# Diagnostic snippets

Drop-in snippets for when no profiler is available — no new gems required. Each one names
the file it belongs in, because the two spec helpers load at different times: on the
standard rspec-rails layout `spec_helper.rb` runs before `config/environment`, so
anything touching Rails, ActiveSupport or ActiveRecord belongs in `spec/rails_helper.rb`.

All four were executed against rspec-core 3.13.6 on Ruby 3.4.5.

## GC time tracker — `spec/spec_helper.rb`

Prints GC time accumulated every 1,000 examples and a total at the end. Stdlib only, so
this one is safe in `spec_helper.rb`.

```ruby
RSpec.configure do |config|
  examples_seen = 0
  last_gc_time = 0

  config.after(:each) do
    examples_seen += 1
    if (examples_seen % 1_000).zero?
      elapsed = GC.total_time - last_gc_time
      last_gc_time = GC.total_time
      puts "[GC] #{elapsed / 1_000_000}ms over the last 1,000 examples"
    end
  end

  config.after(:suite) { puts "[GC] total: #{GC.total_time / 1_000_000}ms" }
end
```

`GC.total_time` is nanoseconds on Ruby 3.4, hence the division. How to read it:

- Steady numbers per 1,000 examples → healthy.
- Numbers growing as the suite progresses → memory accumulating; `bottlenecks.md` #5 is
  the usual suspect in a project that develops cops.
- A large first chunk and little after → boot-time allocation, not a per-example problem.

## Per-file runtime summary — `spec/spec_helper.rb`

A poor person's `TPS_PROF`, for a project that does not have `test-prof` yet. It reports
per **file**, where `TPS_PROF` reports per example group, so the two answer slightly
different questions and this one is the coarser.

```ruby
RSpec.configure do |config|
  file_times = Hash.new(0.0)
  file_counts = Hash.new(0)

  config.around(:each) do |example|
    file = example.metadata[:file_path]
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    example.run
    file_times[file] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    file_counts[file] += 1
  end

  config.after(:suite) do
    puts "\n[PER-FILE] Top 20 slowest files (time, count, TPS):"
    file_times.sort_by { |_, time| -time }.first(20).each do |file, total|
      count = file_counts[file]
      puts format('  %8.2fs  %5d ex  %6.2f TPS  %s', total, count, count / total, file)
    end
  end
end
```

## Factory call counter — `spec/rails_helper.rb`

A zero-dependency FactoryProf: it subscribes to factory_bot's own notification, so it
needs `ActiveSupport::Notifications`, which arrives with `config/environment`.

```ruby
RSpec.configure do |config|
  counts = Hash.new(0)

  ActiveSupport::Notifications.subscribe('factory_bot.run_factory') do |*, payload|
    counts[payload[:name]] += 1
  end

  config.after(:suite) do
    puts "\n[FACTORIES] Top 10 most-called factories:"
    counts.sort_by { |_, count| -count }.first(10).each do |name, count|
      puts format('  %6d  %s', count, name)
    end
  end
end
```

A factory called tens of thousands of times is a candidate for `let_it_be` or
`create_default`. The count includes associations built on the way to another factory,
which is what makes it a fan-out signal as well as a usage one.

## Boot time — the shell, or the existing require

"The suite is slow" sometimes means "loading the app is slow". Measure it from outside:

```bash
time ruby -e "require './config/environment'"
```

To measure it inside the suite, time the require `rails_helper.rb` already performs
rather than adding a second one — `config/environment` is not idempotent work you want to
pay for twice:

```ruby
# spec/rails_helper.rb, around the existing require
boot_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require_relative '../config/environment'
puts "[BOOT] #{Process.clock_gettime(Process::CLOCK_MONOTONIC) - boot_started}s"
```

If boot alone is 10 seconds or more, look at initializers and eager loading before
blaming the specs. `TEST_STACK_PROF=boot bundle exec rspec` profiles the same phase when
`stackprof` is in the bundle.
