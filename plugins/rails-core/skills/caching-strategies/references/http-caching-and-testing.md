# Caching Strategies: HTTP Caching and Testing

## HTTP Caching

### Conditional GET (ETag / Last-Modified)

```ruby
class EventsController < ApplicationController
  def show
    @event = Event.find(params[:id])

    # 304 Not Modified when the validators still match
    if stale?(@event)
      respond_to do |format|
        format.html
        format.json { render json: @event }
      end
    end
  end

  def index
    @events = current_account.events.recent

    if stale?(etag: @events, last_modified: @events.maximum(:updated_at))
      render :index
    end
  end
end
```

`fresh_when(@event)` is the same mechanism where the whole action is the render:

```ruby
def show
  @event = Event.find(params[:id])
  fresh_when(@event)
end
```

Anything in the ETag has to be part of what changes the response, so include the current user or the
role when the body varies by viewer: `fresh_when([ @event, current_user ])`.

### Cache-Control Headers

```ruby
class Api::EventsController < Api::BaseController
  def show
    @event = Event.find(params[:id])

    # A CDN and any browser may cache this for an hour
    expires_in 1.hour, public: true

    render json: @event
  end

  def dashboard
    # This viewer's browser only, for fifteen minutes. private is the default.
    expires_in 15.minutes

    render json: current_account.dashboard
  end
end
```

One `expires_in` per action carries the whole policy, because a second call replaces the options the
first one set. Measured on 8.1.3.1: `expires_in 1.hour, public: true` emits
`Cache-Control: max-age=3600, public`, `expires_in 15.minutes` emits `max-age=900, private`, and the
two together emit `max-age=900, private` — the `public` from the first call is gone. `private:` is
accepted and dropped, since private is already the default.

## Testing Caching

### Spec Configuration

The generated test environment sets `config.cache_store = :null_store`, which accepts every write and
answers every read with a miss. So a caching spec supplies its own store as well as flipping
`perform_caching` — with a real store in place the example can fail, which is the property that makes
it worth writing:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    original_store = Rails.cache
    original_perform_caching = ActionController::Base.perform_caching

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true

    example.run

    ActionController::Base.perform_caching = original_perform_caching
    Rails.cache = original_store
  end
end
```

### Testing a Cached Read

```ruby
RSpec.describe DashboardStatsService, :caching do
  it "computes once and serves the cached value" do
    account = create(:account)
    service = described_class.new

    expect(service).to receive(:calculate_stats).once.and_call_original

    first = service.call(account: account)
    second = service.call(account: account)

    expect(second).to eq(first)
  end
end
```

The `receive(...).once` expectation is what distinguishes a hit from a recompute; asserting only on
the returned value passes whether the cache works or not.

### Testing Invalidation

```ruby
RSpec.describe DashboardStatsService, :caching do
  describe "#invalidate" do
    it "makes the next read recompute" do
      account = create(:account)
      service = described_class.new

      service.call(account: account)
      expect(Rails.cache.exist?([ account, "dashboard_stats" ])).to be true

      service.invalidate(account: account)
      expect(Rails.cache.exist?([ account, "dashboard_stats" ])).to be false
    end
  end
end
```

Both halves of the assertion matter: the `be true` after priming is what proves the store is live, so
the `be false` afterwards means something.

### Testing a Conditional GET

```ruby
RSpec.describe "Events", :caching, type: :request do
  it "answers 304 while the event is unchanged" do
    event = create(:event)

    get event_path(event)
    expect(response).to have_http_status(:ok)
    etag = response.headers["ETag"]

    get event_path(event), headers: { "HTTP_IF_NONE_MATCH" => etag }
    expect(response).to have_http_status(:not_modified)

    event.update!(name: "New Name")

    get event_path(event), headers: { "HTTP_IF_NONE_MATCH" => etag }
    expect(response).to have_http_status(:ok)
  end
end
```

Metadata order in `RSpec.describe`: symbols first, then the keyword pairs —
`RSpec.describe "Events", :caching, type: :request do`. A positional symbol after `type: :request`
is a Ruby syntax error and the whole spec file stops loading.

## Instrumentation

### Fragment Cache Logging

```ruby
# config/environments/production.rb
config.action_controller.enable_fragment_cache_logging = true
```

### Hit and Miss Rates for Every Store

```ruby
# config/initializers/cache_instrumentation.rb
ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info "Cache #{event.payload[:hit] ? 'HIT' : 'MISS'}: #{event.payload[:key]}"
end
```

`cache_read.active_support` fires for every store, `InertiaRails.cache` included, since prop caching
goes through the same `ActiveSupport::Cache::Store`.
