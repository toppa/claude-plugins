# Generator Namespacing Patterns

Organizing generators with namespaces for modular, discoverable generator libraries.

## Table of Contents

- [Basic Namespacing](#basic-namespacing)
- [Generator Search Path](#generator-search-path)
- [Namespaced Templates](#namespaced-templates)
- [Two different namespaces, and the helpers that tell them apart](#two-different-namespaces-and-the-helpers-that-tell-them-apart)
- [Engine Generators](#engine-generators)
- [Gem-Packaged Generators](#gem-packaged-generators)
- [Usage Examples](#usage-examples)

## Basic Namespacing

Namespace generators to organize related generators under a common prefix:

```ruby
# lib/generators/admin/resource/resource_generator.rb
module Admin
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_admin_resource
        template 'resource.rb.tt', "app/admin/#{file_name}.rb"
      end

      def create_admin_controller
        template 'controller.rb.tt',
          "app/controllers/admin/#{file_name.pluralize}_controller.rb"
      end

      def create_admin_views
        directory 'views', "app/views/admin/#{file_name.pluralize}"
      end
    end
  end
end
```

Invoke with: `rails generate admin:resource User`

## Generator Search Path

Rails searches for generators in this order:

1. `rails/generators/[namespace]/[name]/[name]_generator.rb`
2. `generators/[namespace]/[name]/[name]_generator.rb`
3. `rails/generators/[namespace]/[name]_generator.rb`
4. `generators/[namespace]/[name]_generator.rb`

Each one is a plain `require`, so it resolves against `$LOAD_PATH` rather than against the
application root (railties 8.1.3.1, `rails/command/behavior.rb:36-53`, over the two
`lookup_paths` and the two forms `namespaces_to_paths` builds at `:70-80`). For
`admin:resource`, that is these four requires, tried in this order:

1. `rails/generators/admin/resource/resource_generator`
2. `generators/admin/resource/resource_generator`
3. `rails/generators/admin/resource_generator`
4. `generators/admin/resource_generator`

**Write your own generator at `lib/generators/admin/resource/resource_generator.rb`.** That
file satisfies require 2, because `lib` is on the load path by declaration — Rails' engine
configuration does `paths.add "lib", load_path: true` (`rails/engine/configuration.rb:91`).

### `lib/templates` is already on the template-override path

`config.generators.templates` is the search path for **template overrides**, not for generator lookup, and
`lib/templates` is unshifted into it automatically —
`Rails::Application#ensure_generator_templates_added` (`application.rb:635`) does
`configured_paths.unshift(*(paths["lib/templates"].existent - configured_paths))`. So adding it by hand in
`config/application.rb` is a no-op.

Verified end to end: dropping `lib/templates/active_record/model/model.rb.tt` into an app with no
configuration at all made `rails generate model Widget name:string` emit that template's body, and
`Rails.application.config.generators.templates` read back as `[".../lib/templates"]`.

Add a path only for a directory outside `lib/templates`:

```ruby
config.generators do |g|
  g.templates.unshift Rails.root.join('config/generator_templates').to_s
end
```

### Fallback Resolution

When a namespaced generator is not found, Rails checks fallbacks:

```ruby
config.generators do |g|
  g.fallbacks[:admin] = :rails
end
```

This means `admin:model` falls back to `rails:model` if not found.

## Namespaced Templates

Templates for namespaced generators follow the same directory structure:

```
lib/generators/admin/resource/
├── resource_generator.rb
└── templates/
    ├── resource.rb.tt
    ├── controller.rb.tt
    └── views/
        ├── index.html.erb.tt
        └── show.html.erb.tt
```

Handle namespace in templates:

```erb
# lib/generators/admin/resource/templates/controller.rb.tt
module Admin
  class <%= class_name.pluralize %>Controller < Admin::BaseController
    def index
      @<%= plural_name %> = <%= class_name %>.all
    end

    def show
      @<%= singular_name %> = <%= class_name %>.find(params[:id])
    end
  end
end
```

## Two different namespaces, and the helpers that tell them apart

"Namespace" means two unrelated things in generator code, and mixing them up is the usual source of
confusion in this area:

- **The invocation namespace** — `admin:resource` — derived from the generator class's constant path. That
  is everything above.
- **The isolated-engine namespace** — the module an engine's generated code is nested inside. Three
  protected helpers on `Rails::Generators::Base` (`base.rb:312-326`) report it:
  - `namespace` → `Rails::Generators.namespace`, the isolated engine's module, or `nil` in an application.
  - `namespaced?` → `!options[:skip_namespace] && namespace`.
  - `namespaced_path` → the module path underscored and joined, e.g. `my_engine`.

`--skip-namespace` is a global `class_option` on every generator (`base.rb:21`), described as
*"Skip namespace (affects only isolated engines)"* — so it turns `namespaced?` off and has no effect in a
plain application.

Use them in a generator that must work inside an engine and inside an app:

```ruby
def create_service
  template 'service.rb.tt', File.join('app/services', namespaced_path.to_s, "#{file_name}_service.rb")
end
```

```erb
<%- if namespaced? -%>
module <%= namespace.name %>
<%- end -%>
  class <%= class_name %>Service
  end
<%- if namespaced? -%>
end
<%- end -%>
```

`Rails::Generators.namespace` is populated by `isolate_namespace` in the engine's class body
(`engine.rb:384-389`, which also sets `config.default_scope` and `isolated = true`) — so a generator that
reads `namespaced?` behaves correctly in an isolated engine without any extra flags.

## Engine Generators

Generators packaged in Rails engines:

```ruby
# my_engine/lib/generators/my_engine/install/install_generator.rb
module MyEngine
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_initializer
        template 'initializer.rb.tt',
          'config/initializers/my_engine.rb'
      end

      def copy_migrations
        rake 'my_engine:install:migrations'
      end

      def add_routes
        route "mount MyEngine::Engine => '/my_engine'"
      end
    end
  end
end
```

Invoke with: `rails generate my_engine:install`

## Gem-Packaged Generators

Structure generators in a gem for reuse across projects:

```
my_generators/
├── lib/
│   ├── generators/
│   │   └── my_gem/
│   │       ├── service/
│   │       │   ├── service_generator.rb
│   │       │   └── templates/
│   │       └── query/
│   │           ├── query_generator.rb
│   │           └── templates/
│   └── my_generators.rb
├── my_generators.gemspec
└── Gemfile
```

Register generators in the gem:

```ruby
# lib/my_generators.rb
module MyGenerators
  class Railtie < Rails::Railtie
    generators do
      require 'generators/my_gem/service/service_generator'
      require 'generators/my_gem/query/query_generator'
    end
  end
end
```

## Usage Examples

### Multi-Level Namespace

```ruby
# lib/generators/api/v2/resource/resource_generator.rb
module Api
  module V2
    module Generators
      class ResourceGenerator < Rails::Generators::NamedBase
        source_root File.expand_path('templates', __dir__)

        def create_controller
          template 'controller.rb.tt',
            "app/controllers/api/v2/#{file_name.pluralize}_controller.rb"
        end
      end
    end
  end
end
```

Invoke with: `rails generate api:v2:resource Product`

### Customize a Built-in Generator

**Override the template, not the source root.** Drop a file at the same relative path under
`lib/templates/<generator namespace>/` and Rails uses it in place of the framework's:

```
lib/templates/
├── active_record/model/model.rb.tt
├── rails/scaffold_controller/controller.rb.tt
└── erb/scaffold/index.html.erb.tt
```

Verified: `lib/templates/active_record/model/model.rb.tt` changed the output of
`rails generate model Widget name:string` with no configuration and no reopened class. Templates you do not
override keep coming from the framework, so this composes.

Verified against the framework's own scaffold too: `lib/templates/rails/scaffold_controller/controller.rb.tt`
replaced the generated controller body while the `erb` views kept coming from railties.

**Do not reopen the class to point it somewhere else.** Two mechanics make that route a dead end:

- `Thor::Actions::ClassMethods#source_root` is `@_source_root = path if path`
  (`thor/actions.rb:27-29`) — it *assigns*, replacing the built-in root outright. Every template the
  reopened class does not itself ship then stops resolving.
- Pushing onto the plural `source_paths` instead does not help, because `source_paths_for_search`
  (`thor/actions.rb:38-42`) builds its list as `[source_root] + source_paths +
  from_superclass(:source_paths)` — the built-in root is consulted first, so an unshifted path never wins.
  Measured: `source_paths.unshift` on a reopened `ScaffoldControllerGenerator` had no effect on the output,
  while the same template under `lib/templates` did.

`lib/templates` is the supported route and the only one that works without breaking something else.

### Listing Available Generators

```bash
# List all generators including namespaced ones
rails generate --help

# List generators matching a pattern
rails generate --help | grep admin
```
