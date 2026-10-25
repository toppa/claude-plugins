# Testing Rails Generators with RSpec

Testing generators from an RSpec suite. Checked against rspec-rails 8.0.4 / railties 8.1.3.1 / Ruby 3.4.5.

## Table of Contents

- [Setup](#setup)
- [Basic Testing with generator_spec](#basic-testing-with-generator_spec)
- [Structure Assertions](#structure-assertions)
- [Testing Options](#testing-options)
- [Testing Against a Dummy App](#testing-against-a-dummy-app)
- [Mixing RSpec and Rails Assertions](#mixing-rspec-and-rails-assertions)

## Setup

Two facts to settle before any of the examples below make sense.

**`type: :generator` on its own gives you nothing.** rspec-rails 8.0.4 has
`generator: %w[spec generator]` in `DIRECTORY_MAPPINGS`, so a file in `spec/generator/` is tagged
`type: :generator` automatically — but there is **no** `GeneratorExampleGroup`, so the tag supplies no helper
methods. `run_generator`, `destination`, `destination_root` and `prepare_destination` all come from
`Rails::Generators::Testing` modules (or from the `generator_spec` gem, which includes them for you).

**The directory is `spec/generator` — singular.** That is rspec-rails' own mapping. A file under
`spec/generators/` still runs; it just does not pick up the type tag.

### Option A — include the Rails helpers directly, no extra gem

Works with nothing but rspec-rails, and uses the twelve assertions documented in
[testing-rails.md](testing-rails.md#assertion-methods):

```ruby
# spec/generator/service_generator_spec.rb
require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/assertions'
require 'generators/service/service_generator'

RSpec.describe ServiceGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include ActiveSupport::Testing::Assertions   # supplies assert_nothing_raised — see below
  include Rails::Generators::Testing::Assertions
  include FileUtils

  self.destination_root = File.expand_path('../../tmp/generator', __dir__)
  self.generator_class = described_class

  before { prepare_destination }

  it 'creates the service file' do
    run_generator ['payment_processor']

    assert_file 'app/services/payment_processor_service.rb' do |content|
      expect(content).to match(/class PaymentProcessorService/)
    end
  end
end
```

Verified: that spec, with six examples covering `assert_file` with and without a block, `assert_directory`,
`assert_no_directory` and the `type: :generator` tag, ran green under rspec-rails 8.0.4.

Three modules, each pulling its weight:

- **`Rails::Generators::Testing::Behavior`** — `run_generator`, `prepare_destination`, and the
  `destination_root` / `generator_class` class writers.
- **`Rails::Generators::Testing::Assertions`** — `assert_file` and its eleven siblings.
- **`ActiveSupport::Testing::Assertions`** — and this one is easy to miss. **`assert_file` with a block calls
  `assert_nothing_raised`, which is a Minitest assertion RSpec does not define.** Without this include, every
  block form fails with `NoMethodError: undefined method 'assert_nothing_raised'` — measured: four of six
  examples failed on exactly that, while the blockless `assert_file` and `assert_directory` passed. Any RSpec
  guide that shows `assert_file … do |content|` without it is showing a spec that cannot run.

`include FileUtils` is what `Rails::Generators::TestCase` itself does, and `prepare_destination` needs it.

### Option B — the `generator_spec` gem

```ruby
group :development, :test do
  gem 'generator_spec'
end
```

Adds the `have_structure` matcher and includes the Rails helpers for you. **The `have_structure` /
`no_file` / `contains` DSL below is the gem's, and was not verifiable here** — the gem is not installed on this
stack, so treat those blocks as the gem's documented API rather than as something measured. Everything using
`assert_file` was executed.

Only add the gem to your own project. On a shared codebase, Option A needs no dependency at all.

## Basic Testing with generator_spec

### Running Generators

```ruby
RSpec.describe ServiceGenerator, type: :generator do
  destination File.expand_path('../../tmp', __FILE__)
  before { prepare_destination }

  context "with default options" do
    before { run_generator ["payment_processor"] }

    it "creates service file" do
      expect(destination_root).to have_structure {
        directory "app/services" do
          file "payment_processor_service.rb" do
            contains "class PaymentProcessorService"
            contains "def call"
          end
        end
      }
    end

    it "creates the spec file" do
      expect(destination_root).to have_structure {
        directory "spec/services" do
          file "payment_processor_service_spec.rb"
        end
      }
    end
  end
end
```

### With Arguments and Options

```ruby
context "with namespace option" do
  before { run_generator ["payment", "--namespace=billing"] }

  it "creates namespaced service" do
    expect(destination_root).to have_structure {
      directory "app/services/billing" do
        file "payment_service.rb" do
          contains "module Billing"
          contains "class PaymentService"
        end
      end
    }
  end
end

context "with multiple options" do
  before do
    run_generator ["payment", "--namespace=billing", "--async", "--skip-tests"]
  end

  it "creates an async service and no spec" do
    expect(destination_root).to have_structure {
      directory "app/services/billing" do
        file "payment_service.rb" do
          contains "def self.call_later"
        end
      end
      directory "app/jobs/billing" do
        file "payment_job.rb"
      end
      no_file "spec/services/billing/payment_service_spec.rb"
      no_file "test/services/billing/payment_service_test.rb"
    }
  end
end
```

## Structure Assertions

### `have_structure` Matcher

The `generator_spec` gem provides a `have_structure` matcher:

```ruby
expect(destination_root).to have_structure {
  # Check directory exists
  directory "app/services"

  # Check directory with nested assertions
  directory "app/services" do
    # Check file exists
    file "payment_service.rb"

    # Check file with content
    file "payment_service.rb" do
      contains "class PaymentService"
      does_not_contain "TODO"
    end
  end

  # Check file does NOT exist
  no_file "app/services/old_service.rb"
}
```

Unverified here — the gem is not installed on this stack. The `assert_file` equivalents in
[Option A](#option-a--include-the-rails-helpers-directly-no-extra-gem) were all executed.

### Content Assertions

```ruby
file "payment_service.rb" do
  # String contains
  contains "class PaymentService"

  # Negative assertion
  does_not_contain "TODO"
  does_not_contain "FIXME"
end
```

## Testing Options

### Boolean Options

```ruby
context "with skip-tests option" do
  before { run_generator ["payment", "--skip-tests"] }

  it "skips test file" do
    expect(destination_root).to have_structure {
      directory "app/services" do
        file "payment_service.rb"
      end
      no_file "spec/services/payment_service_spec.rb"
      no_file "test/services/payment_service_test.rb"
    }
  end
end
```

Assert the absence of **both** paths for `--skip-tests`. A generator that reads the configured framework writes
to one or the other, so checking only `test/` passes on a project where it actually wrote to `spec/`.

### Array Options — space-separated

```ruby
context "with dependencies" do
  before { run_generator ["payment", "--dependencies", "user", "account"] }

  it "generates a keyword constructor" do
    assert_file "app/services/payment_service.rb" do |content|
      expect(content).to include("def initialize(user:, account:)")
      expect(content).to match(/^    @user = user$/)
      expect(content).to match(/^    @account = account$/)
    end
  end
end

context "when the array option is given commas" do
  before { run_generator ["payment", "--dependencies=user,account"] }

  it "receives a single element, which is Thor's actual behaviour" do
    assert_file "app/services/payment_service.rb" do |content|
      expect(content).to include("def initialize(user,account:)")
    end
  end
end
```

**`--dependencies=user,account` yields `["user,account"]`, one element.** Measured against Thor 1.5.0, so
`def initialize(user:, account:)` is never generated by the comma form. Hash options are the same:
`--config timeout:30 retries:3` gives two pairs, while `--config={timeout:30,retries:3}` drops `timeout`
silently.

`assert_file` with anchored regexes is used here rather than `contains`, because `contains "@user = user"` passes
even when the generated indentation is wrong — and misaligned assignments are a regression a generator produces
easily.

### String Options

```ruby
context "with command pattern" do
  before { run_generator ["payment", "--pattern=command"] }

  it "generates command-style service" do
    expect(destination_root).to have_structure {
      directory "app/services" do
        file "payment_service.rb" do
          contains "attr_reader :errors"
          contains "def validate!"
          contains "def execute"
        end
      end
    }
  end
end
```

## Testing Against a Dummy App

Generators that modify existing files — `route`, `initializer`, `inject_into_file` — need those files to exist.
Give the generator a destination that already contains them, and keep the whole thing inside
`destination_root`:

```ruby
RSpec.describe ApiControllerGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include ActiveSupport::Testing::Assertions   # assert_file's block form needs it
  include Rails::Generators::Testing::Assertions
  include FileUtils

  self.destination_root = File.expand_path('../../tmp/generator', __dir__)
  self.generator_class = described_class

  before do
    prepare_destination
    # Seed only the files the generator needs to modify.
    mkdir_p File.join(destination_root, 'config')
    File.write(File.join(destination_root, 'config/routes.rb'),
               "Rails.application.routes.draw do\nend\n")
  end

  it 'merges routes into a single namespace block across runs' do
    run_generator ['product', 'name:string']
    run_generator ['order', 'total:decimal']

    assert_file 'config/routes.rb' do |content|
      expect(content.scan(/namespace :api do/).size).to eq(1)
      expect(content).to include('resources :products')
      expect(content).to include('resources :orders')
    end
  end
end
```

**Do not shell a generator into a live source tree.** The version this replaces did
`Dir.chdir(dummy_app_path) { \`rails generate service payment_processor\` }`, and it has four separate problems:

- **Backtick output and exit status are discarded**, so a generator that failed reads as a spec that failed for
  a different reason.
- **Cleanup runs only on the happy path.** An assertion failure raises before `FileUtils.rm_rf`, leaving
  generated files and an injected route behind for the next run to trip over.
- **`Dir.chdir` is process-global**, so it corrupts any example running in parallel.
- **It mutates checked-in files.** `config/routes.rb` in that tree is under version control, and the second
  example's cleanup is `rails destroy`, which only undoes what Thor can invert (see
  [file-actions.md](file-actions.md#revoke-and-behavior) — `gsub_file` needs `force: true` under revoke).

`prepare_destination` plus a seeded `destination_root` gets you the same coverage with none of that: it is a
scratch directory, it is emptied before each example, and `run_generator` runs in-process so you keep the
output string.

## Mixing RSpec and Rails Assertions

Rails' generator assertions work inside RSpec examples, and mixing them with `expect` is the most economical
combination: `assert_file` locates and reads the file, `expect` describes the content.

```ruby
RSpec.describe ServiceGenerator, type: :generator do
  include Rails::Generators::Testing::Behavior
  include ActiveSupport::Testing::Assertions
  include Rails::Generators::Testing::Assertions
  include FileUtils

  self.destination_root = File.expand_path('../../tmp/generator', __dir__)
  self.generator_class = described_class

  before { prepare_destination }

  context 'with default options' do
    before { run_generator ['payment'] }

    it 'creates the service with the right content' do
      assert_file 'app/services/payment_service.rb' do |content|
        expect(content).to match(/class PaymentService/)
        expect(content).to match(/def call/)
      end
    end

    it 'creates the migration at whatever timestamp it got' do
      assert_migration 'db/migrate/create_payments.rb' do |content|
        expect(content).to match(/create_table :payments/)
      end
    end
  end
end
```

Two things this spec does that the short version cannot:

- **`include ActiveSupport::Testing::Assertions`.** Both examples above use the *block* form, and that form calls
  `assert_nothing_raised` internally. Without the include they fail with
  `NoMethodError: undefined method 'assert_nothing_raised'` — reproduced. This is the single most common reason
  an RSpec generator spec copied from a guide does not run.
- **`self.destination_root =` and `self.generator_class =`**, not `destination`/`tests`. Those two class macros
  belong to `Rails::Generators::TestCase`; in a plain RSpec example group the writers from
  `Testing::Behavior` are what exist. (The `generator_spec` gem adds `destination` as an alias.)

### Custom RSpec Matchers

```ruby
RSpec::Matchers.define :generate_file do |path|
  match do |generator_args|
    prepare_destination
    run_generator generator_args
    File.exist?(File.join(destination_root, path))
  end

  failure_message do |generator_args|
    "expected generator with args #{generator_args} to create #{path}"
  end
end

# Usage
it { expect(["payment"]).to generate_file("app/services/payment_service.rb") }
```

A matcher that runs the generator inside `match` is convenient for the one-liner case, but it hides the
generator's output string — which is where a `error  rspec  [not found]` line from a missing hook responder shows
up. When a generator has hooks, assert on the output as well as on the files:

```ruby
it 'invokes a responder that actually exists' do
  output = run_generator ['payment', '--test-framework=rspec']

  expect(output).not_to include('[not found]')
  assert_file 'spec/models/payment_spec.rb'
end
```

A missing responder prints `error  <framework>  [not found]`, writes no file, raises nothing and exits 0 —
reproduced — so a spec that only checks the main file passes on a hook that did nothing.

## Cross-references

- [testing-rails.md](testing-rails.md) — the same scenarios with `Rails::Generators::TestCase`, plus the full
  list of built-in assertions and the behaviours that do not raise.
- [hooks.md](hooks.md) — which responders exist and how `--test-framework` selects one.
