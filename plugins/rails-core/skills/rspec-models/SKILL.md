---
name: rspec-models
description: >-
  What an RSpec model spec covers — the model's own methods, non-trivial scopes,
  important callbacks, declarations you configured, and the database constraints
  behind them — and what Rails already guarantees, so the spec skips it. Also
  names the behavior that belongs in a request spec or a system spec instead.
when_to_use: >-
  Use when you write or review a spec under `spec/models/`, and when you add a
  model with its factory. Also use it when the user asks which kind of spec a
  behavior belongs in, or asks for tests for a feature that has no spec file yet.
  This skill owns that question in general; Rule 1's table gives one row per
  response mode, and hands an Inertia page's assertions to the
  `inertia-react:inertia-rails-testing` skill.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here so it travels with the Rails work. The
    spec-type routing section was lifted from the rejected ai-context `rspec`
    skill; see docs/adr/0005-rails-core-takes-16-of-33-upstream-skills.md in
    the claude-plugins repository.
  synced: 2026-08-10
  verified_against: rspec-rails 8.0.4, rspec-core 3.13.6, Rails 8.1.3.1 (activerecord), Ruby 3.4.5
---

# RSpec model spec conventions

## Rule 1: Pick the spec type before you pick the examples

The behavior decides which spec you open.

| Behavior | Spec type |
|---|---|
| Data, validations, associations, scopes, and the model's own methods | Model spec |
| An HTTP route, authorization, a status code | Request spec |
| What an action renders under **Hotwire** — the ERB template and the markup it emits | Request spec; a view spec where the template carries its own logic |
| What an action renders under **Inertia** — the page and the props it sends | Request spec, with the matchers in the `inertia-react:inertia-rails-testing` skill |
| What an action renders under **JSON API** — the response body and its shape | Request spec |
| A user workflow across pages, JavaScript | System spec |

Only one of the three mode rows applies in a given project, because a project renders in
one mode. The `rails-core:rails-architecture` skill settles which mode, in its "Response
mode" section. Run that check before you pick a row.

Business logic that has moved out of the model belongs to the spec of whatever now
owns it — a service spec for a service, a query-object spec for a query. The
`rails-core:extraction-timing` skill decides when it moves; this skill covers what
stays in the model.

For a layer these rows do not name — a policy, a presenter, a mailer, a job — use the
`rails-core:rails-architecture` skill, which maps a layer to its spec type in its
testing-strategy reference, under "The Layer-to-Spec-Type Map". Mailer and job specs are
rows in that map. A concern is the layer with no row: its specs are the including model's,
so they are this skill's. That skill decides which spec type a layer gets; this skill decides
what earns an example once you are in a model spec.

## Rule 2: Test the logic you wrote

Write examples for:

- A custom method that carries logic you wrote
- A scope whose query is non-trivial — it filters on more than one column, joins,
  orders, takes an argument, or depends on the current time
- A callback that performs an important operation
- A class method that orchestrates behavior
- A declaration you configured, where the configuration is the thing that can be
  wrong: `normalizes :email_address, with: ->(e) { e.strip.downcase }` earns an
  example on a value that needs both halves of the lambda, such as `' USER@X.COM '`
- A `dependent:` option whose choice matters to the domain, since `:destroy`,
  `:nullify`, and `:restrict_with_error` are three different product decisions

Skip examples for:

- A standard Rails validation, such as `validates :name, presence: true`. Such an
  example confirms that Rails works, which Rails already establishes.
- Rails-provided behavior, such as an association existing
- A trivial delegation or alias

**Two exceptions.** A validation that carries custom business logic beyond a standard
Rails validator earns an example, because you wrote the logic.

**Uniqueness earns an example.** Rails documents that
`validates :email_address, uniqueness: true` "does not guarantee the absence of
duplicate record insertions, because uniqueness checks on the application level are
inherently prone to race conditions" (activerecord 8.1.3.1,
`lib/active_record/validations/uniqueness.rb:228-236`) and recommends a unique index
as well. So the example worth writing asserts the constraint the database enforces:

```ruby
it 'refuses a duplicate email address at the database level' do
  create(:user, email_address: 'user@example.com')
  duplicate = build(:user, email_address: 'user@example.com')

  expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
end
```

`save(validate: false)` is what aims the example at the index rather than at the
validation, so it passes on a model that has the index and no validator, which is what
Rails 8's own generators write.

The same holds for the other constraints the schema carries — `null: false`, a check
constraint, a foreign key. A model spec is where a reader learns which guarantees are
the database's, and those are the ones that survive a race.

## Rule 3: A factory example for a new model

When you add a model with its factory, include this baseline:

```ruby
RSpec.describe MyModel, type: :model do
  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:my_model)).to be_valid
    end
  end
end
```

It confirms the factory is configured, and it fails loudly when a later migration
adds a constraint the factory does not satisfy.

**Check `rails_helper.rb` first. Where it does not enable
`config.infer_spec_type_from_file_location!`, state `type: :model` in every model
spec**, as the example above does. rspec-rails 8.0.4 generates that line commented
out and describes it as legacy
(`lib/generators/rspec/install/templates/spec/rails_helper.rb:78-85`). On a freshly
generated project the spec's own metadata is the only thing that supplies the type.

A project that uncomments the line gets the same behaviour from the file's location
under `spec/models/`, so the metadata is redundant there. It also inherits the
removal RSpec announces in that comment. When the config goes, a spec with no
metadata loses the type in silence, and the leak below is what it loses.

What the type buys, verified against rspec-rails 8.0.4 on Rails 8.1.3.1: it includes
`RSpec::Rails::RailsExampleGroup`, which resets `ActiveSupport::CurrentAttributes`
and the execution context between examples. Without the type, a `Current.session` set
in one example is still set in the next one. Metadata-scoped configuration —
`config.before(:each, type: :model)` — is likewise inert without it. Record rollback
is the one thing that survives the omission on 8.0.4, because
`RSpec::Rails::FixtureSupport` is still included into every example group
(`lib/rspec/rails/configuration.rb:82`), and that file marks the global inclusion
deprecated in the same breath.
