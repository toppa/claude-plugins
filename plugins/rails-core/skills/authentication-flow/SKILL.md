---
name: authentication-flow
description: Rails 8 built-in authentication — what `bin/rails generate authentication` creates, the API it gives you (`allow_unauthenticated_access`, `authenticate_by`, `Current.user`, `rate_limit`, `has_secure_password`), password reset and API tokens via `generates_token_for`, and what you still have to build yourself.
when_to_use: >-
  Use when adding sign-in, sign-out, password reset, session expiry, or an API
  token to a Rails 8 application, when the user mentions authentication, sessions,
  `has_secure_password`, or how to sign a request spec in, and when deciding between
  the built-in generator and an authentication gem. For `params.expect`, `normalizes`, or `rate_limit` outside
  authentication, use the rails-8-idioms skill.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/authentication-flow/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: railties, activerecord, activemodel, actionpack and activesupport 8.1.3.1, Ruby 3.4.5, bcrypt 3.1.22, rspec-rails 8.0.4, solid_queue 1.6.0
---

# Rails 8 Authentication

Rails 8 ships an authentication generator. It uses a database-backed `Session` record plus
a signed cookie. The one gem it needs is `bcrypt`, which a generated `Gemfile` already
carries commented out.

```bash
bin/rails generate authentication
bin/rails db:migrate
```

**Read the generated files before writing anything.** They are the source of truth.
This skill tells you what to expect and what it does not give you. It deliberately
does not reproduce the generated code, because a copy drifts every release.

## What the generator creates

Models:
- `app/models/user.rb` — `has_secure_password`, `has_many :sessions, dependent: :destroy`, and
  `normalizes :email_address, with: ->(e) { e.strip.downcase }`
- `app/models/session.rb` — `belongs_to :user`, nothing more
- `app/models/current.rb` — `ActiveSupport::CurrentAttributes` with a `session`
  attribute and `delegate :user, to: :session, allow_nil: true`

Controllers and the concern:
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/passwords_controller.rb`

Mailer and views:
- `app/mailers/passwords_mailer.rb`
- `app/views/passwords_mailer/reset.html.erb` and `reset.text.erb`
- Sign-in and password views, through the template-engine hook. Pass `--api` to skip
  every view.

Also:
- `app/channels/application_cable/connection.rb`, when Action Cable is loaded
- Two routes: `resources :passwords, param: :token` and `resource :session`
- Two migrations: `CreateUsers` with `email_address:string!:uniq` and
  `password_digest:string!`, then `CreateSessions` with `user:references`,
  `ip_address:string`, and `user_agent:string`
- `gem "bcrypt"` uncommented in the `Gemfile`

Note the column is `email_address`, not `email`. There is no token column anywhere.

## The API you get

`require_authentication` runs as a `before_action` on every controller. Opt out per
controller:

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
end
```

Authenticate a user with `authenticate_by`, which avoids leaking whether the address
exists:

```ruby
if user = User.authenticate_by(params.permit(:email_address, :password))
  start_new_session_for user
  redirect_to after_authentication_url
else
  redirect_to new_session_path, alert: "Try another email address or password."
end
```

`authenticate_by` digests the submitted password even when no record matched, which
equalises the work between found and not-found and so mitigates timing-based
enumeration. That is a work-equalising measure, not a constant-time comparison, so
reach for `authenticate_by` rather than comparing a digest yourself.

Read the current user anywhere, including in views, through `Current.user`. Check
sign-in state with `authenticated?`, which the concern exposes as a helper method.

The concern also gives you `start_new_session_for(user)`, `terminate_session`, and
`after_authentication_url`. That last one returns the URL the user was trying to
reach, so use it after sign-in instead of a fixed `root_url`.

## Password reset — already built, including the token

`has_secure_password` takes `reset_token: true` **by default**
(`activemodel/lib/active_model/secure_password.rb:125`), so the bare declaration the
generator writes already gives a `User`:

- `user.password_reset_token` and `user.password_reset_token_expires_in`
- `User.find_by_password_reset_token(token)` and the `!` variant that raises

The token is signed rather than stored. `generates_token_for :password_reset`
(`secure_password.rb:177-179`) builds a payload of `[id, password_salt.last(10)]` and
takes `expires_in:` from `DEFAULT_RESET_TOKEN_EXPIRES_IN = 15.minutes`
(`secure_password.rb:14`). Widen
that window per model: `has_secure_password reset_token: { expires_in: 2.hours }`.

Binding the payload to the bcrypt salt is the property a token column does not have.
`resolve_token` recomputes the payload and compares it
(`activerecord/lib/active_record/token_for.rb:34`), so **changing the password
invalidates every outstanding reset token.** Executed against activerecord 8.1.3.1:
after `user.update!(password: "…")`, `find_by_password_reset_token` returns `nil` and
`find_by_password_reset_token!` raises
`ActiveSupport::MessageVerifier::InvalidSignature`.

The generated `PasswordsController` already rescues that exception, and its `update`
action calls `@user.sessions.destroy_all`, so a completed reset signs every device out.
The mailer view builds the link with `edit_password_url(@user.password_reset_token)`.

**The smell to recognise is a persisted reset-token column, at any length.**
`SecureRandom` is a CSPRNG, so `hex(4)` is unpredictable — it is 32 bits, which makes it
brute-forceable. Growing it to 32 bytes fixes the entropy and leaves the real defect: a
bearer credential sitting in the database with no expiry and no invalidation when the
password changes. Delete the column rather than lengthen it.

## Password rules

`has_secure_password` validates three things: the digest is present, the password is at
most `MAX_PASSWORD_LENGTH_ALLOWED = 72` bytes (bcrypt ignores anything past that), and
`password_confirmation` matches when it is not `nil`. It sets **no minimum length and no
complexity rule**, so add your own if the product wants one:

```ruby
validates :password, length: { minimum: 12 }, allow_nil: true
```

`allow_nil` matters: the attribute is `nil` on every load, so a bare length validation
fails every update that does not set a password.

You also get `password_challenge`. Assign the user's current password to it and the save
fails unless it authenticates against the persisted digest — which is how you gate a
password or email change on re-entry of the old password. It reads
`password_digest_was`, so it depends on dirty tracking.

## Sessions: the credential, fixation, and expiry

The credential is the `Session` row's **id**, in a signed cookie:
`cookies.signed.permanent[:session_id] = { value: session.id, httponly: true,
same_site: :lax }`. Note what is absent — `secure` is not set here. It comes from the
SSL middleware, so it follows from `config.force_ssl` or `config.assume_ssl`.

**Fixation is handled by construction.** `start_new_session_for` creates a new row and
overwrites the cookie, so an identifier planted before sign-in is replaced rather than
inherited. `terminate_session` destroys the row and deletes the cookie, so the
credential dies server-side too — but it does not call `reset_session`, so anything you
stored in Rails' own `session` hash survives sign-out. Clear it there if you keep
anything user-specific in it.

**If you add expiry, measure inactivity rather than age.** The generator adds none: the
cookie is `permanent` (20 years) and the row never expires. A scope over `created_at`
expires a session someone is actively using and keeps an idle one — the opposite of
"expire inactive sessions". Key expiry off a column you touch on each resume, and keep
the cookie's lifetime at or under the row's, or the browser keeps presenting a
credential the server has already discarded.

## Rate limiting

`rate_limit` is built in. The generator puts it on `SessionsController#create` and
`PasswordsController#create`:

```ruby
rate_limit to: 10, within: 3.minutes, only: :create,
  with: -> { redirect_to new_session_path, alert: "Try again later." }
```

- Identity defaults to `request.remote_ip`; pass `by:` for anything else.
- `with:` defaults to raising `ActionController::TooManyRequests`, which Action Dispatch
  renders as `429 Too Many Requests`.
- The counter is scoped to `controller_path` unless you pass `scope:`. Two limits on one
  controller need distinct `name:` values.
- It counts through `ActiveSupport::Cache` and inherits `config.cache_store`. **With
  `:null_store`, `increment` returns `nil` and the limit never fires** — and
  `:null_store` is the generated test environment's cache store, so a spec that asserts
  a 429 has to install a real store first.

## API tokens

None of this is generated; the pieces are all in the framework.

- **Short-lived and stateless** — `generates_token_for :api_access, expires_in:
  30.minutes`. Same machinery as the reset token, needs no column, and the block's
  return value is bound into the payload, so a change to whatever you name there
  invalidates outstanding tokens.
- **Long-lived and revocable** — `has_secure_token :api_token`. `SecureRandom.base58`,
  a 24-character minimum (`MINIMUM_TOKEN_LENGTH`), and a `regenerate_api_token` method.
  Add a unique index. The column holds the token in clear text, because lookup needs it —
  so keep it out of logs and out of URLs, compare it with `secure_compare` as the next
  bullet says, and call `regenerate_api_token` on any suspicion of exposure.
- Read the header with `authenticate_or_request_with_http_token`; its `TOKEN_REGEX`
  accepts both `Token` and `Bearer`. If you compare a token yourself, use
  `ActiveSupport::SecurityUtils.secure_compare`.

## What the generator does not give you

You build these yourself:

1. **Registration.** There is no sign-up controller or view.
2. **Email confirmation.** Nothing verifies that an address belongs to the user.
3. **Two-factor authentication.**
4. **OAuth or single sign-on.**
5. **Roles or authorization.** Authentication answers who the user is, not what they
   may do. See the `security-audit` skill, its "Broken access control" section.
6. **Account lockout.** `rate_limit` slows an attacker down; it locks nothing.
7. **A sign-in test helper, on RSpec.** The `test_framework` hook writes one for
   Minitest — `sign_in_as`, which plants the signed `session_id` cookie. rspec-rails
   8.0.4's authentication generator writes only a pending `spec/models/user_spec.rb` and
   a users fixture, so an RSpec project gets no helper at all. Write one that plants the
   cookie: assigning `Current.session` in a `before` block does not reach the request,
   because `Current` resets around each one.

## When to reach for a gem instead

The built-in generator is the right default. Choose a gem when you need several of the
gaps above on a deadline, or when you need a provider integration that is already
solved. Adding a gem later is harder than starting with one, because the generated
`Session` model and the gem's session handling will both want the cookie.

## References

- See [current.md](references/current.md) (~230 lines) for what belongs on `Current`, reading it
  per layer, and an RSpec sign-in helper that plants the cookie
- See [sessions.md](references/sessions.md) (~275 lines) for the inactivity timeout migration,
  a device list with non-colliding routes, cleanup, and the opaque-token deviation
