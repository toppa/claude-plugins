# Layer Interactions

Detailed examples of how architectural layers communicate in a Rails 8 application.

Everything below is one **server-rendered** feature: it renders ERB templates and
ViewComponents, so its controller re-renders on failure. In an Inertia app the failure
branch redirects with `inertia: { errors: }` instead — see "Skinny Controllers" in this
skill's SKILL.md. The Policy and Component steps assume `pundit` and `view_component`;
SKILL.md's "What Needs a Gem" table gives the fallback when they are absent.

## Base Classes

Three of the five superclasses used below are yours to write. `ApplicationPolicy` comes
from `bin/rails generate pundit:install` and `ApplicationComponent` from
`bin/rails generate component`, so let the generators write those.

```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(...) = new.call(...)

  private

  def success(data = nil) = Result.success(data)

  def failure(error, code: :error, details: nil) = Result.failure(error, code: code, details: details)
end
```

```ruby
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
end
```

```ruby
# app/presenters/base_presenter.rb
class BasePresenter < SimpleDelegator
  include ActionView::Helpers::TagHelper

  def model = __getobj__

  private

  def not_specified_span
    tag.span(I18n.t("common.not_specified"), class: "text-slate-400")
  end
end
```

`SimpleDelegator` forwards `to_model`, so `link_to event.name, event` routes correctly
with a presenter in place of the record. `model` is there for the cases that need the
record itself, such as `policy(event.model)`.

`Result` is defined once, in SKILL.md's "Result Objects for Services".

## Request Flow Example

A complete example showing how layers interact for creating an event with vendors.

### 1. Controller (Entry Point)

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def new
    @form = EventCreationForm.new
  end

  def create
    authorize Event

    @form = EventCreationForm.new(event_params)
    return render(:new, status: :unprocessable_content) unless @form.valid?

    result = Events::CreateService.call(account: current_account, form: @form)

    if result.success?
      EventCreatedJob.perform_later(result.data.id)
      redirect_to result.data, notice: t(".success")
    else
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_content
    end
  end

  private

  def event_params
    params.expect(event: [:name, :event_date, :event_type, vendor_ids: []])
  end
end
```

The controller hands the **form object** to the service, not `@form.attributes`.
`ActiveModel::Attributes#attributes` returns String keys, so a service reading
`params[:name]` off that hash gets `nil` for every field and the create fails on the
model's own presence validations. Typed readers — `form.name` — cannot drift that way.

### 2. Form Object (Input Handling)

```ruby
# app/forms/event_creation_form.rb
class EventCreationForm < ApplicationForm
  attribute :name, :string
  attribute :event_date, :date
  attribute :event_type, :string
  attribute :vendor_ids, default: -> { [] }

  validates :name, presence: true
  validates :event_date, presence: true
  validate :event_date_in_future

  def vendor_ids=(value)
    super(Array(value).compact_blank.map(&:to_i))
  end

  private

  def event_date_in_future
    return if event_date.blank?

    errors.add(:event_date, :in_past) if event_date < Date.current
  end
end
```

Two things about `vendor_ids`. `ActiveModel` has no `array:` option — that is an Active
Record PostgreSQL column option, and passed here it is silently discarded, leaving the
attribute untyped and a String reading back as a String. Casting in the writer is explicit
and does the compacting the form actually wants. And `default: -> { [] }` builds a fresh
array per instance, where `default: []` would share one array across every form object in
the process.

### 3. Service Object (Business Logic)

```ruby
# app/services/events/create_service.rb
module Events
  class CreateService < ApplicationService
    def call(account:, form:)
      event = nil

      ActiveRecord::Base.transaction do
        event = account.events.create!(
          name: form.name,
          event_date: form.event_date,
          event_type: form.event_type
        )

        attach_vendors(event, form.vendor_ids)
      end

      success(event)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence, code: :validation_failed)
    end

    private

    def attach_vendors(event, vendor_ids)
      return if vendor_ids.blank?

      event.vendors = event.account.vendors.where(id: vendor_ids)
    end
  end
end
```

`attach_vendors` resolves the ids **through the account**. Ids arrive from a form, so a
bare `event.event_vendors.create!(vendor_id: id)` attaches whatever id was posted,
including another tenant's vendor — the multi-tenancy rule applies to writes exactly as it
does to reads. `event.vendors =` issues one insert per join row; for a long list,
`insert_all!` on the join model does it in one statement, at the cost of skipping
callbacks and needing `created_at`/`updated_at` supplied.

There is no `update_account_stats` step. Rails maintains the count inside the insert:

```ruby
class Event < ApplicationRecord
  belongs_to :account, counter_cache: :events_count
end
```

That needs an `events_count` integer column on `accounts`. A hand-rolled
`account.update_column(:events_count, account.events.count)` reads and then writes with no
lock, so two concurrent creates both read the pre-insert count and one is lost for good.

### 4. Model (Data & Validations)

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  belongs_to :account, counter_cache: :events_count
  has_many :event_vendors, dependent: :destroy
  has_many :vendors, through: :event_vendors

  validates :name, presence: true
  validates :event_date, presence: true

  enum :event_type, { wedding: 0, corporate: 1, private_event: 2 }
  enum :status, { draft: 0, confirmed: 1, completed: 2, cancelled: 3 }

  scope :upcoming, -> { where(event_date: Date.current..) }
  scope :recent, -> { order(created_at: :desc) }

  def days_until
    return if event_date.nil?

    (event_date - Date.current).to_i
  end
end
```

The third `event_type` is `private_event`, not `private`. `enum` generates a class-level
scope per value, and Active Record refuses to generate one that would overwrite a
restricted class method — `RESTRICTED_CLASS_METHODS` is `private public protected allocate
new name superclass` — so `private: 2` raises `ArgumentError` **while the class body is
loading**, taking every file that references the model with it. The same applies to a
status named `new`.

### 5. Policy (Authorization)

```ruby
# app/policies/event_policy.rb
class EventPolicy < ApplicationPolicy
  def show? = owner?

  def edit? = update?

  def update? = owner? && !record.completed?

  def destroy? = owner?

  def create?
    user.account_id.present?
  end

  private

  def owner?
    record.account_id == user.account_id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(account_id: user.account_id)
    end
  end
end
```

Every action a view or a spec asks about is defined here. Pundit's base class answers
`edit?` with `update?` but answers `destroy?` with `false`, so a policy that omits
`destroy?` silently forbids it.

### 6. Background Job (Async Processing)

```ruby
# app/jobs/event_created_job.rb
class EventCreatedJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find(event_id)

    EventMailer.created(event).deliver_now
    DashboardChannel.broadcast_stats(event.account)

    ActivityService.call(account: event.account, action: :event_created, resource: event)
  end
end
```

`deliver_now` inside a job, not `deliver_later`. The work is already off the request, so
`deliver_later` only enqueues a second job — another queue hop, another retry surface, and
a delay before the mail goes out.

### 7. Mailer (Email)

```ruby
# app/mailers/event_mailer.rb
class EventMailer < ApplicationMailer
  def created(event)
    @event = event
    @user = event.account.users.first

    mail(to: @user.email_address, subject: t(".subject", name: event.name))
  end
end
```

Rails 8.1's generated `User` normalizes and validates `email_address`, so that is the
attribute a mailer reads.

### 8. Query Object (Complex Queries)

The controller and the channel both call the same query object. It is defined once, under
"Dashboard Queries" in [query-patterns.md](query-patterns.md):

```ruby
stats = DashboardStatsQuery.new(account: account).call
```

### 9. Presenter (View Formatting)

```ruby
# app/presenters/event_presenter.rb
class EventPresenter < BasePresenter
  STATUS_CLASSES = {
    draft: "bg-slate-100 text-slate-800",
    confirmed: "bg-green-100 text-green-800",
    completed: "bg-blue-100 text-blue-800",
    cancelled: "bg-red-100 text-red-800"
  }.freeze

  def status_badge
    tag.span(
      status_text,
      class: "inline-flex px-2 py-1 rounded-full text-xs font-medium #{status_class}"
    )
  end

  def formatted_date
    return not_specified_span if event_date.nil?

    I18n.l(event_date, format: :long)
  end

  def vendor_count_text
    I18n.t("events.vendors_count", count: vendors.size)
  end

  private

  def status_text
    I18n.t(status, scope: "events.statuses", default: status.humanize)
  end

  def status_class
    STATUS_CLASSES.fetch(status.to_sym, STATUS_CLASSES[:draft])
  end
end
```

`events.statuses.*` is a key the app defines in its own locale file; Rails has no
convention that translates enum *values*, and
`activerecord.attributes.event/statuses.confirmed` is not one — that scope names
attributes, not their values. `I18n.t` returns the literal string
`"Translation missing: …"` for an absent key rather than raising, which is how a wrong key
survives to production, so the `default:` is what makes the presenter readable before the
locale file exists. `events.vendors_count` has no default because a count needs `one:` and
`other:` in the locale file, which a fallback string cannot supply.

### 10. ViewComponent (Reusable UI)

```ruby
# app/components/event_card_component.rb
class EventCardComponent < ApplicationComponent
  def initialize(event:)
    @event = EventPresenter.new(event)
  end

  attr_reader :event
end
```

```erb
<%# app/components/event_card_component.html.erb %>
<article class="bg-white rounded-lg shadow p-6">
  <header class="flex justify-between items-start">
    <h3 class="text-lg font-semibold"><%= event.name %></h3>
    <%= event.status_badge %>
  </header>

  <dl class="mt-4 space-y-2">
    <div>
      <dt class="text-sm text-slate-500"><%= t(".date") %></dt>
      <dd><%= event.formatted_date %></dd>
    </div>
    <div>
      <dt class="text-sm text-slate-500"><%= t(".vendors") %></dt>
      <dd><%= event.vendor_count_text %></dd>
    </div>
  </dl>

  <footer class="mt-4 flex gap-2">
    <%= link_to t("common.view"), event, class: "btn btn-primary" %>
    <% if policy(event.model).edit? %>
      <%= link_to t("common.edit"), edit_event_path(event), class: "btn btn-secondary" %>
    <% end %>
  </footer>
</article>
```

### 11. Channel (Real-time)

```ruby
# app/channels/dashboard_channel.rb
class DashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user.account
  end

  def self.broadcast_stats(account)
    broadcast_to(account, type: "stats_update", data: DashboardStatsQuery.new(account: account).call)
  end
end
```

## Layer Communication Rules

### Who Calls Whom

```
Controller → Model, Service, Query, Policy, Form, Presenter
Service    → Model, Query, Job, Mailer, Channel
Query      → Model (reads)
Job        → Service, Mailer, Channel
Presenter  → Model (reads)
Component  → Presenter, Policy
Channel    → Query
```

Read the arrows as the whole permission: a Query reads models, which is also the statement
that it does not write them or call a service, and a Presenter formats what it reads,
which is the statement that it has no side effects. A model with a callback that reaches
back into a controller or a service is the one case worth naming outright, because the
call is invisible at the call site.

## Data Flow Patterns

### Pattern 1: Simple CRUD

```
Request → Controller → Model → View
```

### Pattern 2: Complex Business Logic

```
Request → Controller → Service → Model → Presenter → Component → Response
                    ↘ Job → Mailer
```

### Pattern 3: Dashboard with Stats

```
Request → Controller → Query → Presenter → Component → Response
                    ↘ Policy (for authorization)
```

### Pattern 4: Real-time Updates

```
Service → Channel → WebSocket → Client
       ↘ Job (async)
```

### Pattern 5: Form with Multiple Models

```
Request → Controller → Form Object → Service → Models → Response
```

## Testing Each Layer

The layer-to-spec-type map, and a worked example per layer, are in
[testing-strategy.md](testing-strategy.md).
