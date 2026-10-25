# Rails Patterns Reference

Rails-specific patterns to check in review, stated as the form to expect. Every claim here was
checked against Rails 8.1.3.1 on Ruby 3.4.5. Where a section names something to look for, it names
the shape in prose so you can grep for it rather than rendering it as working Ruby.

---

## N+1 queries

**What it is**: one query loads a collection, then each item in the collection triggers another
query for its association.

### The three loaders, `joins`, and which one to expect

```ruby
# Preload the association in a second query. This is the default choice.
Post.includes(:author)

# Force separate queries, whatever else the relation says.
Post.preload(:author)

# Force a single LEFT OUTER JOIN, needed when you filter or order on the joined table.
Post.eager_load(:author).where(users: { active: true })

# Filter only. joins does not load the association, so accessing it is still N+1.
Post.joins(:author).where(users: { country: "US" })

# Nested associations, one level at a time.
Post.includes(comments: :author)
```

**`includes` already preloads.** It picks the strategy at run time and picks `preload` unless the
relation references the joined table — verified: `Post.includes(:comments).eager_loading?` is
`false`, and it only becomes `true` once something like `references(:comments)` or a
`where("comments.…")` string forces the join. So "use `preload` for separate queries" is not a
correction to `includes`; reach for `preload` when you want to *stop* `includes` from switching to a
join, and for `eager_load` when you want to guarantee the join.

The distinction that matters in review: `joins` filters and `includes` loads. A `joins` with no
`includes`, followed by code that reads the association, is the N+1 that looks like it was already
fixed.

### Detection, with no gem to add

Rails 8.1 detects this itself:

```ruby
# config/environments/development.rb
config.active_record.strict_loading_by_default = true
config.active_record.action_on_strict_loading_violation = :log
```

Then a lazy association load raises `ActiveRecord::StrictLoadingViolationError` (or logs, per the
setting). Per-record and per-relation forms exist too — `user.strict_loading!` for the strict
version, and `user.strict_loading!(mode: :n_plus_one_only)` to allow single-record loads while still
catching the collection case. Because this is built in, do not prescribe the `bullet` gem; if a
project already has it (`grep -E '^\s*gem "bullet"' Gemfile`) then use what is there, and never add
it to a shared Gemfile to run a review.

### Counter caches for counts

```ruby
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true, touch: true
end
```

```ruby
class AddCommentsCountToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :comments_count, :integer, default: 0, null: false
  end
end
```

Backfill after the column exists, in a task or a console, not inside the migration:

```ruby
Post.find_each { |post| Post.reset_counters(post.id, :comments) }
```

`post.comments_count` then costs nothing. `touch: true` is the half people leave off, and it is what
makes fragment caching correct — see the caching section below.

---

## Callbacks

**Normalization is what callbacks are for**, and Rails 8.1 has a declaration for it:

```ruby
class User < ApplicationRecord
  normalizes :email_address, with: ->(email) { email.strip.downcase }
end
```

`normalizes` beats a hand-rolled `before_validation :normalize_email` on a point that is easy to
miss: **it normalizes query values too.** Verified — with `normalizes`,
`User.where(email_address: " ADA@EXAMPLE.COM ").count` finds the record; with the hand-rolled
callback it returns 0, because the callback only ever ran on assignment. It also applies at
assignment time rather than at validation time, so the attribute reads back normalized immediately.

**Keeping one record's own data consistent is also fair**:

```ruby
class Post < ApplicationRecord
  before_save :generate_slug

  private

  def generate_slug
    self.slug = title.parameterize if slug.blank?
  end
end
```

**Side effects belong in the caller**, where a reader can see them happen and a seed script or a bulk
import can skip them:

```ruby
class RegisterUser
  def self.call(attributes)
    new(attributes).call
  end

  def initialize(attributes)
    @attributes = attributes
  end

  def call
    user = User.create!(@attributes)
    UserMailer.welcome(user).deliver_later
    SyncUserToCrmJob.perform_later(user)
    user
  end
end
```

`deliver_later` already enqueues `ActionMailer::MailDeliveryJob`, so writing a `WelcomeEmailJob` whose
only job is to call the mailer duplicates a class Rails ships. Write your own job for work that is not
mail.

**What to look for**: `after_create` or `after_save` that sends mail, calls an external API, or
updates another model. `after_commit` is the least bad callback for a side effect, because it fires
only once the transaction has really committed — but the question to ask first is whether the caller
should be doing it explicitly.

---

## Fat models

A model is for persistence: associations, validations, scopes, normalization, and small predicates
about its own state. Everything else has a home.

| What it is | Where it goes |
|---|---|
| Multi-step operation, external call, orchestration | Service object |
| A query too complex for a scope | Query object |
| Formatting for display | Presenter |
| Behavior genuinely shared by several models | Concern |
| Sending mail | Mailer |
| Work that can happen later | Job |

The `extraction-timing` skill's "Extraction Thresholds" section decides *when* a given piece has
grown enough to move, and
`solid-principles.md`'s SRP section covers how to tell one responsibility from two. In review, the
useful question is not "how many lines" but "which two stakeholders would ask for a change here".

### Query objects

```ruby
class PostQuery
  def initialize(relation = Post.all)
    @relation = relation
  end

  # Each step returns another PostQuery, which is what makes them chainable.
  def recent = chain(@relation.where(created_at: 1.week.ago..))
  def popular = chain(@relation.where(views_count: 1000..))
  def published = chain(@relation.where(published_at: ..Time.current))
  def by_author(author) = chain(@relation.where(author_id: author.id))

  def trending = recent.popular.published.to_relation.order(views_count: :desc)

  # The one place a caller crosses back into ActiveRecord.
  def to_relation = @relation

  private

  def chain(relation)
    self.class.new(relation)
  end
end
```

`PostQuery.new.by_author(author).recent.to_relation` composes, because every step hands back a
`PostQuery`. A query object whose methods return `@relation.where(...)` directly is **not chainable**
— the second call goes to `ActiveRecord::Relation`, which has never heard of `popular`, and raises
`NoMethodError`. If you find a class commented "chainable" whose methods return relations, that is
the bug.

Note also that model scopes are already chainable. Reach for a query object when a query has outgrown
a scope — several joins, conditional clauses, or a name worth reusing — not as a matter of course.

### Presenters

```ruby
class UserPresenter
  DEFAULT_AVATAR = "/images/avatar-placeholder.png"

  def initialize(user)
    @user = user
  end

  def display_name
    [@user.first_name, @user.last_name].compact_blank.join(" ")
  end

  def avatar_url
    @user.avatar_url.presence || DEFAULT_AVATAR
  end
end
```

A plain PORO is enough. Match whatever the codebase already has — if it uses presenters, do not
introduce decorators, and vice versa.

### Concerns

```ruby
module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, -> { where(published_at: ..Time.current) }
    scope :unpublished, -> { where(published_at: nil).or(where(published_at: Time.current..)) }
  end

  def publish!(at = Time.current)
    update!(published_at: at)
  end

  def unpublish!
    update!(published_at: nil)
  end

  def published?
    published_at.present? && published_at <= Time.current
  end
end
```

The two scopes are written so that **every row falls into exactly one of them.** A pair like
`where(published: true)` / `where(published: false)` leaves any row whose column is `NULL` in
neither — verified against Postgres, where `published = false` does not match `NULL` — and that hole
is how a record becomes invisible to both halves of an admin screen.

**What to look for**: a concern with one including model (keep it in the model); a concern holding
unrelated methods under a vague name; a concern whose methods read a column that not every including
model has.

---

## Service objects

Use one for a multi-step operation, an external integration, work spanning several models, or
anything with side effects.

```ruby
class Result
  attr_reader :value, :error

  def self.success(value = nil) = new(success: true, value: value)
  def self.failure(error) = new(success: false, error: error)

  def initialize(success:, value: nil, error: nil)
    @success = success
    @value = value
    @error = error
  end

  def success? = @success
  def failure? = !@success
end
```

```ruby
class PlaceOrder
  def self.call(attributes)
    new(attributes).call
  end

  def initialize(attributes)
    @attributes = attributes
  end

  def call
    order = Order.new(@attributes)
    return Result.failure(order.errors.full_messages.to_sentence) unless order.save

    Result.success(order)
  end
end
```

Callers read `result.value`, because that is what `Result` exposes. A `Result` used as
`result.order` in one place and `result.value` in another is two objects wearing one name; pick the
accessor once.

**Strong parameters stay in the controller.** A service takes an already-permitted hash and never
calls `require`, `permit`, or `expect` itself. This is not style — a service that calls
`params.require(:user).permit(...)` on a hash its caller already filtered raises
`ActionController::ParameterMissing` (there is no `:user` root left), and handed a hostile scalar
like `user: "hack"` it raises `NoMethodError: undefined method 'permit' for String`, which is a 500
rather than a 400. Both verified. See the `rails-8-idioms` skill's "Strong parameters: pick the
form from the shape of the incoming params" section for which filter shape belongs in which action.

---

## Performance

### Indexes

```ruby
class AddPostIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :email_address, unique: true, algorithm: :concurrently
    add_index :posts, :published_at, where: "published_at IS NOT NULL", algorithm: :concurrently
    add_index :posts, [:author_id, :published_at], algorithm: :concurrently
  end
end
```

Three facts behind that migration:

- **Foreign keys are already indexed.** `t.references` and `add_reference` default to `index: true`
  at 8.1, so `add_index :comments, :post_id` after `t.references :post` creates a duplicate. Check
  the schema before flagging a missing foreign-key index.
- **A low-selectivity column does not benefit from a plain index.** Verified on Postgres with 200,000
  rows and a boolean that is true for half of them: `EXPLAIN` chose `Seq Scan` and ignored the index.
  A partial index over the selective slice (`where: "published_at IS NOT NULL"`) gets used. Index the
  rows a query actually asks for.
- **On Postgres, `algorithm: :concurrently` avoids blocking writes**, and it requires
  `disable_ddl_transaction!` because it cannot run inside a transaction. A plain `add_index` on a
  large, live table takes a lock that blocks writes for the duration.

### Caching

```erb
<% cache @post do %>
  <h1><%= @post.title %></h1>

  <% @post.comments.each do |comment| %>
    <% cache comment do %>
      <%= render comment %>
    <% end %>
  <% end %>
<% end %>
```

Russian-doll caching is only correct if the inner records touch the outer one:

```ruby
class Comment < ApplicationRecord
  belongs_to :post, touch: true
end
```

Without `touch: true`, adding a comment leaves `post.cache_key_with_version` unchanged — verified
identical before and after — so the outer `cache @post` block never expires and the new comment never
appears. `belongs_to touch:` is built in; there is nothing to add.

Low-level caching, for an expensive computation rather than a fragment:

```ruby
class Post < ApplicationRecord
  def reading_time_minutes
    Rails.cache.fetch([self, "reading_time"], expires_in: 12.hours) do
      (body.split.size / 200.0).ceil
    end
  end
end
```

Passing the record as part of the key gets `cache_key_with_version`, so the entry expires when the
record changes.

### Background jobs

```ruby
class UsersController < ApplicationController
  def create
    user = RegisterUser.call(user_params)
    redirect_to user
  end

  private

  def user_params
    params.expect(user: [:email_address, :first_name, :last_name])
  end
end
```

The slow work is inside `RegisterUser`, as `deliver_later` and `perform_later`. A request that waits
on mail delivery or an external API is the pattern to look for; `deliver_now` in a controller action
is the most common instance.

---

## Controllers

A controller action reads parameters, calls one thing, and chooses a response.

```ruby
class OrdersController < ApplicationController
  def create
    result = PlaceOrder.call(order_params)

    if result.success?
      redirect_to result.value
    else
      redirect_to new_order_path, alert: result.error
    end
  end

  private

  def order_params
    params.expect(order: [:product_id, :quantity])
  end
end
```

**Which response a write failure gets is version- and mode-specific, and it is the `rails-8-idioms`
skill's call, in its "Redirect status codes" section, not this file's.** Under Hotwire, the 8.1
scaffold re-renders with `status: :unprocessable_content` and redirects with `status: :see_other`.
Under Inertia there is no template to re-render, and a failure is a redirect carrying the errors.
Under JSON API the errors go back as a JSON body on the same 422. A bare `render :new` with no
status is stale in any of the three.

`Current.user` is what the Rails 8.1 authentication generator provides. `current_user` comes from
Devise; do not write it into a generated 8.1 app that has no such method.

---

## Review checklist

**N+1 queries**

- [ ] Association reads inside a loop have a matching `includes`, `preload`, or `eager_load`
- [ ] A `joins` used for filtering is paired with a loader if the association is then read
- [ ] Counts on a collection use a counter cache
- [ ] `strict_loading_by_default` is on in development

**Callbacks**

- [ ] Normalization uses `normalizes`
- [ ] No mail, external calls, or writes to other models in `after_create` / `after_save`
- [ ] Side effects are explicit in a service or job

**Model size**

- [ ] Class body at or under 100 lines — `Metrics/ClassLength` `Max: 100` at rubocop 1.89.0, which is
      a review ceiling rather than an enforced limit, because `rubocop-rails-omakase` sets
      `Metrics: Enabled: false`. This is the class measure and it applies to models, controllers, and
      services alike
- [ ] Business logic in services, complex queries in query objects, formatting in presenters

**Performance**

- [ ] Indexes on the columns queries filter and order by, partial where the column is not selective
- [ ] No duplicate index on a `t.references` column, which is already indexed at 8.1
- [ ] `algorithm: :concurrently` with `disable_ddl_transaction!` for an index on a large live table
- [ ] `touch: true` on associations whose records appear inside a parent's cache block

**Controllers**

- [ ] Roughly 10 lines or fewer per action — `Metrics/MethodLength`, `Max: 10` (rubocop 1.89.0);
      the unit is lines of method body with comments excluded, and the role is a review ceiling.
      The `extraction-timing` skill carries the row, in its "Extraction Thresholds" section
- [ ] Strong parameters in the controller, not in the service
- [ ] No business logic in the action body
