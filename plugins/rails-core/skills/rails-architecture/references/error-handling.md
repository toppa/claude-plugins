# Error Handling Strategies

## Result Object Pattern (Preferred)

Services return a `Result` instead of raising. There is one definition of it, in this
skill's SKILL.md under "Result Objects for Services": a five-member `Data` with
`Result.success` and `Result.failure` constructors. Everything below assumes that one.

Two of its members do the work here:

- `code` — a symbol the caller branches on. It never reaches a user.
- `details` — client-safe extras, such as field-level messages. Anything rendered back to
  a client comes from here, which is what keeps the success payload in `data` out of error
  responses.

## Error Codes Without a Registry

A code per failure the caller has to distinguish, and a message from a locale file:

```ruby
module Orders
  class CreateService < ApplicationService
    def call(user:, params:)
      return failure(message(:empty_cart), code: :empty_cart) if params[:items].blank?
      return failure(message(:out_of_stock), code: :out_of_stock) unless inventory_available?(params[:items])

      success(create_order(user, params))
    rescue PaymentGateway::Declined
      failure(message(:payment_declined), code: :payment_declined)
    rescue ActiveRecord::RecordInvalid => e
      failure(
        message(:validation_failed),
        code: :validation_failed,
        details: e.record.errors.to_hash
      )
    end

    private

    def message(code) = I18n.t(code, scope: "services.orders.errors")
  end
end
```

```yaml
# config/locales/en.yml
en:
  services:
    orders:
      errors:
        empty_cart: "Your cart is empty"
        out_of_stock: "One or more items are out of stock"
        payment_declined: "Your payment was declined"
        validation_failed: "Please check your order details"
```

The codes need no registry of their own. A constant mapping `:empty_cart` to `:empty_cart`
adds a place to update and nothing else; the symbol in the `failure` call *is* the code,
and the locale file is what turns it into words.

## Controller Error Handling

### Handle by Error Code

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.call(user: current_user, params: order_params)

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      handle_error(result)
    end
  end

  private

  def handle_error(result)
    case result.code
    when :empty_cart
      redirect_to cart_path, alert: result.error
    when :out_of_stock
      @out_of_stock = true
      re_render(result)
    when :payment_declined
      redirect_to payment_path, alert: result.error
    else
      re_render(result)
    end
  end

  def re_render(result)
    @order = Order.new(order_params)
    @errors = result.details
    flash.now[:alert] = result.error
    render :new, status: :unprocessable_content
  end
end
```

`re_render` re-assigns everything `#new` assigned, because `render :new` runs that template
with none of `#new`'s setup. In an Inertia app this branch is a **redirect** carrying
`inertia: { errors: }` instead — there is no ERB template to re-render. See "Skinny
Controllers" in this skill's SKILL.md.

### Pattern Matching (Ruby 3+)

`Data` supplies `deconstruct_keys`, so a `Result` matches on any subset of its members:

```ruby
def create
  case Orders::CreateService.call(user: current_user, params: order_params)
  in { success: true, data: order }
    redirect_to order, notice: t(".success")
  in { code: :empty_cart }
    redirect_to cart_path, alert: t(".empty_cart")
  in { code: :payment_declined, error: message }
    redirect_to payment_path, alert: message
  in { error: message, details: }
    @order = Order.new(order_params)
    @errors = details
    flash.now[:alert] = message
    render :new, status: :unprocessable_content
  end
end
```

## API Error Responses

### Consistent Error Format

```ruby
# app/controllers/api/base_controller.rb
module Api
  class BaseController < ApplicationController
    private

    def render_error(result, status: :unprocessable_content)
      render json: {
        error: {
          code: result.code,
          message: result.error,
          details: result.details
        }
      }, status: status
    end

    def render_success(data, status: :ok)
      render json: { data: data }, status: status
    end
  end
end
```

`details`, not `data`. Serialising `result.data` into an error body is how a record reaches
a client that was only supposed to learn that its request failed, and no checklist item
about sensitive data can prevent it — the two slots have to be different slots.

### HTTP Status Mapping

```ruby
ERROR_STATUS_MAP = {
  not_found: :not_found,
  unauthorized: :unauthorized,
  forbidden: :forbidden,
  validation_failed: :unprocessable_content,
  conflict: :conflict,
  rate_limited: :too_many_requests
}.freeze

def render_service_result(result)
  if result.success?
    render_success(result.data)
  else
    render_error(result, status: ERROR_STATUS_MAP.fetch(result.code, :unprocessable_content))
  end
end
```

`:unprocessable_content` is the current symbol for 422. `:unprocessable_entity` still
resolves in Rack 3.2 but is obsolete and warns.

## Exception Handling Layers

### Service Layer (Catch and Wrap)

```ruby
class ExternalApiService < ApplicationService
  def call(params)
    success(client.request(params).data)
  rescue Faraday::TimeoutError
    failure(I18n.t("services.errors.timeout"), code: :timeout)
  rescue Faraday::ConnectionFailed
    failure(I18n.t("services.errors.connection_failed"), code: :connection_failed)
  rescue JSON::ParserError
    failure(I18n.t("services.errors.invalid_response"), code: :invalid_response)
  end
end
```

The exception classes belong to whichever HTTP client the project uses — these are
`faraday`'s. Check the `Gemfile` and rescue the classes that are actually there.

### Controller Layer (Rescue From)

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found }
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end
end
```

Add `rescue_from Pundit::NotAuthorizedError, with: :forbidden` when the project has
`pundit`; with a PORO policy the controller decides for itself what to do with a `false`
answer, and there is no exception to rescue.

### Global Error Handler

```ruby
# config/initializers/error_handler.rb
Rails.application.config.exceptions_app = ->(env) {
  ErrorsController.action(:show).call(env)
}
```

```ruby
# app/controllers/errors_controller.rb
class ErrorsController < ApplicationController
  allow_unauthenticated_access

  def show
    @status = request.path_info.delete("/").to_i
    render status: @status
  end
end
```

`allow_unauthenticated_access` is what the Rails 8.1 authentication generator gives you —
its `Authentication` concern installs `before_action :require_authentication` and exposes
that class method. `skip_before_action :authenticate_user!` names Devise's callback and
raises `ArgumentError` in a generated Rails 8 app, because there is no such callback to
skip.

Setting `exceptions_app` from an initializer works: the middleware stack is built after
`load_config_initializers`, and it reads the setting then.

## Validation Errors

### Model Validations to Result

```ruby
def call(params)
  record = Model.new(params)
  return success(record) if record.save

  failure(
    record.errors.full_messages.to_sentence,
    code: :validation_failed,
    details: record.errors.to_hash
  )
end
```

### Display Validation Errors

```ruby
# in the controller
@errors = result.details if result.code == :validation_failed
```

```erb
<% if @errors&.dig(:email) %>
  <p class="text-red-500"><%= @errors[:email].to_sentence %></p>
<% end %>
```

`errors.to_hash` gives `{ email: ["can't be blank"] }` — keyed by attribute, which is what
lets a form put each message next to its own input.

In an Inertia app there is no ERB template here either. Redirect with
`inertia: { errors: result.details }` and read them from the page's `errors` prop, as the
`re_render` note above states for the controller side.

## Logging Errors

Give `ApplicationService#failure` a logging step, so every service logs its failures
without any of them having to remember to:

```ruby
class ApplicationService
  private

  def failure(error, code: :error, details: nil, exception: nil)
    log_failure(code, error, exception)
    Result.failure(error, code: code, details: details)
  end

  def log_failure(code, error, exception)
    Rails.logger.error({
      service: self.class.name,
      error_code: code,
      message: error,
      exception: exception&.class&.name,
      backtrace: exception&.backtrace&.first(5)
    }.to_json)
  end
end
```

## Error Tracking Integration

Report the failures nobody expected, and stay quiet about the ones the code already
handles:

```ruby
def failure(error, code: :error, details: nil, exception: nil)
  Sentry.capture_exception(exception, extra: { code: code }) if exception && report?(code)

  Result.failure(error, code: code, details: details)
end

def report?(code)
  ![:validation_failed, :not_found, :unauthorized].include?(code)
end
```

`Sentry` needs the `sentry-ruby` gem; `Rails.error.report(exception, context: { code: })`
is the framework's own reporter and needs nothing.

## Checklist

- [ ] Services return the one `Result`
- [ ] Error codes are symbols the caller branches on
- [ ] Controllers branch on the code, not on the message text
- [ ] API error bodies read `details`, never `data`
- [ ] Unexpected errors reach the tracker with context
- [ ] User-facing messages come from a locale file
- [ ] A re-render branch re-assigns everything the `new` action assigned
