# Testing Strategy by Layer

## Test Pyramid

```
        /\
       /  \  System Specs (few)
      /----\
     /      \  Request Specs (moderate)
    /--------\
   /          \  Unit Specs (many)
  --------------
  Models, Services, Queries, Presenters, Forms, Policies
```

## The Layer-to-Spec-Type Map

This is the map from a layer to its spec type, and a worked example for each row follows
below. **Concern is the one layer in the "Layer Responsibilities" table with no row here**,
because a concern gets no spec file of its own: it is tested through the specs of the models
that include it, which is what the `extraction-timing` skill states in its "Concerns vs
Service Objects" table. The last row is a journey rather than a layer.

**The View and Helper rows apply under Hotwire only.** An Inertia project renders a React
page, and a JSON API project renders no markup at all, so neither has an ERB template or a
view helper to spec. The `rails-architecture` skill's "Response mode" section settles which
mode a project is in. Neither row appears in the "Layer Responsibilities" table: that
table's Presenter row covers view formatting that carries logic, and its "When to keep it
simple" table sends basic text formatting to a helper.

| Layer | Spec file | Declare | The example asserts |
|-------|-----------|---------|---------------------|
| Model | `spec/models/event_spec.rb` | `type: :model` | Non-trivial scopes, business-logic methods, important callbacks |
| Service | `spec/services/orders/create_service_spec.rb` | `type: :model` | Each branch of `#call`, and the Result it returns |
| Query | `spec/queries/confirmed_events_query_spec.rb` | `type: :model` | Which rows come back, and tenant isolation |
| Form | `spec/forms/event_creation_form_spec.rb` | `type: :model` | Validations and attribute casting |
| Presenter | `spec/presenters/event_presenter_spec.rb` | `type: :model` | The formatted string or markup |
| Policy | `spec/policies/event_policy_spec.rb` | `type: :model` | Each question the policy answers, both ways |
| Controller | `spec/requests/events_spec.rb` | `type: :request` | Status, redirect, and what the response contains |
| Component | `spec/components/event_card_component_spec.rb` | `type: :component` | Rendered markup, one example per variant |
| View | `spec/views/events/index.html.erb_spec.rb` | `type: :view` | Markup an ERB template builds on its own |
| Helper | `spec/helpers/events_helper_spec.rb` | `type: :helper` | The string or markup the helper returns |
| Job | `spec/jobs/event_created_job_spec.rb` | `type: :job` | What `perform` does, and that callers enqueue it |
| Mailer | `spec/mailers/event_mailer_spec.rb` | `type: :mailer` | Recipients, subject, and body content |
| Channel | `spec/channels/dashboard_channel_spec.rb` | `type: :channel` | Which stream a subscription opens |
| End to end | `spec/system/create_event_spec.rb` | `type: :system` | One critical journey through the browser |

**Declare the type in the `describe`, in every spec.** rspec-rails 8.0.4 generates
`rails_helper.rb` with `config.infer_spec_type_from_file_location!` commented out, so the
directory a file sits in selects nothing — the metadata does. The type is what supplies the
layer's helpers: `:mailer` brings `ActionMailer::TestCase::Behavior`, `:request` brings
integration-test behaviour, `:channel` brings Action Cable's two test cases, `:system`
brings Capybara. Every generator rspec-rails ships writes the metatag for exactly this
reason.

The six unit rows say `type: :model` because rspec-rails has no example group per PORO
layer. `:model` is the one that gives a plain class the Rails example group, and it reads
as "a unit spec against the database" rather than as a claim about Active Record.

`type: :component` comes from `view_component`, not from rspec-rails: the gem's install
adds `config.include ViewComponent::TestHelpers, type: :component` to `rails_helper.rb`.
With no `view_component` in the `Gemfile` there is no component layer to spec.

## Unit Specs

### Model Specs

Test the logic you wrote: non-trivial scopes, instance methods that carry business
logic, important callbacks, and class methods that orchestrate. A standard Rails
validation and a plain association need no example, because such an example confirms
that Rails works. The `rspec-models` skill is the authority here, and it states the
full rule with its two exceptions — a validation carrying custom business logic, and
uniqueness, whose example has to aim at the database constraint.

```ruby
# spec/models/event_spec.rb
RSpec.describe Event, type: :model do
  describe ".upcoming" do
    let!(:past_event) { create(:event, event_date: Date.current - 1) }
    let!(:future_event) { create(:event, event_date: Date.current + 1) }

    it "returns only future events" do
      expect(described_class.upcoming).to contain_exactly(future_event)
    end
  end

  describe "#days_until" do
    it "counts whole days from today" do
      event = build(:event, event_date: Date.current + 5)

      expect(event.days_until).to eq(5)
    end

    it "is nil without a date" do
      expect(build(:event, event_date: nil).days_until).to be_nil
    end
  end
end
```

`Date.current + 5` rather than `5.days.from_now`: `event_date` is a `date` column, and a
`Time` five days out crosses into the sixth day whenever the suite runs late in the
evening.

### Service Specs

One example per branch of `#call`, asserting on the Result:

```ruby
# spec/services/orders/create_service_spec.rb
RSpec.describe Orders::CreateService, type: :model do
  let(:user) { create(:user) }
  let(:product) { create(:product, inventory: 10) }

  describe ".call" do
    context "with valid params" do
      let(:params) { { items: [{ product_id: product.id, quantity: 2 }] } }

      it "returns success" do
        expect(described_class.call(user: user, params: params)).to be_success
      end

      it "creates an order" do
        expect { described_class.call(user: user, params: params) }.to change(Order, :count).by(1)
      end

      it "returns the order as the Result's data" do
        result = described_class.call(user: user, params: params)

        expect(result.data).to be_a(Order)
      end
    end

    context "with empty items" do
      let(:params) { { items: [] } }

      it "returns a failure coded :empty_cart" do
        result = described_class.call(user: user, params: params)

        expect(result).to be_failure
        expect(result.code).to eq(:empty_cart)
      end

      it "does not create an order" do
        expect { described_class.call(user: user, params: params) }.not_to change(Order, :count)
      end
    end

    context "with insufficient inventory" do
      let(:params) { { items: [{ product_id: product.id, quantity: 100 }] } }

      it "returns a failure coded :out_of_stock" do
        expect(described_class.call(user: user, params: params).code).to eq(:out_of_stock)
      end
    end
  end
end
```

`described_class.call(user:, params:)` is the one signature — `ApplicationService.call`
forwards to `new.call`. Instantiate directly only to inject a collaborator, as in
"Testing with Mocks" in [service-patterns.md](service-patterns.md).

### Query Specs

Which rows come back, and tenant isolation:

```ruby
# spec/queries/confirmed_events_query_spec.rb
RSpec.describe ConfirmedEventsQuery, type: :model do
  subject(:query) { described_class.new(account: account) }

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  describe "#call" do
    let!(:confirmed_event) { create(:event, :confirmed, account: account) }
    let!(:cancelled_event) { create(:event, account: account, status: :cancelled) }
    let!(:other_event) { create(:event, :confirmed, account: other_account) }

    it "returns confirmed events for the account" do
      expect(query.call).to include(confirmed_event)
    end

    it "excludes events in another status" do
      expect(query.call).not_to include(cancelled_event)
    end

    it "excludes another account's events" do
      expect(query.call).not_to include(other_event)
    end
  end
end
```

Every status here is one the enum defines. A status the enum does not define does not fail
loudly in a `where` clause — it compiles to `IS NULL` and returns no rows, so an isolation
example written against it passes for the wrong reason.

### Form Specs

Validations and casting, with no database involved:

```ruby
# spec/forms/event_creation_form_spec.rb
RSpec.describe EventCreationForm, type: :model do
  it "rejects a date in the past" do
    form = described_class.new(name: "Gala", event_date: Date.current - 1)

    expect(form).not_to be_valid
    expect(form.errors[:event_date]).to be_present
  end

  it "casts vendor_ids to integers and drops blanks" do
    form = described_class.new(vendor_ids: ["7", "", "9"])

    expect(form.vendor_ids).to eq([7, 9])
  end

  it "defaults vendor_ids to a fresh array" do
    expect(described_class.new.vendor_ids).to eq([])
  end
end
```

### Presenter Specs

```ruby
# spec/presenters/event_presenter_spec.rb
RSpec.describe EventPresenter, type: :model do
  let(:event) { create(:event, name: "Test Event", status: :confirmed) }
  let(:presenter) { described_class.new(event) }

  it "delegates to the model" do
    expect(presenter.name).to eq("Test Event")
  end

  describe "#status_badge" do
    it "is HTML-safe" do
      expect(presenter.status_badge).to be_html_safe
    end

    it "labels the status" do
      expect(presenter.status_badge).to include("Confirmed")
    end

    it "colours by status" do
      expect(presenter.status_badge).to include("bg-green")
    end
  end

  describe "#formatted_date" do
    it "formats a date" do
      event.update!(event_date: Date.new(2026, 7, 15))

      expect(presenter.formatted_date).to include("2026")
    end

    it "renders a placeholder without one" do
      event.update!(event_date: nil)

      expect(presenter.formatted_date).to include("text-slate-400")
    end
  end
end
```

### Helper Specs

Under Hotwire only. A helper earns a spec once it branches or formats; one that only
delegates to a presenter does not, because the presenter's spec already covers the string.

```ruby
# spec/helpers/events_helper_spec.rb
RSpec.describe EventsHelper, type: :helper do
  describe "#event_date_label" do
    it "formats a date" do
      expect(helper.event_date_label(Date.new(2026, 7, 15))).to eq("15 July 2026")
    end

    it "labels a missing date" do
      expect(helper.event_date_label(nil)).to eq("Date to be confirmed")
    end
  end
end
```

Call the method on `helper`, not on `described_class`. `described_class` is a module, and
its methods are instance methods, so a call on the module itself raises `NoMethodError`.
`helper` is an `ActionView::Base` with that module mixed in, plus `ApplicationHelper` and
every built-in Rails helper (rspec-rails,
`lib/rspec/rails/example/helper_example_group.rb:22-27`). That is what a helper calling
`link_to` or `number_to_currency` needs around it.

## Integration Specs

### Request Specs

Status, redirect and response body:

```ruby
# spec/requests/events_spec.rb
RSpec.describe "Events", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }

  before { sign_in_as(user) }

  describe "GET /events" do
    let!(:event) { create(:event, account: account) }
    let!(:other_event) { create(:event) }

    it "returns success" do
      get events_path

      expect(response).to have_http_status(:ok)
    end

    it "shows the account's own events" do
      get events_path

      expect(response.body).to include(event.name)
    end

    it "does not show another account's events" do
      get events_path

      expect(response.body).not_to include(other_event.name)
    end
  end

  describe "POST /events" do
    let(:valid_params) { { event: { name: "New Event", event_date: Date.current + 7 } } }

    it "creates the event" do
      expect { post events_path, params: valid_params }.to change(Event, :count).by(1)
    end

    it "redirects to it" do
      post events_path, params: valid_params

      expect(response).to redirect_to(Event.last)
    end

    context "with invalid params" do
      it "re-renders the form" do
        post events_path, params: { event: { name: "" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
```

`:unprocessable_content` is the current 422 symbol; `:unprocessable_entity` is obsolete in
Rack 3.2 and warns. And an Inertia controller answers a validation failure with a
**redirect**, not a 422 — assert on the redirect and the `errors` prop instead, using the
`inertia-rails-testing` skill in the `inertia-react` plugin.

**Write the sign-in helper yourself.** `sign_in` is Devise's, and there is no Devise in a
generated Rails 8.1 app. Rails' authentication generator writes a `SessionTestHelper` and
auto-includes it into *integration* tests, but that is the Minitest half of the generator;
rspec-rails 8.0.4's hook writes only a user spec and a fixture, so nothing lands in
`spec/`. Copy the module across:

```ruby
# spec/support/session_test_helper.rb
module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

RSpec.configure do |config|
  config.include SessionTestHelper, type: :request
end
```

A system spec signs in through the form instead, because the cookie jar the helper writes
to is the test request's, not the browser's.

### Policy Specs

```ruby
# spec/policies/event_policy_spec.rb
RSpec.describe EventPolicy, type: :model do
  subject { described_class.new(user, event) }

  let(:account) { create(:account) }
  let(:event) { create(:event, account: account) }

  context "when the user owns the event" do
    let(:user) { create(:user, account: account) }

    it { is_expected.to permit_actions([:show, :edit, :update, :destroy]) }
  end

  context "when the user is from another account" do
    let(:user) { create(:user) }

    it { is_expected.to forbid_actions([:show, :edit, :update, :destroy]) }
  end

  describe "Scope" do
    let(:user) { create(:user, account: account) }
    let!(:own_event) { create(:event, account: account) }
    let!(:other_event) { create(:event) }

    it "returns only the account's events" do
      scope = EventPolicy::Scope.new(user, Event.all).resolve

      expect(scope).to include(own_event)
      expect(scope).not_to include(other_event)
    end
  end
end
```

Every action named in `permit_actions` is defined on the policy. `permit_actions` and
`forbid_actions` come from `pundit-matchers`, and Pundit's own base class answers an
undefined `destroy?` with `false`, so a policy missing one fails an otherwise correct
example.

## Job Specs

A job spec answers two questions, and they are asserted from different places: does
`perform` do the work, and does the caller enqueue it?

```ruby
# spec/jobs/event_created_job_spec.rb
RSpec.describe EventCreatedJob, type: :job do
  let(:event) { create(:event) }

  it "emails the account owner" do
    expect { described_class.perform_now(event.id) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)
  end

  it "broadcasts the dashboard stats" do
    expect { described_class.perform_now(event.id) }
      .to have_broadcasted_to(event.account).from_channel(DashboardChannel)
  end
end
```

```ruby
# in spec/services/events/create_service_spec.rb — the caller's spec
it "enqueues the notification job" do
  expect { described_class.call(account: account, form: form) }
    .to have_enqueued_job(EventCreatedJob)
end
```

Three facts about the ActiveJob matchers, all of them things that bite once:

- **They need the test adapter.** `have_enqueued_job`, `have_been_enqueued` and
  `have_performed_job` read `ActiveJob::Base.queue_adapter.enqueued_jobs`, and rspec-rails
  checks first: without it you get `StandardError: To use ActiveJob matchers set
  'ActiveJob::Base.queue_adapter = :test'`. Set it in `rails_helper.rb`. A Rails 8 app
  running Solid Queue does not have it by default.
- **`perform_enqueued_jobs` is not included for you.** It belongs to
  `ActiveJob::TestHelper`, and rspec-rails' job example group includes only the common
  Rails group. Add `config.include ActiveJob::TestHelper, type: :job` if you want it.
- **`perform_now` tests the body; `perform_later` tests the enqueue.** Calling
  `perform_later` and expecting side effects asserts nothing under the test adapter, which
  records the job instead of running it.

`have_broadcasted_to` has the same shape of requirement and the generated
`config/cable.yml` already meets it — `test: adapter: test` — so that one needs no setup.
Without it the matcher raises ``To use ActionCable matchers set `adapter: test` in your
cable.yml``.

## Mailer Specs

`type: :mailer` includes `ActionMailer::TestCase::Behavior`, which switches the delivery
method to `:test` and resets `ActionMailer::Base.deliveries` around every example, so a
mailer spec needs no cleanup of its own.

```ruby
# spec/mailers/event_mailer_spec.rb
RSpec.describe EventMailer, type: :mailer do
  describe "#created" do
    let(:user) { create(:user, email_address: "owner@example.com") }
    let(:event) { create(:event, name: "Company Party", account: user.account) }
    let(:mail) { described_class.created(event) }

    it "addresses the account owner" do
      expect(mail.to).to eq(["owner@example.com"])
    end

    it "names the event in the subject" do
      expect(mail.subject).to include("Company Party")
    end

    it "names the event in the body" do
      expect(mail.body.encoded).to include("Company Party")
    end
  end
end
```

Calling the mailer method returns a `Mail::Message` and delivers nothing, which is why
these examples assert on `mail` rather than on `deliveries`. Assert on `deliveries` when
what you are testing is that something *sent* mail — as the job spec above does — and use
`have_enqueued_mail(EventMailer, :created)` when the caller uses `deliver_later`. That
matcher reads the same test adapter as `have_enqueued_job`.

## Channel Specs

```ruby
# spec/channels/dashboard_channel_spec.rb
RSpec.describe DashboardChannel, type: :channel do
  let(:user) { create(:user) }

  before { stub_connection(current_user: user) }

  it "streams for the user's account" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(user.account)
  end
end
```

`stub_connection`, `subscribe` and `subscription` come with `type: :channel`;
`have_stream_for` and `have_stream_from` are defined by rspec-rails' channel example group.

## System Specs

One example per critical journey:

```ruby
# spec/system/create_event_spec.rb
RSpec.describe "Creating an event", type: :system do
  let(:user) { create(:user, password: "s3cret-passphrase") }

  before do
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "s3cret-passphrase"
    click_button "Sign in"
  end

  it "creates an event" do
    visit new_event_path

    fill_in "Name", with: "Company Party"
    fill_in "Event date", with: Date.current + 30
    select "Corporate", from: "Event type"
    click_button "Create Event"

    expect(page).to have_content("Company Party")
  end

  it "shows validation errors" do
    visit new_event_path
    click_button "Create Event"

    expect(page).to have_content("Name can't be blank")
  end
end
```

## Component Specs

```ruby
# spec/components/event_card_component_spec.rb
RSpec.describe EventCardComponent, type: :component do
  let(:event) { create(:event, name: "Test Event", status: :confirmed) }

  it "renders the event name" do
    render_inline(described_class.new(event: event))

    expect(page).to have_content("Test Event")
  end

  it "renders the status badge" do
    render_inline(described_class.new(event: event))

    expect(page).to have_css("span.rounded-full", text: "Confirmed")
  end
end
```

Assert on markup the component actually emits. The presenter's `status_badge` builds a
`span` with `inline-flex px-2 py-1 rounded-full …` and no `badge` class, so
`have_css(".badge")` fails against a component that renders correctly — and a spec that
fails for the wrong reason gets "fixed" by changing the component.

## View Specs

Under Hotwire only. A view spec earns its keep where the template decides something on its
own — a conditional, a loop, an empty state. Where the template only prints what the action
assigned, the request spec already covers the markup, and a view spec adds a second file to
change for one edit.

```ruby
# spec/views/events/index.html.erb_spec.rb
RSpec.describe "events/index", type: :view do
  it "lists each event by name" do
    assign(:events, [build_stubbed(:event, name: "Summer Gala")])

    render

    expect(rendered).to have_content("Summer Gala")
  end

  it "says so when there are none" do
    assign(:events, [])

    render

    expect(rendered).to have_content("No events yet")
  end
end
```

The describe string is the template's path with its extensions dropped, and `assign` sets
the instance variable the template reads. `rendered` is a String, and `have_content` and
`have_link` are Capybara's: rspec-rails includes `Capybara::RSpecMatchers` into a view spec
and a helper spec (`lib/rspec/rails/vendor/capybara.rb:19-20`), and only where Capybara is
loaded. Without it, assert with `include` or `match` instead.

## Test Helpers

### Shared Examples

```ruby
# spec/support/shared_examples/tenant_isolation.rb
RSpec.shared_examples "tenant isolated" do
  it "excludes another tenant's data" do
    other_record = create(factory, account: create(:account))

    expect(subject).not_to include(other_record)
  end
end
```

```ruby
RSpec.describe ConfirmedEventsQuery, type: :model do
  subject { described_class.new(account: account).call }

  let(:account) { create(:account) }
  let(:factory) { :event }

  it_behaves_like "tenant isolated"
end
```

### Factory Traits

`factory_bot_rails` and `faker` are gems; check the `Gemfile` before writing factories.

```ruby
# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    account
    name { Faker::Company.name }
    event_date { Date.current + 30 }
    status { :draft }

    trait :confirmed do
      status { :confirmed }
    end

    trait :past do
      event_date { Date.current - 30 }
    end

    trait :with_vendors do
      after(:create) do |event|
        create_list(:event_vendor, 3, event: event)
      end
    end
  end
end
```

## Coverage

This skill states no coverage percentage. A floor that a suite can enforce belongs in the
suite: `SimpleCov.minimum_coverage` and `minimum_coverage_by_group` in
`spec/spec_helper.rb` both gate the exit code, where a number written in a skill gates
nothing. Per-layer line coverage is also the metric most cheaply satisfied without testing
anything, which is the pressure the `rspec-models` skill's rule against confirming-Rails
examples exists to resist.

## Checklist

- [ ] Every spec declares its `type:`
- [ ] Model specs for every model that carries its own logic
- [ ] Service specs cover every branch of `#call`, asserting on the Result
- [ ] Query specs test tenant isolation
- [ ] Request specs for every endpoint, with a sign-in helper you control
- [ ] Policy specs assert every action the policy answers, both ways
- [ ] Job specs call `perform_now`; callers assert `have_enqueued_job`
- [ ] Mailer specs assert recipients, subject and body
- [ ] Channel specs assert the stream a subscription opens
- [ ] System specs for critical flows
- [ ] Component specs assert markup the component emits
- [ ] Under Hotwire, view specs for templates that branch, and helper specs for helpers that format
- [ ] Shared examples for repeated assertions, factory traits for common states
