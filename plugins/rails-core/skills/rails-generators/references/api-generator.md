# API Controller Generator Patterns

A custom API controller generator with versioned endpoints, serializers and route configuration, checked
against Rails 8.1.3.1 / Ruby 3.4.5.

## Table of Contents

- [Generator Implementation](#generator-implementation)
- [Controller Template](#controller-template)
- [Serializer Templates](#serializer-templates)
- [Route Generation](#route-generation)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Checklist Specific to an API Generator](#checklist-specific-to-an-api-generator)

## Generator Implementation

```ruby
# lib/generators/api_controller/api_controller_generator.rb
class ApiControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  class_option :serializer, type: :string, default: 'none',
    desc: "Serializer framework (none, jbuilder, active_model_serializers, jsonapi)"
  class_option :actions, type: :array, default: %w[index show create update destroy],
    desc: "Controller actions to generate (space-separated)"
  class_option :version, type: :string, default: 'v1',
    desc: "API version"
  class_option :authenticate, type: :boolean, default: true,
    desc: "Require authentication (uses the app's own filter)"
  class_option :pagination, type: :boolean, default: false,
    desc: "Include pagination support (requires a pagination gem)"

  hook_for :test_framework, as: :controller

  def create_controller
    template 'controller.rb.tt',
      "app/controllers/api/#{options[:version]}/#{file_name.pluralize}_controller.rb"
  end

  def create_serializer
    return if options[:serializer] == 'none'

    template "serializer_#{options[:serializer]}.rb.tt", serializer_path
  end

  def add_routes
    route "resources :#{file_name.pluralize}, only: #{action_symbols.inspect}",
          namespace: [:api, options[:version].to_sym]
  end

  private

  def action_symbols
    options[:actions].map(&:to_sym)
  end

  def serializer_path
    case options[:serializer]
    when 'jbuilder'
      "app/views/api/#{options[:version]}/#{file_name.pluralize}/index.json.jbuilder"
    else
      "app/serializers/#{file_name}_serializer.rb"
    end
  end
end
```

Four changes from the obvious version, each with a reason that showed up on execution:

- **`none` is the default serializer, because the controller template renders JSON directly.** A default of
  `jbuilder` writes a view that a `render json:` action never renders. The other two defaults are worse:
  `ActiveModel::Serializer` comes from `active_model_serializers` and `JSONAPI::Serializer` from
  `jsonapi-serializer`, so either one makes the out-of-the-box output a class the app cannot load. Read the
  `Gemfile` and pick what the project has — and do not add a gem to a shared project to make a generator's
  default work.
- **`route …, namespace: [:api, :v1]` instead of a hand-written `namespace do` block.** With the keyword,
  successive additions merge into one correctly indented block; with a string, each invocation appends a
  fresh `namespace :api do`. Verified by running both forms twice against a fresh `config/routes.rb`.
- **`--authenticate`, not `--auth`, and it does not name a filter.** `before_action :authenticate_user!` is
  Devise's, and Devise is not part of a Rails 8.1 app — measured,
  `ApplicationController#respond_to?(:authenticate_user!, true)` is `false`. With `--auth` defaulting to
  true, *every* generated controller raised on its first request. See the controller template for what to
  emit instead.
- **No `permitted_params` helper.** The version that used to be here was never called by any template, and it
  probed `File.exist?("app/models/…")` relative to the **process working directory** rather than
  `destination_root` — so under `Rails::Generators::TestCase` it inspected the wrong tree. If a generator
  method needs to look at the target app, join the path against `destination_root`.

## Controller Template

```erb
<%# lib/generators/api_controller/templates/controller.rb.tt -%>
module Api
  module <%= options[:version].camelize %>
    class <%= class_name.pluralize %>Controller < Api::BaseController
      <%- if options[:authenticate] -%>
      before_action :require_authentication
      <%- end -%>
      <%- member_actions = options[:actions] & %w[show update destroy] -%>
      <%- if member_actions.any? -%>
      before_action :set_<%= singular_name %>, only: %i[<%= member_actions.join(' ') %>]
      <%- end -%>

      <%- if options[:actions].include?('index') -%>
      # GET /api/<%= options[:version] %>/<%= plural_name %>
      def index
        <%= plural_name %> = <%= class_name %>.all
        <%- if options[:pagination] -%>
        <%= plural_name %> = <%= plural_name %>.page(params[:page]).per(params[:per_page] || 25)
        <%- end -%>

        render json: <%= plural_name %>
      end
      <%- end -%>

      <%- if options[:actions].include?('show') -%>
      # GET /api/<%= options[:version] %>/<%= plural_name %>/:id
      def show
        render json: @<%= singular_name %>
      end
      <%- end -%>

      <%- if options[:actions].include?('create') -%>
      # POST /api/<%= options[:version] %>/<%= plural_name %>
      def create
        <%= singular_name %> = <%= class_name %>.new(<%= singular_name %>_params)

        if <%= singular_name %>.save
          render json: <%= singular_name %>, status: :created
        else
          render json: { errors: <%= singular_name %>.errors }, status: :unprocessable_content
        end
      end
      <%- end -%>

      <%- if options[:actions].include?('update') -%>
      # PATCH/PUT /api/<%= options[:version] %>/<%= plural_name %>/:id
      def update
        if @<%= singular_name %>.update(<%= singular_name %>_params)
          render json: @<%= singular_name %>
        else
          render json: { errors: @<%= singular_name %>.errors }, status: :unprocessable_content
        end
      end
      <%- end -%>

      <%- if options[:actions].include?('destroy') -%>
      # DELETE /api/<%= options[:version] %>/<%= plural_name %>/:id
      def destroy
        @<%= singular_name %>.destroy!
        head :no_content
      end
      <%- end -%>

      private

      <%- if member_actions.any? -%>
      def set_<%= singular_name %>
        @<%= singular_name %> = <%= class_name %>.find(params.expect(:id))
      end
      <%- end -%>

      <%- if (options[:actions] & %w[create update]).any? -%>
      def <%= singular_name %>_params
        params.expect(<%= singular_name %>: [<%= attribute_keys %>])
      end
      <%- end -%>
    end
  end
end
```

Five decisions in that template, all of which came out of running the previous version:

- **`Api::BaseController`, and `render_resource` / `render_collection` are gone.** Emitting a private
  `render_resource` into *every* generated controller duplicates the same two methods per resource; if the API
  needs a shared response shape, it belongs in one base class the generator does not rewrite.
- **`render json:` directly, not wrapped in `respond_to do |format| format.json`.** The `respond_to` wrapper
  returns **406 Not Acceptable** for any other `Accept` header, where a bare `render json:` just answers. On a
  JSON API that is a needless way to reject clients.
- **`before_action :require_authentication`, which the Rails 8.1 authentication generator defines** in
  `app/controllers/concerns/authentication.rb`. Do not emit `authenticate_user!` — that is Devise's, and it is
  undefined on a stock 8.1 app, so with authentication on by default every generated controller raised on its
  first request. If the project uses something else, read what its `ApplicationController` already calls and
  emit that.
- **`params.expect(<name>: [...])`, not `params.require(:<name>).permit(...)`.** `expect` is what the Rails 8.1
  scaffold template writes, and it is the form that turns a wrong-shaped root key into a **400** rather than a
  500: measured, `user: "notahash"` gives 400 under `expect` and 500 under `require(:user).permit`. Two caveats
  worth knowing: `expect` raises only when a **root** key is missing or empty, and it filters a wrong-shaped
  *nested* key silently — so it is a root-key guard, not a nested-shape validator. And given several root
  scalars it returns an **Array**, not a `Parameters` — measured — which is why a flat sign-in action wants
  `params.permit(:email_address, :password)` instead. `rails-core:rails-8-idioms` has the full shape
  rule in its "Strong parameters: pick the form from the shape of the incoming params" section.
- **Local variables in `index` and `create`, ivars only where a `before_action` set them.** A JSON action has
  no view to share state with, so an ivar there is a longer way to write a local.

`attribute_keys` is the one thing the generator has to decide for you, and there is no honest way to infer it
from a class name alone. Take it as an argument:

```ruby
argument :attributes, type: :array, default: [], banner: "field:type field:type"

private

def attribute_keys
  return ':id' if attributes.empty?

  attributes.map { |attr| ":#{attr.name}" }.join(', ')
end
```

A generated `permit`/`expect` list that guesses is worse than one that makes you type the fields, because a
wrong list either drops attributes silently or admits ones you did not mean.

## Serializer Templates

**Check the `Gemfile` before generating any of these.** Only jbuilder ships with Rails 8.1; the other two
templates emit constants from gems that may not be installed.

### Jbuilder (ships with Rails 8.1)

```erb
<%# lib/generators/api_controller/templates/serializer_jbuilder.rb.tt -%>
json.array! <%= plural_name %> do |<%= singular_name %>|
  json.extract! <%= singular_name %>, <%= attribute_keys %>
end
```

A jbuilder view is rendered by `render json:`-free actions, so `--serializer=jbuilder` also needs a controller
template that calls `render` without `json:`. That is why the serializer defaults to `none`: the controller
template above calls `render json:`, which serializes directly and needs no view. Pick one. Generating both is
how a project ends up with two serialization paths for the same resource, and the jbuilder view is the one
that never renders.

### ActiveModelSerializers (requires `active_model_serializers`)

```erb
<%# lib/generators/api_controller/templates/serializer_active_model_serializers.rb.tt -%>
class <%= class_name %>Serializer < ActiveModel::Serializer
  attributes <%= attribute_keys %>
end
```

### JSON:API (requires `jsonapi-serializer`)

```erb
<%# lib/generators/api_controller/templates/serializer_jsonapi.rb.tt -%>
class <%= class_name %>Serializer
  include JSONAPI::Serializer

  attributes <%= attribute_keys %>
end
```

Gate the choice in the generator rather than letting a template emit an unloadable constant:

```ruby
SERIALIZER_GEMS = {
  'active_model_serializers' => 'active_model_serializers',
  'jsonapi' => 'jsonapi-serializer'
}.freeze

def create_serializer
  return if options[:serializer] == 'none'

  gem_name = SERIALIZER_GEMS[options[:serializer]]
  if gem_name && !Gem.loaded_specs.key?(gem_name)
    raise Thor::Error,
      "--serializer=#{options[:serializer]} needs the #{gem_name} gem, which this app does not have."
  end

  template "serializer_#{options[:serializer]}.rb.tt", serializer_path
end
```

`Gem.loaded_specs` reflects the app's own bundle, so this fails at generation time with a message instead of at
boot with a `NameError`.

## Route Generation

The generator adds versioned, namespaced routes through `route`'s `namespace:` keyword, so repeated runs merge:

```ruby
# After: rails generate api_controller Product --actions index show create
#        rails generate api_controller Order   --actions index
namespace :api do
  namespace :v1 do
    resources :orders, only: [:index]
    resources :products, only: [:index, :show, :create]
  end
end
```

Verified: two runs of the keyword form produced one merged, correctly indented block, while two runs of a
hand-written `"namespace :api do\n    namespace :v1 do\n…"` string produced two separate `namespace :api`
blocks with drifting indentation.

Custom version:

```bash
rails generate api_controller Product --version=v2
# Routes under api/v2, controller at app/controllers/api/v2/products_controller.rb
```

## Usage Examples

### Basic CRUD API

```bash
rails generate api_controller Product name:string price:decimal
# Creates:
# - app/controllers/api/v1/products_controller.rb (all five CRUD actions, rendering JSON directly)
# - merges `resources :products` into namespace :api / namespace :v1
```

### Read-Only, Unauthenticated API

```bash
rails generate api_controller Report title:string --actions index show --no-authenticate
```

`--actions index show`, space-separated: `--actions=index,show` arrives as the single element
`["index,show"]`, so the generated `only:` list reads `[:"index,show"]` and matches no action. Measured.

### Paginated API

```bash
rails generate api_controller Order total:decimal --pagination
```

`--pagination` emits `.page(...).per(...)`, which needs a pagination gem — `kaminari` or `pagy`. Read the
`Gemfile` first; if neither is there, either leave the flag off or add the gem yourself in your own app.
A generator should not decide a shared project's dependencies. The same `Gem.loaded_specs` gate shown for
serializers works here:

```ruby
def create_controller
  if options[:pagination] && !%w[kaminari pagy].any? { |g| Gem.loaded_specs.key?(g) }
    raise Thor::Error, '--pagination needs kaminari or pagy, which this app does not have.'
  end

  template 'controller.rb.tt', controller_path
end
```

## Testing

```ruby
class ApiControllerGeneratorTest < Rails::Generators::TestCase
  tests ApiControllerGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  test "generates API controller with all actions" do
    run_generator ["product", "name:string"]

    assert_file "app/controllers/api/v1/products_controller.rb" do |content|
      assert_match(/module Api/, content)
      assert_match(/module V1/, content)
      assert_match(/class ProductsController < Api::BaseController/, content)
      %w[index show create update destroy].each do |action|
        assert_match(/def #{action}/, content)
      end
    end
  end

  test "generates controller with limited actions" do
    run_generator ["product", "name:string", "--actions", "index", "show"]

    assert_file "app/controllers/api/v1/products_controller.rb" do |content|
      assert_match(/def index/, content)
      assert_match(/def show/, content)
      refute_match(/def create/, content)
      refute_match(/def destroy/, content)
      assert_match(/only: %i\[show\]/, content)
    end
  end

  test "uses params.expect for strong parameters" do
    run_generator ["product", "name:string", "price:decimal"]

    assert_file "app/controllers/api/v1/products_controller.rb" do |content|
      assert_match(/params\.expect\(product: \[:name, :price\]\)/, content)
      refute_match(/params\.require/, content)
    end
  end

  test "emits the framework authentication filter, not Devise's" do
    run_generator ["product", "name:string"]

    assert_file "app/controllers/api/v1/products_controller.rb" do |content|
      assert_match(/before_action :require_authentication/, content)
      refute_match(/authenticate_user!/, content)
    end
  end

  test "omits the filter when authentication is off" do
    run_generator ["report", "title:string", "--no-authenticate"]

    assert_file "app/controllers/api/v1/reports_controller.rb" do |content|
      refute_match(/before_action :require_authentication/, content)
    end
  end

  test "merges routes into one namespace block across runs" do
    run_generator ["product", "name:string"]
    run_generator ["order", "total:decimal"]

    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan(/namespace :api do/).size
      assert_match(/resources :products/, content)
      assert_match(/resources :orders/, content)
    end
  end

  test "supports custom API version" do
    run_generator ["product", "name:string", "--version=v2"]

    assert_file "app/controllers/api/v2/products_controller.rb"
  end
end
```

The routes test is the one worth keeping: asserting that `namespace :api do` appears **once** after two runs is
what distinguishes `route(namespace:)` from a hand-written string, and a `assert_match(/namespace :api/)` passes
either way.

## Checklist Specific to an API Generator

- [ ] The default serializer is one the app can actually load, and any gem-backed choice is gated on
      `Gem.loaded_specs`.
- [ ] Routes are added with `route …, namespace: […]`, and a test asserts one block after two runs.
- [ ] The authentication filter emitted is the one this app's `ApplicationController` defines.
- [ ] Strong parameters use `params.expect(model: [...])` for a nested model key, with the attribute list
      supplied rather than guessed.
- [ ] Shared response helpers live in a base controller the generator does not rewrite per resource.
- [ ] No `respond_to` wrapper around a lone `format.json` block.
- [ ] Any filesystem probe joins its path against `destination_root`.
- [ ] Array options are documented and tested as space-separated.
