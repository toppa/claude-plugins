# Service Object Patterns

Every service here inherits `ApplicationService`, which supplies `.call`, `success` and
`failure`. It is defined once, under "Base Classes" in
[layer-interactions.md](layer-interactions.md), and the `Result` it returns is defined in
this skill's SKILL.md.

## Basic Service Structure

```ruby
# app/services/[namespace]/[verb]_service.rb
module Namespace
  class VerbService < ApplicationService
    def call(account:, params:)
      return failure(t_error(:invalid_input), code: :invalid_input) unless valid?(params)

      success(perform_operation(account, params))
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence, code: :validation_failed)
    end

    private

    def t_error(code) = I18n.t(code, scope: "services.errors")
  end
end
```

Two things this template does deliberately.

**It returns the value it just computed.** A template that ends `success(result)` without
assigning `result` raises `NameError` — and if the `rescue` is broad enough to catch it,
the service returns `failure("undefined local variable or method 'result'")`, so a bug in
the service reports itself to the user as a validation failure.

**It rescues named exceptions.** `rescue StandardError` converts `NoMethodError`,
`TypeError` and `KeyError` into user-facing messages and keeps them out of the error
tracker, which is the opposite of what you want from the one class that knows an operation
failed. Rescue what you can explain; let the rest reach the tracker.

## Service Categories

### 1. Command Services (Write Operations)

Single action that changes state:

```ruby
# app/services/orders/create_service.rb
module Orders
  class CreateService < ApplicationService
    def call(user:, params:)
      return failure(message(:empty_cart), code: :empty_cart) if params[:items].blank?

      order = nil

      ActiveRecord::Base.transaction do
        order = user.orders.create!(status: :pending)
        create_line_items(order, params[:items])
        reserve_inventory(params[:items])
      end

      OrderMailer.confirmation(order).deliver_later
      success(order)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence, code: :validation_failed)
    end

    private

    def message(code) = I18n.t(code, scope: "services.orders.errors")
  end
end
```

Call it as `Orders::CreateService.call(user: current_user, params: order_params)`. One
signature, everywhere: `.call` on the class, keywords in, a `Result` out. A second arity
for the same method is the thing that makes a service unusable from a spec without reading
it first.

### 2. Query Services (Read Operations)

Complex reads that don't fit in Query Objects:

```ruby
# app/services/reports/generate_service.rb
module Reports
  class GenerateService < ApplicationService
    def call(account:, date_range:, format:)
      success(format_data(gather_data(account, date_range), format))
    end

    private

    def gather_data(account, range)
      {
        events: EventStatsQuery.new(account: account).call(range),
        revenue: RevenueQuery.new(account: account).call(range),
        leads: LeadConversionQuery.new(account: account).call(range)
      }
    end
  end
end
```

### 3. Integration Services (External APIs)

Wrap external service calls. The gateway is injected, so the spec never reaches the
network:

```ruby
# app/services/payments/charge_service.rb
module Payments
  class ChargeService < ApplicationService
    def initialize(gateway: StripeGateway.new)
      @gateway = gateway
    end

    def call(order:, payment_method_id:)
      charge = gateway.charge(
        amount: order.total_cents,
        currency: "eur",
        payment_method_id: payment_method_id
      )

      order.update!(payment_status: :paid, payment_reference: charge.id)

      success(charge)
    rescue PaymentGateway::CardDeclined => e
      failure(e.message, code: :card_declined)
    rescue PaymentGateway::Error => e
      failure(e.message, code: :payment_error)
    end

    private

    attr_reader :gateway
  end
end
```

An HTTP client is a gem: `faraday`, `httparty` or Ruby's own `net/http`. Check the
`Gemfile` before naming one.

### 4. Orchestrator Services (Complex Workflows)

Coordinate several services, returning the first failure:

```ruby
# app/services/onboarding/complete_service.rb
module Onboarding
  class CompleteService < ApplicationService
    def call(user:, params:)
      result = Accounts::SetupService.call(user: user, params: params[:account])
      return result if result.failure?

      result = Preferences::ConfigureService.call(user: user, params: params[:preferences])
      return result if result.failure?

      Notifications::WelcomeService.call(user: user)
      user.update!(onboarding_completed_at: Time.current)

      success(user)
    end
  end
end
```

Because every service returns the same `Result`, an orchestrator can hand a collaborator's
failure straight back to its own caller, code and message intact.

## Dependency Injection Patterns

### Constructor Injection

```ruby
module Orders
  class CreateService < ApplicationService
    def initialize(inventory: InventoryService.new, payment: PaymentService.new)
      @inventory = inventory
      @payment = payment
    end

    private

    attr_reader :inventory, :payment
  end
end
```

Every dependency has a default, so `ApplicationService.call` — which forwards to
`new.call` — still works in production code. Instantiate the class directly only when you
are substituting one.

### Testing with Mocks

```ruby
RSpec.describe Orders::CreateService, type: :model do
  subject(:service) { described_class.new(inventory: inventory, payment: payment) }

  let(:inventory) { instance_double(InventoryService, available?: true, reserve: true) }
  let(:payment) { instance_double(PaymentService, charge: true) }
  let(:user) { create(:user) }
  let(:params) { { items: [{ product_id: create(:product).id, quantity: 1 }] } }

  it "checks inventory before charging" do
    service.call(user: user, params: params)

    expect(inventory).to have_received(:available?).ordered
    expect(payment).to have_received(:charge).ordered
  end
end
```

The class under test is the class that takes those keywords. A spec that calls
`described_class.new(inventory:, payment:)` against a service defining no `initialize`
raises `ArgumentError` before it asserts anything, and every `let` the example reads has to
exist.

## Error Handling Patterns

### Typed Error Codes

The code is what the caller branches on; the message is what a user reads. Keep the
messages in a locale file so they can be translated and reviewed:

```ruby
module Orders
  class CreateService < ApplicationService
    def call(user:, params:)
      return failure(message(:empty_cart), code: :empty_cart) if params[:items].blank?
      return failure(message(:out_of_stock), code: :out_of_stock) unless inventory_available?(params[:items])

      success(create_order(user, params))
    rescue PaymentError
      failure(message(:payment_failed), code: :payment_failed)
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
        payment_failed: "Your payment could not be processed"
        validation_failed: "Please check your order details"
```

Field-level messages go in `details`, not in `data`. `data` is the success payload, and a
renderer that serialises it on failure will eventually serialise a record.

### Controller Error Handling

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.call(user: current_user, params: order_params)

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      handle_service_error(result)
    end
  end

  private

  def handle_service_error(result)
    case result.code
    when :empty_cart
      redirect_to cart_path, alert: result.error
    when :payment_failed
      redirect_to checkout_path, alert: result.error
    else
      @order = Order.new(order_params)
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_content
    end
  end
end
```

The re-render branch re-assigns what `#new` assigned, and it is the branch that changes in
an Inertia app: there is no `new.html.erb` to render, so the failure redirects with
`inertia: { errors: }`. See "Skinny Controllers" in this skill's SKILL.md.

## Service Naming Conventions

| Pattern | Example | Use Case |
|---------|---------|----------|
| `VerbNounService` | `CreateOrderService` | Single action |
| `Namespace::VerbService` | `Orders::CreateService` | Namespaced (preferred) |
| `NounVerbService` | `OrderCreatorService` | Alternative style |

## Checklist

- [ ] One public method, `#call`, with one signature
- [ ] Inherits `ApplicationService` and returns its `Result`
- [ ] Dependencies injected via constructor, each with a default
- [ ] Named exceptions rescued; the rest reach the error tracker
- [ ] Transaction around multi-model writes
- [ ] A code per failure the caller branches on, and a message from a locale file
- [ ] Field-level messages in `details`, never in `data`
- [ ] Spec covers every branch
