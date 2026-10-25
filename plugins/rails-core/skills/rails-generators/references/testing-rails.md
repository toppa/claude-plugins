# Testing Rails Generators with Rails::Generators::TestCase

Testing generators with the framework's own test case. Every behavioural claim below was executed against a real
`Rails::Generators::TestCase` on railties 8.1.3.1 / Thor 1.5.0 / Ruby 3.4.5, because several of the obvious
assertions do not hold.

## Table of Contents

- [Test Setup](#test-setup)
- [Running Generators in Tests](#running-generators-in-tests)
- [Assertion Methods](#assertion-methods)
- [Testing Options and Arguments](#testing-options-and-arguments)
- [Testing Generator Hooks](#testing-generator-hooks)
- [Testing File Modifications](#testing-file-modifications)
- [Testing Template Rendering](#testing-template-rendering)
- [Testing Generator Composition](#testing-generator-composition)
- [Integration Testing](#integration-testing)
- [Advanced Testing Patterns](#advanced-testing-patterns)
- [Test Organization](#test-organization)
- [Running Tests](#running-tests)
- [Best Practices](#best-practices)
- [Cross-references](#cross-references)

## Test Setup

### Basic Test Structure

```ruby
require 'test_helper'
require 'generators/service/service_generator'

class ServiceGeneratorTest < Rails::Generators::TestCase
  tests ServiceGenerator
  destination File.expand_path('../tmp', __dir__)

  setup :prepare_destination

  teardown :cleanup_destination

  private

  def cleanup_destination
    FileUtils.rm_rf(destination_root)
  end
end
```

### Configuration

```ruby
class ServiceGeneratorTest < Rails::Generators::TestCase
  tests ServiceGenerator

  # Set temporary destination for generated files
  destination Rails.root.join('tmp/generators')

  # Prepare clean slate before each test
  setup :prepare_destination

  # Copy fixture files if needed
  setup :copy_fixtures

  private

  # Note the trailing "/." — it copies the directory's *contents* into destination_root.
  def copy_fixtures
    FileUtils.cp_r(
      "#{File.expand_path('../fixtures', __dir__)}/.",
      destination_root
    )
  end
end
```

`cp_r(fixtures, dest)` without the `/.` creates `<dest>/fixtures/...`, one level deeper than every assertion in
this file assumes. Pick one form and use it everywhere; the two differ silently and the failure reads as "the
generator did not create the file".

## Running Generators in Tests

### Basic Generation

```ruby
test "generates service file" do
  run_generator ["payment_processor"]

  assert_file "app/services/payment_processor_service.rb"
end
```

### With Arguments and Options

```ruby
test "generates with namespace" do
  run_generator ["payment", "--namespace=billing"]

  assert_file "app/services/billing/payment_service.rb"
end

test "generates with multiple options" do
  run_generator ["payment", "--namespace=billing", "--async", "--skip-tests"]

  assert_file "app/services/billing/payment_service.rb"
  assert_no_file "test/services/billing/payment_service_test.rb"
end
```

### Errors, and the two things that do not raise

Both of these were run against a real `Rails::Generators::TestCase` on railties 8.1.3.1, and both of the
obvious assertions fail.

**A missing required argument does not raise.** `run_generator []` prints
`No value provided for required arguments 'name'` to the console and **returns `""`** — no exception, exit
status untouched. So assert on the absence of output, not on `assert_raises`:

```ruby
test "generates nothing without a name" do
  assert_equal "", run_generator([])
  assert_no_file "app/services/_service.rb"
end
```

**An unknown option is silently ignored.** `check_unknown_options!` appears **nowhere** in railties 8.1.3.1
(grepped across the gem), so nothing warns:

```ruby
test "an unknown option is ignored rather than rejected" do
  output = run_generator ["payment", "--invalid-option=value"]

  # Documents the behaviour: the generator runs normally and says nothing about the flag.
  assert_match(/create  app\/services\/payment_service\.rb/, output)
  refute_match(/Unknown option/, output)
end
```

Measured on a throwaway generator, the whole output for that second case was the single `create` line for the
file it wrote, and nothing about the flag. A test asserting
`/Unknown option/` therefore fails, and — worse as documentation — implies a safety net that is not there. If
you want unknown options rejected, call `check_unknown_options!` in your own generator class; Thor provides
it even though railties does not use it.

## Assertion Methods

### File Assertions

#### assert_file

Basic file existence:
```ruby
test "creates service file" do
  run_generator ["payment"]

  assert_file "app/services/payment_service.rb"
end
```

With content checking:
```ruby
test "creates service with correct content" do
  run_generator ["payment"]

  assert_file "app/services/payment_service.rb" do |content|
    assert_match(/class PaymentService/, content)
    assert_match(/def call/, content)
    assert_match(/# Implementation/, content)
  end
end
```

Multiple assertions:
```ruby
test "creates properly structured service" do
  run_generator ["payment_processor", "--dependencies", "account"]

  assert_file "app/services/payment_processor_service.rb" do |content|
    # Check class definition
    assert_match(/class PaymentProcessorService/, content)

    # Check initialization
    assert_match(/def initialize\(account:\)/, content)

    # Check main method
    assert_match(/def call/, content)

    # Ensure no typos
    refute_match(/Paymen tProcessor/, content)
  end
end
```

#### assert_no_file

```ruby
test "skips test file with option" do
  run_generator ["payment", "--skip-tests"]

  assert_file "app/services/payment_service.rb"
  assert_no_file "test/services/payment_service_test.rb"
end

test "does not create unnecessary files" do
  run_generator ["payment"]

  assert_no_file "app/services/payment_controller.rb"
  assert_no_file "app/models/payment_service.rb"
end
```

#### assert_migration

```ruby
test "creates migration" do
  run_generator ["create_payments"]

  assert_migration "db/migrate/create_payments.rb" do |content|
    assert_match(/class CreatePayments < ActiveRecord::Migration/, content)
    assert_match(/create_table :payments/, content)
  end
end

test "creates migration with timestamp" do
  run_generator ["add_status_to_orders"]

  # Check migration exists with any timestamp
  assert_migration "db/migrate/add_status_to_orders.rb"
end
```

### Directory Assertions

`assert_directory` and `assert_no_directory` are built in — do not define your own.

```ruby
test "creates directory structure" do
  run_generator ["payment", "--namespace=billing/processors"]

  assert_directory "app/services/billing"
  assert_directory "app/services/billing/processors"
  assert_no_directory "app/services/marketing"
  assert_file "app/services/billing/processors/payment_service.rb"
end
```

`Rails::Generators::Testing::Assertions` defines **twelve** public assertions, enumerated from the module in
railties 8.1.3.1:

| Assertion | What it checks |
|---|---|
| `assert_file` / `assert_no_file` | a path exists (optional content block) |
| `assert_directory` / `assert_no_directory` | a directory exists |
| `assert_migration` / `assert_no_migration` | a migration matching the name, at any timestamp |
| `assert_initializer` | a file under `config/initializers/` |
| `assert_method` | a `def <name>` in the given content |
| `assert_class_method` | a `def self.<name>` |
| `assert_instance_method` | a `def <name>` inside the given class body |
| `assert_field_type` | a migration column's type |
| `assert_field_default_value` | a migration column's default |

Defining a same-named helper does not add anything and **silently changes the semantics of the built-in** for
every test in the class — a hand-rolled `assert_directory` that only checks `File.directory?` loses the
built-in's failure message and its alias behaviour. `respond_to?` returned true for `assert_directory`,
`assert_no_directory` and `assert_initializer` in a live `TestCase`.

### Content Assertions

```ruby
test "generates correct class name" do
  run_generator ["payment_processor"]

  assert_file "app/services/payment_processor_service.rb" do |content|
    assert_match(/\bclass PaymentProcessorService\b/, content)
    refute_match(/\bclass PaymentProcessor\b/, content)
  end
end

test "generates the enqueue path with --async" do
  run_generator ["payment", "--async"]

  assert_file "app/services/payment_service.rb" do |content|
    assert_match(/def self\.call_later/, content)
  end
  assert_file "app/jobs/payment_job.rb"
end

test "omits the enqueue path by default" do
  run_generator ["payment"]

  assert_file "app/services/payment_service.rb" do |content|
    refute_match(/def self\.call_later/, content)
  end
  assert_no_file "app/jobs/payment_job.rb"
end
```

## Testing Options and Arguments

### Boolean Options

```ruby
test "respects skip-tests option" do
  run_generator ["payment", "--skip-tests"]

  assert_file "app/services/payment_service.rb"
  assert_no_file "test/services/payment_service_test.rb"
end

test "respects no-skip-tests option" do
  run_generator ["payment", "--no-skip-tests"]

  assert_file "app/services/payment_service.rb"
  assert_file "test/services/payment_service_test.rb"
end
```

### String Options

```ruby
test "uses custom namespace" do
  run_generator ["payment", "--namespace=billing"]

  assert_file "app/services/billing/payment_service.rb" do |content|
    assert_match(/module Billing/, content)
    assert_match(/class PaymentService/, content)
  end
end

test "handles deep namespace" do
  run_generator ["payment", "--namespace=billing/api/v1"]

  assert_file "app/services/billing/api/v1/payment_service.rb" do |content|
    assert_match(/module Billing/, content)
    assert_match(/module Api/, content)
    assert_match(/module V1/, content)
  end
end
```

### Array Options — space-separated

```ruby
test "generates with multiple dependencies" do
  run_generator ["payment", "--dependencies", "user", "account", "payment_method"]

  assert_file "app/services/payment_service.rb" do |content|
    assert_match(/def initialize\(user:, account:, payment_method:\)/, content)
    assert_match(/^    @user = user$/, content)
    assert_match(/^    @account = account$/, content)
    assert_match(/^    @payment_method = payment_method$/, content)
  end
end

test "a comma-separated array option arrives as one element" do
  run_generator ["payment", "--dependencies=user,account"]

  # Pins Thor's real behaviour so nobody "corrects" the docs above.
  assert_file "app/services/payment_service.rb" do |content|
    assert_match(/def initialize\(user,account:\)/, content)
  end
end
```

**`--dependencies=user,account` yields `["user,account"]`, one element.** Measured against Thor 1.5.0, so a test written
with commas never generates the three-keyword constructor it asserts. Anchor the assignment assertions with
`^` and `$`: a bare `/@user = user/` passes even when the generated indentation is wrong, which is a real
regression a pre-joined `join("\n      ")` in the generator produces.

### Hash Options — space-separated `key:value` pairs

```ruby
test "generates with configuration" do
  run_generator ["payment", "--config", "timeout:30", "retries:3"]

  assert_file "config/initializers/payment_service.rb" do |content|
    assert_match(/timeout: 30/, content)
    assert_match(/retries: 3/, content)
  end
end
```

**There is no brace syntax.** `--config={timeout:30,retries:3}` parses to `{"retries" => "3"}` — `timeout` is
silently dropped — while `--config timeout:30 retries:3` parses to `{"timeout" => "30", "retries" => "3"}`.
Both measured. A single value may contain commas, though: `--enums status:draft,published` gives
`{"status" => "draft,published"}`, which the generator splits itself.

## Testing Generator Hooks

### Hook Invocation

```ruby
test "invokes multiple hooks" do
  run_generator ["payment"]

  # Main file
  assert_file "app/services/payment_service.rb"

  # Test hook
  assert_file "test/services/payment_service_test.rb"

  # Fixture hook (if configured)
  assert_file "test/fixtures/payments.yml"
end

```

**Drive the CLI switch `hook_for` creates; do not mutate configuration.** `class_option` freezes its default at
class-definition time, and the generator is `require`d at the top of the test file — so a `with_test_framework`
helper that flips `Rails.application.config.generators` (or `Rails::Generators.options`) inside an example has no
effect on the already-loaded class. Proved by execution: setting both hashes to `:rspec` left the baked default
where it was, and only a class loaded *after* the change picked it up.

`hook_for :test_framework` creates a real `--test-framework` flag, so `run_generator` can select the responder:

```ruby
test "invokes the rspec responder when asked" do
  run_generator ["payment", "--test-framework=rspec"]

  assert_file "app/services/payment_service.rb"
  assert_file "spec/models/payment_spec.rb"
end

test "invokes the test_unit responder when asked" do
  run_generator ["payment", "--test-framework=test_unit"]

  assert_file "test/models/payment_test.rb"
end
```

Verified: `--test-framework=test_unit` changed which namespace was searched. And note that a responder your
generator names but nobody ships — `as: :service`, for instance — prints `error  <framework>  [not found]`,
writes no file and exits 0, so a test that only asserts the main file passes on a hook that did nothing.

### Hook Options Pass-Through

```ruby
test "passes options to hooks" do
  run_generator ["payment", "--namespace=billing", "--async"]

  assert_file "test/services/billing/payment_service_test.rb" do |content|
    # Verify hook received namespace option
    assert_match(/class Billing::PaymentServiceTest/, content)

    # Verify hook received async option
    assert_match(/test "async behavior"/, content)
  end
end
```

## Testing File Modifications

### Routes

```ruby
test "adds routes" do
  run_generator ["payment"]

  assert_file "config/routes.rb" do |content|
    assert_match(/resources :payments/, content)
  end
end

test "adds namespaced routes" do
  run_generator ["payment", "--namespace=api/v1"]

  assert_file "config/routes.rb" do |content|
    assert_match(/namespace :api/, content)
    assert_match(/namespace :v1/, content)
    assert_match(/resources :payments/, content)
  end
end
```

### Initializers

```ruby
test "creates initializer" do
  run_generator ["payment"]

  assert_file "config/initializers/payment_service.rb" do |content|
    assert_match(/Rails.application.config.to_prepare/, content)
    assert_match(/PaymentService.configure/, content)
  end
end
```

### Registry File Modifications

```ruby
test "registers the service in config/services.yml" do
  # Seed the file the generator modifies
  FileUtils.mkdir_p File.join(destination_root, 'config')
  File.write(File.join(destination_root, 'config/services.yml'), "---\n")

  run_generator ["payment"]

  assert_file "config/services.yml" do |content|
    assert_match(/payment: enabled/, content)
  end
end
```

A generator modifies files the app already owns. It does not add a gem to a shared project's `Gemfile` —
that is an application template's job. [file-actions.md](file-actions.md#gemfile-environment-and-command-actions)
states the distinction, in its "Gemfile, Environment and Command Actions" section.

## Testing Template Rendering

### Template Variables

```ruby
test "renders template with correct variables" do
  run_generator ["payment_processor"]

  assert_file "app/services/payment_processor_service.rb" do |content|
    # Check class_name variable
    assert_match(/class PaymentProcessorService/, content)

    # Check file_name variable
    assert_match(/# File: payment_processor_service.rb/, content)

    # Check plural_name (if applicable)
    assert_match(/# Handles payment_processors/, content)
  end
end
```

### Conditional Template Blocks

```ruby
test "includes optional blocks when option enabled" do
  run_generator ["payment", "--with-logging"]

  assert_file "app/services/payment_service.rb" do |content|
    assert_match(/include Loggable/, content)
    assert_match(/def log_operation/, content)
  end
end

test "excludes optional blocks by default" do
  run_generator ["payment"]

  assert_file "app/services/payment_service.rb" do |content|
    refute_match(/include Loggable/, content)
    refute_match(/def log_operation/, content)
  end
end
```

## Testing Generator Composition

### Invoking Other Generators

```ruby
test "invokes model generator" do
  run_generator ["payment"]

  # Main generator output
  assert_file "app/services/payment_service.rb"

  # Invoked model generator output
  assert_file "app/models/payment.rb"
  assert_migration "db/migrate/create_payments.rb"
end

test "conditionally invokes generators" do
  run_generator ["payment", "--with-job"]

  assert_file "app/services/payment_service.rb"
  assert_file "app/jobs/payment_job.rb"
end

test "does not invoke optional generators by default" do
  run_generator ["payment"]

  assert_file "app/services/payment_service.rb"
  assert_no_file "app/jobs/payment_job.rb"
end
```

## Integration Testing

### Full Feature Generation

```ruby
test "generates complete feature" do
  run_generator ["order", "--full"]

  # Model
  assert_file "app/models/order.rb"
  assert_migration "db/migrate/create_orders.rb"

  # Service
  assert_file "app/services/order_service.rb"

  # Controller
  assert_file "app/controllers/orders_controller.rb"

  # Views
  assert_file "app/views/orders/index.html.erb"
  assert_file "app/views/orders/show.html.erb"

  # Tests
  assert_file "test/models/order_test.rb"
  assert_file "test/services/order_service_test.rb"
  assert_file "test/controllers/orders_controller_test.rb"

  # Routes
  assert_file "config/routes.rb" do |content|
    assert_match(/resources :orders/, content)
  end
end
```

### Real-World Scenario

```ruby
test "generates payment processing system" do
  run_generator ["payment",
    "--namespace=billing",
    "--with-job",
    "--with-mailer",
    "--async"
  ]

  # Core service
  assert_file "app/services/billing/payment_service.rb" do |content|
    assert_match(/module Billing/, content)
    assert_match(/class PaymentService/, content)
    assert_match(/def self\.call_later/, content)
  end

  # Background job
  assert_file "app/jobs/billing/payment_job.rb"

  # Mailer
  assert_file "app/mailers/billing/payment_mailer.rb"

  # Tests for all components
  assert_file "test/services/billing/payment_service_test.rb"
  assert_file "test/jobs/billing/payment_job_test.rb"
  assert_file "test/mailers/billing/payment_mailer_test.rb"
end
```

## Advanced Testing Patterns

### Custom Assertions

```ruby
module GeneratorTestHelpers
  def assert_proper_service_structure(path)
    assert_file path do |content|
      assert_match(/class \w+Service/, content)
      assert_match(/def initialize/, content)
      assert_match(/def call/, content)
    end
  end

  def assert_namespaced_file(namespace, file_name)
    path = "app/services/#{namespace}/#{file_name}"
    assert_file path do |content|
      namespace_modules = namespace.split('/').map(&:camelize)
      namespace_modules.each do |mod|
        assert_match(/module #{mod}/, content)
      end
    end
  end
end

class ServiceGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelpers

  test "generates proper service" do
    run_generator ["payment"]
    assert_proper_service_structure "app/services/payment_service.rb"
  end

  test "generates namespaced service" do
    run_generator ["payment", "--namespace=billing/processors"]
    assert_namespaced_file "billing/processors", "payment_service.rb"
  end
end
```

### Testing with Fixtures

```ruby
class ServiceGeneratorTest < Rails::Generators::TestCase
  setup do
    prepare_destination
    copy_fixtures
  end

  test "integrates with existing code" do
    # Fixture provides existing base service
    assert File.exist?(File.join(destination_root, 'app/services/base_service.rb'))

    run_generator ["payment"]

    assert_file "app/services/payment_service.rb" do |content|
      # Should inherit from existing base
      assert_match(/class PaymentService < BaseService/, content)
    end
  end

  private

  def copy_fixtures
    fixture_path = File.expand_path('../fixtures', __dir__)
    FileUtils.cp_r("#{fixture_path}/.", destination_root)
  end
end
```

### Parameterized Tests

```ruby
class ServiceGeneratorTest < Rails::Generators::TestCase
  {
    'simple_name' => 'SimpleNameService',
    'payment_processor' => 'PaymentProcessorService',
    'api_handler' => 'ApiHandlerService'
  }.each do |input, expected_class|
    test "generates #{expected_class} from #{input}" do
      run_generator [input]

      assert_file "app/services/#{input}_service.rb" do |content|
        assert_match(/class #{expected_class}/, content)
      end
    end
  end
end
```

## Test Organization

### Grouping Related Tests

**Group with a shared module, or with separate top-level classes and a common superclass that declares no
tests.** Subclassing the test case is the shape to avoid: a subclass inherits its parent's test methods, so
every parent test runs again in each child. Measured: three declared tests in that shape produced **5 runs**,
with the parent's `"generates service file"` body executing **3 times** — once per class. On a slow generator
that triples the suite for no coverage.

The superclass form:

```ruby
# A base class with configuration and no test methods.
class ServiceGeneratorTestCase < Rails::Generators::TestCase
  tests ServiceGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination
end

class ServiceGeneratorBasicsTest < ServiceGeneratorTestCase
  test "generates service file" do
    run_generator ["payment"]
    assert_file "app/services/payment_service.rb"
  end
end

class ServiceGeneratorOptionsTest < ServiceGeneratorTestCase
  test "respects namespace option" do
    run_generator ["payment", "--namespace=billing"]
    assert_file "app/services/billing/payment_service.rb"
  end

  test "respects skip-tests option" do
    run_generator ["payment", "--skip-tests"]
    assert_no_file "test/services/payment_service_test.rb"
    assert_no_file "spec/services/payment_service_spec.rb"
  end
end
```

Each test body now runs exactly once, and the configuration is still declared in one place.

## Running Tests

### Command Line

```bash
# Run all generator tests
rails test test/generators

# Run specific generator test
rails test test/generators/service_generator_test.rb

# Run specific test
rails test test/generators/service_generator_test.rb:15

# With verbose output
RAILS_LOG_TO_STDOUT=true rails test test/generators/service_generator_test.rb

# With backtrace
rails test test/generators/service_generator_test.rb --backtrace
```

### Running them as part of the suite

`bin/rails test` already picks up `test/generators/**/*_test.rb`, so no Rake task is needed. If you want a named
task, use the framework's own:

```ruby
# lib/tasks/generator_tests.rake
namespace :test do
  desc "Run generator tests"
  task :generators do
    Rails::Command.invoke :test, ["test/generators"]
  end
end
```

**`Rails::TestTask` no longer exists** — verified, `NameError: uninitialized constant Rails::TestTask`, and the
constant appears nowhere in railties 8.1.3.1. It was removed years ago; a rake task built on it fails on load.

On an RSpec project the equivalent directory is **`spec/generator`** — singular — which is what rspec-rails
8.0.4's `DIRECTORY_MAPPINGS` uses (`generator: %w[spec generator]`). See
[testing-rspec.md](testing-rspec.md) for the RSpec side.

## Best Practices

1. **Always use `prepare_destination`** in setup, so each test starts from an empty destination.
2. **Reach for the twelve built-in assertions** before writing your own; a same-named helper silently replaces
   the built-in.
3. **Assert on absent output rather than `assert_raises`** for a missing argument, and on the generated file
   rather than a warning for an unknown option — neither raises.
4. **Write array and hash options space-separated**, and keep one test that pins the comma behaviour.
5. **Anchor content assertions with `^` and `$`** where indentation matters.
6. **Select a hook responder with `--test-framework=…`**, not by mutating generator configuration.
7. **Assert on the hook's output file**, because a missing responder reports and continues.
8. **Group with sibling classes or a module**, never by subclassing a test case that declares tests.
9. **Use one `cp_r` form** for fixtures — with the trailing `/.` — so the paths your assertions use are the
   paths that exist.
10. **Run the suite with `bin/rails test`**; `Rails::TestTask` was removed.

## Cross-references

- [testing-rspec.md](testing-rspec.md) — the same scenarios on an RSpec project, plus the `spec/generator`
  directory convention.
- [hooks.md](hooks.md) — which responders exist, and how `--test-framework` selects one.
- [file-actions.md](file-actions.md) — the actions these tests are asserting the effects of, including `revoke`.
