# Full-Stack Scaffold Generator Patterns

A feature scaffold generator that composes the model, controller, views, specs and routes in one invocation.
Checked against Rails 8.1.3.1 / Ruby 3.4.5.

## Table of Contents

- [Generator Implementation](#generator-implementation)
- [View Templates](#view-templates)
- [Invoking Sub-Generators](#invoking-sub-generators)
- [Usage Examples](#usage-examples)
- [Testing](#testing)

## Generator Implementation

```ruby
# lib/generators/feature/feature_generator.rb
class FeatureGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  class_option :api, type: :boolean, default: false, desc: "Generate API-only scaffold"
  class_option :skip_views, type: :boolean, default: false, desc: "Skip view generation"
  class_option :skip_controller, type: :boolean, default: false, desc: "Skip controller"
  class_option :skip_model, type: :boolean, default: false, desc: "Skip model and migration"
  class_option :namespace, type: :string, desc: "Controller namespace"
  class_option :parent, type: :string, desc: "Parent model for nested resource"
  class_option :mailer, type: :boolean, default: false, desc: "Also generate a mailer"
  class_option :background_job, type: :boolean, default: false, desc: "Also generate a job"

  VIEWS = %w[index show new edit _form].freeze

  def create_model
    return if options[:skip_model]
    invoke 'model', [name] + attributes.map(&:to_s), migration: true
  end

  def create_controller
    return if options[:skip_controller]

    if options[:api]
      invoke 'api_controller', [name]
    else
      template 'controller.rb.tt', controller_path
    end
  end

  def create_views
    return if options[:api] || options[:skip_views] || options[:skip_controller]

    VIEWS.each do |view|
      template "views/#{view}.html.erb.tt",
        "app/views/#{controller_file_path}/#{view}.html.erb"
    end
  end

  def create_mailer
    invoke 'mailer', [name] if options[:mailer]
  end

  def create_job
    invoke 'job', ["#{name}_job"] if options[:background_job]
  end

  def add_routes
    return if options[:skip_controller]

    if options[:parent]
      add_nested_routes
    elsif options[:namespace]
      route "resources :#{file_name.pluralize}", namespace: options[:namespace].to_sym
    else
      route "resources :#{file_name.pluralize}"
    end
  end

  private

  def controller_path
    if options[:namespace]
      "app/controllers/#{options[:namespace]}/#{file_name.pluralize}_controller.rb"
    else
      "app/controllers/#{file_name.pluralize}_controller.rb"
    end
  end

  def controller_file_path
    if options[:namespace]
      "#{options[:namespace]}/#{file_name.pluralize}"
    else
      file_name.pluralize
    end
  end
end
```

Four corrections, each of which showed up on execution:

- **`--mailer` and `--background_job` are declared.** They were read by `invoke … if options[:mailer]` without
  a matching `class_option`, and Thor returns `nil` for an undeclared key — so both branches were permanently
  dead while looking like working code.
- **`VIEWS` lists all five templates the generator must ship.** With only `index`, `show` and `_form` present
  in `templates/views/`, the run dies with Thor's `Could not find "views/new.html.erb.tt" in any of your
  source paths`. Either ship five templates or shorten the list; a partial set fails the whole generator.
- **`route`'s `namespace:` keyword for the namespaced case.** A hand-written
  `"namespace :admin do\n    resources :x\n  end"` string appends a fresh block on every run, with drifting
  indentation. Verified by running both forms twice: the string form produced two separate blocks, the keyword
  form one merged block.
- **No `invoke 'test_unit:model'`.** `test_unit:model`, `test_unit:controller` and `test_unit:system` all
  exist, so a hardcoded invoke *succeeds* — and dumps Minitest files into a project whose suite is RSpec. Let
  the model generator's own `hook_for` do it: `invoke 'model'` already fires the configured test framework,
  which is `:rspec` as soon as rspec-rails is installed (`rspec-rails.rb:33`). Verified: `invoke 'model'` on an
  app with rspec-rails created `spec/models/…_spec.rb`.

Nesting under a parent has no `route` keyword of its own, so that branch needs a block string. Anchor it and
guard against a second insertion rather than appending blindly:

```ruby
def add_nested_routes
  parent = options[:parent].underscore.pluralize
  anchor = "resources :#{parent} do\n"

  unless File.read(File.join(destination_root, 'config/routes.rb')).include?(anchor)
    route "resources :#{parent} do\nend"
  end

  inject_into_file 'config/routes.rb', "    resources :#{file_name.pluralize}\n", after: anchor
end
```

## View Templates

### Index View

```erb
# lib/generators/feature/templates/views/index.html.erb.tt
<h1><%= class_name.pluralize %></h1>

<%%= link_to "New <%= class_name.titleize %>", new_<%= singular_route_name %>_path %>

<table>
  <thead>
    <tr>
      <%- attributes.each do |attr| -%>
      <th><%= attr.human_name %></th>
      <%- end -%>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <%% @<%= plural_name %>.each do |<%= singular_name %>| %>
      <tr>
        <%- attributes.each do |attr| -%>
        <td><%%= <%= singular_name %>.<%= attr.name %> %></td>
        <%- end -%>
        <td>
          <%%= link_to "Show", <%= singular_name %> %>
          <%%= link_to "Edit", edit_<%= singular_route_name %>_path(<%= singular_name %>) %>
          <%%= button_to "Delete", <%= singular_name %>, method: :delete, data: { confirm: "Are you sure?" } %>
        </td>
      </tr>
    <%% end %>
  </tbody>
</table>
```

### Show View

```erb
# lib/generators/feature/templates/views/show.html.erb.tt
<h1><%= class_name %></h1>

<%- attributes.each do |attr| -%>
<p>
  <strong><%= attr.human_name %>:</strong>
  <%%= @<%= singular_name %>.<%= attr.name %> %>
</p>
<%- end -%>

<%%= link_to "Edit", edit_<%= singular_route_name %>_path(@<%= singular_name %>) %>
<%%= link_to "Back", <%= plural_route_name %>_path %>
```

### Form Partial

```erb
# lib/generators/feature/templates/views/_form.html.erb.tt
<%%= form_with(model: <%= singular_name %>) do |form| %>
  <%% if <%= singular_name %>.errors.any? %>
    <div id="error_explanation">
      <h2><%%= pluralize(<%= singular_name %>.errors.count, "error") %> prohibited this from being saved:</h2>
      <ul>
        <%% <%= singular_name %>.errors.each do |error| %>
          <li><%%= error.full_message %></li>
        <%% end %>
      </ul>
    </div>
  <%% end %>

  <%- attributes.each do |attr| -%>
  <div class="field">
    <%%= form.label :<%= attr.name %> %>
    <%- case attr.type -%>
    <%- when :text -%>
    <%%= form.text_area :<%= attr.name %> %>
    <%- when :boolean -%>
    <%%= form.check_box :<%= attr.name %> %>
    <%- when :integer, :float, :decimal -%>
    <%%= form.number_field :<%= attr.name %> %>
    <%- when :date -%>
    <%%= form.date_field :<%= attr.name %> %>
    <%- when :datetime -%>
    <%%= form.datetime_field :<%= attr.name %> %>
    <%- else -%>
    <%%= form.text_field :<%= attr.name %> %>
    <%- end -%>
  </div>
  <%- end -%>

  <div class="actions">
    <%%= form.submit %>
  </div>
<%% end %>
```

## Invoking Sub-Generators

The scaffold generator composes other generators using `invoke`:

```ruby
# Invoke built-in Rails generators
invoke 'model', [name], migration: true
invoke 'controller', [name], actions: %w[index show new create edit update destroy]

# Invoke custom generators
invoke 'api_controller', [name]
invoke 'service', ["#{name}_processor"]

# Conditional invocation
invoke 'mailer', [name] if options[:mailer]
invoke 'job', ["#{name}_job"] if options[:background_job]
```

Key considerations:

- Invoked generators receive the same `destination_root`.
- `invoke` really does forward an options hash to the invoked generator (thor `invocation.rb:102-116`), so
  `migration: true` and `actions: […]` arrive as `options` there.
- Use `invoke` for generators that should only run once per name.
- **Let the invoked generator's own `hook_for` pick the test framework.** `invoke 'model'` fires
  `<configured framework>:model`, which is `rspec:model` as soon as rspec-rails is installed. A hardcoded
  `invoke 'test_unit:model'` succeeds — the responder exists — and writes Minitest files into an RSpec
  project, which is the failure mode worth avoiding, because nothing errors.
- **`hook_for` only reaches responders that exist.** `as: :model`, `:controller`, `:scaffold`, `:mailer`,
  `:job`, `:channel`, `:integration` and `:system` resolve; anything else prints
  `error  <framework>  [not found]`, writes nothing and exits 0. For a layer Rails does not generate, read
  `Rails::Generators.options[:rails][:test_framework]` in a private method, or ship the responder yourself
  (see [hooks.md](hooks.md#creating-hook-responders)).

## Usage Examples

### Basic Feature Scaffold

```bash
rails generate feature Product name:string price:decimal description:text
```

Creates, on a project with rspec-rails installed:

```
db/migrate/XXXXXXXXXXXXXX_create_products.rb
app/models/product.rb
spec/models/product_spec.rb                          # from the model generator's hook_for
app/controllers/products_controller.rb
app/views/products/{index,show,new,edit,_form}.html.erb
config/routes.rb                                     # resources :products
```

On a Minitest project the same run writes `test/models/product_test.rb` instead — because the hook follows the
configured framework rather than a hardcoded namespace. That is the whole reason not to hardcode it.

### API-Only Scaffold

```bash
rails generate feature Product name:string price:decimal --api
# Model, migration, API controller and serializer; no views
```

### Nested Resource

```bash
rails generate feature Comment body:text --parent=Post
# Nests `resources :comments` inside `resources :posts do … end`
```

### Namespaced Feature

```bash
rails generate feature Widget title:string --namespace=admin
# app/controllers/admin/widgets_controller.rb, app/views/admin/widgets/…,
# and `resources :widgets` merged into a single `namespace :admin do` block
```

## Testing

```ruby
class FeatureGeneratorTest < Rails::Generators::TestCase
  tests FeatureGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  test "generates complete feature" do
    run_generator ["order", "status:string", "total:decimal"]

    assert_file "app/models/order.rb"
    assert_migration "db/migrate/create_orders.rb"
    assert_file "app/controllers/orders_controller.rb"

    # All five, because a partial template set fails the whole run.
    %w[index show new edit _form].each do |view|
      assert_file "app/views/orders/#{view}.html.erb"
    end
  end

  test "generates API-only feature" do
    run_generator ["order", "--api"]

    assert_file "app/models/order.rb"
    assert_no_directory "app/views/orders"
  end

  test "skips model when requested" do
    run_generator ["order", "--skip-model"]

    assert_no_migration "db/migrate/create_orders.rb"
    assert_file "app/controllers/orders_controller.rb"
  end

  test "generates a mailer only when the flag is given" do
    run_generator ["order"]
    assert_no_file "app/mailers/order_mailer.rb"

    prepare_destination
    run_generator ["order", "--mailer"]
    assert_file "app/mailers/order_mailer.rb"
  end

  test "merges namespaced routes into one block across runs" do
    run_generator ["widget", "--namespace=admin"]
    run_generator ["gadget", "--namespace=admin"]

    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan(/namespace :admin do/).size
      assert_match(/resources :widgets/, content)
      assert_match(/resources :gadgets/, content)
    end
  end
end
```

`assert_no_directory` is a built-in — `Rails::Generators::Testing::Assertions` defines twelve assertions, not
the five usually quoted: `assert_file`, `assert_no_file`, `assert_directory`, `assert_no_directory`,
`assert_migration`, `assert_no_migration`, `assert_initializer`, `assert_method`, `assert_class_method`,
`assert_instance_method`, `assert_field_type`, `assert_field_default_value`. Enumerated from the module in
railties 8.1.3.1.

The two tests worth keeping past the first review are the flag test and the routes test: one catches an option
no method reads, the other catches a hand-written `namespace do` string. Both are failure modes that produce
plausible-looking output rather than an error.
