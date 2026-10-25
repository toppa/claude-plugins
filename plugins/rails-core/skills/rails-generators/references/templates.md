# ERB Template Patterns for Rails Generators

Comprehensive guide to writing ERB templates (`.tt` files) for Rails generators.

## Table of Contents

- [Template Basics](#template-basics)
- [Available Variables](#available-variables)
- [Whitespace Control](#whitespace-control)
- [Escaping for Nested ERB](#escaping-for-nested-erb)
- [Conditional Blocks](#conditional-blocks)
- [Iteration Patterns](#iteration-patterns)
- [Advanced Template Patterns](#advanced-template-patterns)

## Template Basics

Generator templates use the `.tt` extension and are processed with ERB:

```erb
# templates/service.rb.tt
class <%= class_name %>Service
  def call
    # Implementation
  end
end
```

Templates have access to all generator instance variables and methods.

## Available Variables

### From NamedBase

| Variable | Input: `payment_processor` | Description |
|----------|---------------------------|-------------|
| `name` | `payment_processor` | Raw argument |
| `class_name` | `PaymentProcessor` | CamelCase |
| `file_name` | `payment_processor` | snake_case |
| `singular_name` | `payment_processor` | Singular |
| `plural_name` | `payment_processors` | Plural |
| `table_name` | `payment_processors` | DB table |
| `human_name` | `Payment processor` | Human-readable |
| `class_path` | `[]` | Module nesting array |
| `file_path` | `payment_processor` | Path with modules |

### From Options

Access `class_option` values via `options[:option_name]`:

```erb
<%- if options[:namespace] -%>
module <%= options[:namespace].camelize %>
<%- end -%>
  class <%= class_name %>Service
  end
<%- if options[:namespace] -%>
end
<%- end -%>
```

### Custom Variables

Set instance variables in the generator for template access:

```ruby
# In generator
def create_service
  @custom_var = compute_something
  template 'service.rb.tt', destination
end
```

```erb
# In template
class <%= class_name %>Service
  CUSTOM = "<%= @custom_var %>"
end
```

## Whitespace Control

### Suppressing Whitespace

- `<%-` suppresses leading whitespace (indentation before the tag)
- `-%>` suppresses trailing newline

```erb
# Without whitespace control (produces blank lines):
<% if options[:async] %>
  def self.call_later(...) = <%= class_name %>Job.perform_later(...)
<% end %>

# With whitespace control (clean output):
<%- if options[:async] -%>
  def self.call_later(...) = <%= class_name %>Job.perform_later(...)
<%- end -%>
```

### Output Tags

| Tag | Behavior |
|-----|----------|
| `<%= expr %>` | Output expression result |
| `<% code %>` | Execute code, no output |
| `<%# comment %>` | Comment, not in output |
| `<%- code -%>` | Execute with whitespace suppression |

## Escaping for Nested ERB

When a generator template produces a file that itself contains ERB (e.g., Rails views), escape the ERB tags:

```erb
# Template that generates a view file:
<h1><%= class_name.pluralize %></h1>

<%# This will be evaluated at generation time: %>
<%- attributes.each do |attr| -%>
<p><%= attr.human_name %></p>
<%- end -%>

<%# This will appear as literal ERB in the generated file: %>
<%%= render partial: 'form', locals: { <%= singular_name %>: @<%= singular_name %> } %>
<%%= @<%= singular_name %>.name %>
```

Escaping rules:
- `<%%` outputs a literal `<%` in the generated file
- `%%>` is NOT needed; use regular `%>` after `<%%`
- Only the opening tag needs escaping

## Conditional Blocks

### Simple Conditions

```erb
<%- if options[:result_object] -%>
  <%= class_name %>Result.success(data: nil)
<%- else -%>
  true
<%- end -%>
```

### Multiple Conditions

```erb
<%- case options[:pattern] -%>
<%- when 'command' -%>
class <%= class_name %>Command
<%- when 'interactor' -%>
class <%= class_name %>Interactor
<%- else -%>
class <%= class_name %>Service
<%- end -%>
```

### Conditional Sections

```erb
<%- if options[:callbacks] -%>
  include ActiveSupport::Callbacks
  define_callbacks :call
<%- end -%>
```

**Use `if`/`end` in templates; a bare `return` produces an empty file.** ERB evaluates the template in the
caller's binding, so `return` abandons the render and Thor writes the buffer as it stands. Measured against
Rails 8.1.3.1 / Thor 1.5.0: a `.tt` containing `<% return %>` produced a **0-byte file**, no exception, no
warning, exit status 0, and the generator's remaining methods all ran. That is harder to diagnose than a
raise, because the only symptom is a file that looks like it was never written to.

## Iteration Patterns

### Attribute Iteration

```erb
def initialize(<%= attributes.map(&:name).join(', ') %>)
  <%- attributes.each do |attr| -%>
  @<%= attr.name %> = <%= attr.name %>
  <%- end -%>
end
```

### Array Option Iteration

```erb
<%- if options[:dependencies].any? -%>
def initialize(<%= options[:dependencies].map { |d| "#{d}:" }.join(', ') %>)
  <%- options[:dependencies].each do |dep| -%>
  @<%= dep %> = <%= dep %>
  <%- end -%>
end
<%- end -%>
```

### Indexed Iteration

```erb
<%- attributes.each_with_index do |attr, index| -%>
<%= ',' unless index == 0 %> :<%= attr.name %>
<%- end -%>
```

## Advanced Template Patterns

### Module Nesting

Handle arbitrary nesting depth:

```erb
<%- class_path.each do |mod| -%>
module <%= mod.camelize %>
<%- end -%>
  class <%= class_name %>
  end
<%- class_path.reverse.each do |_mod| -%>
end
<%- end -%>
```

### Attribute Type Mapping

```erb
<%- attributes.each do |attr| -%>
<%- case attr.type -%>
<%- when :string, :text -%>
  validates :<%= attr.name %>, length: { maximum: 255 }
<%- when :integer, :float, :decimal -%>
  validates :<%= attr.name %>, numericality: true
<%- when :boolean -%>
  validates :<%= attr.name %>, inclusion: { in: [true, false] }
<%- end -%>
<%- end -%>
```

`inclusion: { in: [true, false] }` is the right check for a boolean because `presence: true` rejects
`false` — a boolean column with a presence validation can only ever hold `true`.

**Generator attribute types are not Active Model attribute types.** `attr.type` returns whatever the user
typed — `:text`, `:references`, `:digest`, `:json`, `:jsonb`, `:uuid` are all valid generator types — and
`ActiveModel::Attributes` registers none of them. Measured: `attribute :body, :text` raises
`ArgumentError: Unknown type :text`, as do `:digest`, `:references` and `:json`. A template that emits an
`ActiveModel` attribute has to map first:

```ruby
# In the generator
ACTIVE_MODEL_TYPES = {
  text: :string, citext: :string, digest: :string, token: :string,
  json: :string, jsonb: :string, uuid: :string,
  references: :integer, belongs_to: :integer, primary_key: :integer,
  bigint: :big_integer, timestamp: :datetime
}.freeze

def active_model_type(attr)
  ACTIVE_MODEL_TYPES.fetch(attr.type, attr.type)
end
```

```erb
<%- attributes.each do |attr| -%>
  attribute :<%= attr.name %>, :<%= active_model_type(attr) %>
<%- end -%>
```

Verified: each mapped type is accepted by `ActiveModel::Attributes`.

### Helper Methods in Templates

Define private methods in the generator and call them from templates:

```ruby
# In generator
private

def dependency_params
  options[:dependencies].map { |dep| "#{dep}:" }.join(', ')
end
```

```erb
# In template
def initialize(<%= dependency_params %>)
```

This is cleaner than embedding complex logic directly in templates.
