---
name: rails-8-idioms
description: >-
  The Rails 8.1 form that overrides an older Rails idiom — `params.expect`,
  `authenticate_by`, `normalizes`, `rate_limit`, `allow_browser`,
  `:unprocessable_content`, `status: :see_other`, the Solid adapters, Propshaft, and Kamal.
when_to_use: >-
  Use when older code and Rails 8.1 disagree about the current form, or when the task
  names strong parameters, a redirect's status code, rate limiting, `normalizes`, or a
  Solid adapter. For the sign-in and password-reset flow, use the authentication-flow
  skill.
metadata:
  upstream_repo: none
  origin: Written for this plugin. No upstream.
  synced: 2026-08-11
  verified_against: rails 8.1.3.1, inertia_rails 3.22.0, propshaft 1.3.2
  verification_method: >-
    Read the railties, actionpack, activerecord, activemodel, propshaft and inertia_rails
    gem sources, and the config of a generated Rails 8.1.3.1 app. Executed every
    `params.expect` claim in this file against actionpack 8.1.3.1 on Ruby 3.4.5. Source
    over guide, because the guides lag the generators.
  reference_guides:
    - https://guides.rubyonrails.org/action_controller_overview.html
    - https://guides.rubyonrails.org/active_record_basics.html
    - https://guides.rubyonrails.org/active_job_basics.html
    - https://guides.rubyonrails.org/asset_pipeline.html
---

# Rails 8.1 idioms

Each idiom below **overrides** an older Rails form. Write the Rails 8.1 form in new code.
Leave an older form in place until you have a reason to touch that call. Two of the rules
below are forks rather than overrides: strong parameters and redirect status.

## Controllers

| Write this | It overrides |
|---|---|
| `params.expect(post: [:title, :body])` | `params.require(:post).permit(:title, :body)` |
| `params.expect(:id)`, for a **required** scalar | `params[:id]` where the action cannot run without it |
| `status: :unprocessable_content` | `status: :unprocessable_entity` |
| `rate_limit to: 10, within: 3.minutes, only: :create` | a hand-written throttle |
| `allow_browser versions: :modern` | a hand-written user agent check |

`:unprocessable_entity` still works: Rails maps the old symbol to the new one, because
Rack 3.1 removed the old name.

`rate_limit` installs a `before_action` on **every** action in the controller unless you
pass `only:` or `except:` (`rate_limiting.rb:65`), so a throttle written for `create` also
caps `index` and `show`. The 8.1 authentication generator passes `only: :create`.
`rate_limit`'s own default `with:` raises `TooManyRequests`, which reaches the client as a
bare 429; pass your
own `with:` wherever a bare 429 is a dead end, as it is on an Inertia XHR visit.

The count lives in the cache store, which makes rate limiting **inert in the test
environment**: a generated app sets `config.cache_store = :null_store` in
`config/environments/test.rb`, `NullStore#increment` returns `nil`, and that fails the
`if count && count > to` guard. A spec expecting a 429 gets a 200 until it swaps the store
for that example.

### Strong parameters: pick the form from the shape of the incoming params

| The params arrive as | Write |
|---|---|
| Nested under a model key: a resourceful create or update | `params.expect(user: [:name, address_attributes: [:street]])` |
| Flat at the root: sign-in, password reset | `params.permit(:email_address, :password)` |
| A required scalar, such as an id from the path | `params.expect(:id)` |
| An optional read where `nil` is the right answer | `params[:page]` |

Several root scalars together take `permit` for a mechanical reason: given
several root keys, `expect` returns **an array of the values**, not a hash
(`strong_parameters.rb:776`), and `authenticate_by(["user@example.com", "secret"])` is not
a call that works. That is why the Rails 8.1 authentication generator writes
`User.authenticate_by(params.permit(:email_address, :password))`. One root scalar on its
own is the table's `params.expect(:id)` row, which returns that one value.

An array declares its shape, and an array of hashes takes a doubled array:

```ruby
params.expect(order: [:note, { lines: [[:sku, :qty]] }])  # array of hashes
params.expect(tags: [])                                   # array of scalars
```

**`expect` guards root keys only.** A missing or empty root key raises
`ActionController::ParameterMissing`, which actionpack renders as a 400, where
`require(:user).permit` on `user: "notahash"` gives a `NoMethodError` 500. A *nested* key of
the wrong shape is filtered out by `permit` and never checked, so a mechanical rewrite from
`permit` to `expect` can change behavior: convert one call at a time, and read the call's
shape first. For the worked drop and the `fields_for` encoding that survives it, read
[references/strong-parameters.md](references/strong-parameters.md) (~19 lines).

## Redirect status codes

The rule forks by response mode. Run the check in the `rails-architecture` skill's
"Response mode" section before you write the response. Every path below cites a Rails 8.1
scaffold template under `railties-8.1.3.1/lib/rails/generators/rails/scaffold_controller/`.

**Hotwire** — the ERB scaffold's own choices:

| Write this | Because |
|---|---|
| `status: :see_other` on a PUT/PATCH/DELETE redirect | `controller.rb.tt:37,46` |
| omit `status:` on a POST redirect | the generator deliberately omits it at `:28`; a 302 on POST is already followed as a GET |
| `render :new, status: :unprocessable_content` on a validation failure | `controller.rb.tt:30,39` |

**Inertia** — `inertia_rails` in the Gemfile:

| Write this | Because |
|---|---|
| omit `status:` on every write redirect | the middleware rewrites 301/302 to 303 itself, and only when `X-Inertia` is present and the method is PUT/PATCH/DELETE (`middleware.rb:39,60-72`) |
| `redirect_to new_user_path, inertia: { errors: @user.errors }` on a validation failure | a validation failure is a redirect, not a 422 render: the page lives in `app/frontend/pages` and there is no template for `render :new` to find |

Leaving `:see_other` off under Inertia is the fix rather than a tidy-up: it is redundant at
`inertia_rails` 3.22.0, whose CHANGELOG fixes `inertia: { errors: }` "being discarded when
`redirect_to` is given an explicit non-302 status such as `status: :see_other`" — so on
3.21.x and earlier the explicit status silently threw the errors away.

**JSON API** — there is no redirect here to carry a status. The `--api` scaffold answers
every action with `render json:`, or with nothing at all:

| Write this | Because |
|---|---|
| `render json: @user, status: :created, location: @user` on a successful create | `api_controller.rb.tt:22` |
| omit `status:` on a successful update, which leaves the 200 | `api_controller.rb.tt:31` |
| render nothing from `destroy`, which gives a 204 | `api_controller.rb.tt:39` |
| `render json: @user.errors, status: :unprocessable_content` on a validation failure | `api_controller.rb.tt:24,33` |

Two of the three modes answer a validation failure with `:unprocessable_content`: Hotwire
re-renders the form, and JSON API returns the errors as the body. Inertia is the exception,
because it redirects. Its status is the redirect's own, and `inertia: { errors: }` carries
the errors.

For the props contract, the error shape, and the `serialize_x` convention, the
`inertia-rails-controllers` skill in the `inertia-react` plugin owns them, in its "Prop Types",
"Redirects & Validation Errors", and "Serializing Props" sections.

## Models

```ruby
class User < ApplicationRecord
  has_secure_password
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end

User.authenticate_by(email_address: "user@example.com", password: "secret")
```

`authenticate_by` overrides `find_by` followed by `authenticate`. It takes the same time
whether or not the record exists, which denies an attacker a timing signal. It needs at
least one password attribute and one non-password attribute. It raises `ArgumentError`
otherwise, and returns `nil` on a bad password.

`normalizes` runs when the attribute is **assigned or validated**, and on the values in a
hash condition, so `User.find_by(email_address: " USER@EXAMPLE.COM ")` finds the normalized
record. Three limits, all stated in the same doc block
(`active_model/attributes/normalization.rb:62-79`):

- It does not reach a SQL fragment, so `where(["email_address = ?", " USER@EXAMPLE.COM "])`
  matches nothing while the hash form matches.
- It is not applied when the attribute is read back from the database, so a row written
  before the declaration stays unnormalized until something assigns to it or calls
  `normalize_attribute`.
- It skips `nil` unless you pass `apply_to_nil: true`.

It lives in ActiveModel in 8.1, so a plain ActiveModel object can use it too.

`has_secure_password` needs the `bcrypt` gem, and a generated Gemfile ships it **commented
out** (`Gemfile.tt:9`) — only `bin/rails generate authentication` uncomments it. If it is
still commented out in the project you are in, report that and stop; adding a gem to a
shared project is the user's call.

## Infrastructure

| Concern | Rails 8 default | Where its options live | Where it is switched on |
|---|---|---|---|
| Jobs | Solid Queue | `config/queue.yml`, run with `bin/jobs` | `config.active_job.queue_adapter = :solid_queue` in `config/environments/production.rb` |
| Cache | Solid Cache | `config/cache.yml` | `config.cache_store = :solid_cache_store` in `config/environments/production.rb` |
| Cable | Solid Cable | `config/cable.yml` | the `production:` block of `config/cable.yml` names the adapter |
| Assets | Propshaft | `config/initializers/assets.rb` | it is the only pipeline 8.1 offers |
| Deploy | Kamal and Thruster | `config/deploy.yml`, `.kamal/secrets` | `bin/kamal deploy` |

The last column matters because the installers usually rewrite `production.rb` rather than the
YAML file — someone told "the cache is configured in `config/cache.yml`" greps for `cache_store`
there and does not find it. Cable is the exception the table records: its adapter is named in
`config/cable.yml`, in that file's own `production:` block.

The three Solid adapters are **production only** in a generated app. Development keeps
`:memory_store`, the async cable adapter, and the async job adapter. Each Solid adapter
also gets its own entry in `config/database.yml`, with its own `migrations_paths`. A job,
cache, or cable bug that appears in production alone usually traces to this split.

Propshaft's contribution is that there is no hand-maintained `manifest.js` and no
Sprockets — 8.1 offers no Sprockets option, only `--skip-asset-pipeline`. It does write a
manifest of its own: `config.assets.manifest_path` defaults to
`public/assets/.manifest.json` (`propshaft/railtie.rb:43`) and the resolver switches to
`Resolver::Static` once that file exists (`assembly.rb:30-31`). Precompile and deploy
questions turn on that file existing, so do not answer them with "Propshaft has no
manifest".

For a Solid Queue job's own structure and configuration, use the `solid-queue-setup` skill.
For cache key design and invalidation, use the `caching-strategies` skill. For what
`bin/rails generate authentication` creates and what it leaves to you, use the
`authentication-flow` skill.
