# Generator Hooks and Composition

Generator hooks let one generator delegate to another without tight coupling, and they are how Rails' own generators reach a test framework. A hook resolves only to a responder that exists, and a missing responder never raises. So a hook for a layer Rails does not generate needs a responder you ship yourself.

## Table of Contents

- [Hook Basics](#hook-basics)
- [Creating Hook Responders](#creating-hook-responders)
- [Fallback Configuration](#fallback-configuration)
- [Hook Invocation Options](#hook-invocation-options)
- [Advanced Hook Patterns](#advanced-hook-patterns)
- [Hook Resolution Path](#hook-resolution-path)
- [Real-World Example: Complete Hook System](#real-world-example-complete-hook-system)
- [Testing Hooks](#testing-hooks)
- [Best Practices](#best-practices)

## Hook Basics

### Defining Hooks

```ruby
class ModelExtrasGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  # Hook for test framework integration
  hook_for :test_framework, as: :model

  def create_concern
    template 'concern.rb.tt', "app/models/concerns/#{file_name}_extras.rb"
  end
end
```

When invoked, this calls `<configured framework>:model` — `rspec:model` on an RSpec project,
`test_unit:model` otherwise. Verified: with rspec-rails 8.0.4 installed it created
`spec/models/payment3_spec.rb`.

**`hook_for` only reaches responders that exist, and says nothing useful when one does not.** Neither
railties 8.1.3.1 nor rspec-rails 8.0.4 ships a `service` responder, so `as: :service` prints
`error  rspec  [not found]`, writes no file, raises nothing and exits 0 — verified by invocation. The
responders that resolve are the ones for layers Rails itself generates: `model`, `controller`, `scaffold`,
`mailer`, `job`, `channel`, `integration`, `system`.

There are two ways to make `as: :service` work, and both are worth knowing:

- **Ship the responder yourself**, in `lib/generators/rspec/service/service_generator.rb` — see
  [Creating Hook Responders](#creating-hook-responders) below. Verified: with that file present, the same
  `hook_for :test_framework, as: :service` printed `invoke rspec` and created
  `spec/services/payout_service_spec.rb`. This is the right choice when the generator ships to a team, or
  in a gem, and you want the hook's framework-switching for free.
- **Skip the hook** and pick the path in a private method, which is simpler for a single app's generator —
  see the `<usage_pattern>` section of this skill's `SKILL.md` for the framework check.

**Installing rspec-rails is enough to switch the hook.** Its railtie calls
`generators.test_framework :rspec` (`rspec-rails.rb:33`), so no application config is needed — verified:
`Rails.application.config.generators.options[:rails][:test_framework]` read `:rspec` on an app whose only
change was adding the gem.

### Hook Parameters

`hook_for` consumes `:in`, `:as` and `:type`, and forwards everything else to `class_option`:

```ruby
hook_for :test_framework,
  as: :model,                      # Responder name to invoke; must exist
  in: :rails,                      # Namespace to search
  default: true                    # Whether to invoke by default
```

**There is no `required:` concept in `hook_for`.** Because unrecognised keys are forwarded to
`class_option`, `required: true` means Thor's *"the `--test-framework` switch must be supplied on the
command line"* — the opposite of "raise if the responder is missing". A missing responder never raises:
`invoke_from_option` calls `say_status :error, "… [not found]"` and continues, and `exit_on_failure?` is
`false`. Reproduced: `error rspec [not found]`, exit 0. If a hook is genuinely mandatory, assert on its
output yourself:

```ruby
def verify_spec_was_generated
  spec = "spec/models/#{file_name}_spec.rb"
  return if File.exist?(File.join(destination_root, spec))

  raise Thor::Error, "expected #{spec} — is a test-framework responder installed?"
end
```

## Creating Hook Responders

### Test Framework Hook

Create a generator that responds to the hook:

```ruby
# lib/generators/rspec/service/service_generator.rb
module Rspec
  module Generators
    class ServiceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_service_spec
        template 'service_spec.rb.tt',
          "spec/services/#{file_name}_service_spec.rb"
      end
    end
  end
end
```

Template (service_spec.rb.tt):
```erb
require 'rails_helper'

RSpec.describe <%= class_name %>Service do
  describe '#call' do
    it 'performs the operation' do
      service = described_class.new
      result = service.call

      expect(result).to be_success
    end
  end
end
```

### Test::Unit Hook (same shape, `TestUnit` namespace)

Follows Rails' own naming for the built-in responders, which is why the hook finds it. It is still your
file — railties ships no `test_unit:service`.

```ruby
# lib/generators/test_unit/service/service_generator.rb
module TestUnit
  module Generators
    class ServiceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_service_test
        template 'service_test.rb.tt',
          "test/services/#{file_name}_service_test.rb"
      end
    end
  end
end
```

## Fallback Configuration

### Application-Level Fallbacks

Configure in `config/application.rb`:

```ruby
module MyApp
  class Application < Rails::Application
    config.generators do |g|
      # Use custom test framework
      g.test_framework :my_test_framework

      # Fallback to test_unit for generators we haven't implemented
      g.fallbacks[:my_test_framework] = :test_unit
    end
  end
end
```

This enables:
- `my_test_framework:model` (custom) ✓
- `my_test_framework:service` (custom) ✓
- `my_test_framework:controller` → falls back to `test_unit:controller` ✓

### Fallbacks take one symbol, not a chain

```ruby
config.generators do |g|
  g.test_framework :my_framework

  g.fallbacks[:my_framework] = :rspec   # one level
  g.fallbacks[:rspec] = :test_unit      # chain it by chaining the entries
end
```

Resolution is `my_framework:model`, then `rspec:model`, then `test_unit:model`.

**A Hash value silently never resolves.** `invoke_fallbacks_for` does
`Array(fallbacks[base.to_sym]).each`, and `Array({rspec: :test_unit})` is `[[:rspec, :test_unit]]` —
verified — so the lookup namespace becomes the literal string `"[:rspec, :test_unit]:model"` and matches
nothing. Chain the fallbacks hash entry by entry instead, as above.

## Hook Invocation Options

### Conditional hooks are conditional at run time, not at class-definition time

`hook_for` is a class method and `options` is an *instance* accessor, so a class-body condition on
`options[...]` does not compile: verified,
`NameError: undefined local variable or method 'options' for class`. Even if it did resolve, a class body
runs before any command line is parsed, so it could never see the user's flags.

Declare the hook unconditionally and let `hook_for`'s own generated switch turn it off, or invoke
explicitly from a generator method:

```ruby
class FeatureGenerator < Rails::Generators::NamedBase
  class_option :with_job, type: :boolean, default: false

  # `hook_for` creates a `--mailer` / `--skip-mailer` switch; users opt out with `--skip-mailer`.
  hook_for :mailer

  def create_job
    invoke 'job', [name] if options[:with_job]
  end

  def create_feature
    # Main feature code
  end
end
```

### Manual Hook Invocation

```ruby
class CustomGenerator < Rails::Generators::NamedBase
  def invoke_test_generator
    case Rails::Generators.options[:rails][:test_framework]
    when :rspec     then invoke 'rspec:service', [name]
    when :test_unit then invoke 'test_unit:service', [name]
    end
  end
end
```

Read the configured framework rather than probing for a `spec/` or `test/` directory: a `File.directory?`
check resolves against the process working directory, not `destination_root`, so it reports the wrong
answer under `Rails::Generators::TestCase`. Both `rspec:service` and `test_unit:service` are responders you
supply (see above).

## Advanced Hook Patterns

### Multiple Hooks

```ruby
class ApiResourceGenerator < Rails::Generators::NamedBase
  hook_for :test_framework, as: :model
  hook_for :test_framework, as: :controller
  hook_for :serializer   # optional by nature: a missing responder reports and continues

  def create_model
    invoke 'model', [name]
  end

  def create_controller
    template 'controller.rb.tt',
      "app/controllers/#{file_name.pluralize}_controller.rb"
  end
end
```

### Custom Hook Behavior

```ruby
class ServiceGenerator < Rails::Generators::NamedBase
  def invoke_test_generator
    invoke "#{test_framework}:service", [name],
           namespace: options[:namespace], async: options[:async]

    configure_test_helpers
  end

  private

  def test_framework
    Rails::Generators.options[:rails][:test_framework] || :test_unit
  end
end
```

`invoke` really does forward an options hash to the invoked generator (thor
`invocation.rb:102-116`), so the responder sees `options[:namespace]` and `options[:async]` — provided it
declares them as `class_option`s of its own.

`Rails::Generators.options` is the hash the generator machinery actually reads at run time, and it returns
`nil` when nothing has configured a framework, which is why the `|| :test_unit` is there. No
`empty_directory` step is needed first: `template` and `create_file` both create missing parent
directories.

## Hook Resolution Path

Rails searches for hook responders in this order:

1. **Explicit namespace**:
   - `rails/generators/rspec/service/service_generator.rb`

2. **Generator namespace**:
   - `generators/rspec/service/service_generator.rb`

3. **Fallback namespace**:
   - `rails/generators/test_unit/service/service_generator.rb`
   - `generators/test_unit/service/service_generator.rb`

4. **`say_status :error, "… [not found]"` and continue.** Nothing raises and the exit status stays 0.
   Reproduced. If the hook's output is required, assert on the file (see Hook Parameters above).

## Real-World Example: Complete Hook System

### Main Generator

```ruby
# lib/generators/business_logic/business_logic_generator.rb
class BusinessLogicGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :pattern, type: :string, default: 'service',
    desc: "Pattern to use (service, command, interactor)"

  hook_for :test_framework, as: :business_logic

  def create_business_logic
    case options[:pattern]
    when 'service'
      template 'service.rb.tt', "app/services/#{file_name}_service.rb"
    when 'command'
      template 'command.rb.tt', "app/commands/#{file_name}_command.rb"
    when 'interactor'
      template 'interactor.rb.tt', "app/interactors/#{file_name}_interactor.rb"
    end
  end
end
```

### RSpec Hook Responder

```ruby
# lib/generators/rspec/business_logic/business_logic_generator.rb
module Rspec
  module Generators
    class BusinessLogicGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :pattern, type: :string, default: 'service'

      def create_spec
        case options[:pattern]
        when 'service'
          template 'service_spec.rb.tt', "spec/services/#{file_name}_service_spec.rb"
        when 'command'
          template 'command_spec.rb.tt', "spec/commands/#{file_name}_command_spec.rb"
        when 'interactor'
          template 'interactor_spec.rb.tt', "spec/interactors/#{file_name}_interactor_spec.rb"
        end
      end
    end
  end
end
```

### Configuration

```ruby
# config/application.rb
config.generators do |g|
  g.test_framework :rspec
  g.fixture_replacement :factory_bot

  # Custom hook for business logic patterns
  g.fallbacks[:rspec] = :test_unit
end
```

Usage:
```bash
rails generate business_logic payment_processor --pattern=service
# Creates:
# - app/services/payment_processor_service.rb
# - spec/services/payment_processor_service_spec.rb

rails generate business_logic order_fulfillment --pattern=command
# Creates:
# - app/commands/order_fulfillment_command.rb
# - spec/commands/order_fulfillment_command_spec.rb
```

## Testing Hooks

**Drive the CLI switch `hook_for` creates.** `class_option` freezes its default at class-definition time,
and the generator is `require`d at the top of the test file, so flipping configuration inside an example
cannot move it. Proved by execution: setting both `Rails.application.config.generators` and
`Rails::Generators.options` to `:rspec` left the baked default where it was, and only a class loaded
*after* the change picked it up. The switch is a real command-line flag, so it works from
`run_generator`:

```ruby
class BusinessLogicGeneratorTest < Rails::Generators::TestCase
  tests BusinessLogicGenerator
  destination File.expand_path('../tmp', __dir__)

  setup :prepare_destination

  test "invokes the rspec responder when asked" do
    run_generator ["payment", "--test-framework=rspec"]

    assert_file "app/services/payment_service.rb"
    assert_file "spec/services/payment_service_spec.rb"
  end

  test "leaves the spec unwritten when another framework is asked for" do
    run_generator ["payment", "--test-framework=test_unit"]

    assert_file "app/services/payment_service.rb"
    assert_no_file "spec/services/payment_service_spec.rb"
  end
end
```

Verified: `run_generator ["payment", "--test-framework=test_unit"]` changed which namespace was searched.
This section ships an `Rspec::Generators::BusinessLogicGenerator` responder and no `test_unit` one, so the
second run prints `error  test_unit  [not found]` and exits 0 — which is what the second test pins.

## Best Practices

1. **Point `as:` at a responder that exists** — `model`, `controller`, `scaffold`, `mailer`, `job`,
   `channel`, `integration`, `system` — or ship the responder yourself under
   `lib/generators/<framework>/<name>/`. For a one-app generator, picking the path in a private method is
   less machinery.
2. **Chain fallbacks one symbol at a time**; a Hash value never resolves.
3. **Pass options through** to hook responders.
4. **Assert on the hook's output** when it is mandatory, since a miss never raises.
5. **Select the responder in tests with `--test-framework=…`**, not by mutating configuration.
6. **Use conventional naming** for responders you write yourself (`framework:type`).
7. **Document which hooks a generator fires** in its `USAGE` file.
