# Session Management Reference

Everything here builds on the generated contract rather than replacing it. Read
`app/models/session.rb` and `app/controllers/concerns/authentication.rb` first. Where a
section changes a generated method, it names the method.

## The generated contract, in one place

- `Session` is `belongs_to :user` and nothing else. There is **no token column**.
- `User` has `has_many :sessions, dependent: :destroy`.
- `CreateSessions` migrates `user:references`, `ip_address:string`, `user_agent:string`, plus
  timestamps — nothing more.
- The credential in the cookie is the row's **id**, signed:

```ruby
# app/controllers/concerns/authentication.rb, as generated
def start_new_session_for(user)
  user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
    Current.session = session
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
  end
end
```

`ip_address` and `user_agent` are captured here, from `request`, at creation. A `before_create`
callback reading them off `Current` would duplicate that and raise, because the generated
`Current` declares only `attribute :session`.

`secure` is deliberately absent from that hash: the SSL middleware adds it, so it follows from
`config.force_ssl` or `config.assume_ssl` rather than from this line.

## Cookie options

| Option | Purpose | Where it comes from |
|---|---|---|
| `httponly` | keeps JavaScript out of the cookie | set explicitly above |
| `same_site` | `:lax` by default from `load_defaults "5.2"` | set explicitly above |
| `secure` | HTTPS only | the SSL middleware, via `force_ssl` / `assume_ssl` |
| `expires` | cookie lifetime | `.permanent` is 20 years; set it to match row expiry |
| `domain` | share across subdomains | `domain: :all`, or an explicit `.example.com` |

**Repeat the options on every write.** A rotation that writes a bare value silently drops
`httponly` and `same_site`:

```ruby
# Rotate the credential after a sensitive action. Same options as start_new_session_for.
def rotate_session
  old = Current.session
  Current.session = Current.user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
  cookies.signed.permanent[:session_id] = { value: Current.session.id, httponly: true, same_site: :lax }
  old.destroy
end
```

## An inactivity timeout

The generator ships no expiry: the cookie is `permanent` and the row never goes stale. If you
add one, **measure inactivity, not age.** A scope over `created_at` logs out someone who is
using the app and keeps someone who left, which is the opposite of the intent.

First add the column the generator does not create:

```ruby
class AddLastSeenAtToSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :sessions, :last_seen_at, :datetime
    add_index :sessions, :last_seen_at
    execute "UPDATE sessions SET last_seen_at = updated_at WHERE last_seen_at IS NULL"
  end

  def down
    remove_column :sessions, :last_seen_at
  end
end
```

The backfill is load-bearing: without it every existing row has `last_seen_at IS NULL` and the
first deploy signs the whole user base out. `touch` also writes the attribute before issuing
the UPDATE, so before this migration `session.touch(:last_seen_at)` raises
`ActiveModel::MissingAttributeError`.

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  IDLE_TIMEOUT = 30.days

  belongs_to :user

  scope :active,  -> { where(last_seen_at: IDLE_TIMEOUT.ago..) }
  scope :expired, -> { where(last_seen_at: ..IDLE_TIMEOUT.ago).or(where(last_seen_at: nil)) }

  def expired?
    last_seen_at.nil? || last_seen_at <= IDLE_TIMEOUT.ago
  end
end
```

The `or(where(last_seen_at: nil))` is what keeps the cleanup job and `expired?` agreeing: SQL
comparison against `NULL` is never true, so a bare `<=` scope would leave a row `expired?`
already reports as dead sitting in the table forever.

Then extend the generated `resume_session`, keeping its `||=` guard — that guard is why
`require_authentication` and `authenticated?` do not re-query on every call:

```ruby
# app/controllers/concerns/authentication.rb — replaces the generated resume_session
def resume_session
  Current.session ||= find_session_by_cookie
  return if Current.session.nil?

  if Current.session.expired?
    terminate_session
    return
  end

  Current.session.touch(:last_seen_at) if Current.session.last_seen_at.nil? ||
    Current.session.last_seen_at < 5.minutes.ago
  Current.session
end
```

The `5.minutes` throttle is a house heuristic with no external source; it exists so a busy
session does not write on every request. Pick whatever granularity your timeout can tolerate.

Cap the cookie at the row's lifetime too, or the browser keeps presenting a credential the
server has already discarded:

```ruby
cookies.signed[:session_id] = {
  value: session.id, expires: Session::IDLE_TIMEOUT.from_now, httponly: true, same_site: :lax
}
```

## Listing and revoking devices

**The generated route is `resource :session`, singular.** So `session_path` takes no argument
and `sessions_path` does not exist. Do not reach for `session_path(session)`: it does not
raise — the positional argument lands in `:format`, producing `/session.42`, which routes to
`DELETE /session` and signs the user out of the device they are looking at instead of the one
they clicked. Give the device list its own resource:

```ruby
# config/routes.rb
resource :session
resources :devices, only: %i[ index destroy ] do
  delete :all, on: :collection
end
```

That yields `devices_path`, `device_path(session)` and `all_devices_path`, none of which
collide with `session_path`, and it keeps `SessionsController#destroy` meaning "sign out of
this device".

```ruby
class DevicesController < ApplicationController
  def index
    @sessions = Current.user.sessions.active.order(last_seen_at: :desc)
  end

  def destroy
    Current.user.sessions.find(params[:id]).destroy
    redirect_to devices_path, notice: "Device signed out."
  end

  def all
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to devices_path, notice: "All other devices signed out."
  end
end
```

Scoping through `Current.user.sessions` rather than `Session.find` is what stops one user
revoking another's session.

```erb
<%# app/views/devices/index.html.erb %>
<% @sessions.each do |session| %>
  <div class="device <%= "current" if session == Current.session %>">
    <p><%= session.ip_address %></p>
    <p><%= session.user_agent %></p>
    <p>Last seen <%= time_ago_in_words(session.last_seen_at || session.created_at) %> ago</p>
    <% unless session == Current.session %>
      <%= button_to "Sign out", device_path(session), method: :delete %>
    <% end %>
  </div>
<% end %>

<%= button_to "Sign out all other devices", all_devices_path, method: :delete %>
```

`button_to` emits a real form, so it works under Turbo. `link_to … method: :delete` does not:
`method:` renders `data-method`, a rails-ujs attribute, and Rails 8.1 ships turbo-rails and no
ujs gem. Use `link_to … data: { turbo_method: :delete }` if you need a link rather than a
button.

## Cleaning up expired rows

```ruby
# app/jobs/cleanup_expired_sessions_job.rb
class CleanupExpiredSessionsJob < ApplicationJob
  def perform
    Session.expired.in_batches.delete_all
  end
end
```

```yaml
# config/recurring.yml
production:
  cleanup_sessions:
    class: CleanupExpiredSessionsJob
    schedule: at 5am every day
```

**Scope it under the environment.** Solid Queue's `config_from` falls back to the whole hash
when the top-level key is not the current environment, so a task written at the top level
registers in development and test as well. `production:` is the shape Solid Queue's own
`recurring.yml` template uses. Schedules are parsed by fugit, and `at 5am every day` is the
form that template ships; if you write `queue: low` here, configure that queue in
`config/queue.yml` or nothing will run it.

## If you want an opaque rotatable token instead of the row id

This is a **deviation from the generated contract**, not a correction of it. It is defensible:
an opaque token can be rotated without destroying the row, and it never puts a primary key in
a cookie. It also costs you a column, a unique index, and a replacement for two generated
methods — so take it only if you want one of those properties.

```ruby
class AddTokenToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :token, :string
    add_index :sessions, :token, unique: true
  end
end
```

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user
  has_secure_token :token  # SecureRandom.base58, 24 characters minimum
end
```

Then replace the generated methods that touch the cookie, and nothing else:

```ruby
def find_session_by_cookie
  Session.find_by(token: cookies.signed[:session_token]) if cookies.signed[:session_token]
end

def start_new_session_for(user)
  user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
    Current.session = session
    cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }
  end
end
```

`terminate_session` also needs `cookies.delete(:session_token)` rather than `:session_id`.
Keep the `find_by(token:)` form above. `Session.find_by_token(...)` resolves through
`DynamicMatchers`, which checks `columns_hash["token"]`, so it works only once the migration
has run and gives a worse error than `find_by` when it has not.

## Security considerations

1. **Rotate after a privilege change.** Password reset already destroys every session
   (`PasswordsController#update` calls `@user.sessions.destroy_all`); do the same after an
   email change or a role change.
2. **Idle timeout.** Above — keyed on `last_seen_at`, not `created_at`.
3. **Concurrent session limits.** Destroy the oldest rows in `start_new_session_for` if the
   product wants a cap.
4. **Metadata is for the user, not for enforcement.** Showing IP and user agent in the device
   list is useful; binding a session to an IP signs out anyone on mobile data.
