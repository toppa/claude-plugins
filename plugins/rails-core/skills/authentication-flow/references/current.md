# Current Attributes Reference

`Current` uses `ActiveSupport::CurrentAttributes` to hold request-local state, so
`Current.user` reads the same everywhere in a request without being threaded through every
call. Rails clears it when a unit of work completes — the Active Support railtie registers
`app.executor.to_complete { ActiveSupport::CurrentAttributes.clear_all }` — and the generated
concern is the only thing that ever populates it. That is both the feature and the constraint:
outside a request nothing has filled it in.

## What the generator writes

```ruby
# app/models/current.rb, as generated
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

Two lines, and they are enough for everything the generated concern does. **Add an attribute
only when more or less every request needs it** — the `CurrentAttributes` documentation warns
against exactly this expansion, because each addition becomes an implicit input to every
object that reads it. Request metadata is the common mistake: `request.user_agent`,
`request.remote_ip` and `request.request_id` are already available wherever `request` is, and
the generated concern reads them straight off `request` when it creates a session. Copying
them onto `Current` in a `before_action` adds a global with no named consumer.

`Current` is populated by the generated `resume_session`, which is also where its idempotency
guard lives:

```ruby
# app/controllers/concerns/authentication.rb, as generated
def resume_session
  Current.session ||= find_session_by_cookie
end
```

Keep the `||=` when you extend this. `require_authentication` and the `authenticated?` helper
both call `resume_session`, so dropping the guard re-queries on each call.

## Reading `Current`

### In controllers and views

```ruby
class PostsController < ApplicationController
  def create
    @post = Current.user.posts.build(post_params)
  end

  def index
    @posts = Current.user.posts
  end
end
```

```erb
<% if Current.user %>
  Logged in as: <%= Current.user.email_address %>
  <%= button_to "Sign out", session_path, method: :delete %>
<% else %>
  <%= link_to "Sign in", new_session_path %>
<% end %>
```

The column is `email_address`, not `email` — that holds everywhere, including in mailers.

`button_to` is the form that works. `link_to "Sign out", session_path, method: :delete` is
inert on Rails 8.1: `method:` renders `data-method`, a rails-ujs attribute, and 8.1 ships
turbo-rails with no ujs gem, so the browser follows the link as `GET /session` →
`sessions#show`, an action the generated controller does not define. Use `button_to`, or
`link_to … data: { turbo_method: :delete }` if it has to look like a link.

### In models — sparingly

```ruby
class Post < ApplicationRecord
  belongs_to :user

  before_create :set_author

  private

  def set_author
    self.user ||= Current.user
  end
end
```

**Warning**: this couples the model to the request context. It makes the model harder to test
and it is `nil` in a background job, a rake task and a console. Prefer passing the user in.

### In mailers

```ruby
class NotificationMailer < ApplicationMailer
  def alert(user, message)
    @user = user
    @message = message

    mail(to: user.email_address)
  end
end
```

Pass the data the mail needs as arguments. A mailer delivered with `deliver_later` renders
inside a job, outside any request, so `Current.user` is `nil` there — including in the `mail`
call. The generated `PasswordsMailer` takes the user as an argument for exactly this reason.

### In jobs — never

```ruby
class AuditLogJob < ApplicationJob
  def perform(action:, user_id:, ip_address:, request_id:)
    AuditLog.create!(action: action, user_id: user_id, ip_address: ip_address, request_id: request_id)
  end
end

# Enqueue from the request, where the values still exist
AuditLogJob.perform_later(
  action: "created_post",
  user_id: Current.user.id,
  ip_address: request.remote_ip,
  request_id: request.request_id
)
```

## Callbacks

`resets` (aliased as `after_reset`) fires **after** the reset, between requests. It is the hook
for undoing process-global state you set during the request, not for reacting to an assignment.
To react to an assignment, override the writer:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :time_zone

  # Runs between requests, after everything is cleared.
  resets { Time.zone = nil }

  # Runs when Current.session is assigned.
  def session=(session)
    super
    self.time_zone = session&.user&.time_zone
    Time.zone = time_zone if time_zone
  end
end
```

This is the one expansion that earns a `Current` attribute in a generated app, and only once
`users` actually has a `time_zone` column — the generator does not create one. Note the shape:
the `resets` block exists *because* the writer sets `Time.zone`, which is process-global and
would otherwise leak into the next request on the same thread.

## Testing

There is no generated sign-in helper on RSpec. rspec-rails 8.0.4's authentication generator
writes only a pending `spec/models/user_spec.rb` and a users fixture, so write the helper
yourself — and write it to plant the signed cookie, the way the Minitest template
(`sign_in_as`) does:

```ruby
# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  # Request and system specs: plants the signed session_id cookie the concern reads.
  def sign_in_as(user)
    session = user.sessions.create!
    ActionDispatch::TestRequest.create.cookie_jar.tap do |jar|
      jar.signed[:session_id] = session.id
      cookies["session_id"] = jar[:session_id]
    end
    session
  end

  # Unit specs that read Current directly, with no request involved.
  def with_current_session(user)
    Current.session = user.sessions.create!
    yield
  ensure
    Current.reset
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
  config.include AuthenticationHelpers, type: :model
end
```

**Setting `Current.session` in a `before` block does not sign a request spec in.** `Current` is
reset around each request, so the assignment is gone by the time the controller runs. That is
why the helper plants a cookie instead: the concern's `find_session_by_cookie` is what
populates `Current` inside the request.

```ruby
RSpec.describe "Posts", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "attributes the post to the signed-in user" do
    post posts_path, params: { post: { title: "Test" } }
    expect(Post.last.user).to eq(user)
  end
end
```

```ruby
RSpec.describe Post, type: :model do
  let(:user) { create(:user) }

  it "sets the author from Current.user" do
    with_current_session(user) do
      expect(Post.create!(title: "Test").user).to eq(user)
    end
  end
end
```

## Where to read `Current`

| Layer | Rule |
|---|---|
| Controllers, views | Read `Current.user` freely; that is what it is for. |
| Models | Pass the user in. Use `Current` only for an audit-style default. |
| Jobs | Never. It is already reset; pass the values as arguments. |
| Mailers | Never — `deliver_later` runs in a job. Pass everything as arguments. |
| Services, queries | Accept the user as a parameter, so they run outside a request too. |
| Specs | `Current.reset` after any example that assigns it. |
