# Generator File Actions Reference

The file-manipulation methods available in every Rails generator and application template come from two
places, and knowing which is which tells you where to look them up:

- **`Thor::Actions`** — `create_file`, `copy_file`, `template`, `create_link`, `insert_into_file` /
  `inject_into_file`, `append_to_file`, `prepend_to_file`, `gsub_file`, `comment_lines`,
  `uncomment_lines`, `remove_file`, `empty_directory`, `directory`, `inside`, `run`, `run_ruby_script`,
  `chmod`, `find_in_source_paths`, `ask`, `yes?`, `no?`, `say`, `say_status`.
- **`Rails::Generators::Actions`** — `gem`, `gem_group`, `add_source`, `environment`, `initializer`,
  `lib`, `rakefile`, `vendor`, `route`, `generate`, `rails_command`, `rake`, `git`, `github`, `readme`,
  `after_bundle`.

Both modules are mixed into `Rails::Generators::Base`, so all of it is callable from a generator method or
an application template body. The Rails half is the half an application template mostly lives on.

## Table of Contents

- [File Creation](#file-creation)
- [File Modification](#file-modification)
- [Directory Operations](#directory-operations)
- [Rails-Specific Helpers](#rails-specific-helpers)
- [Gemfile, Environment and Command Actions](#gemfile-environment-and-command-actions)
- [File System Queries](#file-system-queries)
- [User Interaction](#user-interaction)
- [Output and Logging](#output-and-logging)
- [Advanced File Operations](#advanced-file-operations)
- [Behavior Modifiers](#behavior-modifiers)
- [Practical Patterns](#practical-patterns)
- [Error Handling](#error-handling)
- [Revoke and Behavior](#revoke-and-behavior)
- [Best Practices](#best-practices)

## File Creation

### create_file

Creates a new file with specified content.

```ruby
def create_config_file
  create_file 'config/service_config.yml', <<~YAML
    development:
      timeout: 30
      retries: 3
    production:
      timeout: 60
      retries: 5
  YAML
end
```

**With block**:
```ruby
def create_json_config
  create_file 'config/settings.json' do
    JSON.pretty_generate({
      name: class_name,
      timestamp: Time.now.iso8601
    })
  end
end
```

**Options**:
- `verbose: false` - Suppress output
- `force: true` - Overwrite existing files

### copy_file

Copies a file from source_root to destination.

```ruby
def copy_template_files
  copy_file 'readme.md', 'README.md'
  copy_file 'gitignore', '.gitignore'
end
```

**To a different destination path**:
```ruby
def copy_with_namespace
  copy_file 'service.rb',
    "app/services/#{options[:namespace]}/#{file_name}_service.rb"
end
```

**With transformation** — `copy_file` takes a block that receives the source content and returns what to
write, which is the cheap alternative to a full `.tt` when one substitution is all you need:
```ruby
def copy_and_stamp
  copy_file 'service.rb', "app/services/#{file_name}_service.rb" do |content|
    content.sub('PlaceholderService', "#{class_name}Service")
  end
end
```

### template

Processes ERB template and writes result.

```ruby
def create_from_template
  template 'service.rb.tt', "app/services/#{file_name}_service.rb"
end
```

**With custom context**:
```ruby
def create_with_context
  @custom_var = "value"
  @another_var = options[:setting]

  template 'config.rb.tt', 'config/settings.rb'
end
```

**Inline template**:
```ruby
def create_inline
  create_file 'app/models/concern.rb' do
    <<~RUBY
      module #{class_name}Concern
        extend ActiveSupport::Concern

        included do
          # Included logic
        end
      end
    RUBY
  end
end
```

## File Modification

### insert_into_file

Inserts content into an existing file.

```ruby
def add_to_routes
  route "resources :#{plural_name}"

  # More control with insert_into_file
  insert_into_file 'config/routes.rb',
    "  namespace :api do\n    resources :#{plural_name}\n  end\n",
    after: "Rails.application.routes.draw do\n"
end
```

**Before/After positioning**:
```ruby
def insert_middleware
  insert_into_file 'config/application.rb',
    "    config.middleware.use MyMiddleware\n",
    before: "  end\nend"
end

def insert_at_end
  insert_into_file 'app/models/user.rb',
    "\n  include #{class_name}Concern\n",
    after: "class User < ApplicationRecord\n"
end
```

**With block**:
```ruby
def add_initializer_code
  insert_into_file 'config/initializers/app.rb', after: "Rails.application.configure do\n" do
    <<~RUBY
      config.custom_setting = true
      config.another_setting = "value"
    RUBY
  end
end
```

### gsub_file

Replaces text using regular expressions.

```ruby
def update_config
  gsub_file 'config/application.rb',
    /config\.load_defaults \d+\.\d+/,
    'config.load_defaults 8.1'
end
```

Write the version you actually target — `8.1` is current on this stack, and a template that rewrites a
newer app down to `8.0` silently changes framework defaults under it.

**With block**:
```ruby
def replace_with_logic
  gsub_file 'app/models/user.rb', /old_method_name/ do |match|
    "new_method_name_#{class_name.underscore}"
  end
end
```

### comment_lines / uncomment_lines

Comments out or uncomments matching lines.

```ruby
def relax_asset_check_in_production
  comment_lines 'config/environments/production.rb',
    /config\.assume_ssl = true/
end

def enable_bullet_in_development
  uncomment_lines 'config/environments/development.rb',
    /config\.action_mailer\.raise_delivery_errors/
end
```

**Both no-op silently when the pattern does not match**, which makes them the easiest actions to write
against a target that no longer exists. Two examples that used to be idiomatic no longer match anything on
Rails 8.1: `config.assets.compile` and `config.cache_classes` occur **zero** times in a generated
`config/environments/production.rb` (verified by reading a real one) — 8.1 writes
`config.enable_reloading = false` instead. Grep the generated environment file for your pattern before
shipping a `comment_lines` call against it.

## Directory Operations

### empty_directory

Creates an empty directory.

```ruby
def create_structure
  empty_directory 'app/services'
  empty_directory "app/services/#{options[:namespace]}" if options[:namespace]
end
```

### directory

Recursively copies a directory.

```ruby
def copy_templates
  directory 'views', "app/views/#{plural_name}"
  directory 'api_templates', "app/views/api/v1/#{plural_name}"
end
```

**With exclusions**:
```ruby
def copy_selective
  directory 'templates', 'app/templates', exclude_pattern: /\.keep$/
end
```

## Rails-Specific Helpers

### route

Adds routes to `config/routes.rb`.

```ruby
def add_routes
  route "resources :#{plural_name}"

  # Nested routes
  route <<~RUBY
    namespace :api do
      namespace :v1 do
        resources :#{plural_name}
      end
    end
  RUBY

  # Custom routes
  route "get '/#{plural_name}/search', to: '#{plural_name}#search'"
end
```

### initializer

Creates an initializer file.

```ruby
def create_initializer
  initializer "#{file_name}.rb", <<~RUBY
    Rails.application.config.to_prepare do
      #{class_name}Service.configure do |config|
        config.timeout = 30
      end
    end
  RUBY
end
```

**With template**:
```ruby
def create_initializer_from_template
  initializer "#{file_name}.rb" do
    <<~RUBY
      # #{class_name} Configuration
      Rails.application.config.#{file_name} = {
        enabled: true,
        options: {}
      }
    RUBY
  end
end
```

### lib

Creates a file in `lib/`.

```ruby
def create_lib_file
  lib "#{file_name}.rb", <<~RUBY
    module #{class_name}
      def self.call
        # Implementation
      end
    end
  RUBY
end
```

### rakefile

Creates a Rake task.

```ruby
def create_rake_task
  rakefile "#{file_name}.rake", <<~RUBY
    namespace :#{file_name} do
      desc "Run #{class_name} task"
      task run: :environment do
        #{class_name}Service.new.call
      end
    end
  RUBY
end
```

### vendor

Creates a file in `vendor/`.

```ruby
def add_vendor_lib
  vendor "plugins/#{file_name}.rb", <<~RUBY
    # Vendor plugin: #{class_name}
    module Plugins
      module #{class_name}
      end
    end
  RUBY
end
```

## Gemfile, Environment and Command Actions

These are the `Rails::Generators::Actions` half, and the half an application template mostly uses. They
are listed here because [application-templates.md](application-templates.md) points at this file for the
DSL.

```ruby
# Gemfile
gem 'acts_as_tenant', comment: 'Row-level multi-tenancy'
gem 'rspec-rails', group: [:development, :test]
gem_group :development, :test do
  gem 'factory_bot_rails'
end
add_source 'https://gems.example.com'

# Environment config
environment 'config.active_job.queue_adapter = :solid_queue'
environment 'config.action_mailer.delivery_method = :letter_opener', env: 'development'

# Invoking generators, Rails commands and Rake
generate 'authentication'
generate 'model', 'Organization', 'name:string'
rails_command 'db:prepare'
rails_command 'db:seed', abort_on_failure: true
rake 'assets:precompile', env: 'production'

# Repo and docs
git :init
git add: '.', commit: %(-m 'Apply template')
github repo_name: 'acme/widgets'
readme 'README.md'                 # copies from source_paths and prints it

# Deferred until the bundle exists (fires under `app:template` too)
after_bundle do
  rails_command 'db:prepare'
end
```

**`gem` in a generator is a different act from `gem` in an application template.** A template is a script
for standing up the reader's own app, so writing `Gemfile` lines is its whole job. A generator runs inside
an app that already has a `Gemfile`, so read it and work with what is there rather than adding a
dependency on the project's behalf.

## File System Queries

### File and Directory Checks

```ruby
def conditional_creation
  if Rails::Generators.options[:rails][:test_framework] == :rspec
    create_file 'spec/support/service_helpers.rb', helper_content
  else
    create_file 'test/support/service_helpers.rb', helper_content
  end
end

def check_structure
  if File.directory?(File.join(destination_root, 'app/services'))
    say "Services directory exists", :green
  else
    empty_directory 'app/services'
    say "Created services directory", :blue
  end
end
```

### find_in_source_paths

Returns the absolute path of a file found in the generator's source paths, and **raises `Thor::Error` when
it finds nothing** — it never returns a falsey value, so it cannot be used as a predicate. Verified by
invocation: a missing template produced
`Thor::Error: Could not find "nope.rb.tt" in any of your source paths.`

To choose between templates, test the filesystem and keep `find_in_source_paths` for resolving a path you
already know exists:

```ruby
def use_template
  if File.exist?(File.join(self.class.source_root, 'custom_template.rb.tt'))
    template 'custom_template.rb.tt', destination
  else
    template 'default_template.rb.tt', destination
  end
end
```

## User Interaction

### ask

Prompts user for input.

```ruby
def interactive_setup
  namespace = ask("Enter namespace (or leave empty):")
  @namespace = namespace unless namespace.empty?

  async = ask("Enable async processing? (yes/no)", limited_to: ['yes', 'no'])
  @async = async == 'yes'
end
```

### yes?

Boolean prompt.

```ruby
def optional_features
  if yes?("Include background job?")
    invoke 'job', ["#{name}_job"]
  end

  if yes?("Add API endpoints?")
    create_api_controller
  end
end
```

### no?

Inverse boolean prompt.

```ruby
def skip_optional
  return if no?("Create test files?")
  invoke 'test_unit:service', [name]
end
```

## Output and Logging

### say

Prints a message.

```ruby
def announce
  say "Creating #{class_name} service..."
  create_service_file
  say "Service created successfully!", :green
end
```

**Colors**: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`

### say_status

Prints status with formatting.

```ruby
def status_updates
  say_status :create, "app/services/#{file_name}_service.rb", :green
  say_status :invoke, "test_unit:service", :blue
  say_status :skip, "API controller (--skip-api)", :yellow
end
```

## Advanced File Operations

### append_to_file

Appends content to end of file.

```ruby
def add_to_registry
  append_to_file 'config/services.yml', "#{file_name}: enabled\n"
end
```

**With specific position**:
```ruby
def insert_in_configure_block
  inject_into_file 'config/environments/development.rb',
                   after: "Rails.application.configure do\n" do
    "  config.#{file_name}.verbose = true\n"
  end
end
```

### prepend_to_file

Prepends content to beginning of file.

```ruby
def add_header
  prepend_to_file 'app/services/base_service.rb', <<~RUBY
    # frozen_string_literal: true
    # Generated by #{self.class.name}

  RUBY
end
```

### remove_file

Deletes a file.

```ruby
def cleanup
  remove_file 'config/old_config.yml'
  remove_file "app/services/#{file_name}_service.rb" if options[:force]
end
```

## Behavior Modifiers

### inside

Changes directory context temporarily.

```ruby
def work_in_subdirectory
  inside 'app/services' do
    create_file "#{file_name}_service.rb", service_content
    create_file 'concerns/serviceable.rb', concern_content
  end
end
```

### run

Executes shell commands.

```ruby
def install_dependencies
  run 'bundle install'
end

def with_conditional
  rails_command 'db:migrate' if yes?('Run migrations now?')
end
```

Prefer `rails_command` over `run 'rails …'`: it invokes Rails in-process and takes `abort_on_failure:`.
And do not assume a JavaScript package manager — Rails 8.1 defaults to importmap plus Propshaft, so
`yarn` need not be installed. Read the app's `package.json` (or its absence) before shipping a
`run 'yarn add …'`.

### git

Executes git commands.

```ruby
def commit_changes
  git :init if options[:git]
  git add: '.'
  git commit: "-m 'Generated #{class_name} service'"
end
```

## Practical Patterns

### Complex File Structure Creation

```ruby
def create_service_structure
  # Base service
  template 'service.rb.tt', "app/services/#{namespace_path}/#{file_name}_service.rb"

  # Result object
  template 'result.rb.tt', "app/services/#{namespace_path}/#{file_name}_result.rb"

  # Error classes — `template` creates the directory
  template 'error.rb.tt', "app/services/#{namespace_path}/errors/#{file_name}_error.rb"

  # Tests
  template 'service_test.rb.tt', test_path

  # Documentation
  create_file "app/services/#{namespace_path}/README.md", documentation
end

private

def namespace_path
  options[:namespace] ? options[:namespace].underscore : ''
end

def test_path
  if rspec?
    "spec/services/#{namespace_path}/#{file_name}_service_spec.rb"
  else
    "test/services/#{namespace_path}/#{file_name}_service_test.rb"
  end
end

def rspec?
  Rails::Generators.options[:rails][:test_framework] == :rspec
end
```

### Conditional File Creation

```ruby
def create_conditional_files
  # Always create
  template 'service.rb.tt', service_path

  # Conditional on options
  template 'job.rb.tt', job_path if options[:async]
  template 'mailer.rb.tt', mailer_path if options[:notifications]

  # Conditional on environment
  if Rails.env.development?
    template 'service_console.rb.tt', 'lib/console/service_helper.rb'
  end

  # Conditional on existing files
  if File.exist?(File.join(destination_root, 'app/serializers/application_serializer.rb'))
    template 'serializer.rb.tt', serializer_path
  end
end
```

### Safe File Modification

```ruby
def modify_application_config
  config_path = File.join(destination_root, 'config/application.rb')
  return unless File.exist?(config_path)

  # Check if modification already exists
  return if File.read(config_path).include?("config.#{file_name}")

  insert_into_file 'config/application.rb',
    "    config.#{file_name}.enabled = true\n",
    after: "class Application < Rails::Application\n"
end
```

### Interactive Template Selection

```ruby
def choose_template_style
  style = ask("Choose template style:", limited_to: ['simple', 'advanced', 'dry'])

  case style
  when 'simple'
    template 'simple_service.rb.tt', destination
  when 'advanced'
    template 'advanced_service.rb.tt', destination
    template 'service_concerns.rb.tt', concerns_destination
  when 'dry'
    template 'dry_service.rb.tt', destination
    template 'dry_schema.rb.tt', schema_destination
  end
end
```

## Error Handling

### Graceful Failure

```ruby
def safe_route_addition
  begin
    route "resources :#{plural_name}"
  rescue => e
    say_status :error, "Failed to add routes: #{e.message}", :red
    say "Please add the following to config/routes.rb manually:", :yellow
    say "  resources :#{plural_name}", :cyan
  end
end
```

### Validation Before Creation

```ruby
def validate_and_create
  raise Thor::Error, "Invalid service name: #{name}" unless valid_service_name?

  if service_exists?
    return unless yes?('Service already exists. Overwrite?')
  end

  create_service_file
end

private

def valid_service_name?
  name.match?(/\A[A-Z][a-zA-Z0-9]*\z/)
end

def service_exists?
  File.exist?(File.join(destination_root, "app/services/#{file_name}_service.rb"))
end
```

Two things make that block correct where the obvious version is not:

- **`raise Thor::Error`, not `exit`.** `SystemExit` is not rescued by the generator machinery, so `exit 1`
  inside a generator also kills any parent generator that invoked it, and inside an application template it
  tears down `rails new` mid-build. `Thor::Error` produces one clean message and a non-zero exit.
- **Join paths against `destination_root`.** A bare `File.exist?('app/services/…')` resolves against the
  **process working directory**, not the generator's destination — so it silently probes the wrong tree
  under `Rails::Generators::TestCase`, where `destination_root` is a scratch directory.

## Revoke and Behavior

`rails destroy <generator> <name>` re-runs the generator with `behavior == :revoke`, and Thor inverts each
action for you: `create_file` deletes, `empty_directory` removes, `inject_into_file` strips the injected
text. Read `behavior` when an action has no natural inverse:

```ruby
def register_service
  case behavior
  when :invoke
    append_to_file 'config/services.yml', "#{file_name}: enabled\n"
  when :revoke
    gsub_file 'config/services.yml', /^#{file_name}: enabled\n/, '', force: true
  end
end
```

**`force: true` is what makes that `gsub_file` run.** `gsub_file` opens with
`return unless behavior == :invoke || config.fetch(:force, false)`
(`thor/actions/file_manipulation.rb:294`), so inside a `when :revoke` branch it is a no-op without it —
measured: `rails destroy` removed the generated file and left `config/services.yml` untouched, printing
nothing. With `force: true` the same run printed `gsub config/services.yml` and removed the entry.

`run` is not reversible, so anything shelled out stays done. Guard it with
`return if behavior == :revoke` rather than letting a destroy re-run it.

## Best Practices

1. **Skip `empty_directory` before `create_file`** — `create_file` creates missing parent directories, so
   the extra call only adds a spurious `create` line to the output.
2. **Check for existing content** before inserting, so a second run does not duplicate it.
3. **Provide user feedback** with `say` and `say_status`.
4. **Raise `Thor::Error` on unrecoverable input**, and let genuinely optional steps report and continue.
5. **Use relative paths** from `source_root` for templates, and `destination_root`-joined paths for
   probing the target app.
6. **Validate user input** when using `ask` and `yes?`.
7. **Cover file operations with a generator test**, which is where a silently-missed `inject_into_file`
   anchor shows up.
8. **Use `inside` blocks** for cleaner directory operations.
9. **Let the action names carry the meaning.** These are short, declarative calls; a comment explaining
   what `inject_into_file` does adds nothing a reader cannot see. Reserve comments for the case where a
   line is load-bearing in a way the code cannot show — an anchor string that must match the generator's
   exact output, for instance.
10. **Handle `revoke`** for any action Thor cannot invert on its own (see above).
