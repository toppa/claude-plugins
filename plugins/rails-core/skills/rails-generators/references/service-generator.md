# Service Object Generator Example

**Rails ships no service generator.** Everything here is a generator you write yourself, and the
invocation examples only work once the generator class and its templates exist in your app. That is the
point of the file — a service object is exactly the kind of team convention a custom generator is for — but
it means you cannot paste `rails generate service payment_processor` into a fresh app and expect anything to
happen.

Every generator and template below was run against Rails 8.1.3.1 / Ruby 3.4.5 in a throwaway app, and each
"Creates:" block is that run's output.

## Table of Contents

- [Generator Implementation](#generator-implementation)
- [Service Templates](#service-templates)
- [Job Template](#job-template)
- [Result Object Template](#result-object-template)
- [Error Class Template](#error-class-template)
- [Usage Examples](#usage-examples)
- [Testing the Generated Service](#testing-the-generated-service)
- [Generator Testing](#generator-testing)
- [Advanced Patterns](#advanced-patterns)
- [Checklist Specific to a Service Generator](#checklist-specific-to-a-service-generator)

## Generator Implementation

```ruby
# lib/generators/service/service_generator.rb
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :namespace, type: :string, desc: "Namespace for the service"
  class_option :dependencies, type: :array, default: [],
    desc: "Dependencies to inject (space-separated: --dependencies user order)"
  class_option :async, type: :boolean, default: false, desc: "Also generate a job wrapper"
  class_option :result_object, type: :boolean, default: true, desc: "Generate result object"
  class_option :skip_tests, type: :boolean, default: false, desc: "Skip spec/test files"
  class_option :pattern, type: :string, default: 'simple',
    desc: "Service pattern (simple, command, interactor)"

  def create_service_file
    template service_template, service_path
  end

  def create_result_object
    return unless options[:result_object]
    template 'result.rb.tt', result_path
  end

  def create_error_class
    return unless options[:pattern] == 'interactor'
    template 'error.rb.tt', error_path
  end

  def create_job
    return unless options[:async]
    template 'job.rb.tt', job_path
  end

  def create_spec_file
    return if options[:skip_tests]

    if rspec?
      template 'service_spec.rb.tt', spec_path
    else
      template 'service_test.rb.tt', test_path
    end
  end

  private

  def rspec?
    Rails::Generators.options[:rails][:test_framework] == :rspec
  end

  def service_template
    case options[:pattern]
    when 'command'
      'command_service.rb.tt'
    when 'interactor'
      'interactor_service.rb.tt'
    else
      'service.rb.tt'
    end
  end

  def service_path
    if options[:namespace]
      "app/services/#{namespace_path}/#{file_name}_service.rb"
    else
      "app/services/#{file_name}_service.rb"
    end
  end

  def result_path
    if options[:namespace]
      "app/services/#{namespace_path}/#{file_name}_result.rb"
    else
      "app/services/#{file_name}_result.rb"
    end
  end

  # The error class lives next to the service, not under an `errors/` subdirectory —
  # see "Error Class Template" for why.
  def error_path
    service_path.sub(/_service\.rb\z/, '_error.rb')
  end

  def job_path
    if options[:namespace]
      "app/jobs/#{namespace_path}/#{file_name}_job.rb"
    else
      "app/jobs/#{file_name}_job.rb"
    end
  end

  def spec_path
    "spec/services/#{options[:namespace] ? "#{namespace_path}/" : ''}#{file_name}_service_spec.rb"
  end

  def test_path
    "test/services/#{options[:namespace] ? "#{namespace_path}/" : ''}#{file_name}_service_test.rb"
  end

  def namespace_path
    options[:namespace].underscore
  end

  def namespace_modules
    options[:namespace].split('::').map(&:camelize)
  end

  def dependency_params
    options[:dependencies].map { |dep| "#{dep}:" }.join(', ')
  end

  def dependency_keywords
    options[:dependencies].map { |dep| "#{dep}: #{dep}" }.join(', ')
  end

  def dependency_ivars
    options[:dependencies].map { |dep| "@#{dep}" }.join(', ')
  end
end
```

Five things about that class, each reproduced:

- **No `hook_for :test_framework, as: :service`.** Neither railties 8.1.3.1 nor rspec-rails 8.0.4 ships a
  `service` responder, so the hook prints `error  rspec  [not found]`, writes nothing, raises nothing and
  exits 0 — the generator appears to have created a spec and has not. `create_spec_file` picks the path
  itself instead. (If you would rather keep the hook, ship the responder — see
  [hooks.md](hooks.md#creating-hook-responders).)
- **`--skip-tests` now has something to skip.** As an advertised flag with no method reading it, it did
  nothing at all.
- **`--dependencies user order`, space-separated.** `--dependencies=user,order` arrives as the single
  element `["user,order"]`, so `def initialize(user,order:)` — one malformed keyword. Measured.
- **`dependency_keywords` exists because keywords cannot be passed positionally.** See the interactor
  template below.
- **`namespace_modules` returns an array**, so a nested namespace emits nested `module` lines rather than a
  compact `module Billing::Payments`. See "Namespaced Service".

## Service Templates

### Simple Service Pattern

```erb
<%# lib/generators/service/templates/service.rb.tt -%>
<%- namespace_modules.each_with_index do |mod, i| -%>
<%= '  ' * i %>module <%= mod %>
<%- end -%>
<%- indent = '  ' * namespace_modules.size -%>
<%= indent %>class <%= class_name %>Service
<%- if options[:dependencies].any? -%>
<%= indent %>  def initialize(<%= dependency_params %>)
<%- options[:dependencies].each do |dep| -%>
<%= indent %>    @<%= dep %> = <%= dep %>
<%- end -%>
<%= indent %>  end

<%- end -%>
<%= indent %>  def call
<%- if options[:result_object] -%>
<%= indent %>    <%= class_name %>Result.success(data: nil)
<%- else -%>
<%= indent %>    true
<%- end -%>
<%- if options[:result_object] -%>
<%= indent %>  rescue StandardError => e
<%= indent %>    <%= class_name %>Result.failure(error: e.message)
<%- else -%>
<%= indent %>  rescue StandardError => e
<%= indent %>    Rails.logger.error("#{self.class.name} failed: #{e.message}")
<%= indent %>    false
<%- end -%>
<%= indent %>  end
<%- if options[:async] -%>

<%= indent %>  def self.call_later(<%= dependency_params %>)
<%= indent %>    <%= class_name %>Job.perform_later(<%= dependency_keywords %>)
<%= indent %>  end
<%- end -%>
<%= indent %>end
<%- namespace_modules.size.times do |i| -%>
<%= '  ' * (namespace_modules.size - 1 - i) %>end
<%- end -%>
```

Three corrections are baked into that template:

- **No `include ActiveJob::Helpers`.** There is no such constant: measured,
  `NameError: uninitialized constant ActiveJob::Helpers`, and the only `Help`-named constant in Active Job
  8.1.3.1 is `ActiveJob::TestHelper`. A service does not need an Active Job mixin to be enqueued — the job
  wrapper below is the whole mechanism.
- **`self.call_later`, taking the same keywords, not an instance `call_async` reading bare locals.** The
  original emitted `<%= class_name %>Job.perform_later(user, template)` inside an *instance* method whose
  constructor had stored `@user` and `@template`, so the generated code raised `NameError` on the bare
  locals. Enqueueing is a class-level concern anyway: you have the arguments before you have an instance.
- **`namespace_modules` produces one nested `module` per level.** A compact `module Billing::Payments`
  only resolves because Zeitwerk pre-defines the parent constant; loaded any other way it raises
  `NameError: uninitialized constant Billing` (reproduced).

### Command Pattern

```erb
<%# lib/generators/service/templates/command_service.rb.tt -%>
  class <%= class_name %>Service
    attr_reader :errors

    <% if options[:dependencies].any? -%>
    def initialize(<%= dependency_params %>)
<%- options[:dependencies].each do |dep| -%>
      @<%= dep %> = <%= dep %>
<%- end -%>
      @errors = []
    end
    <% else -%>
    def initialize
      @errors = []
    end
    <% end -%>

    def call
      validate!
      return failure_result if errors.any?

      execute
    rescue StandardError => e
      handle_error(e)
    end

    def success?
      errors.empty?
    end

    private

    def validate!
      # Add validation logic
      <% if options[:dependencies].any? -%>
      <% options[:dependencies].each do |dep| -%>
      errors << "<%= dep.humanize %> is required" if @<%= dep %>.blank?
      <% end -%>
      <% end -%>
    end

    def execute
      # Implementation goes here
      success_result
    end

    def success_result
      <% if options[:result_object] -%>
      <%= class_name %>Result.success(data: nil)
      <% else -%>
      true
      <% end -%>
    end

    def failure_result
      <% if options[:result_object] -%>
      <%= class_name %>Result.failure(errors: errors)
      <% else -%>
      false
      <% end -%>
    end

    def handle_error(error)
      Rails.logger.error("#{self.class.name}: #{error.message}")
      errors << error.message
      failure_result
    end
  end
```

### Interactor Pattern

```erb
<%# lib/generators/service/templates/interactor_service.rb.tt -%>
  class <%= class_name %>Service
    def self.call(<%= dependency_params %>)
      new(<%= dependency_keywords %>).call
    end

    <% if options[:dependencies].any? -%>
    def initialize(<%= dependency_params %>)
<%- options[:dependencies].each do |dep| -%>
      @<%= dep %> = <%= dep %>
<%- end -%>
    end
    <% end -%>

    def call
      validate_inputs!
      perform
      success_result
    rescue <%= class_name %>Error => e
      failure_result(e.message)
    rescue StandardError => e
      Rails.logger.error("Unexpected error in #{self.class.name}: #{e.message}")
      failure_result("An unexpected error occurred")
    end

    private

    def validate_inputs!
      <% if options[:dependencies].any? -%>
      <% options[:dependencies].each do |dep| -%>
      raise <%= class_name %>Error, "<%= dep.humanize %> is required" if @<%= dep %>.blank?
      <% end -%>
      <% end -%>
    end

    def perform
      # Implementation goes here
    end

    def success_result
      <%= class_name %>Result.success(data: result_data)
    end

    def failure_result(message)
      <%= class_name %>Result.failure(error: message)
    end

    def result_data
      {}
    end
  end
```

**`new(<%= dependency_keywords %>)`, not `new(<%= options[:dependencies].join(', ') %>)`.** The class method
takes keywords, so forwarding the names as bare positional arguments raises
`ArgumentError: wrong number of arguments (given 2, expected 0; required keywords: user, order)` —
reproduced. That broke the `--pattern=interactor` path for any non-empty `--dependencies`, which is the only
case where the pattern is interesting.

Wrap in `namespace_modules` the same way the simple template does if you want the namespace option here too;
it is omitted above to keep the pattern's own shape readable.

## Job Template

The `--async` flag's whole implementation. It is what makes `self.call_later` above resolve:

```erb
<%# lib/generators/service/templates/job.rb.tt -%>
class <%= class_name %>Job < ApplicationJob
  queue_as :default

  def perform(<%= dependency_params %>)
    <%= class_name %>Service.new(<%= dependency_keywords %>).call
  end
end
```

Keeping enqueueing and performing in the job, and the work in the service, means the service stays callable
synchronously in a console or a test.

## Result Object Template

```erb
<%# lib/generators/service/templates/result.rb.tt -%>
  class <%= class_name %>Result
    attr_reader :data, :error, :errors

    def initialize(success:, data: nil, error: nil, errors: [])
      @success = success
      @data = data
      @error = error
      @errors = errors
    end

    def self.success(data: nil)
      new(success: true, data: data)
    end

    def self.failure(error: nil, errors: [])
      new(success: false, error: error, errors: errors)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def error_message
      error || errors.join(', ')
    end
  end
```

## Error Class Template

```erb
<%# lib/generators/service/templates/error.rb.tt -%>
<%- namespace_modules.each_with_index do |mod, i| -%>
<%= '  ' * i %>module <%= mod %>
<%- end -%>
<%- indent = '  ' * namespace_modules.size -%>
<%= indent %>class <%= class_name %>Error < StandardError
<%= indent %>end
<%- namespace_modules.size.times do |i| -%>
<%= '  ' * (namespace_modules.size - 1 - i) %>end
<%- end -%>
```

Written to `app/services/<name>_error.rb` — alongside the service, **not** under
`app/services/errors/`.

**Zeitwerk requires the constant path to match the file path.** A file at
`app/services/errors/payment_processor_error.rb` must define `Errors::PaymentProcessorError`. Declaring a
top-level `PaymentProcessorError` there fails: reproduced with `bin/rails zeitwerk:check`, which reported
`expected file app/services/errors/payment_processor_error.rb to define constant
Errors::PaymentProcessorError, but didn't`. That breaks `zeitwerk:check`, eager loading and production boot,
and the interactor's `rescue <%= class_name %>Error` then cannot resolve either.

Two ways to satisfy the contract, both verified with `zeitwerk:check` reporting `All is good!`:

- **Flat**, as above: `app/services/payment_processor_error.rb` defining `PaymentProcessorError`.
- **Namespaced to the directory**: `app/services/errors/payment_processor_error.rb` wrapped in
  `module Errors`.

**One error class, not three.** `ValidationError` and `ProcessingError` were generated for every service and
referenced by none of the templates — unused constants a maintainer then has to decide whether to delete.
Generate the class the interactor actually rescues; a service that needs a subclass hierarchy can grow one.

## Usage Examples

Each block below is the file the generator actually wrote.

### Simple Service

```bash
rails generate service charge_card
```

Creates `app/services/charge_card_service.rb`, `app/services/charge_card_result.rb` and
`spec/services/charge_card_service_spec.rb`:

```ruby
class ChargeCardService
  def call
    ChargeCardResult.success(data: nil)
  rescue StandardError => e
    ChargeCardResult.failure(error: e.message)
  end
end
```

No empty `def initialize; end` — a constructor that takes nothing and does nothing is noise in generated
code as much as in hand-written code.

### Service with Dependencies

```bash
rails generate service charge_card --dependencies user payment_method amount
```

```ruby
class ChargeCardService
  def initialize(user:, payment_method:, amount:)
    @user = user
    @payment_method = payment_method
    @amount = amount
  end

  def call
    ChargeCardResult.success(data: nil)
  rescue StandardError => e
    ChargeCardResult.failure(error: e.message)
  end
end
```

**Space-separated.** `--dependencies=user,payment_method,amount` arrives as `["user,payment_method,amount"]`
and generates `def initialize(user,payment_method,amount:)`. Measured.

**Emit the assignments by iterating in the template**, not by pre-joining them in the generator: a
`join("\n      ")` bakes in one indentation level, so the second and later assignments are misaligned as
soon as the template's own indentation differs. Observed on the namespaced path before this was fixed.

### Namespaced Service

```bash
rails generate service charge_card --namespace=Billing::Payments --dependencies order
```

Creates `app/services/billing/payments/charge_card_service.rb`:

```ruby
module Billing
  module Payments
    class ChargeCardService
      def initialize(order:)
        @order = order
      end

      def call
        ChargeCardResult.success(data: nil)
      rescue StandardError => e
        ChargeCardResult.failure(error: e.message)
      end
    end
  end
end
```

**One `module` per level, and every companion file namespaced the same way.** Two things went wrong here
before this was verified with `bin/rails zeitwerk:check`:

- A compact `module Billing::Payments` resolves under Zeitwerk only because Zeitwerk pre-defines the parent
  constant; loaded any other way it raises `NameError: uninitialized constant Billing`.
- The result-object template was **not** namespaced, so eager loading failed with
  `expected file app/services/billing/payments/charge_card_result.rb to define constant
  Billing::Payments::ChargeCardResult, but didn't`. Every template a namespaced run emits — service, result,
  error, job — has to carry the same module nesting. `zeitwerk:check` reports `All is good!` once they all do.

### Command Pattern Service

```bash
rails generate service fulfil_order --pattern=command --dependencies order warehouse
```

```ruby
class FulfilOrderService
  attr_reader :errors

  def initialize(order:, warehouse:)
    @order = order
    @warehouse = warehouse
    @errors = []
  end

  def call
    validate!
    return failure_result if errors.any?

    execute
  rescue StandardError => e
    handle_error(e)
  end

  def success? = errors.empty?

  private

  def validate!
    errors << "Order is required" if @order.blank?
    errors << "Warehouse is required" if @warehouse.blank?
  end

  def execute = success_result
  def success_result = FulfilOrderResult.success(data: nil)
  def failure_result = FulfilOrderResult.failure(errors: errors)

  def handle_error(error)
    Rails.logger.error("#{self.class.name}: #{error.message}")
    errors << error.message
    failure_result
  end
end
```

`rescue StandardError`, `handle_error`, `success_result` and `failure_result` are all shown, because the
template emits them. An earlier version of this file documented an abridged version and a reader could not
tell what the generator produced.

### Interactor Pattern Service

```bash
rails generate service settle_invoice --pattern=interactor --dependencies user order
```

Creates the service, the result object, and `app/services/settle_invoice_error.rb`:

```ruby
class SettleInvoiceService
  def self.call(user:, order:)
    new(user: user, order: order).call
  end

  def initialize(user:, order:)
    @user = user
    @order = order
  end

  def call
    validate_inputs!
    perform
    success_result
  rescue SettleInvoiceError => e
    failure_result(e.message)
  end

  private

  def validate_inputs!
    raise SettleInvoiceError, "User is required" if @user.blank?
    raise SettleInvoiceError, "Order is required" if @order.blank?
  end

  def perform
  end

  def success_result = SettleInvoiceResult.success(data: result_data)
  def failure_result(message) = SettleInvoiceResult.failure(error: message)
  def result_data = {}
end
```

Executed against the real install:

```
SettleInvoiceService.call(user: nil, order: 2)  # => failure? true, error "User is required"
SettleInvoiceService.call(user: 1,   order: 2)  # => success? true, data {}
```

`new(user: user, order: order)` is what makes that work. Forwarding the names positionally —
`new(user, order)` — raises
`ArgumentError: wrong number of arguments (given 2, expected 0; required keywords: user, order)`.

### Async Service

```bash
rails generate service notify_user --dependencies user template --async
```

```ruby
class NotifyUserService
  def initialize(user:, template:)
    @user = user
    @template = template
  end

  def call
    NotifyUserResult.success(data: nil)
  rescue StandardError => e
    NotifyUserResult.failure(error: e.message)
  end

  def self.call_later(user:, template:)
    NotifyUserJob.perform_later(user: user, template: template)
  end
end
```

And `app/jobs/notify_user_job.rb`:

```ruby
class NotifyUserJob < ApplicationJob
  queue_as :default

  def perform(user:, template:)
    NotifyUserService.new(user: user, template: template).call
  end
end
```

`--async` generates the job it enqueues. Before this was verified, the flag emitted
`include ActiveJob::Helpers` — a constant that does not exist — and a `call_async` that referenced a
`<Name>Job` no method ever created.

## Testing the Generated Service

The spec the generator writes is a placeholder; here is what it grows into. Written for RSpec because that is
what `create_spec_file` selects when rspec-rails is installed — swap in `ActiveSupport::TestCase` and
`assert` if the project is on Minitest.

```ruby
# spec/services/charge_card_service_spec.rb
require 'rails_helper'

RSpec.describe ChargeCardService do
  subject(:service) do
    described_class.new(user: user, payment_method: payment_method, amount: amount)
  end

  let(:user) { create(:user) }
  let(:payment_method) { create(:payment_method) }
  let(:amount) { 100.00 }

  describe '#call' do
    it 'returns a successful result' do
      result = service.call

      expect(result).to be_success
    end

    context 'when a dependency is missing' do
      let(:payment_method) { nil }

      it 'returns a failure result carrying the message' do
        result = service.call

        expect(result).to be_failure
        expect(result.error).to be_present
      end
    end
  end
end
```

Two things this deliberately does not do:

- **It does not reference models the generator did not create.** An earlier version leaned on `Payment`,
  `PaymentProvider` and `PaymentProvider::Error`, none of which the generator produces and none of which
  exist in a fresh app — so it read as if the generator had delivered a passing spec. Anything beyond the
  generated class is yours to add; the generated spec should pass on the day it is generated.
- **It does not use fixtures.** `users(:john)` needs `test/fixtures/users.yml`, which this generator does not
  create; on an RSpec project with factory_bot the fixture accessor does not exist at all. Whichever the
  project uses, generate a spec that matches it — that is what `create_spec_file` is reading the configured
  framework for.

## Generator Testing

```ruby
# test/generators/service_generator_test.rb
require 'test_helper'
require 'generators/service/service_generator'

class ServiceGeneratorTest < Rails::Generators::TestCase
  tests ServiceGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  test "generates service and result files" do
    run_generator ["charge_card"]

    assert_file "app/services/charge_card_service.rb" do |content|
      assert_match(/class ChargeCardService/, content)
      assert_match(/def call/, content)
    end

    assert_file "app/services/charge_card_result.rb" do |content|
      assert_match(/class ChargeCardResult/, content)
    end
  end

  test "namespaces every generated file, not just the service" do
    run_generator ["charge_card", "--namespace=Billing::Payments"]

    assert_file "app/services/billing/payments/charge_card_service.rb" do |content|
      assert_match(/^module Billing$/, content)
      assert_match(/^  module Payments$/, content)
    end

    # The regression that eager loading caught: the result object was not namespaced.
    assert_file "app/services/billing/payments/charge_card_result.rb" do |content|
      assert_match(/^module Billing$/, content)
      assert_match(/^  module Payments$/, content)
    end
  end

  test "generates service with dependencies" do
    run_generator ["charge_card", "--dependencies", "user", "amount"]

    assert_file "app/services/charge_card_service.rb" do |content|
      assert_match(/def initialize\(user:, amount:\)/, content)
      assert_match(/^    @user = user$/, content)
      assert_match(/^    @amount = amount$/, content)
    end
  end

  test "an array option given commas arrives as one element" do
    run_generator ["charge_card", "--dependencies=user,amount"]

    # Documents Thor's actual behaviour so nobody "fixes" the space-separated docs.
    assert_file "app/services/charge_card_service.rb" do |content|
      assert_match(/def initialize\(user,amount:\)/, content)
    end
  end

  test "generates command pattern service" do
    run_generator ["fulfil_order", "--pattern=command"]

    assert_file "app/services/fulfil_order_service.rb" do |content|
      assert_match(/attr_reader :errors/, content)
      assert_match(/def validate!/, content)
      assert_match(/def execute/, content)
    end
  end

  test "interactor forwards keywords as keywords" do
    run_generator ["settle_invoice", "--pattern=interactor", "--dependencies", "user", "order"]

    assert_file "app/services/settle_invoice_service.rb" do |content|
      assert_match(/def self\.call\(user:, order:\)/, content)
      assert_match(/new\(user: user, order: order\)/, content)
    end

    assert_file "app/services/settle_invoice_error.rb" do |content|
      assert_match(/class SettleInvoiceError < StandardError/, content)
    end
  end

  test "async generates the job it enqueues" do
    run_generator ["notify_user", "--async", "--dependencies", "user"]

    assert_file "app/services/notify_user_service.rb" do |content|
      assert_match(/def self\.call_later\(user:\)/, content)
      assert_match(/NotifyUserJob\.perform_later\(user: user\)/, content)
    end

    assert_file "app/jobs/notify_user_job.rb" do |content|
      assert_match(/class NotifyUserJob < ApplicationJob/, content)
    end
  end

  test "skips result object when option disabled" do
    run_generator ["charge_card", "--no-result-object"]

    assert_file "app/services/charge_card_service.rb"
    assert_no_file "app/services/charge_card_result.rb"
  end

  test "skips the spec file when asked" do
    run_generator ["charge_card", "--skip-tests"]

    assert_file "app/services/charge_card_service.rb"
    assert_no_file "spec/services/charge_card_service_spec.rb"
    assert_no_file "test/services/charge_card_service_test.rb"
  end
end
```

Three notes on the assertions above:

- **`^    @user = user$` with anchors**, because the indentation is the thing that regressed once already. A
  bare `/@user = user/` passes on misaligned output.
- **The comma test asserts the wrong-looking output on purpose.** It documents that Thor arrays are
  space-separated so nobody "corrects" the docs back.
- **A generated `--skip-tests` run should produce nothing under either `spec/` or `test/`**, which is the
  assertion that would have caught a flag no method read.

## Advanced Patterns

### Service with Callbacks

```ruby
class PaymentProcessorService
  include ActiveSupport::Callbacks

  define_callbacks :call

  set_callback :call, :before, :validate_inputs
  set_callback :call, :after, :log_result
  set_callback :call, :around, :transaction_wrapper

  def call
    run_callbacks :call do
      # Implementation
    end
  end

  private

  def validate_inputs
    # Validation logic
  end

  def log_result
    # Logging logic
  end

  def transaction_wrapper
    ActiveRecord::Base.transaction do
      yield
    end
  end
end
```

### Where the state-machine pattern used to be

An earlier version of this file showed `include AASM` with a four-state machine on a service object. That is
removed for two reasons:

- **`aasm` is a gem** and was presented with no mention of that fact and no `Gemfile` check, so a reader
  pasting it gets `NameError: uninitialized constant AASM`.
- **A stateless service object is the wrong home for state.** The states in that example — pending,
  processing, completed, failed — describe the *order*, and they need to survive the process. Put the state
  machine on the record and let the service transition it.

## Checklist Specific to a Service Generator

Advice about service objects themselves — when to extract one, how big it should get — belongs to the
`rails-core:extraction-timing` and `rails-core:rails-architecture` skills. What follows is about generating
them.

- [ ] Every option the generator advertises is read by some method, and `--skip-tests` in particular.
- [ ] Array and hash options are documented as space-separated, with a test that pins the behaviour.
- [ ] A class method that takes keywords forwards them as keywords.
- [ ] Every file a namespaced run emits — service, result, error, job — carries the same module nesting, one
      `module` per level, and `bin/rails zeitwerk:check` reports `All is good!` after a namespaced run.
- [ ] Error classes sit at a path whose constant Zeitwerk expects: flat beside the service, or wrapped in the
      module named after their directory.
- [ ] Assignment lines are emitted by iterating in the template, so indentation follows the surrounding code.
- [ ] `--async` generates the job it enqueues; nothing references a class no method creates.
- [ ] The generated spec passes as generated, referencing only classes the generator created.
- [ ] The spec or test path matches the framework the project actually runs.
- [ ] No constant from an uninstalled gem appears in generated code.
- [ ] The "Creates:" documentation is the generator's real output, refreshed by running it.
