---
name: inertia-rails-testing
description: >-
  Request specs for a controller whose response is a JSON page object rather than HTML —
  the `inertia` helper and its matcher set (`render_component`, `have_props`, `have_flash`,
  `have_deferred_props`), the `follow_redirect!` rule after a post-redirect-get, and the
  partial-reload helpers.
when_to_use: >-
  Use when you write or review a request spec for a controller action whose response body
  is a page object rather than HTML, so `include` and `assert_select` do not apply — when
  you assert on props or flash, when a spec passes against the redirect rather than
  against the page, when the `inertia` helper reads `nil` or a matcher is undefined, or
  when a feature has no spec file yet and its controller calls
  `render inertia:`. Rails-side only; it says nothing about React component tests.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-testing/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, rspec-rails 8.0.4, rspec-expectations 3.13.5,
    rspec-mocks 3.13.8, Rails 8.1.3.1
---

# Inertia Rails Testing

Request specs for controllers that render Inertia responses. The response body is a JSON
page object, so `assert_select` and `expect(response.body).to include(...)` have nothing to
match — you assert against the page through the `inertia` helper instead.

**For each controller action, verify:**
- **Correct component** → `render_component('users/index')`
- **Expected props** → a literal value, or a block: `have_props { |props| ... }`
- **No leaked data** → `have_no_prop(:secret)`
- **Flash messages** → `follow_redirect!`, then `have_flash(notice: '...')`
- **Deferred props** → `have_deferred_props(:analytics)`

**Call `follow_redirect!` after a post-redirect-get.** Without it you assert against the
302, not against the Inertia page that follows.

## Setup

```ruby
# spec/rails_helper.rb
require 'inertia_rails/rspec'
```

That one line is enough: `rspec.rb:69-84` runs its own `RSpec.configure`, installing the
helpers, the matchers, and a `before(:suite)` hook that patches the renderer. There is no
configuration block to write and no `inertia: true` metadata flag to add — that flag is
deprecated at 3.22.0.

Two further requirements, both outside the gem:

- **The example group must be `type: :request`.** The helpers are included into request
  specs only. `rspec-rails` 8.0.4 ships `infer_spec_type_from_file_location!` commented out
  in the generated `rails_helper.rb`, so either uncomment it and put the file under
  `spec/requests/`, or write the metadata: `RSpec.describe 'Users', type: :request do`.
- **Check `config.always_include_errors_hash` in the Inertia initializer.** The install
  generator writes `true` (`install/templates/initializer.rb:6`), which is what you want:
  every response then carries an `errors` hash, empty when there is nothing wrong, so
  `inertia.props[:errors]` is always there to read. An app that predates the generator may
  be on the gem default `nil` (`configuration.rb:53`) — and `nil` logs a 4.0 deprecation
  warning on every render with no errors (`controller.rb:151-158`), which floods a spec run.
  Set it either way.

## RSpec Matchers

Every matcher in the table below takes the `inertia` helper, not Rails' `response`. Rails'
own matchers still take `response`, and the examples further down use `redirect_to`,
`have_http_status` and a header read that way.
`validate_inertia_response` fails with "Use the `inertia` helper instead of passing the
response directly" if you write `expect(response).to be_inertia_response` — the gem added
that guard because the mistake is common.

| Matcher | Purpose |
|---------|---------|
| `be_inertia_response` | Verify the response is an Inertia page |
| `render_component('path')` | Check the rendered component name |
| `have_props(key: value)` | Partial props match, by value equality |
| `have_props { \|props\| ... }` | Partial props match, by a predicate block |
| `have_exact_props(key: value)` | Exact props match |
| `have_no_prop(:key)` | Assert a prop key is absent |
| `have_flash(key: value)` | Partial flash match |
| `have_exact_flash(key: value)` | Exact flash match |
| `have_no_flash(:key)` | Assert a flash key is absent |
| `have_deferred_props(:key)` | Check deferred props are registered |
| `have_view_data(key: value)` | Partial view_data match |

`inertia` is `nil` until an Inertia render happens in the current example. A request that
302s, or that lands on an action rendering ERB, leaves it `nil`, and `have_props` then
fails with "expected props to be present" — that is the signal to check the response
status, the authentication callbacks, and whether the action really calls
`render inertia:`.

## Asserting on props — the two forms that work, and the one that composes

`have_props` compares each expected value with `==`, and the **actual** value is the
receiver: `expected_sym.all? { |k, v| actual_sym[k] == v }` (`testing.rb:91`). RSpec and
rspec-mocks matchers implement `===`, not `==`, so a matcher in a `have_props` value
position always compares `false`. Two forms work:

```ruby
# A literal value — string and symbol keys are both fine, at any depth
expect(inertia).to render_component('users/index')
expect(inertia).to have_props(users: [1, 2, 3])
expect(inertia).to have_props(errors: { name: ["can't be blank"] })

# A predicate block, for anything that is not an exact value
expect(inertia).to have_props { |props| props[:users].length == 3 }
```

**Use braces for the block form.** `do ... end` binds the block to `to` rather than to
`have_props`, and the matcher then raises `NoMethodError: undefined method
'deep_symbolize_keys' for nil`.

For a partial or structural assertion, read `inertia.props` and use ordinary matchers.
This is what composes with the rest of RSpec, so reach for it whenever the block form
would just re-implement a matcher you already have:

```ruby
expect(inertia.props[:users]).to contain_exactly(1, 2, 3)
expect(inertia.props[:users].first).to include('name' => 'Ada')
expect(inertia.props[:errors]).to include('name')
```

Note the shape of an errors prop: `errors.to_hash` yields `{ name: ["can't be blank"] }`, so
every value is an **array** of messages, not a string. And under the generated
`always_include_errors_hash = true` the key is present on every response, so the assertion
for "this page has no errors" is `expect(inertia.props[:errors]).to be_empty`, not
`have_no_prop(:errors)`.

## Request Spec Examples

```ruby
RSpec.describe 'Users', type: :request do
  # Sign in through the app's own endpoint, so the spec exercises the real session.
  # The Rails 8.1 authentication generator writes no RSpec sign-in helper.
  let(:user) { create(:user, password: 'secret123') }

  before { post session_path, params: { email_address: user.email_address, password: 'secret123' } }

  it 'renders the index with the users prop' do
    create(:user, name: 'Ada')

    get users_path

    expect(inertia).to render_component('users/index')
    expect(inertia.props[:users].map { |u| u['name'] }).to include('Ada')
  end

  it 'redirects with flash on success' do
    post users_path, params: { user: { name: 'Ada', email: 'ada@example.com' } }

    expect(response).to redirect_to(users_path)
    follow_redirect!
    expect(inertia).to have_flash(notice: 'User created!')
  end

  it 'returns validation errors on failure' do
    post users_path, params: { user: { name: '' } }

    expect(response).to redirect_to(new_user_path)
    follow_redirect!
    expect(inertia.props[:errors]).to include('name')
  end
end
```

The failure case redirects rather than re-rendering, which is what the gem's scaffold
generator writes — so `follow_redirect!` is what puts the `errors` prop in reach.

### Test Shared Props

Shared props from `inertia_share` land in `inertia.props` alongside the action's own.

```ruby
it 'includes shared auth data' do
  get dashboard_path

  expect(inertia.props[:auth]['user']).to include('id' => user.id)
end
```

For the unauthenticated case, remember that the Rails 8.1 authentication concern applies
`before_action :require_authentication` to every controller. Unless the action opts out
with `allow_unauthenticated_access`, an unauthenticated request is a 302 that never reaches
a renderer, so assert on the redirect:

```ruby
it 'sends anonymous visitors to sign in' do
  get dashboard_path

  expect(response).to redirect_to(new_session_path)
  expect(inertia).to be_nil
end
```

### Test Deferred and Optional Props

A deferred prop is **absent** from the initial render, listed under `deferredProps`. It is
not `nil` — `props[:analytics]` only reads as `nil` because `props` is a
`HashWithIndifferentAccess` and the key is missing. So `have_props(analytics: nil)` passes
on any absent key, while `have_no_prop` says what you mean:

```ruby
it 'defers expensive analytics data' do
  get dashboard_path

  expect(inertia).to have_no_prop(:analytics)
  expect(inertia).to have_deferred_props(:analytics, :statistics)
  expect(inertia).to have_deferred_props(:slow_data, group: :slow)
end
```

An optional prop is absent too, and unlike a deferred one it is not advertised anywhere in
the page. Resolve either kind by requesting it with a partial reload, or by switching on
`InertiaRails::Testing.evaluate_optional_props`, which makes the resolver keep both kinds on
a full render (`testing.rb:16-26`). That setting is a `mattr_accessor`, so scope it to the
group that needs it:

```ruby
context 'with optional props resolved' do
  around do |example|
    InertiaRails::Testing.evaluate_optional_props = true
    example.run
  ensure
    InertiaRails::Testing.evaluate_optional_props = false
  end

  it 'computes the export when asked' do
    get users_path

    expect(inertia.props[:export_data]).to be_present
  end
end
```

### Partial Reload Helpers

Each of these issues a **fresh HTTP GET** on `request.fullpath` with the partial-reload
headers set (`testing.rb:203-227`), so each one discards the previous response and re-runs
the action. Use one per example, after a request that established the component:

```ruby
it 'sends only the requested props on a partial reload' do
  get users_path

  inertia_reload_only(:users, :pagination)

  expect(inertia).to have_no_prop(:expensive_stats)
  expect(inertia.props.keys).to include('users', 'pagination')
end

it 'resolves deferred props when the client asks for them' do
  get dashboard_path

  inertia_load_deferred_props        # every group; pass a group name for just one

  expect(inertia.props[:analytics]).to be_present
end
```

`inertia_reload_except(:expensive_stats)` is the complement. All three need a prior request
on a GET page, because they read `inertia.component` and re-issue `request.fullpath`.

### Test External Redirects (`inertia_location`)

```ruby
it 'redirects to Stripe via inertia_location' do
  post checkout_path

  # inertia_location returns 409 with an X-Inertia-Location header
  expect(response).to have_http_status(:conflict)
  expect(response.headers['X-Inertia-Location']).to match(/stripe\.com/)
end
```

## What to assert, and where

- **Your controller's decisions** — the component, the prop keys and their shape, which
  props are deferred, the redirect target, the flash. Leave the framework alone: that
  `<Form>` sends a CSRF token and that `router.visit` navigates are Inertia's own tests.
- **The prop shape, not the whole payload.** A block or a targeted `inertia.props[...]`
  assertion survives adding a column; `have_exact_props` on full JSON does not.
- **Flash and props after `follow_redirect!`**, never against the 302 itself.
- **Deferred props by registration** (`have_deferred_props`) or by resolving them
  (`inertia_load_deferred_props`), not by reading a value that is deliberately absent.
- **Through a `type: :request` spec.** `assigns` is not defined in rspec-rails 8.0.4 at
  all — it moved to `rails-controller-testing`, which is not installed. And the
  partial-reload helpers call `get request.fullpath`, an integration-only API, so they
  cannot work in a controller spec either.

## Direct Access

```ruby
inertia.component       # => 'users/index'
inertia.props           # => { 'users' => [...] }   (HashWithIndifferentAccess)
inertia.props[:users]   # a prop, ready for any ordinary RSpec matcher
inertia.flash           # => { 'notice' => 'Created!' }
inertia.deferred_props  # => { 'default' => ['analytics'], 'slow' => ['report'] }
```

`flash` is a top-level key on the page object, a sibling of `props` — which is why it has
its own matcher and why `have_props(flash: ...)` will not find it.

## Related Skills
- **Prop types, `inertia_share`, flash config, the redirect-after-write rule** →
  `inertia-rails-controllers`
- **Form submission and error display** → `inertia-rails-forms`
- **Reading props and flash inside the page component** → `inertia-rails-pages`
