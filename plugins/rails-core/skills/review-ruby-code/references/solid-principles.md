# SOLID Principles Reference

Five design principles, in the form a Ruby reviewer needs them: what the compliant shape looks
like, and the one question that settles each call. Robert C. Martin named and published the five;
the definitions quoted below are his own formulations.

**Read each of the five in its Ruby form.** There is no compiler, no `interface` keyword, and no way to
force a class to implement anything, so the pressures the Java literature describes do not apply
here. Each section says what the Ruby version of the principle actually is. Two habits imported
from that literature are worth naming, because they show up in Ruby code reviews and neither
belongs:

- **An abstract base class whose only content is `raise NotImplementedError` adds nothing.** A duck
  type gives you the same extension point with less coupling — a test double has to be a subclass
  of a base class, whereas it only has to answer the right messages to a duck type. Inherit when
  the parent holds behavior the children share.
- **`NotImplementedError` is not a `StandardError`.** Its ancestors are `ScriptError`, `Exception`.
  A bare `rescue`, a `rescue => e`, and Rails' `rescue_from`/`rescue_responses` all handle
  `StandardError` descendants, so a `NotImplementedError` escapes every one of them and surfaces as
  a 500. Ruby's own docs describe it as "raised when a feature is not implemented on the current
  platform." Raise `NotImplementedError` for a genuinely absent platform feature; for an abstract
  hook you actually want, prefer a duck type or a real default.

The code below is the recommended form throughout. Where the section names a signal to look for,
it names it in prose so you can grep for it, rather than rendering it as working Ruby.

---

## S — Single Responsibility Principle (SRP)

**Definition**: A class should have one, and only one, reason to change.

**Core idea**: "This principle is about people." A reason to change originates with a single
person — or a single tightly coupled group of people representing a single narrowly defined
business function. Martin's alternative formulation is the more useful one in review: *gather
together the things that change for the same reasons; separate the things that change for
different reasons.*

**The review question**: *which stakeholders would independently ask for a change to this class?*
Two answers means two classes. This is not "does it do one thing" — a class that does one thing
for two different departments still has two reasons to change, and a class that does six things
for one department may be exactly right.

**In Rails the SRP seams already exist.** Reach for a mailer, a job, a form object, a query object,
or a presenter before inventing a PORO. A new class whose body only reads its collaborator's
attributes is Feature Envy wearing an SRP costume, and it makes the design worse.

```ruby
class User < ApplicationRecord
  has_secure_password

  validates :email_address, presence: true

  # Authentication belongs here. has_secure_password defines #authenticate_password
  # and aliases it to #authenticate, so User is where Rails itself puts it.
end

# Its own reason to change: how an activity report reads.
class ActivityReport
  def initialize(user)
    @user = user
  end

  def to_s
    @user.activities.map { |activity| line_for(activity) }.join("\n")
  end

  private

  def line_for(activity)
    "#{activity.created_at.to_date}: #{activity.description}"
  end
end
```

`ActivityReport` earns its existence because it holds behavior of its own (`line_for`), not because
it moved a method out of the model.

```ruby
class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: user.email_address, subject: "Welcome")
  end
end

class SyncUserToCrmJob < ApplicationJob
  def perform(user)
    Crm.new.upsert_contact(email: user.email_address, name: user.name)
  end
end
```

Sending the welcome mail and syncing to the CRM are separate reasons to change, and Rails already
supplies the class for each. `UserMailer.welcome(user).deliver_later` *is* the extraction; wrapping
it in a `UserNotifier` adds a name and no behavior.

**Signals worth a comment**: a class you cannot name concisely; methods that read and write
unrelated columns; a class whose test file has to set up two unrelated worlds. A class name ending
in `Manager`, `Handler`, `Processor`, or `Data` is a hint to look, not a finding on its own — say
which two stakeholders you found before you call it an SRP violation.

---

## O — Open/Closed Principle (OCP)

**Definition**: Software entities should be open for extension but closed for modification.

**Core idea**: adding a case should mean adding code, not editing existing code.

**OCP relocates the conditional; it does not delete it.** Something still has to map an input to a
class, and the honest version of this refactoring shows where. Put that mapping in exactly one
known place and the rest of the system stops growing `case` statements.

```ruby
require "json"

class PdfReport
  def render(rows) = "%PDF-1.7\n#{rows.length} rows"
end

class JsonReport
  def render(rows) = JSON.generate(rows)
end

class TextReport
  def render(rows) = rows.map { |row| row.join("\t") }.join("\n")
end

# The one place that changes when a format is added.
REPORT_FORMATS = { pdf: PdfReport, json: JsonReport, text: TextReport }.freeze

def report_for(format)
  REPORT_FORMATS.fetch(format).new
end
```

Adding XML means one new class and one new entry in `REPORT_FORMATS`. `fetch` raises `KeyError` on
an unknown format, which is what you want: an unregistered format is a bug, not a nil. The three
renderers share no superclass, so none of them has to change when a fourth arrives.

**The Rails version, where inheritance carries its weight**:

```ruby
class Payment < ApplicationRecord
  # Shared behavior, not a raising stub: every payment records itself the same way.
  def collect!
    update!(reference: authorize, collected_at: Time.current)
  end
end

class CardPayment < Payment
  def authorize = "card-#{SecureRandom.uuid}"
end

class BankTransferPayment < Payment
  def authorize = "ach-#{SecureRandom.uuid}"
end
```

`Payment` is closed: a `CryptoPayment` subclass needs no edit to it. The base class is worth having
here because `collect!` is real shared behavior — contrast a base class holding nothing but
`raise NotImplementedError`, which buys nothing over three unrelated classes that each answer
`collect!`.

**Signals worth a comment**: a `case` or `if/elsif` on a type, kind, or format that has grown once
already; a method you have to edit every time the product adds an option; the same `case` over the
same values in more than one file.

---

## L — Liskov Substitution Principle (LSP)

**Definition**: Objects of a superclass should be replaceable with objects of a subclass without
breaking the application. If `S` is a subtype of `T`, objects of type `T` may be replaced with
objects of type `S` without altering the correctness of the program.

**The contract rules**, which is what LSP reduces to in practice: a subtype may **weaken
preconditions** (accept more) and **strengthen postconditions** (guarantee more). It may never
strengthen a precondition or weaken a postcondition, and it may never raise where the parent
did not.

```ruby
class Bird
  def initialize(name)
    @name = name
  end

  def describe = "#{@name} #{move}"

  def move = "walks"
end

class Eagle < Bird
  def move = "flies"
end

class Penguin < Bird
  def move = "swims"
end
```

`describe` keeps the same promise — returns a `String`, never raises — for `Bird`, `Eagle`, and
`Penguin` alike, so any caller holding a `Bird` works. Note that `Bird#move` has a real default
rather than a raising stub, which is what makes `Bird` itself substitutable.

**The Rails version.** `save`'s published contract is: persist the record and return `true`, or
return `false` and populate `errors`. A subclass that must refuse to persist can honor that
contract exactly — with a validation.

```ruby
class Account < ApplicationRecord
end

class SystemAccount < Account
  validates :owner_email, absence: { message: "must not be set on a system account" }
end
```

`SystemAccount.new(owner_email: "someone@example.com").save` returns `false` and fills in `errors`,
which is inside `save`'s contract, so `save`, `save!`, `valid?`, `errors`, and every form that
renders them keep working unchanged.

**What would break it**: overriding `save` to `raise` (the parent does not raise on invalid data),
or overriding it to return `false` without adding anything to `errors`. The second is the subtler
one and it is a real postcondition weakening — the caller is promised that a `false` return comes
with a reason, and now it does not. Returning `false` is only compliant when `errors` explains why.

**Type checking**: a client that branches on a *subtype of the hierarchy it is holding*, in order
to work around a substitution that does not hold, is the LSP smell — `if account.is_a?(SystemAccount)
then skip_save`. Ordinary Ruby uses of `is_a?` are not this: coercing a value (`is_a?(String)`),
feature detection with `respond_to?`, and dispatching on a value object's class are all fine.

---

## I — Interface Segregation Principle (ISP)

**Definition**: No client should be forced to depend on methods it does not use.

**Core idea in Ruby**: nothing "forces" anything, so the Java framing ("the class is forced to
implement a stub") does not describe a real pressure here — omitting a method is legal, and a
raising method in an included module simply sits unreached in the ancestor chain. The Ruby cost is
different and worse: **including a module widens the host's public surface with methods it cannot
honor.** `respond_to?` starts answering `true` for behavior the object does not have, and callers
couple to messages that will fail or no-op.

```ruby
module Works
  def work = "processing tasks"
end

module TakesBreaks
  def take_break = "on a break"
end

class HumanWorker
  include Works
  include TakesBreaks
end

class RobotWorker
  include Works
end
```

`RobotWorker.new.respond_to?(:take_break)` is `false`, which is the whole point — the robot's
public surface describes only what it can do, so a caller cannot ask it for a break and get `nil`.

**The Rails version**: concerns split so that each including model gains only methods its table
supports.

```ruby
module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, -> { where(published_at: ..Time.current) }
  end

  def publish!(at = Time.current)
    update!(published_at: at)
  end

  def published?
    published_at.present? && published_at <= Time.current
  end
end

module Schedulable
  extend ActiveSupport::Concern

  def schedule!(at)
    update!(scheduled_for: at)
  end
end

class Article < ApplicationRecord
  include Publishable
  include Schedulable
end

class Comment < ApplicationRecord
  include Publishable
end
```

`Comment` never answers `schedule!`, so it can never be handed to code that schedules — which
matters concretely, because the `comments` table has no `scheduled_for` column and the fat version
of this concern would have put a method there that raises at runtime. Note also that
`where(published_at: ..Time.current)` excludes rows where `published_at` is `NULL`, so a scope pair
built this way has no hole for unpublished records to fall through.

**Signals worth a comment**: a concern more than one of its including models uses only part of;
a method in a concern that reads a column not every including model has; `respond_to?` returning
`true` for a message the object answers with `nil`.

---

## D — Dependency Inversion Principle (DIP)

**Definition**: High-level modules should not depend on low-level modules. Both should depend on
abstractions. Abstractions should not depend on details. Details should depend on abstractions.

**Core idea, and the part usually lost**: DIP is about the **direction of the source-code
dependency**, and about the abstraction being **owned by the high-level module and named in the
high-level module's vocabulary**. Dependency injection is one technique for achieving it, and
testability is a side effect, not the goal. An injected collaborator whose interface mirrors the
database's API — `save(record)`, `execute(sql)` — is a dependency that was *injected but not
inverted*: the policy still depends on a persistence-shaped interface, so swapping the adapter for
one that is not a database is still a rewrite.

```ruby
# The high-level policy owns the abstraction and names it in its own terms.
class Checkout
  def initialize(order_store:, receipts:)
    @order_store = order_store
    @receipts = receipts
  end

  def call(order)
    @order_store.persist(order)
    @receipts.deliver(to: order.email_address, total_cents: order.total_cents)
  end
end

# Low-level adapters are written to Checkout's vocabulary, not the reverse.
class ActiveRecordOrderStore
  def persist(order)
    order.save!
  end
end

class MailerReceipts
  def deliver(to:, total_cents:)
    ReceiptMailer.receipt(to, total_cents).deliver_later
  end
end
```

`persist(order)` and `deliver(to:, total_cents:)` are named for what checkout needs. A file-backed
store or an SMS receipt fits without touching `Checkout`, which is the test that tells you the
dependency really was inverted. Each collaborator has exactly one contract, stated once — two
call sites disagreeing about a collaborator's signature is how the abstraction quietly stops being
one.

**The Rails version**, controller and service:

```ruby
class OrdersController < ApplicationController
  def create
    order = CreateOrder.call(order: Order.new(order_params), payments: payments)

    if order.persisted?
      redirect_to order
    else
      redirect_to new_order_path, alert: order.errors.full_messages.to_sentence
    end
  end

  private

  def order_params
    params.expect(order: [:sku, :quantity, :payment_token])
  end

  def payments
    @payments ||= PaymentGateways::Stripe.new
  end
end
```

```ruby
class CreateOrder
  def self.call(order:, payments:)
    new(order:, payments:).call
  end

  def initialize(order:, payments:)
    @order = order
    @payments = payments
  end

  # Returns the order. Ask it whether it persisted.
  def call
    charge = @payments.charge(amount_cents: @order.total_cents, token: @order.payment_token)
    return reject(charge.error) unless charge.success?

    @order.payment_reference = charge.reference
    @order.save
    @order
  end

  private

  def reject(message)
    @order.errors.add(:base, message)
    @order
  end
end
```

Two things in there are load-bearing beyond DIP:

- **`amount_cents` comes from `@order.total_cents`, never from params.** A price that arrives in the
  request is a price the client sets. Take the payment token from params; derive the amount on the
  server.
- **Returning the order and asking `persisted?` keeps the failure path in Rails' own vocabulary**,
  so `errors` is already populated and already keyed by attribute. Which response a write failure
  gets — a re-render carrying `status: :unprocessable_content` under Hotwire, a redirect carrying the
  errors under Inertia, a JSON body under JSON API — is the `rails-8-idioms` skill's call, in its
  "Redirect status codes" section, not this file's.

**Signals worth a comment**: a class that instantiates its own collaborators with `Foo.new` inside
a method body; a hard-coded gem constant (`Stripe::Charge`, `Twilio::REST::Client`) in a controller
or model; an injected interface whose method names come from the adapter's world rather than the
caller's.

---

## The five questions

One question per principle, which is the whole checklist:

| Principle | Ask |
|---|---|
| **SRP** | Which stakeholders would independently ask for a change to this class? |
| **OCP** | To add the next case, do I add code or edit code — and where is the one mapping? |
| **LSP** | Does every subclass keep every promise its parent's callers rely on? |
| **ISP** | Does this object answer any message it cannot honor? |
| **DIP** | Is the abstraction named for what the caller needs, or for what the adapter does? |

When you write the comment, name the principle, say which of these questions failed and with what
answer, and show the shape you would expect instead.
