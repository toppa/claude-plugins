# Rails Application Template Patterns

Application templates are Ruby scripts that configure a whole Rails application — adding gems, running installers, creating files, and modifying configuration. They use the same Thor action DSL as custom generators but run against the entire app rather than generating a single component.

## Table of Contents

- [Templates vs Generators](#templates-vs-generators)
- [Invocation](#invocation)
- [Template Structure](#template-structure)
- [The Application Template DSL](#the-application-template-dsl)
- [Prefer Framework and Gem Installers Over Hand-Rolled Setup](#prefer-framework-and-gem-installers-over-hand-rolled-setup)
- [Idempotency Guards](#idempotency-guards)
- [Interactive Prompts](#interactive-prompts)
- [Composing Templates](#composing-templates)
- [Common Gotchas](#common-gotchas)
- [Verifying the Template](#verifying-the-template)

## Templates vs Generators

| | Custom generator | Application template |
|---|---|---|
| Invoked with | `rails generate foo` | `rails new app -m template.rb` or `bin/rails app:template` |
| Scope | One component (model, service, controller) | Whole-app setup (gems, auth, config, features) |
| Lives in | `lib/generators/` inside an app or gem | Standalone `.rb` file (local path or URL) |
| Base class | `Rails::Generators::Base` / `NamedBase` | None — top-level script evaluated in a `Rails::Generators::AppGenerator` context |
| Repeatable | Yes, designed for repeated use | Usually once per app; guard against re-runs |

Use a generator when the team will invoke it repeatedly inside one app. Use an application template when standing up new apps from a starter (or retrofitting a feature set like authentication or multi-tenancy onto an existing app).

## Invocation

```bash
# Apply while creating a new app
rails new myapp -m path/to/template.rb

# Apply to an existing app
bin/rails app:template LOCATION=path/to/template.rb

# Templates can also be loaded from a URL
rails new myapp -m https://example.com/template.rb
```

## Template Structure

A well-structured template follows this order:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# 1. Add this template's directory to the search path for partials and copied files.
#    `super +`, not a bare array — see Common Gotchas.
def source_paths
  super + [__dir__]
end

# 2. Guard against double application (see Idempotency Guards)
if File.exist?('app/models/organization.rb')
  raise Thor::Error, 'Template already applied. Reapply from a clean git state.'
end

# 3. Add gems, then install
gem 'acts_as_tenant', comment: 'Row-level multi-tenancy'
gem_group :development do
  gem 'letter_opener', comment: 'Preview email in the browser'
end
run 'bundle install'

# 4. Run the framework's and the gems' own install generators
generate 'authentication'          # Rails 8.1 ships this; no auth gem needed

# 5. Create/modify application files
create_file 'app/models/organization.rb', <<~RUBY
  class Organization < ApplicationRecord
    validates :name, presence: true, uniqueness: true
  end
RUBY

# 6. Migrate and verify, after the bundle is in place
after_bundle do
  rails_command 'db:prepare'
  rails_command 'test'             # or `run 'bundle exec rspec'` on an RSpec app
end

say '✅ Setup complete!', :green
```

Progress output with `say` (optionally colored: `:green`, `:yellow`, `:red`) keeps long-running templates
legible.

**Writing `Gemfile` lines is what an application template is for.** Step 3 is a legitimate use — the
reader is standing up their own app from this script. That is a different act from advising someone to add
a gem to a shared project, and different again from a *generator*, which runs inside an app that already
has a `Gemfile` you should read rather than edit.

**Rails 8.1 ships `bin/rails generate authentication`**, so an authentication template needs no gem. Its
output shape matters downstream: the user column is `email_address`, the user has `has_many :sessions`,
the routes are `resource :session` (singular) and `resources :passwords, param: :token`, and the current
session lives on `Current`. On a stock 8.1 app `authenticate_user!`, `sign_in`, `devise_for` and
`Devise::Test::IntegrationHelpers` are all undefined — verified:
`ApplicationController#respond_to?(:authenticate_user!, true)` is `false`.

## The Application Template DSL

All Thor actions from generators are available (`create_file`, `template`, `inject_into_file`, `gsub_file`, `insert_into_file`, `route`, `initializer` — see [file-actions.md](file-actions.md)), plus app-template-specific methods:

```ruby
# Gemfile management
gem 'sidekiq'
gem 'rspec-rails', group: [:development, :test]
gem_group :development, :test do
  gem 'factory_bot_rails'
end
add_source 'https://gems.example.com'

# Environment configuration
environment 'config.active_job.queue_adapter = :sidekiq'
environment 'config.action_mailer.delivery_method = :letter_opener', env: 'development'

# Run generators and commands
generate 'authentication'
generate 'model', 'Organization', 'name:string', 'description:text'
rails_command 'db:migrate'
rails_command 'db:seed', abort_on_failure: true
rake 'assets:precompile', env: 'production'
run 'bundle exec rubocop -a'

# Files under lib/ and vendor/
lib 'tenant_utils.rb', <<~RUBY
  module TenantUtils
  end
RUBY
vendor 'styles.css', '.tenant-badge { color: red; }'

# Git operations
git :init
git add: '.', commit: %(-m 'Apply multi-tenant template')

# Defer work until after bundle install completes
after_bundle do
  rails_command 'db:prepare'
  git add: '.', commit: %(-m 'Initial commit')
end
```

**`after_bundle` fires under `bin/rails app:template` too**, not only `rails new -m` — both routes go
through `apply_rails_template` → `run_bundle` → `run_after_bundle_callbacks`. Verified: applying a
template whose only content was an `after_bundle` block to an existing app printed the callback's output
right after `bundle install`.

What *is* specific to each route is when the bundle exists. Under `rails new -m`, gems added at the top
are installed by the initial `bundle install`. Under `app:template` against an existing app, nothing
installs them for you, so call `run 'bundle install'` explicitly after adding gems and before invoking
their generators inline — a gem's generator cannot run before the gem is on the load path.

## Prefer Framework and Gem Installers Over Hand-Rolled Setup

Reach for the framework's own generator first, then a gem's install generator, and hand-write config only
for what neither covers:

```ruby
generate 'authentication'        # Rails 8.1 built-in; no gem
generate 'action_policy:install' # gem installer, not: create_file 'config/initializers/...'
generate 'flipper:setup'
generate 'rspec:install'
```

Installers track the current version; hand-written config drifts and encodes assumptions from whenever the
template was written. Reserve `create_file`/`inject_into_file` for your application code and for
post-install customization of what the installer produced.

**Check that the installer exists before calling it.** `acts_as_tenant`, for one, ships no install
generator at all, so a template that calls `generate 'acts_as_tenant:install'` fails; its setup is a
hand-written initializer, which is exactly the case this rule leaves room for.

## Idempotency Guards

Application templates modify files with `inject_into_file` and `gsub_file`, so a second run corrupts the
app (duplicate injections, double routes). Guard at the top, using signals you can read from disk:

```ruby
def template_already_applied?
  return true if File.exist?('app/models/organization.rb')

  routes = File.exist?('config/routes.rb') ? File.read('config/routes.rb') : ''
  return true if routes.include?('resources :organizations')

  return true if Dir.glob('db/migrate/*_create_organizations.rb').any?

  schema = File.exist?('db/schema.rb') ? File.read('db/schema.rb') : ''
  return true if schema.include?('create_table "organizations"')

  false
end

if template_already_applied?
  raise Thor::Error, 'Template already applied. Reapply from a clean git state.'
end
```

Check several signals — a partial prior run may have created some but not others. A model file,
`config/routes.rb`, the migration directory and `db/schema.rb` together cover a partial apply,
and none of them needs a booted application.

**Two constraints make this guard look the way it does, and both were measured.**

**Touch no application constant.** The `rails new` process has not loaded Active Record, so
`ActiveRecord::Base.connection` raises `NameError: uninitialized constant ActiveRecord` — at the body line
*and* again at the `rescue ActiveRecord::StatementInvalid` line, because the rescue class is equally
unresolvable. `apply_rails_template` rescues only `Thor::Error`, `LoadError` and `Errno::ENOENT`, so the
`NameError` escapes: measured, `rails new` exited 1 with no `Gemfile.lock`, no `master.key`, and none of
the template's own files. **A half-built app is the worst outcome available here** — the guard exists to
prevent a corrupt app and instead produces one. Read `db/schema.rb` for the table name, or defer the
database question to `after_bundle`, where the app is loadable.

**Raise `Thor::Error`; never `exit`.** `SystemExit` is not rescued either, so `exit 1` inside a template
tears the process down mid-build for exactly the same reason. `Thor::Error` is rescued and reported:
measured under `rails new -m`, the guard tripping printed the single line
`The template [...] could not be loaded. Error: Template already applied. Reapply from a clean git state.`
and exited 1 with no backtrace. Under `bin/rails app:template` the same raise reports
`Thor::Error: Template already applied…` and exits 1. Inside a *generator*, `exit` additionally kills any
parent generator that invoked it.

With those two corrected, the same template runs `rails new -m` through to a complete app — verified: exit
0, `Gemfile.lock` and `master.key` present, `after_bundle` fired, and the app boots.

## Interactive Prompts

```ruby
app_name = ask('What is the product name?')
use_api = yes?('Generate API endpoints? (y/n)')

gem 'jbuilder' if use_api
```

Prompts make a template flexible but break unattended use (CI, scripted app creation). Prefer detecting from the environment or reading an ENV variable, and fall back to a prompt:

```ruby
use_api = ENV.fetch('TEMPLATE_API', nil) == 'true' || yes?('Generate API endpoints? (y/n)')
```

## Composing Templates

Split large setups into focused templates and compose them with `apply`:

```ruby
# main_template.rb
def source_paths
  super + [__dir__]
end

apply 'authentication_template.rb'
apply 'multitenant_template.rb'
apply 'admin_template.rb'
```

Each sub-template stays independently applicable (with its own guard), which makes them testable in isolation and lets existing apps adopt one feature set at a time.

## Common Gotchas

**`source_paths` replaces rather than extends**: `Thor::Actions#source_paths` is the list every action
searches, so `def source_paths; [__dir__]; end` discards the generator's own roots. Measured on a default
`rails new`: the Kamal installer, which runs after the template, died with
`Could not find "kamal-secrets.tt" in any of your source paths`. Write `super + [__dir__]`.

**No application constants inside the template body**: Active Record, your models and your initializers
are all unloaded during `rails new`. Anything that needs them goes in `after_bundle`. This is the same
trap as the idempotency guard above, and it also rules out interpolating
`ActiveRecord::Migration.current_version` into a hand-built migration.

**Migration timestamp collisions**: creating migrations with
`create_file "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_..."` in a loop produces duplicate
timestamps. Prefer `generate 'migration', 'CreateOrganizations', 'name:string'`, then patch the generated
file with `inject_into_file` for anything attribute syntax cannot express — that gets you correct
sequencing *and* the right `ActiveRecord::Migration[...]` version line for free.

**Silent no-op on a missed anchor**: `inject_into_file` and `gsub_file` change nothing and report nothing
when the pattern does not match. Read the file you are patching once while developing the template.

**Escaping interpolation in heredocs**: Ruby code written inside a template's heredoc that itself contains
`#{}` must be escaped (`\#{user.name}`) or the template evaluates it at apply time. Use `<<~'RUBY'`
(single-quoted heredoc) when the generated code needs literal interpolation and the template needs none.

**`gsub_file` with brittle regexes**: matching multi-line method bodies with `/def index.*?end/m` breaks
silently when the target app's code differs from what the template expects. Prefer `inject_into_file`
anchored on stable lines (class definitions, `Rails.application.routes.draw do`), and verify with tests
after applying.

**Mailer hosts**: a template that installs authentication should also set
`config.action_mailer.default_url_options` in development, or the first password-reset email raises.

**Test framework**: a `rails new` app is on Minitest. Use `rails_command 'test'`, or add `rspec-rails` and
run `generate 'rspec:install'` before the template writes anything under `spec/`.

## Verifying the Template

A template is code — test it by applying it, and always into a throwaway location:

```bash
# Fresh-app path, in a scratch directory outside any repo you care about
rails new /tmp/template_check --database=postgresql -m path/to/template.rb
echo $?                                # 0, with a Gemfile.lock and a bootable app
(cd /tmp/template_check && bin/rails runner 'puts "boots"')

# Existing-app path: copy the app first, so review is a diff and reset is a delete
cp -R existing-app /tmp/template_check_existing
cd /tmp/template_check_existing
bin/rails app:template LOCATION=path/to/template.rb
diff -ru ../existing-app . | less      # review every change the template made
bin/rails test
```

Applying to a copy rather than to the real checkout is what keeps an iteration loop from depending on
`git checkout .` to undo a half-applied template.

Two things to assert beyond "it did not crash": that `rails new` **exited 0** and produced a complete app
(`Gemfile.lock`, `config/master.key`, a successful `bin/rails runner`), and that applying it **twice**
trips the guard with one clean `Thor::Error` line rather than a backtrace. A template that crashes
half-way leaves an app that looks plausible and is not.

End the template itself with the app's test suite inside `after_bundle` so a broken application fails at
apply time, not at first boot. See [multitenant-template.md](multitenant-template.md) for a complete
worked example that was applied this way.

## Sources

- [Rails Application Templates — Ruby on Rails Guides](https://guides.rubyonrails.org/rails_application_templates.html)
- [Creating and Customizing Rails Generators & Templates — Ruby on Rails Guides](https://guides.rubyonrails.org/generators.html)
