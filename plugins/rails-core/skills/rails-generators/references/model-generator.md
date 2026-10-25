# Complete Model Generator Example

A custom model generator with migration, associations, enums and validations. Every generator and template
in this file was run against Rails 8.1.3.1 / Ruby 3.4.5 / PostgreSQL 17.10 in a throwaway app, and every
"Creates:" block is that run's actual output.

## Table of Contents

- [Generator Implementation](#generator-implementation)
- [Migration Template](#migration-template)
- [Model Template](#model-template)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Advanced Customizations](#advanced-customizations)
- [Checklist Specific to a Model Generator](#checklist-specific-to-a-model-generator)

## Generator Implementation

```ruby
# lib/generators/custom_model/custom_model_generator.rb
require 'rails/generators/active_record'

class CustomModelGenerator < Rails::Generators::NamedBase
  include ActiveRecord::Generators::Migration

  source_root File.expand_path('templates', __dir__)

  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  class_option :belongs_to, type: :string, desc: "Model this one belongs_to"
  class_option :superclass, type: :string, default: "ApplicationRecord",
    desc: "Base class (use for single-table inheritance)"
  class_option :has_many, type: :array, default: [], desc: "has_many associations"
  class_option :has_one, type: :array, default: [], desc: "has_one associations"
  class_option :required, type: :array, default: [],
    desc: "Attributes to validate for presence (space-separated)"
  class_option :enums, type: :hash, default: {},
    desc: "Enum definitions, e.g. --enums status:draft,published"
  class_option :timestamps, type: :boolean, default: true, desc: "Add timestamps"

  hook_for :test_framework, as: :model

  def create_model_migration
    migration_template 'migration.rb.tt',
      File.join('db/migrate', "create_#{table_name}.rb")
  end

  def create_model_file
    template 'model.rb.tt', File.join('app/models', class_path, "#{file_name}.rb")
  end

  private

  def migration_class_name
    "Create#{class_name.pluralize}"
  end

  def belongs_to_associations
    options[:belongs_to] ? [options[:belongs_to].underscore] : []
  end

  def required_attributes
    attributes.select { |attr| options[:required].include?(attr.name) }
  end

  def enum_values(csv)
    csv.split(',').map { |value| ":#{value.strip}" }.join(', ')
  end
end
```

Five things in that class are the difference between it running and doing what it says, each reproduced
against Rails 8.1.3.1:

- **`require 'rails/generators/active_record'` plus `include ActiveRecord::Generators::Migration`.**
  `Rails::Generators::Base` mixes in only `Thor::Actions` and `Rails::Generators::Actions`, so
  `migration_template` is otherwise a `NoMethodError`, and `Rails::Generators::Migration`'s own
  `next_migration_number` raises `NotImplementedError`. Without the `require`, the `include` itself fails
  with `uninitialized constant ActiveRecord::Generators`.
- **`create_model_migration`, not `create_migration`.** `migration_template`
  (`railties/lib/rails/generators/migration.rb:63`) calls the `create_migration` Thor action internally, so
  a public generator method by that name shadows it and the run dies with
  `ArgumentError: wrong number of arguments (given 3, expected 0)`.
- **`--required` replaces the `end_with?('?')` test that used to be here.** `GeneratedAttribute.parse`
  splits the argument on `":"`, so an attribute name can never end in `?` — a `reject { … end_with?('?') }`
  therefore selects *every* attribute, and with validations on by default the model gets `presence: true` on
  every column. On a boolean that is actively wrong: `presence: true` rejects `false`, so the column can
  only ever hold `true`. Rails' own `attr.required?` means something narrower — it is
  `reference? && belongs_to_required_by_default`, i.e. "this is a `belongs_to` that Rails will validate
  anyway" — so an explicit list is the honest way to express intent.
- **`type: :hash` and `type: :array` options are space-separated.** `--required title body` yields
  `["title", "body"]`; `--required=title,body` yields the single element `["title,body"]`. Measured both
  ways.
- **`--belongs_to` and `--superclass` are separate options.** One `--parent` cannot be both: used as the
  superclass it produces single-table inheritance, used as an association it produces `belongs_to`. Doing
  both from one flag generated `class OrderItem < Order` *with* `belongs_to :order` — an STI subclass that
  also references its own base table. Splitting them makes each intent sayable.

## Migration Template

```erb
# lib/generators/custom_model/templates/migration.rb.tt
class <%= migration_class_name %> < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :<%= table_name %> do |t|
      <%- attributes.each do |attribute| -%>
      t.<%= attribute.type %> :<%= attribute.name %>
      <%- end -%>
      <%- if options[:belongs_to] -%>
      t.references :<%= options[:belongs_to].underscore %>, null: false, foreign_key: true
      <%- end -%>
      <%- if options[:timestamps] -%>

      t.timestamps
      <%- end -%>
    end
    <%- attributes.select(&:has_index?).each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %>
    <%- end -%>
  end
end
```

Interpolating `ActiveRecord::Migration.current_version` is right *inside a generator*, where Active Record
is loaded — it returns `8.1` on this stack. In an **application template** the same expression raises
`NameError`, because `rails new` has not loaded Active Record; see
[application-templates.md](application-templates.md#common-gotchas).

`t.references :<belongs_to>, null: false, foreign_key: true` is safe only when the column name pluralizes to
the target table. For a self-referential or aliased reference — `invited_by` pointing at `users` — the
generated `foreign_key: true` looks for `invited_bies` and `db:migrate` aborts with
`PG::UndefinedTable`. Those columns need `foreign_key: { to_table: :users }`, which generator attribute
syntax cannot express; write them into the migration explicitly.

## Model Template

```erb
# lib/generators/custom_model/templates/model.rb.tt
class <%= class_name %> < <%= options[:superclass] %>
  <%- belongs_to_associations.each do |assoc| -%>
  belongs_to :<%= assoc %>
  <%- end -%>
  <%- options[:has_many].each do |assoc| -%>
  has_many :<%= assoc.underscore.pluralize %>
  <%- end -%>
  <%- options[:has_one].each do |assoc| -%>
  has_one :<%= assoc.underscore %>
  <%- end -%>
  <%- options[:enums].each do |attr, values| -%>
  enum :<%= attr %>, [ <%= enum_values(values) %> ]
  <%- end -%>
  <%- required_attributes.each do |attr| -%>
  validates :<%= attr.name %>, presence: true
  <%- end -%>
end
```

Two details:

- **`enum :status, [...]`, not `enum status: {...}`.** The legacy keyword form supplies zero positional
  arguments to `def enum(name, values = nil, **options)` and raises
  `ArgumentError: wrong number of arguments (given 0, expected 1..2)` **at class-definition time**, so the
  model cannot be loaded at all. Measured both forms; the positional form is accepted and
  `Article.statuses` reads `{"draft" => 0, "published" => 1}`.
- **No decorative section comments.** `# Associations`, `# Validations`, `# Scopes` are generated into the
  reader's application, where they restate what the next line already says — and then have to be deleted by
  hand. A generator's output is code someone maintains; hold it to the standard you would hold hand-written
  code to.

### Where soft deletes used to be

An earlier version of this file generated `default_scope { where(deleted_at: nil) }` plus three scopes and
three methods on every `--paranoid` model, unconditionally. That is removed rather than fixed, because
`default_scope` for soft deletion has costs a generator should not commit an application to by default:

- It leaks into every `has_many` read through the model, so a parent's association counts change meaning.
- `delete_all` and `update_all` bypass it, so bulk operations see deleted rows.
- **It silently defeats unique indexes** — a "deleted" row still occupies the index, so the email address of
  a deleted user cannot be reused.
- Every admin or audit path then needs `unscoped`, which is the same removal that makes tenant scoping
  unsafe elsewhere.

If an application wants soft deletion, that is a deliberate architectural decision for the team to make
once, with `discard` or `paranoia` or an explicit `kept` scope — not a flag on a model generator.

## Usage Examples

### Basic Model

```bash
rails generate custom_model Product name:string price:decimal sku:string:index --required name price
```

Creates:
```ruby
# db/migrate/20260812015304_create_products.rb
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.decimal :price
      t.string :sku

      t.timestamps
    end
    add_index :products, :sku
  end
end

# app/models/product.rb
class Product < ApplicationRecord
  validates :name, presence: true
  validates :price, presence: true
end
```

`sku` gets an index because of the `:index` suffix, and no presence validation because it is not in
`--required`. Every "Creates:" block in this file was produced by running the generator, not written by
hand — including the `[8.1]` version line, which comes from
`ActiveRecord::Migration.current_version` rather than a literal.

### Model with Associations

```bash
rails generate custom_model OrderItem \
  quantity:integer price:decimal \
  --belongs_to=Order --has_one Product --required quantity price
```

Creates:
```ruby
class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.integer :quantity
      t.decimal :price
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end
  end
end

class OrderItem < ApplicationRecord
  belongs_to :order
  has_one :product
  validates :quantity, presence: true
  validates :price, presence: true
end
```

Note `--has_one Product` with a space. `--has_one=Product,Widget` would arrive as the single element
`["Product,Widget"]` and generate `has_one :product,widget`.

### Model with an Enum

```bash
rails generate custom_model Article \
  title:string body:text status:integer sku:string:index \
  --required title --enums status:draft,published
```

Creates:
```ruby
class Article < ApplicationRecord
  enum :status, [ :draft, :published ]
  validates :title, presence: true
end
```

Verified by invocation and by loading the result: `Article.statuses` reads
`{"draft" => 0, "published" => 1}`.

The `--enums status:draft,published` form works because the **value** of a Thor hash option is an opaque
string that the generator splits itself; the *pairs* are what must be space-separated. Several enums is
`--enums status:draft,published tier:free,pro`.

### Scopes are deliberately not an option here

An earlier version of this file accepted `--scopes=published:published=true,recent:published_at>1.week.ago`
and split each entry on `":"` to build `scope :name, -> { where(<condition>) }`. That cannot work: the
split yields a raw condition *string*, so the template emitted `where(published=true)` — a local variable
assignment degrading to `where(true)` — and `where(published_at>1.week.ago)`, a `NameError`. No input
produces the hash or placeholder forms the documented output claimed.

A scope body is arbitrary Ruby, so there is no attribute syntax that captures it. Generate the model and
write the scopes, or ship a narrower option with an explicit vocabulary (`--boolean-scopes published
archived`) whose generated code you can predict.

## Testing

```ruby
# test/generators/custom_model_generator_test.rb
require 'test_helper'
require 'generators/custom_model/custom_model_generator'

class CustomModelGeneratorTest < Rails::Generators::TestCase
  tests CustomModelGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  test "generates basic model" do
    run_generator ["product", "name:string", "price:decimal"]

    assert_migration "db/migrate/create_products.rb" do |content|
      assert_match(/create_table :products/, content)
      assert_match(/t.string :name/, content)
      assert_match(/t.decimal :price/, content)
    end

    assert_file "app/models/product.rb" do |content|
      assert_match(/class Product < ApplicationRecord/, content)
      assert_match(/validates :name, presence: true/, content)
    end
  end

  test "generates model with a belongs_to" do
    run_generator ["order_item", "--belongs_to=Order", "quantity:integer"]

    assert_migration "db/migrate/create_order_items.rb" do |content|
      assert_match(/t.references :order, null: false, foreign_key: true/, content)
    end

    assert_file "app/models/order_item.rb" do |content|
      assert_match(/class OrderItem < ApplicationRecord/, content)
      assert_match(/belongs_to :order/, content)
    end
  end

  test "generates model with has_many associations" do
    run_generator ["user", "--has_many", "Post", "Comment", "name:string"]

    assert_file "app/models/user.rb" do |content|
      assert_match(/has_many :posts/, content)
      assert_match(/has_many :comments/, content)
    end
  end

  test "generates an enum from a hash option" do
    run_generator ["article", "title:string", "status:integer",
                   "--enums", "status:draft,published"]

    assert_file "app/models/article.rb" do |content|
      assert_match(/enum :status, \[ :draft, :published \]/, content)
    end
  end

  test "validates presence only for attributes named in --required" do
    run_generator ["product", "name:string", "sku:string", "--required", "name"]

    assert_file "app/models/product.rb" do |content|
      assert_match(/validates :name, presence: true/, content)
      refute_match(/validates :sku/, content)
    end
  end

  test "invokes the test-framework responder that is asked for" do
    run_generator ["product", "name:string", "--test-framework=test_unit"]

    assert_file "test/models/product_test.rb"
  end

  test "skips timestamps when option disabled" do
    run_generator ["product", "name:string", "--no-timestamps"]

    assert_migration "db/migrate/create_products.rb" do |content|
      refute_match(/t.timestamps/, content)
    end
  end
end
```

## Advanced Customizations

### JSON / JSONB columns with a default

```erb
<%- attributes.select { |a| %i[json jsonb].include?(a.type) }.each do |attr| -%>
t.<%= attr.type %> :<%= attr.name %>, default: {}
<%- end -%>
```

### UUID primary keys

```ruby
class_option :uuid, type: :boolean, default: false, desc: "Use UUID primary key"
```

```erb
create_table :<%= table_name %><%= ", id: :uuid" if options[:uuid] %> do |t|
```

### Selecting the spec directory without a hook

`hook_for :test_framework, as: :model` covers the model layer, because both railties and rspec-rails ship a
`model` responder. For a layer neither ships — services, queries, form objects — read the configured
framework instead of hardcoding a path:

```ruby
def create_spec_file
  if Rails::Generators.options[:rails][:test_framework] == :rspec
    template 'model_spec.rb.tt', "spec/models/#{file_name}_spec.rb"
  else
    template 'model_test.rb.tt', "test/models/#{file_name}_test.rb"
  end
end
```

Installing rspec-rails is enough to make that read `:rspec`; its railtie calls
`generators.test_framework :rspec` (`rspec-rails.rb:33`). Verified by invocation.

## Checklist Specific to a Model Generator

Generic model advice belongs to the `rails-core:rails-architecture` skill; what follows is the part that is
about *generating* models.

- [ ] `require 'rails/generators/active_record'` and `include ActiveRecord::Generators::Migration` are
      present, and no public method is named `create_migration`.
- [ ] The migration template interpolates `ActiveRecord::Migration.current_version` rather than a literal
      version.
- [ ] Any `:references` attribute whose column name does not pluralize to its table is written by hand with
      `foreign_key: { to_table: … }`.
- [ ] `enum` uses the positional form `enum :name, [...]`.
- [ ] Presence validations are opt-in, and no boolean column gets one.
- [ ] Array and hash options are documented as space-separated, and the tests exercise them that way.
- [ ] `attr.has_index?` drives `add_index`, so the `name:string:index` suffix users already know works.
- [ ] The generated files carry no section comments a maintainer would delete.
- [ ] A generator test asserts both the migration and the model, and covers `--test-framework=test_unit`
      and `--test-framework=rspec` via the CLI switch rather than by mutating configuration.
