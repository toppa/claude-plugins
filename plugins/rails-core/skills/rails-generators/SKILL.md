---
name: rails-generators
description: >-
  Build custom Rails generators with the Thor DSL — models, services,
  controllers, and full-stack features — plus application templates for
  whole-app setup.
when_to_use: >-
  Use when the user asks to write or test a generator, a scaffold, or a Rails
  application template, or names the Thor DSL. Also use for `rails new -m`,
  `app:template`, starter-app automation, and multi-tenant setup.
disable-model-invocation: true
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/rails-generators/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: Rails 8.1.3.1, Ruby 3.4.5, PostgreSQL 17.10, Thor 1.5.0, rspec-rails 8.0.4, Zeitwerk 2.8.3, acts_as_tenant 1.0.1
---

<objective>
Build production-ready Rails generators that automate repetitive coding tasks and enforce architectural patterns. This skill covers creating custom generators for models, service objects, API scaffolds, and complete features with migrations, tests, and documentation — plus application templates (`rails new -m` / `app:template`) for whole-app setup such as authentication and multi-tenancy.
</objective>

<quick_start>
<basic_generator>
Create a simple service object generator:

```ruby
# lib/generators/service/service_generator.rb
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_service_file
    template 'service.rb.tt', "app/services/#{file_name}_service.rb"
  end
end
```

Template file (templates/service.rb.tt):
```ruby
class <%= class_name %>Service
  def call
  end
end
```

Invoke with: `rails generate service payment_processor`

**Declare the class at the top level.** Thor derives the invocation namespace from the class's
constant path, so a `module Generators` wrapper produces `generators:service` and
`rails generate service payment_processor` reports `Could not find generator 'service'.`
`base.rb:54-56` strips a `:generators:` segment only when it is colon-prefixed, which a top-level
class already satisfies. Verified by invocation against Rails 8.1.3.1: wrapped in `module Generators`
the command fails; top-level it creates `app/services/payment_processor_service.rb`.

A `Generators` module *is* right once there is a namespace above it — `Admin::Generators::ResourceGenerator`
gives `admin:resource`, because the `:generators:` segment is then colon-prefixed and gets stripped. See
`<namespacing>` below; both forms were invoked.
</basic_generator>

<usage_pattern>
**Generator location**: `lib/generators/[name]/[name]_generator.rb`
**Template location**: `lib/generators/[name]/templates/`
**Spec location**: `spec/generator/[name]_generator_spec.rb` on an RSpec project (rspec-rails 8.0.4 maps
`generator` to the **singular** `spec/generator`), or `test/generators/[name]_generator_test.rb` on
Minitest.

**Generate the spec or test file into the directory the project's suite actually runs.** Read the
configured framework at runtime rather than hardcoding a path:

```ruby
def create_spec_file
  if Rails::Generators.options[:rails][:test_framework] == :rspec
    template 'service_spec.rb.tt', "spec/services/#{file_name}_service_spec.rb"
  else
    template 'service_test.rb.tt', "test/services/#{file_name}_service_test.rb"
  end
end
```

Installing rspec-rails is enough to make that read `:rspec` — `rspec-rails.rb:33` calls
`generators.test_framework :rspec` from its railtie, with no application config needed. Verified by
invocation.
</usage_pattern>
</quick_start>

<context>
<when_to_create>
Create custom generators when you need to:

- **Enforce architectural patterns**: Service objects, form objects, presenters, query objects
- **Reduce boilerplate**: API controllers with standard CRUD, serializers, policy objects
- **Maintain consistency**: Team conventions for file structure, naming, and organization
- **Automate complex setup**: Multi-file features with migrations, tests, and documentation
- **Override Rails defaults**: Customize scaffold behavior for your application's needs
</when_to_create>

<rails_8_updates>
Rails 8 introduced the authentication generator (`rails generate authentication`), which is the best worked
example of modern generator patterns in the framework itself: controller concerns, a mailer, view
scaffolding, and an Action Cable connection gated on `defined?(ActionCable::Engine)`
(`authentication_generator.rb:26`).

Its output shape matters when a template or generator builds on it: the user column is
**`email_address`**, the user has **`has_many :sessions`**, the route is the **singular**
`resource :session`, and the current session lives on `Current`. `Devise` is not part of this stack, so
`authenticate_user!`, `sign_in`, `devise_for` and `Devise::Test::IntegrationHelpers` are all undefined on
a stock Rails 8.1 app — verified: `ApplicationController#respond_to?(:authenticate_user!, true)` is
`false`.
</rails_8_updates>
</context>

<workflow>
<step_1>
**Choose base class**:

- `Rails::Generators::Base`: Simple generators without required arguments
- `Rails::Generators::NamedBase`: Generators requiring a name argument (provides `name`, `class_name`, `file_name`, `plural_name`)

```ruby
class ServiceGenerator < Rails::Generators::NamedBase
  # Automatically provides: name, class_name, file_name, plural_name
end
```
</step_1>

<step_2>
**Define source root and options**:

```ruby
source_root File.expand_path('templates', __dir__)

class_option :namespace, type: :string, default: nil, desc: "Namespace for the service"
class_option :skip_tests, type: :boolean, default: false, desc: "Skip test files"
```

Access options with: `options[:namespace]`
</step_2>

<step_3>
**Add public methods** (executed in definition order):

```ruby
def create_service_file
  template 'service.rb.tt', service_file_path
end

def create_test_file
  return if options[:skip_tests]
  template 'service_test.rb.tt', test_file_path
end

private

def service_file_path
  if options[:namespace]
    "app/services/#{options[:namespace]}/#{file_name}_service.rb"
  else
    "app/services/#{file_name}_service.rb"
  end
end
```
</step_3>

<step_4>
**Create ERB templates** (`.tt` extension):

```erb
<% if options[:namespace] -%>
module <%= options[:namespace].camelize %>
  class <%= class_name %>Service
    def call
      # Implementation
    end
  end
end
<% else -%>
class <%= class_name %>Service
  def call
    # Implementation
  end
end
<% end -%>
```

**Important**: Use `<%%` to output literal `<%` in generated files. See [references/templates.md](references/templates.md) for template patterns.
</step_4>

<step_5>
**Invoke it, then cover it with a generator spec.** The `<testing>` section below has the
`Rails::Generators::TestCase` shape; [references/testing-rails.md](references/testing-rails.md) and
[references/testing-rspec.md](references/testing-rspec.md) have the full patterns.

```bash
rails generate service payment_processor --namespace=billing
rails generate service notifier --skip-tests
```

**Thor array and hash options are space-separated, not comma-separated.** `--dependencies=user,account`
parses to the single element `["user,account"]`; `--dependencies user account` parses to
`["user", "account"]`. A hash option takes space-separated `key:value` pairs —
`--config timeout:30 retries:3` → `{"timeout" => "30", "retries" => "3"}`. Both verified by invocation.
</step_5>
</workflow>

<common_patterns>
<model_generator>
**Custom model with associations and scopes**:

```ruby
require 'rails/generators/active_record'

class CustomModelGenerator < Rails::Generators::NamedBase
  include ActiveRecord::Generators::Migration

  source_root File.expand_path('templates', __dir__)

  class_option :parent, type: :string, desc: "Parent model for belongs_to"

  def create_model_migration
    migration_template 'migration.rb.tt', "db/migrate/create_#{table_name}.rb"
  end

  def create_model_file
    template 'model.rb.tt', "app/models/#{file_name}.rb"
  end
end
```

Two things make `migration_template` work, and both are easy to miss:

- **`include ActiveRecord::Generators::Migration`.** `Rails::Generators::Base` mixes in only
  `Thor::Actions` and `Rails::Generators::Actions`, so `migration_template` is otherwise a
  `NoMethodError`; and `Rails::Generators::Migration#next_migration_number` raises
  `NotImplementedError` on its own, which is what the Active Record concern supplies. The
  `require 'rails/generators/active_record'` line ahead of the class is what makes the constant
  resolvable.
- **Name the method something other than `create_migration`.** `migration_template`
  (`railties/lib/rails/generators/migration.rb:63`) calls the `create_migration` Thor action
  internally, so a public generator method by that name shadows it and the run dies with
  `ArgumentError: wrong number of arguments (given 3, expected 0)`. Both verified by invocation.

See [references/model-generator.md](references/model-generator.md) for complete example with templates.
</model_generator>

<service_object_generator>
**Service object with result object pattern**:

```ruby
class ServiceGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :result_object, type: :boolean, default: true
  class_option :pattern, type: :string, default: 'simple',
    desc: "Service pattern (simple, command, interactor)"

  def create_service
    template 'service.rb.tt', "app/services/#{file_name}_service.rb"
  end

  def create_result_object
    return unless options[:result_object]
    template 'result.rb.tt', "app/services/#{file_name}_result.rb"
  end
end
```

See [references/service-generator.md](references/service-generator.md) for complete example with all three patterns.
</service_object_generator>

<api_controller_generator>
**API controller with serializer**:

```ruby
class ApiControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :serializer, type: :string, default: 'none'
  class_option :actions, type: :array, default: %w[index show create update destroy]

  def create_controller
    template 'controller.rb.tt',
      "app/controllers/api/v1/#{file_name.pluralize}_controller.rb"
  end

  def create_serializer
    return if options[:serializer] == 'none'

    template "serializer_#{options[:serializer]}.rb.tt", serializer_path
  end

  def add_routes
    route "resources :#{file_name.pluralize}", namespace: [:api, :v1]
  end
end
```

**Pass `namespace:` to `route` instead of writing the `namespace do` block into the string.** With the
keyword, Rails merges successive additions into one correctly indented block; with a hand-rolled string,
each invocation appends a fresh `namespace :api do` and the indentation drifts. Verified by running both
forms twice against a fresh `config/routes.rb`: the hand-rolled form produced two separate `namespace
:api` blocks, `route "resources :x", namespace: [:api, :v1]` produced one merged block.

**`none` is the default serializer, because the controller template renders JSON directly.** A
default of `jbuilder` writes a view that a `render json:` action never renders.
`ActiveModel::Serializer` and `JSONAPI::Serializer` come from `active_model_serializers` and
`jsonapi-serializer`, so a generator that emits them by default writes a class the app cannot load.
Read the `Gemfile` first and pick a serializer the project already has.

See [references/api-generator.md](references/api-generator.md) for complete example with templates.
</api_controller_generator>

<full_stack_scaffold>
**Complete feature scaffold** using generator composition:

```ruby
class FeatureGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  class_option :api, type: :boolean, default: false

  def create_model
    invoke 'model', [name], migration: true
  end

  def create_controller
    if options[:api]
      invoke 'api_controller', [name]
    else
      invoke 'controller', [name], actions: %w[index show new create edit update destroy]
    end
  end

  def create_views
    return if options[:api]
    %w[index show new edit _form].each do |view|
      template "views/#{view}.html.erb.tt",
        "app/views/#{file_name.pluralize}/#{view}.html.erb"
    end
  end
end
```

See [references/scaffold-generator.md](references/scaffold-generator.md) for complete example.
</full_stack_scaffold>
</common_patterns>

<advanced_features>
<hooks>
**Generator hooks** enable modular composition and test framework integration:

```ruby
class ServiceGenerator < Rails::Generators::NamedBase
  hook_for :test_framework, as: :model
end
```

This invokes `<configured framework>:model` — `rspec:model` on an RSpec project, `test_unit:model`
otherwise. **`as:` has to name a responder that exists.** Neither railties 8.1.3.1 nor rspec-rails 8.0.4
ships a `service` responder, so `as: :service` prints `error  <framework>  [not found]`, writes no file,
raises nothing, and exits 0 — verified by invocation. `as: :model` and `as: :controller` both resolve.

So `hook_for` is the right tool when you are extending a layer Rails already generates specs for, and
a plain private method (see the `<usage_pattern>` framework check above) is the right tool for a layer
it does not. See [references/hooks.md](references/hooks.md) for hook patterns, responders, and fallback
configuration.
</hooks>

<generator_composition>
**Invoke other generators**:

```ruby
class FeatureGenerator < Rails::Generators::NamedBase
  class_option :mailer, type: :boolean, default: false, desc: "Also generate a mailer"

  def create_dependencies
    invoke 'model', [name], migration: true
    invoke 'service', ["#{name}_processor"]
    invoke 'mailer', [name] if options[:mailer]
  end
end
```

**Declare every option a branch reads.** Thor returns `nil` for an undeclared key, so
`if options[:mailer]` without the matching `class_option` is a branch that can never be taken — and it
looks like working code.
</generator_composition>

<namespacing>
**Namespace generators** for organization:

```ruby
# lib/generators/admin/resource/resource_generator.rb
module Admin
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_admin_resource
        template 'resource.rb.tt', "app/admin/#{file_name}.rb"
      end
    end
  end
end
```

Invoke with: `rails generate admin:resource User`

See [references/namespacing.md](references/namespacing.md) for search paths, engine generators, and gem packaging.
</namespacing>

<file_manipulation>
**File-manipulation actions** available in generators:

```ruby
# Create files
create_file 'config/settings.yml', yaml_content
template 'config.rb.tt', 'config/settings.rb'

# Modify existing files
insert_into_file 'config/routes.rb', route_content, after: "Rails.application.routes.draw do\n"
gsub_file 'config/application.rb', /old_value/, 'new_value'

# Rails-specific helpers
initializer 'service_config.rb', config_content
route 'resources :users', namespace: :api
```

`create_file`, `template`, `insert_into_file` and `gsub_file` are Thor's; `route`, `initializer`, `lib`,
`rakefile`, `vendor` and `git` are `Rails::Generators::Actions`. See
[references/file-actions.md](references/file-actions.md) for the full list of both.
</file_manipulation>
</advanced_features>

<application_templates>
**Application templates** configure a whole app (gems, auth, config, feature sets) rather than generating one component. They use the same Thor action DSL but are invoked with `rails new myapp -m template.rb` or `bin/rails app:template LOCATION=template.rb`:

```ruby
# multitenant_template.rb
def source_paths
  super + [__dir__]
end

# Guard against double application, using signals readable without booting the app
if File.exist?('app/models/organization.rb')
  raise Thor::Error, 'Template already applied. Reapply from a clean git state.'
end

gem 'acts_as_tenant', comment: 'Row-level multi-tenancy'
run 'bundle install'

# Rails 8.1 ships authentication; reach for the framework generator first
generate 'authentication'
generate 'model', 'Organization', 'name:string:uniq', 'slug:string:uniq'

after_bundle do
  rails_command 'db:migrate'
end
```

**A template is the one place where writing a `Gemfile` line is the job.** `gem 'acts_as_tenant'` above
is legitimate because adding gems is what an application template does, and the reader is standing up
their own app. That is a different act from telling someone to add a gem to a shared project — inside a
generator, or in advice about an existing codebase, read the `Gemfile` and work with what is there.

**Key rules:**

- **Guard against re-runs** with file, route and schema signals; injections corrupt on a second apply.
- **Raise `Thor::Error`, never `exit`.** `apply_rails_template` rescues `Thor::Error`, so `rails new -m`
  prints one clean line and stops. `SystemExit` is not rescued, so `exit 1` tears the process down
  mid-build and leaves a partial app. Both verified by running `rails new -m` in a throwaway directory.
- **Touch no application constant.** The `rails new` process has not loaded Active Record, so a guard
  that calls `ActiveRecord::Base.connection` raises `NameError` — at the body line *and* again at the
  `rescue ActiveRecord::StatementInvalid` line, since the rescue class is equally unresolvable. Verified:
  `rails new` exits 1 with no `Gemfile.lock` and no template output.
- **Prefer gem install generators** over hand-rolled setup, and **prefer `inject_into_file` on stable
  anchors** over brittle `gsub_file` regexes.
- **Match the app's test framework before running its suite.** A `rails new` app is on Minitest, so
  `run 'bundle exec rspec'` fails unless the template also added `rspec-rails` and ran `rspec:install`.
  Verify with `rails_command 'test'`, or install RSpec explicitly first.

- See [references/application-templates.md](references/application-templates.md) for the full DSL, `after_bundle`, composing templates with `apply`, and verification workflow
- See [references/multitenant-template.md](references/multitenant-template.md) for a complete worked example: multi-tenant SaaS setup with acts_as_tenant, Organizations, role-based Memberships, and invitations
</application_templates>

<testing>
**Testing with Rails::Generators::TestCase**:

```ruby
require 'test_helper'
require 'generators/service/service_generator'

class ServiceGeneratorTest < Rails::Generators::TestCase
  tests ServiceGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  test "generates service file" do
    run_generator ["payment_processor"]

    assert_file "app/services/payment_processor_service.rb" do |content|
      assert_match(/class PaymentProcessorService/, content)
      assert_match(/def call/, content)
    end
  end

  test "skips tests when flag provided" do
    run_generator ["payment", "--skip-tests"]
    assert_file "app/services/payment_service.rb"
    assert_no_file "test/services/payment_service_test.rb"
  end
end
```

**All twelve assertions** `Rails::Generators::Testing::Assertions` defines in railties 8.1.3.1, enumerated
from the module: `assert_file`, `assert_no_file`, `assert_directory`, `assert_no_directory`,
`assert_migration`, `assert_no_migration`, `assert_initializer`, `assert_method`, `assert_class_method`,
`assert_instance_method`, `assert_field_type`, `assert_field_default_value`. Reach for these before
writing your own — a hand-rolled `assert_directory` silently changes the semantics of the built-in.

- See [references/testing-rails.md](references/testing-rails.md) for comprehensive Rails testing patterns
- See [references/testing-rspec.md](references/testing-rspec.md) for RSpec and generator_spec usage
</testing>

<validation>
<checklist>
Before considering a generator complete, verify:

- [ ] Generator inherits from appropriate base class
- [ ] `source_root` points to templates directory
- [ ] All options have appropriate types and defaults
- [ ] Public methods execute in correct order
- [ ] Templates use correct ERB syntax (`.tt` extension)
- [ ] File paths handle namespacing correctly
- [ ] Tests cover default behavior and all options
- [ ] Generator can be destroyed (if applicable)
</checklist>

<common_issues>
The four that a reader will not infer, each reproduced against Rails 8.1.3.1 / Thor 1.5.0:

**`Could not find generator 'service'`**: the class is nested in a module, so the namespace is
`generators:service`. Declare it at the top level.

**`ArgumentError: wrong number of arguments (given 3, expected 0)` from `migration_template`**: a public
generator method named `create_migration` shadows the Thor action `migration_template` calls. Rename it.
A bare `NoMethodError: migration_template` instead means the `ActiveRecord::Generators::Migration`
include is missing.

**A generated file arrives empty, exit status 0**: the `.tt` contains `return`. ERB evaluates the
template in the caller's binding, so `return` abandons the render and Thor writes the buffer as it
stands — no exception, no warning. Use `if`/`end` in templates.

**An option "does nothing"**: either it was never declared as a `class_option` (Thor returns `nil`), or
it was passed comma-separated to an array or hash option. Both are silent.

Plus the routine ones: add `source_root File.expand_path('templates', __dir__)`; use `<%%` for literal
ERB in generated files (`<%%= @user.name %>` generates `<%= @user.name %>`); public methods execute in
definition order, so place dependent steps after their prerequisites.
</common_issues>
</validation>

<reference_guides>
**Detailed references**:

- [Model generator patterns](references/model-generator.md) - Custom models with migrations and associations
- [Service generator patterns](references/service-generator.md) - Service objects with result objects
- [API generator patterns](references/api-generator.md) - Controllers, serializers, and routes
- [Scaffold patterns](references/scaffold-generator.md) - Full-stack feature generation
- [Hooks and composition](references/hooks.md) - Generator hooks and fallbacks
- [Namespacing](references/namespacing.md) - Organizing generators with namespaces
- [File manipulation](references/file-actions.md) - Thor::Actions and Rails::Generators::Actions reference
- [Template system](references/templates.md) - ERB template patterns
- [Rails testing](references/testing-rails.md) - Rails::Generators::TestCase patterns
- [RSpec testing](references/testing-rspec.md) - generator_spec and RSpec patterns
- [Examples](references/examples.md) - Complete generator examples (query objects, form objects, presenters)
- [Application templates](references/application-templates.md) - Whole-app setup via `rails new -m` / `app:template`
- [Multi-tenant template](references/multitenant-template.md) - Worked example: acts_as_tenant, Organizations, Memberships, invitations
</reference_guides>

<success_criteria>
A well-built Rails generator has clear inheritance, properly configured `source_root`, well-defined `class_option` declarations, public methods in logical order, correct ERB templates, comprehensive tests, and consistent Rails naming conventions.
</success_criteria>

**Sources**:
- [Creating and Customizing Rails Generators & Templates — Ruby on Rails Guides](https://guides.rubyonrails.org/generators.html)
- [Rails 8 adds built in authentication generator | Saeloun Blog](https://blog.saeloun.com/2025/05/12/rails-8-adds-built-in-authentication-generator/)
- [Shaping Rails to Your Needs, Customizing Rails Generators using Thor Templates | Saeloun Blog](https://blog.saeloun.com/2023/05/31/customizing-rails-generators-using-thor-templates/)
- [Generators · rails/thor Wiki · GitHub](https://github.com/rails/thor/wiki/Generators)
- [GitHub: generator_spec](https://github.com/stevehodgkiss/generator_spec)
- [A Deep Dive Into RSpec Tests in Ruby on Rails | AppSignal Blog](https://blog.appsignal.com/2024/02/07/a-deep-dive-into-rspec-tests-in-ruby-on-rails.html)
