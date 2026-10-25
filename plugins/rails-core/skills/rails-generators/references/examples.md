# Generator Examples

Four generators for layers Rails does not generate: service objects, query objects, form objects and
presenters. Checked against Rails 8.1.3.1 / Ruby 3.4.5.

## Table of Contents

- [Service with Dependency Injection](#service-with-dependency-injection)
- [Query Object Generator](#query-object-generator)
- [Form Object Generator](#form-object-generator)
- [Presenter Generator](#presenter-generator)
- [What these four have in common](#what-these-four-have-in-common)

## Service with Dependency Injection

```ruby
# lib/generators/advanced_service/advanced_service_generator.rb
class AdvancedServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :dependencies, type: :array, default: [],
    desc: "Dependencies to inject (space-separated)"
  class_option :async, type: :boolean, default: false, desc: "Also generate a job wrapper"

  def create_service
    template 'service.rb.tt', "app/services/#{file_name}_service.rb"
  end

  def create_job
    return unless options[:async]
    template 'job.rb.tt', "app/jobs/#{file_name}_job.rb"
  end

  def create_spec
    if rspec?
      template 'service_spec.rb.tt', "spec/services/#{file_name}_service_spec.rb"
    else
      template 'service_test.rb.tt', "test/services/#{file_name}_service_test.rb"
    end
  end

  private

  def rspec?
    Rails::Generators.options[:rails][:test_framework] == :rspec
  end

  def dependency_params
    options[:dependencies].map { |dep| "#{dep}:" }.join(', ')
  end

  def dependency_keywords
    options[:dependencies].map { |dep| "#{dep}: #{dep}" }.join(', ')
  end
end
```

Template (`service.rb.tt`):

```erb
class <%= class_name %>Service
  <%- if options[:dependencies].any? -%>
  def initialize(<%= dependency_params %>)
    <%- options[:dependencies].each do |dep| -%>
    @<%= dep %> = <%= dep %>
    <%- end -%>
  end

  <%- end -%>
  def call
  end
  <%- if options[:async] -%>

  def self.call_later(<%= dependency_params %>)
    <%= class_name %>Job.perform_later(<%= dependency_keywords %>)
  end
  <%- end -%>
end
```

Template (`job.rb.tt`) — `--async` generates the class it enqueues:

```erb
class <%= class_name %>Job < ApplicationJob
  queue_as :default

  def perform(<%= dependency_params %>)
    <%= class_name %>Service.new(<%= dependency_keywords %>).call
  end
end
```

Usage:

```bash
rails generate advanced_service payment_processor --dependencies user account --async
```

Three things this gets right that the obvious version does not:

- **No `include ActiveJob::Helpers`.** That constant does not exist — measured,
  `NameError: uninitialized constant ActiveJob::Helpers`; the only `Help`-named constant in Active Job 8.1.3.1
  is `ActiveJob::TestHelper`. Enqueueing needs a job class, not a mixin.
- **`--dependencies user account`, space-separated.** `--dependencies=user,account` arrives as
  `["user,account"]`, so the constructor is generated as `def initialize(user,account:)`. Measured.
- **The spec path follows the project's framework**, read from `Rails::Generators.options` at run time, rather
  than hardcoding `test/` on a project whose suite is `spec/`.

## Query Object Generator

```ruby
# lib/generators/query/query_generator.rb
class QueryGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :model, type: :string, required: true
  class_option :filters, type: :array, default: [],
    desc: "Filter steps to stub out (space-separated)"

  def create_query
    template 'query.rb.tt', "app/queries/#{file_name}_query.rb"
  end

  def create_spec
    if Rails::Generators.options[:rails][:test_framework] == :rspec
      template 'query_spec.rb.tt', "spec/queries/#{file_name}_query_spec.rb"
    else
      template 'query_test.rb.tt', "test/queries/#{file_name}_query_test.rb"
    end
  end
end
```

Template (`query.rb.tt`):

```erb
class <%= class_name %>Query
  def initialize(relation = <%= options[:model].camelize %>.all)
    @relation = relation
  end

  def call
    relation
    <%- options[:filters].each do |filter| -%>
      .then { |rel| apply_<%= filter %>(rel) }
    <%- end -%>
  end

  private

  attr_reader :relation

  <%- options[:filters].each do |filter| -%>
  def apply_<%= filter %>(rel)
    rel # TODO: implement the <%= filter %> filter
  end

  <%- end -%>
end
```

Usage:

```bash
rails generate query active_users --model=User --filters active verified recent
```

`call` reads `relation` through the reader rather than reaching for `@relation` directly, so the `attr_reader`
under `private` is used rather than dead. And `--filters`, not `--scopes`: these generate private methods on the
query object, not Active Record scopes on the model, and naming them "scopes" invites the reader to expect the
latter.

## Form Object Generator

```ruby
# lib/generators/form_object/form_object_generator.rb
class FormObjectGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  # Generator attribute types are not Active Model attribute types.
  ACTIVE_MODEL_TYPES = {
    text: :string, citext: :string, digest: :string, token: :string,
    json: :string, jsonb: :string, uuid: :string,
    references: :integer, belongs_to: :integer, primary_key: :integer,
    bigint: :big_integer, timestamp: :datetime
  }.freeze

  argument :attributes, type: :array, default: [], banner: "field:type"
  class_option :model, type: :string, desc: "Backing model"
  class_option :required, type: :array, default: [],
    desc: "Attributes to validate for presence (space-separated)"

  def create_form_object
    template 'form_object.rb.tt', "app/forms/#{file_name}_form.rb"
  end

  def create_spec
    if Rails::Generators.options[:rails][:test_framework] == :rspec
      template 'form_object_spec.rb.tt', "spec/forms/#{file_name}_form_spec.rb"
    else
      template 'form_object_test.rb.tt', "test/forms/#{file_name}_form_test.rb"
    end
  end

  private

  def active_model_type(attr)
    ACTIVE_MODEL_TYPES.fetch(attr.type, attr.type)
  end

  def required_attributes
    attributes.select { |attr| options[:required].include?(attr.name) }
  end
end
```

Template (`form_object.rb.tt`):

```erb
class <%= class_name %>Form
  include ActiveModel::Model
  include ActiveModel::Attributes

  <%- attributes.each do |attr| -%>
  attribute :<%= attr.name %>, :<%= active_model_type(attr) %>
  <%- end -%>
  <%- required_attributes.each do |attr| -%>
  validates :<%= attr.name %>, presence: true
  <%- end -%>

  def save
    return false unless valid?

    <%- if options[:model] -%>
    <%= options[:model].camelize %>.create!(<%= attributes.map { |a| "#{a.name}: #{a.name}" }.join(', ') %>)
    <%- else -%>
    true
    <%- end -%>
  end
end
```

Usage:

```bash
rails generate form_object registration email:string bio:text --model=User --required email
```

**`active_model_type` is the load-bearing part.** `ActiveModel::Attributes` registers only
`big_integer`, `binary`, `boolean`, `date`, `datetime`, `decimal`, `float`, `immutable_string`, `integer`,
`string` and `time` — while `text`, `references`, `digest`, `json`, `jsonb` and `uuid` are all valid *generator*
attribute types. Passing one straight through raises at class-definition time: measured,
`attribute :bio, :text` → `ArgumentError: Unknown type :text`, as do `:digest`, `:references` and `:json`. So
`rails g form_object post body:text` used to produce a class that could not be loaded at all. Each mapped type
above was verified accepted.

The other change is `--required`: validating presence on *every* attribute means a boolean form field can never
be `false`, since `presence: true` rejects it.

## Presenter Generator

```ruby
# lib/generators/presenter/presenter_generator.rb
class PresenterGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :model, type: :string, required: true, desc: "Model to present"
  class_option :delegate, type: :array, default: [],
    desc: "Methods to delegate to the model (space-separated)"

  def create_presenter
    template 'presenter.rb.tt', "app/presenters/#{file_name}_presenter.rb"
  end

  def create_spec
    if Rails::Generators.options[:rails][:test_framework] == :rspec
      template 'presenter_spec.rb.tt', "spec/presenters/#{file_name}_presenter_spec.rb"
    else
      template 'presenter_test.rb.tt', "test/presenters/#{file_name}_presenter_test.rb"
    end
  end
end
```

Template (`presenter.rb.tt`):

```erb
<%- subject = options[:model].underscore -%>
class <%= class_name %>Presenter
  attr_reader :<%= subject %>

  <%- if options[:delegate].any? -%>
  delegate <%= options[:delegate].map { |m| ":#{m}" }.join(', ') %>, to: :<%= subject %>

  <%- end -%>
  def initialize(<%= subject %>)
    @<%= subject %> = <%= subject %>
  end
end
```

Usage:

```bash
rails generate presenter user --model=User --delegate name email created_at
```

`--model` is `required: true` here rather than optional: a presenter with no subject is an empty class, and the
`else` branch that generated one was a branch nobody wanted. Note that Thor's `required: true` means the switch
must be supplied on the command line — the generator fails with a usage message if it is missing, which is the
intent.

## What these four have in common

Every one of them writes its spec into the directory the project's suite actually runs, chosen by reading
`Rails::Generators.options[:rails][:test_framework]` at run time. None uses
`hook_for :test_framework, as: :<layer>`, because railties and rspec-rails ship responders only for the layers
Rails itself generates — `model`, `controller`, `scaffold`, `mailer`, `job`, `channel`, `integration`,
`system` — and a hook pointed at anything else prints `error  rspec  [not found]` and writes nothing while
exiting 0. If you would rather keep the hook, ship the responder: see
[hooks.md](hooks.md#creating-hook-responders).

And every array option is space-separated. `--delegate name email` gives `["name", "email"]`;
`--delegate=name,email` gives `["name,email"]`, which generates `delegate :name,email`. Measured.
