---
name: inertia-rails-controllers
description: >-
  Rails controller patterns for Inertia responses — `render inertia:`, the prop types
  (`defer`, `optional`, `once`, `merge`, `always`, `scroll`), `inertia_share` for shared
  data, flash, post-redirect-get with keyed validation errors, and `inertia_location`
  for external URLs.
when_to_use: >-
  Use when you write or review a Rails controller that serves an Inertia page, when you
  specify or pass the props a page needs, when you redirect after a create, an update, or a
  delete, or when you send the user to an external URL such as a payment provider. This skill
  owns the code inside such an action; which layer the action delegates to, and how thin it
  stays, is the `rails-core:rails-architecture` skill's.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-controllers/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, "@inertiajs/react" 3.6.1, "@inertiajs/core" 3.6.1,
    Rails 8.1.3.1, Ruby 3.4.5, js-routes 2.4.1
---

# Inertia Rails Controllers

The props contract between a Rails action and an Inertia page: what to send, in which
wrapper, and where a write redirects.

**Five rules that settle most controller work:**
- Every prop reaches the page through an explicit `render inertia:` call, and every prop
  helper is a module method on the `InertiaRails` constant: `InertiaRails.defer { ... }`.
- Serialize the columns the page renders and nothing else — the initial page object ships
  inside the HTML document, so a prop is readable from view-source.
- Send validation errors as the keyed hash `@user.errors` and redirect to the page that
  holds the form.
- Send the user off-site with `inertia_location`, which answers 409 plus an
  `X-Inertia-Location` header.
- Let the middleware supply the 303 on a write redirect: `redirect_to users_path,
  notice: 'Created!'` carries the status the protocol wants on its own.

**Choosing a wrapper:** needed on every page → `inertia_share`; expensive to compute →
`InertiaRails.defer`; needed only on a partial reload → `InertiaRails.optional`; reference
data that rarely changes → `InertiaRails.once`; a list the client appends to →
`InertiaRails.merge`; infinite scroll → `InertiaRails.scroll`. The "Prop Types" section below
carries all ten forms, including `deep_merge`, `always` and `defer(group:)`.

## Render Syntax

| Situation | Syntax | Component path |
|-----------|--------|----------------|
| Action loads data | `render inertia: { users: serialized_users }` | Inferred from controller/action |
| Action loads no data | `render inertia: true` | Inferred from controller/action |
| Rendering a different page | `render inertia: 'errors/show', props: { error: e }` | Explicit path |

`render inertia: true` is the form the gem's own controller generator writes
(`inertia/controller/templates/controller.rb.tt:5`), and `renderer.rb:152` resolves the
component identically for `true` and for a props hash.

**Give every Inertia action an explicit render**, including the ones with no data. A bare
`def index; end` renders an Inertia page only when `config.default_render = true`, which
defaults to `false` (`configuration.rb:13`) and which the install generator does not set —
see the first two rows of Troubleshooting for how that fails.

**Instance variables are props only under `use_inertia_instance_props`**, a class method
that hands the renderer *every* view assign the action happened to set. Name the props you
mean instead. `config.default_render` is a separate setting: it infers the component name
and passes no data. Mechanism and citations: [`references/prop-types.md`](references/prop-types.md),
section "Instance variables as props".

## Prop Types

| Type | Syntax | Behavior |
|------|--------|----------|
| Regular | `{ key: value }` | Always evaluated, always included |
| Lambda | `-> { expensive_value }` | Included on the initial render; skipped on partial reloads that do not request it |
| Optional | `InertiaRails.optional { ... }` | Evaluated only on a partial reload that requests it |
| Defer | `InertiaRails.defer { ... }` | Fetched automatically after the initial render |
| Defer (grouped) | `InertiaRails.defer(group: 'name') { ... }` | One follow-up request per group |
| Once | `InertiaRails.once { ... }` | Resolved once, then kept by the client across pages that include it |
| Merge | `InertiaRails.merge { ... }` | Appended to the existing client-side array on partial reloads |
| Deep merge | `InertiaRails.deep_merge { ... }` | Deep merged into the existing object |
| Always | `InertiaRails.always { ... }` | Included even in partial reloads that do not request it |
| Scroll | `InertiaRails.scroll(pagination) { ... }` | Infinite scroll — takes the pagination metadata object |

```ruby
def index
  render inertia: {
    filters: filter_params,
    messages: -> { messages_scope.map { |message| serialize_message(message) } },
    stats: InertiaRails.defer { Dashboard.stats },
    chart: InertiaRails.defer(group: 'analytics') { Dashboard.chart },
    countries: InertiaRails.once { Country.pluck(:name, :code) },
    activities: InertiaRails.merge { @recent_activities.map { |a| serialize_activity(a) } },
  }
end
```

`scroll` is the infinite-scroll tool, paired with `<InfiniteScroll>` on the client, and it
needs its metadata argument. A plain Hash of the four page keys needs no paginator gem, and the
`inertia-react:inertia-rails-performance` skill works that form out in its "Server-side
pagination props" section. Where the project's `Gemfile.lock` already has Pagy or Kaminari, pass
the paginator object straight in — `InertiaRails.scroll(pagy) { ... }`, whose Pagy syntax turns
on the installed major version; see [Scroll Props](references/prop-types.md#scroll-props).
Reach for `merge` when
data accumulates from user actions or background updates, such as a feed refreshed by
`router.reload({ only: ['activities'] })`.

**CSRF needs no prop.** The gem sets the `XSRF-TOKEN` cookie in an `after_action` and the
middleware copies the returning `X-XSRF-TOKEN` header into `X-CSRF-TOKEN`.

`merge: true` composes with `defer`, and with `optional` or `once` it is accepted and
silently ignored. See [`references/prop-types.md`](references/prop-types.md) for the full
combination table. `<Deferred>` and `<InfiniteScroll>` on the client belong to
`inertia-rails-pages`.

## Shared Data (`inertia_share`)

Shared data needs controller context — `Current.user`, the request — so it lives in a
controller, not the initializer. Put it in `InertiaController`, the base class the install
generator creates (`generators/inertia/install/templates/inertia_controller.rb`), so
controllers that render ERB never register the callback.

```ruby
class InertiaController < ApplicationController
  # A static value
  inertia_share app_name: 'MyApp'

  # A lambda, evaluated per request in controller context
  inertia_share auth: -> { { user: Current.user && serialize_user(Current.user) } }

  # A block returning a hash, scoped to signed-in requests
  inertia_share if: :authenticated? do
    { unread_count: Current.user.unread_notifications_count }
  end
end
```

`inertia_share` registers a `before_action` (`controller.rb:34-43`), so it accepts that
callback's `:if`, `:unless`, `:only` and `:except` — `:only`/`:except` is how you scope a
share to particular actions. An instance-level form (`controller.rb:71-75`) shares a value
computed inside your own callback: `inertia_share tenant: serialize_tenant(Current.tenant)`.

**Evaluation order:** the registered shares collect parent-first, then fold with
`reduce(initial_data, &:merge)` (`controller.rb:162-168`), so a child controller's value for
a key a parent also shares is the one that wins. Blocks and lambdas are evaluated per
request, and only for Inertia responses.

## Flash Messages

Flash is automatic: write ordinary Rails flash, `redirect_to users_path, notice: 'Created!'`,
and read it at `usePage().flash.notice`. Flash sits at the **top level of the page object**
(`renderer.rb:140-141`), a sibling of `props`. Its TypeScript type comes from your
`flashDataType` augmentation of `InertiaConfig` — see `inertia-rails-typescript`.

`config.flash_keys` is `inertia_rails`' own allowlist over Rails' flash — Rails itself has
none. The install generator does not set it, so a fresh app is on `%i[notice alert]`
(`configuration.rb:69`) and a `flash[:toast]` reaches the page only once you widen it:
`config.flash_keys = %i[notice alert toast]`. Setting it to `nil` turns Rails flash
integration off entirely.

For a value **one** action sends once, write `flash.inertia`, which bypasses the allowlist
(`controller.rb:176-185`):

```ruby
flash.inertia[:new_user_id] = user.id
flash.inertia[:toast] = { message: 'Created!', type: 'success' }
redirect_to users_path
```

`flash.now.inertia[:key]` scopes the value to the current request, for a `render` rather
than a redirect.

## Redirects & Validation Errors

After a create, update or delete, redirect (Post-Redirect-Get).

```ruby
def create
  @user = User.new(user_params)
  if @user.save
    redirect_to users_path, notice: 'Created!'
  else
    redirect_to new_user_path, inertia: { errors: @user.errors }
  end
end

private

def user_params
  params.expect(user: [:name, :email])
end

def serialize_user(user)
  user.as_json(only: [:id, :name, :email])
end
```

**Redirect to the page that holds the form** — `new_user_path` after a failed create,
`edit_user_path(@user)` after a failed update, which is what the gem's scaffold generator
writes (`inertia/scaffold_controller/templates/controller.rb.tt:48,57`). A fixed target is
also the one a request spec can assert on.

**Pass the bare `@user.errors` object.** The front end receives
`{ name: ["can't be blank"] }` — keyed by attribute name, which is the property that maps a
message to its input, so keep the keys matching the input `name` attributes. Short messages
are also what live validation produces, so the submit path and the Precognition path render
the same string. A validation failure is a redirect here, not a 422 re-render, because there
is no template to re-render; a Hotwire controller needs the opposite habit, and
`rails-core:rails-8-idioms` owns that side of the rule in its "Redirect status codes" section.

Why the middleware handles the status, why `redirect_back_or_to` loses the errors, and the
session-to-prop chain the gem runs are in
[`references/redirects-and-errors.md`](references/redirects-and-errors.md) (~50 lines).

`params.expect(user: [...])` is the shape for attributes nested under a model key; a sign-in
form's root-level scalars take `params.permit` instead. `rails-core:rails-8-idioms` owns that
rule, in its "Strong parameters: pick the form from the shape of the incoming params" section.

## Serializing Props

Give each model a private `serialize_<model>` returning `as_json(only: [...])`, matching the
gem's scaffold (`inertia/scaffold_controller/templates/controller.rb.tt:84-98`). A prop that
needs more than one expression belongs in one of those methods or in a query object, not
inline in the `render` call.

**Prop breadth is a disclosure decision.** Both carriers put the initial page object in the
HTML document, so `use_script_element_for_initial_page` is defence in depth for CSP and
**hides nothing** — the control that works is the prop list. The two carriers are in
[`references/configuration.md`](references/configuration.md), section "Initial page carrier".

## Authorization as Props

Pass permissions as a per-resource `can` hash. The front end controls visibility; the
server still enforces access.

Read [`references/authorization.md`](references/authorization.md) (~52 lines) in full when
you pass permission data to the front end — it holds the full-stack `can` pattern, and how
to write the checks against whichever authorization gem the project already has.

## External Redirects (`inertia_location`)

Use `inertia_location` for every URL outside the Inertia app — payment providers, OAuth,
SSO. The 409 and its header (`controller.rb:171-174`) tell the client to do
`window.location = url`:

```ruby
inertia_location checkout_session.url
```

A plain `redirect_to` to an external host is followed by the XHR, which then receives a
response carrying no `X-Inertia` header — the client reports "All Inertia requests must
receive a valid Inertia response", or the browser blocks the cross-origin request first.

## History Encryption

Set `config.encrypt_history = true` in **every** environment, which is what the install
generator writes. Then `redirect_to path, inertia: { clear_history: true }` on logout or a
role change locks the back button out of the previous session's pages. Encryption is the
prerequisite for that rather than an optimisation, because `clear_history` works by deleting
the encryption key — so gating encryption on `Rails.env.production?` leaves the logout
protection dead in development, which is exactly where you would try to confirm it works.
Citations and the client-side `router.clearHistory()` are in
[`references/configuration.md`](references/configuration.md), section "History Encryption".

## Configuration

**Read the initializer before reasoning from a gem default.** `rails generate
inertia:install` writes five settings — `version`, `encrypt_history`,
`always_include_errors_hash`, `use_script_element_for_initial_page` and
`use_data_inertia_head_attribute` — and the last three *differ* from the gem's own defaults
(`configuration.rb:53,59,62`), so an app older than the generator needs them added by hand.
Everything else, `flash_keys` and `default_render` included, sits at its `configuration.rb`
default.

The one with a visible consequence is `always_include_errors_hash = true`: `errors` is then
a key on **every** response, empty when nothing is wrong, so the front end reads
`props.errors` unconditionally and a spec asserts `be_empty` rather than key absence.

Read [`references/configuration.md`](references/configuration.md) (~245 lines) when you set
up or debug `InertiaRails.configure` — it holds every option, the initial page carrier,
history encryption, error handling, and the middleware behaviour the rest depends on.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "All Inertia requests must receive a valid Inertia response" | A `redirect_to` to an external host, or an action that rendered no Inertia page | `inertia_location` for off-site URLs; an explicit `render inertia:` in every Inertia action |
| `MissingExactTemplate`, or a 204 on the Inertia XHR | An action with no `render` while `default_render` is at its default `false` | `render inertia: true` |
| Errors don't display next to fields | The error keys don't match the input `name` attributes | Pass `@user.errors` — its keys are attribute names; keep the inputs named to match |
| `MissingMetadataAdapterError` on first page load | `InertiaRails.scroll` called with no metadata | Pass the metadata: a paginator object where the project has Pagy or Kaminari, the four page keys (`page_name`, `current_page`, `previous_page`, `next_page`) where it has neither |

## Related Skills
- **Form submission and error display** → `inertia-rails-forms`
- **Request specs for these actions** → `inertia-rails-testing`
- **Flash and deferred props inside the page** → `inertia-rails-pages`
- **Typing props and the `flashDataType` augmentation** → `inertia-rails-typescript`
- **Prop payload size and pagination** → `inertia-rails-performance`

## References

Read [`references/prop-types.md`](references/prop-types.md) (~345 lines) in full when you
use `merge`, `deep_merge` or `scroll`, when you combine two prop options, or when you need
the pagination code a scroll prop's metadata argument comes from. The table above is enough
for plain `defer`, `optional`, `once` and `always`.
