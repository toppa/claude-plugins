---
name: rails-architecture
description: Rails 8 layer architecture — what each layer owns, and the order to build a new feature in. Covers controllers, models, services, queries, concerns, presenters, policies, components, jobs, forms, mailers, and channels.
when_to_use: >-
  Use when designing the architecture of a feature, when deciding which layer a
  responsibility belongs to, when the user mentions architecture, layered design,
  or code organization. Also use it when the user wants a custom generator or a Rails
  application template that scaffolds a whole feature: this skill states the build order
  such a generator writes, and its New Feature Checklist names the generator skill the
  user can invoke. For the numeric thresholds that trigger an extraction, use the
  extraction-timing skill. Use it also to settle which of the three response modes —
  Hotwire, Inertia, or JSON API — a project renders in: its "Response mode" section holds
  the ordered check that every other skill points at. This skill owns which layer a
  controller action delegates to and how thin it stays; for the code inside an action that
  renders an Inertia page — the prop wrappers, the serialization convention, the redirect
  that carries errors — use the `inertia-react:inertia-rails-controllers` skill.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/rails-architecture/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against:
    - rails 8.1.3.1 (activerecord, activemodel, actionpack, actionmailer, activejob)
    - ruby 3.4.5
    - rspec-rails 8.0.4
    - inertia_rails 3.22.0
---

# Modern Rails 8 Architecture Patterns

## Response mode

A Rails 8 application answers a browser in one of three ways, and a rule that is right in one
mode is wrong in another. The three modes are **Hotwire**, **Inertia**, and **JSON API**. Run
this check once per project. Stop at the first step that matches.

1. `config.api_only = true` in `config/application.rb`, or an `ApplicationController` that
   inherits from `ActionController::API` → **JSON API**
2. `inertia_rails` in the `Gemfile` → **Inertia**
3. `turbo-rails` in the `Gemfile`, **and** an `.html.erb` under `app/views` outside
   `layouts/`, `*_mailer/` and `pwa/` → **Hotwire**
4. Otherwise → **JSON API**

Step 4 can match while `app/views` still holds a page template outside `layouts/`,
`*_mailer/` and `pwa/`. Ask the user which mode the project is.

Every skill in this plugin that branches on the mode names this section. Run the check first,
then apply the branch it names.

## Layer Responsibilities

Each layer owns one thing; code that reaches past what its layer owns moves to the layer
that owns it. This table is the answer to "where should this code go?" — read it by layer, or
ask `extraction-timing` whether the code has grown enough to move at all.

| Layer | Owns |
|-------|------|
| **Controller** | The HTTP request and response: params, status, redirect or render |
| **Model** | Data, validations, associations, and scopes over its own table |
| **Service** | Business logic and orchestration across models |
| **Query** | One complex read, returned as a relation or a hash of results |
| **Concern** | Behavior several models share as a property of each — soft-delete, slugs, search |
| **Presenter** | View formatting for a server-rendered view — badges, dates, labels. Under Inertia and JSON API there is no such view, so a private `serialize_x` in the controller shapes the response instead; that is what the `inertia_rails` scaffold generates |
| **Policy** | Authorization rules for one record or scope |
| **Component** | A reusable piece of UI and the logic to render it |
| **Job** | Work moved off the request |
| **Form** | Input from a form that spans several models, and its validations |
| **Mailer** | Composing one email |
| **Channel** | WebSocket subscriptions and broadcasts |

## What Needs a Gem

Four things this skill's examples use are gems rather than Rails, and none of them is
installed by `rails new`. Check the `Gemfile` before writing one, and leave adding a gem to
a shared project to the user.

| For | Gem | Without it |
|-----|-----|------------|
| Policy | `pundit` | Write the policy as a PORO and call it explicitly: `EventPolicy.new(current_user, @event).update?`. `authorize` and `policy` are Pundit's helpers, not Rails'. |
| Component | `view_component` | Render a partial. |
| Pagination | `kaminari` or `pagy` | `limit` and `offset`, from a `page` param the controller reads. |
| Factories in specs | `factory_bot_rails`, `faker` | `Model.create!` in the example itself. |

## When to keep it simple

| Situation | Keep it simple |
|-----------|----------------|
| CRUD under the extraction-timing threshold | Keep it in the controller |
| Used only once | Inline the code |
| Simple query on one table | Model scope |
| Basic text formatting | Helper method |
| Single model form | `form_with model:` |
| Logic-free partial | Partial |

**For when TO abstract, use the `extraction-timing` skill.**

## Core Patterns

### Skinny Controllers

The controller calls one collaborator and chooses a response. **Which failure response is
correct depends on the project's response mode**, so run the check in the "Response mode"
section above first.

**Hotwire — there is an `app/views/orders/new.html.erb` to render:**

```ruby
class OrdersController < ApplicationController
  def new
    @order = Order.new
  end

  def create
    result = Orders::CreateService.call(user: current_user, params: order_params)

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      @order = Order.new(order_params)
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_content
    end
  end

  private

  def order_params
    params.expect(order: [:note, :ship_by])
  end
end
```

The failure branch re-assigns everything `#new` assigned. `render :new` runs the same
template with none of `#new`'s setup, so a missing `@order` raises on `form_with model:
@order` and an empty one discards what the user typed.

**Inertia — the page lives in `app/frontend/pages` and there is no ERB template.** The
failure branch redirects and carries the errors as a prop; `render :new` raises
`ActionView::MissingTemplate`, so the same action ends:

```ruby
else
  redirect_to new_order_path, inertia: { errors: result.details }
end
```

Working from a record rather than a service, that value is `@order.errors`, the gem's own
scaffold form; the gem calls `to_hash` on whatever it is given, so both work.

**JSON API — the client reads the response body. There is no ERB template and no Inertia
page.** The failure branch renders the errors and keeps the same status:

```ruby
else
  render json: { errors: result.details }, status: :unprocessable_content
end
```

`details` is the Result member that carries client-safe field-level messages, described under
"Result Objects for Services" below. Working from a record rather than a service, that value
is `@order.errors`.

For which write redirects take an explicit `status:` in each mode, and which form of strong
parameters an action needs, use the `rails-8-idioms` skill's "Redirect status codes" and "Strong
parameters: pick the form from the shape of the incoming params" sections. For the props contract, the
error shape and the `serialize_x` convention, the `inertia-rails-controllers` skill in the
`inertia-react` plugin owns them, in its "Prop Types", "Redirects & Validation Errors", and
"Serializing Props" sections.

### Result Objects for Services

All services return one Result. Five members, each with one job:

```ruby
# app/services/result.rb
Result = Data.define(:success, :data, :error, :code, :details) do
  def self.success(data = nil) = new(success: true, data: data, error: nil, code: nil, details: nil)

  def self.failure(error, code: :error, details: nil)
    new(success: false, data: nil, error: error, code: code, details: details)
  end

  def success? = success
  def failure? = !success
end
```

`data` is the success payload; `error` is one message a user can read; `code` is what the
caller branches on; `details` carries client-safe extras such as field-level messages, so
that an error response has somewhere to read from that is never the success payload.

Build with the two class methods — `Data`'s keyword constructor requires all five members.
`Data` also supplies `deconstruct_keys`, so `case result in { code: :empty_cart }` works
with no extra code.

### Multi-Tenancy by Default

```ruby
def index
  @events = current_account.events.recent
end
```

Reach through the tenant on writes as well as reads. Ids arriving from params name records
the current user may not own, so resolve them through the tenant before attaching them:
`account.vendors.where(id: vendor_ids)`.

## Rails 8 Specific Features

Rails 8 ships Solid Queue, Solid Cache, Solid Cable, Propshaft, and Kamal 2 with Thruster.
`rails-8-idioms` states where each of those five is configured and where it is switched on, in
its "Infrastructure" table, along with the rest of the Rails 8.1 API surface. Three have a skill
of their own: a job's structure is `solid-queue-setup`'s, cache key design is `caching-strategies`', and what
`bin/rails generate authentication` creates is `authentication-flow`'s.

## Testing Strategy by Layer

The map from a layer to its spec type is a table in
[testing-strategy.md](references/testing-strategy.md) (~713 lines), which also holds a worked
example per row. Concern is the one layer above with no row of its own, because a concern is
tested through the specs of the models that include it. Model specs are the one row with an outside authority: the `rspec-models` skill
states the full rule for what earns an example, in its "Rule 2: Test the logic you wrote" and
"Rule 3: A factory example for a new model" sections.

## New Feature Checklist

Build in this order.

1. **Migration and model** — define the data structure and its validations.
2. **Policy** — add the authorization rules before anything can call them.
3. **Service** — add one only if the logic clears the extraction-timing threshold.
4. **Query** — add one only for queries that clear the threshold.
5. **Controller** — keep it thin. It calls the service and renders.
6. **Presenter** — format for a server-rendered view under Hotwire. Under Inertia and JSON
   API, a private `serialize_x` in the controller shapes the response instead.
7. **Component** — build reusable UI, if the element repeats.
8. **Mailer** — add transactional email, if the feature sends any.
9. **Job** — move slow or external work off the request.

Where the same nine steps repeat feature after feature, the `rails-core:rails-generators`
skill writes a custom generator or a `rails new -m` application template that scaffolds them
in one command. It is user-invoked only, so name it for the user to run and carry on building
this feature by hand.

## References

- See [testing-strategy.md](references/testing-strategy.md) (~713 lines) for the layer-to-spec-type map and a worked spec per layer
- See [layer-interactions.md](references/layer-interactions.md) (~471 lines) for layer communication patterns
- See [service-patterns.md](references/service-patterns.md) (~318 lines) for service object patterns
- See [query-patterns.md](references/query-patterns.md) (~373 lines) for query object patterns
- See [error-handling.md](references/error-handling.md) (~345 lines) for error handling strategies
