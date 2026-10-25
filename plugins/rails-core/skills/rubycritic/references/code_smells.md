# Reading and Fixing What RubyCritic Reports

Three tools produce the output, and they contribute to it differently.

| Analyser | Reports | Contributes to `cost` |
|---|---|---|
| Reek | named design smells | nothing — every Reek smell is recorded `cost: 0` |
| Flog | `HighComplexity` at a method flog score of 25, `VeryHighComplexity` at 60 | nothing as a smell; the file's `complexity` total enters as `complexity / 25.0` |
| Flay | `DuplicateCode`, with the structural mass as its score | `mass / 25`, integer division |

So the smell list is the work queue and the score is a separate reading. Every example
below was run through reek 6.5.0 and rubycritic 5.0.0, and the numbers are what came back.

## Three measured refactors, one per analyser

| Refactor | Smells | Complexity | Duplication | Score |
|---|---|---|---|---|
| Naming three Reek smells away | 9 → 6 | 11.28 → 11.28 | 0 → 0 | **97.18 → 97.18** |
| Flattening a 4-deep method into two | 2 → 1 | 13.33 → 14.43 | 0 → 0 | **96.67 → 96.39** |
| Extracting a duplicated query body | 3 → 1 | 21.08 → 20.48 | 62 → 0 | **82.23 → 94.88** |

Read the middle row twice. **A correct refactor lowered the score**, because splitting one
method into two left every call in place and added a method's worth of flog to the file,
while the highest per-method flog score fell from 13.3 to 5.3. Count smells and read the
per-method flog scores; treat the score as the duplication-and-complexity reading it is.

## Reek smells, what fires each one, and the fix

Every threshold below is Reek 6.5.0's own default, so it is the number that governs the
output you are reading. A project `.reek.yml` can change any of them.

| Smell | Fires when | Fix |
|---|---|---|
| `IrresponsibleModule` | a class or module has no comment above it | none — see below |
| `UtilityFunction` | an instance method touches no instance state | make it a class method, move it onto the argument's class, or accept it |
| `TooManyStatements` | a method has more than 5 statements (`DEFAULT_MAX_STATEMENTS = 5`) | extract a named method |
| `LongParameterList` | more than 3 parameters (`DEFAULT_MAX_ALLOWED_PARAMS = 3`) | pass one value object |
| `DataClump` | the same 2+ parameters appear in a third method (`DEFAULT_MAX_COPIES = 2` allows two) | give the clump a class |
| `DuplicateMethodCall` | the same send appears twice in one method (`DEFAULT_MAX_CALLS = 1`) | hold the result in a local |
| `ControlParameter` | an argument only chooses which branch runs | split into two methods, one per branch |
| `FeatureEnvy` | a method refers to one parameter or local more than to self | move the method to that object's class |
| `NestedIterators` | blocks nested more than 1 deep (`DEFAULT_MAX_ALLOWED_NESTING = 1`) | extract the inner block into a method |
| `RepeatedConditional` | the same test appears in a third place (`DEFAULT_MAX_IFS = 2`) | give the condition a predicate method, or polymorphism |
| `TooManyInstanceVariables` | more than 4 ivars (`DEFAULT_MAX_IVARS = 4`) | split the class |
| `TooManyMethods` | more than 15 methods (`DEFAULT_MAX_METHODS = 15`) | split the class |
| `TooManyConstants` | more than 5 constants (`DEFAULT_MAX_CONSTANTS = 5`) | move them to the class they describe |
| `NilCheck`, `UncommunicativeName`, `ClassVariable`, `InstanceVariableAssumption` | as named, except `InstanceVariableAssumption`: an ivar is read where no `initialize` assigns it | rename, replace the nil branch with a value, or assign the ivar in `initialize` as the Feature Envy example does |

**Reek counts statements where RuboCop counts lines.** `TooManyStatements`'s 5 and
RuboCop's `Metrics/MethodLength` 10 are one shape measured twice, not two rival limits, and
in a Rails 8.1 app `rubocop-rails-omakase` disables the `Metrics` department, so Reek's 5 is
the one that actually fires. For whether the extracted code should move out of the class,
see the `extraction-timing` skill, section "Extraction Thresholds", which owns that
decision.

## `IrresponsibleModule` is the one to leave alone

On a Rails application this is most of the output — measured against a Rails 8.1.3.1 app,
all 15 files carried it, 15 of the 21 smells reported. The only thing that satisfies the detector is a
class-level descriptive comment, and comments here are reserved for clarification,
warnings, amplification, and agreed TODOs. Report it as noise. Reek also raises it for a
`Data.define` or `Struct.new` assigned to a constant, so a value object extracted while
fixing another smell brings one along.

Where the user wants it out of the output, offer the `.reek.yml` in the SKILL's section
"`IrresponsibleModule` on a Rails application".

## Control Parameter

```ruby
# Fires: an argument that only picks a branch.
class ReportsBad
  def process(data, use_cache)
    use_cache ? cached_process(data) : fresh_process(data)
  end
end

# Clean: two methods, each named for what it does.
class ReportsGood
  def process_with_cache(data)
    cached_process(data)
  end

  def process_without_cache(data)
    fresh_process(data)
  end
end
```

## Feature Envy

`FeatureEnvy` needs both halves: an enviable parameter, local, or ivar **and** at least one
reference to self in the same method (`smell_detectors/feature_envy.rb:44-46`). A method
that only reaches through a reader on self does not fire it, and a method with no self
reference at all reports `UtilityFunction` instead.

```ruby
# Fires: `item` is referred to three times, self once.
class Invoice
  def initialize(logger)
    @logger = logger
  end

  def total_price(item)
    @logger.debug("pricing")
    item.price * item.quantity + item.tax
  end
end
```

```ruby
# Clean: a line item that prices itself.
class LineItem
  attr_reader :price, :quantity, :tax

  def total_price
    price * quantity + tax
  end
end

# Clean: an invoice that asks the item for its total.
class Invoice
  def initialize(logger)
    @logger = logger
  end

  def total_price(item)
    @logger.debug("pricing")
    item.total_price
  end
end
```

Reek reports zero warnings on that pair. Note the `initialize`: assigning `@logger` where a
reader can see it is what keeps `InstanceVariableAssumption` off the list.

## Long Parameter List

Define the parameter object. A hash argument unpacked by symbol key inside the method is
not one — it keeps the coupling and drops what type safety there was.

```ruby
# Fires: six positional parameters, so every caller depends on their order.
class RegistrationsBad
  def initialize(account)
    @account = account
  end

  def create_user(name, email, age, address, phone, country)
    @account.users.create!(name: name, email: email, age: age,
                           address: address, phone: phone, country: country)
  end
end

# Clean: one value object, and each caller names the field it sets.
class RegistrationsGood
  # What a registration form submits.
  Details = Data.define(:name, :email, :age, :address, :phone, :country)

  def initialize(account)
    @account = account
  end

  def create_user(details)
    @account.users.create!(details.to_h)
  end
end
```

## Duplicate Method Call

```ruby
# Fires: `user.full_name` twice in one method.
class GreetingBad
  def display
    puts user.full_name
    log("Displayed #{user.full_name}")
  end
end

# Clean: the result held in a local.
class GreetingGood
  def display
    name = user.full_name
    puts name
    log("Displayed #{name}")
  end
end
```

## Data Clump

Reek allows the pair twice and reports it at the third method.

```ruby
# Fires: ['weight', 'zone'] threaded through three methods.
class ShippingBad
  def quote(weight, zone) = rates.fetch(zone) * weight
  def deliver(weight, zone) = carrier.book(weight, zone)
  def refund(weight, zone) = quote(weight, zone) * -1
end

# Clean: a parcel that answers questions about itself.
# Passing the pair as a Struct and then unpacking it inside each method trades
# DataClump for FeatureEnvy; move the behaviour with the data.
Parcel = Struct.new(:weight, :zone) do
  def cost(rates) = rates.fetch(zone) * weight
end

# Clean: shipping asks the parcel rather than unpacking it.
class ShippingGood
  def quote(parcel) = parcel.cost(rates)
  def deliver(parcel) = carrier.book(parcel)
  def refund(parcel) = quote(parcel) * -1
end
```

## Complexity, and what actually lowers it

Flog charges per call, per assignment, and per branch, and multiplies inside nested blocks.
`HighComplexity` names a *method* scoring 25 or more, while the file's `complexity` number
is the sum across its methods — so a file can pass 25 in total with no method flagged.

Measured on the four-deep method below: flog 13.3 for the one method. Rewriting it as a
guard clause plus two helpers took the highest method to 5.3 and the file total to 14.4.
The per-method reading improved, the file total did not, and the score fell 96.67 → 96.39.

```ruby
# Fires: four levels of nesting to reach the work.
class OrdersBad
  def process_order(order)
    if order.valid?
      if order.paid?
        if order.items.any?
          order.items.each do |item|
            item.in_stock? ? item.ship : item.backorder
          end
        end
      end
    end
  end
end

# Clean: a guard clause, one level, and a named predicate.
class OrdersGood
  def initialize(order)
    @order = order
  end

  def process_order
    return unless shippable?

    @order.items.each { |item| process_item(item) }
  end

  private

  def shippable?
    @order.valid? && @order.paid? && @order.items.any?
  end

  def process_item(item)
    item.in_stock? ? item.ship : item.backorder
  end
end
```

`process_item` reports `UtilityFunction`, because it touches only its argument. That is
common in a small private helper and is often the right shape; the alternative Reek is
pointing at is moving `process_item` onto the item's class.

**What lowers a file's complexity is removing work, not relocating it.** Delete a branch,
collapse a conditional into a scope, replace a hand-rolled loop with one query.

## Duplication, and why it is the fix worth doing first

Flay is the only analyser that moves the score, so a duplication fix is the one refactor
whose effect the number will confirm.

```ruby
# Fires: DuplicateCode at mass 62 — cost 2, rating B, score 82.23.
class Reports
  def weekly
    orders = Order.where(state: "paid").includes(:items).order(:created_at)
    total = orders.sum { |order| order.items.sum(&:price) }
    { count: orders.size, total: total, generated_at: Time.current }
  end

  def monthly
    orders = Order.where(state: "paid").includes(:items).order(:created_at)
    total = orders.sum { |order| order.items.sum(&:price) }
    { count: orders.size, total: total, generated_at: Time.current }
  end
end
```

```ruby
# Clean: duplication 0, rating A, score 94.88.
class Reports
  def weekly = summary(Order.paid_since(1.week.ago))
  def monthly = summary(Order.paid_since(1.month.ago))

  private

  def summary(scope)
    orders = scope.includes(:items).order(:created_at)
    total = orders.sum { |order| order.items.sum(&:price) }
    { count: orders.size, total: total, generated_at: Time.current }
  end
end
```

Both versions also report `UtilityFunction`, since none of these methods touch instance
state; that is the same signal discussed above and not what this example is about.

Because flay's cost is `mass / 25` in integer division, a duplicated block under mass 25
costs nothing at all — the smell is reported and the score does not move. Fix it for the
same reason you would have without the tool, not because the number demands it.

## Where to start on a report

1. **`DuplicateCode`**, highest mass first. It is the only smell class the score tracks.
2. **The highest per-method flog scores**, from the `HighComplexity` entries.
3. **The Reek smells that name a design problem** — `FeatureEnvy`, `DataClump`,
   `ControlParameter`, `RepeatedConditional`. These are the ones worth a change of shape.
4. **The Reek smells that name a local fix** — `DuplicateMethodCall`, `NilCheck`,
   `UncommunicativeName`. Cheap, and they clear the list so the first three stay visible.

Leave `IrresponsibleModule` where it is, and take style and formatting to the `rubocop`
skill, which RubyCritic does not report on.
