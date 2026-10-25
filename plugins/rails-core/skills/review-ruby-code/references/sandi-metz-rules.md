# Sandi Metz's Rules Reference

## Four rules, and where they come from

There are **four**, not five. Sandi Metz stated them on Ruby Rogues episode 87 (2013); the canonical
write-up is thoughtbot's *"Sandi Metz' Rules For Developers"*
(https://thoughtbot.com/blog/sandi-metz-rules-for-developers).

**They are not from POODR or 99 Bottles of OOP.** Both books cover the same design ground, and both
are worth citing for the ideas, but neither states this numbered list. A review comment that says
"violates Sandi Metz Rule 5" is citing a rule that does not exist, and one that credits the rules to
a book is citing a source a Ruby developer can check and find empty.

## Rule zero, which is part of the original

> "You should break these rules only if you have a good reason or your pair lets you."

The author of the four most-quoted numbers in Ruby design published them as conversation openers.
A review that treats them as pass/fail is stricter than its own source. State the number, say what
it made you look at, and let the author answer.

## What each number is, and what publishes it

Three roles matter, and mixing them is where most threshold arguments come from. A **design target**
is what you aim for while writing. A **review ceiling** is what earns a comment. An **enforced
limit** is what fails a build.

**On a Rails 8.1 app there are no enforced limits here.** `rubocop-rails-omakase` 1.1.0 sets
`Metrics: Enabled: false` — verified by running `rubocop` against a 12-line method under an
inheriting config and getting no `Metrics` offense. So every number below is a target or a ceiling,
and you reach the cop deliberately:

```bash
bin/rubocop --only Metrics/MethodLength,Metrics/ClassLength,Metrics/ParameterLists app/models/user.rb
```

`--only` overrides the inherited `Enabled: false` — verified at rubocop 1.89.0 with
`rubocop-rails-omakase` 1.1.0, which reported `Metrics/MethodLength: Method has too many lines.
[12/10]` on a config that had otherwise switched the department off.

| Signal | Target | Ceiling | Who publishes the number |
|---|---|---|---|
| Class body length | 100 lines | 100 lines | Metz rule 1; `Metrics/ClassLength` `Max: 100` and `Metrics/ModuleLength` `Max: 100`, rubocop 1.89.0 |
| Method body length | 5 statements | 10 lines | Metz rule 2 says 5 **lines**; Reek 6.5.0's `TooManyStatements` allows 5 **statements**; `Metrics/MethodLength` `Max: 10` **lines**, rubocop 1.89.0 |
| Parameters | 4 | 5 | Metz rule 3 says 4, "hash options are parameters"; Reek's `LongParameterList` allows 3; `Metrics/ParameterLists` `Max: 5` with `CountKeywordArgs: true` |
| Objects a controller action instantiates | 1 | 1 | Metz rule 4 |
| Instance variables in a class | 4 | 4 | Reek 6.5.0's `TooManyInstanceVariables`. **Not a Metz rule** — she published no instance-variable cap |
| ABC size | — | 17 | `Metrics/AbcSize` `Max: 17`, rubocop 1.89.0 |
| Cyclomatic / perceived complexity | — | 7 / 8 | `Metrics/CyclomaticComplexity`, `Metrics/PerceivedComplexity`, rubocop 1.89.0 |
| Block body length / block nesting | — | 25 lines / 3 deep | `Metrics/BlockLength`, `Metrics/BlockNesting`, rubocop 1.89.0 |

Every number in that table was verified by invocation at the versions named. Two facts decide which of
them fire on a project that never configured anything:

- **Reek is the analyser most likely to be actually running.** `rubycritic` vendors it
  (`reek ~> 6.5.0`), so any project with rubycritic in the bundle has Reek's defaults in play, while
  RuboCop's `Metrics` department sits disabled under omakase.
- **Reek counts statements, not lines**, so its 5 and RuboCop's 10 are not rivals — a 5-statement
  method commonly occupies 5 to 10 lines. Verified: a method with 5 statements draws no
  `TooManyStatements`; one with 6 draws `S6#m has approx 6 statements`.

---

## Rule 1: Classes are 100 lines or fewer

**Principle**: a class small enough to hold in your head has one job.

**Detection**:

```bash
bin/rubocop --only Metrics/ClassLength app/models/user.rb
```

Use the cop, not `wc -l`. A line count of the file is the sum of every class in it, so the moment
you extract collaborators into the same file the number goes up rather than down, and each extracted
class inherits the whole file's count. The cop measures the class body — verified: a class whose
body is 103 lines reports `[103/100]`.

**What a long class is telling you**: two cohesive groups of methods that touch different data;
coordination logic mixed with the work itself; a name you had to make vague to cover everything
inside.

**What to do**: name the second group and give it a class. In Rails, look for a framework seam that
already exists — a mailer, a job, a query object, a presenter — before writing a new PORO. See
`solid-principles.md`, SRP section, and the `extraction-timing` skill's decision tree,
"Where Should This Code Go?", for which pattern fits.

---

## Rule 2: Methods are 5 lines or fewer

**Principle**: a method that fits in five lines has a single level of abstraction, which is what
makes its name honest.

**Detection**:

```bash
bin/rubocop --only Metrics/MethodLength app/models/user.rb
```

**The shape to aim for** — a public method that reads as a summary, with the steps named below it:

```ruby
def process_order(order)
  return false unless processable?(order)

  process_items(order)
  finalize_order(order)
  true
end

private

def processable?(order)
  order.items.any? && order.user.active? && order.payment_valid?
end

def process_items(order)
  order.items.each { |item| process_item(item) }
end

def process_item(item)
  item.decrement!(:inventory)
  item.update!(status: "processed")
end

def finalize_order(order)
  order.recalculate_total
  OrderMailer.confirmation(order).deliver_later
  order.update!(status: "completed")
end
```

The guard clause replaces the outer `if/else`, and each extracted method's name says what the
condition or the loop was for. That naming is the point; the line count is only how you notice.

**What a long method is telling you**: a compound condition that deserves a predicate name; a loop
body doing two things; low-level detail sitting next to high-level intent.

---

## Rule 3: Methods take 4 parameters or fewer

**Principle**: a long parameter list is an object that has not been named yet.

Metz is explicit that **hash options are parameters**, and RuboCop implements the same rule:
`Metrics/ParameterLists` sets `CountKeywordArgs: true`. Verified — a method with five positional
parameters draws no offense at the default `Max: 5`, and one with six keyword parameters draws
`[6/5]`. A reviewer who thinks keyword arguments are free misses the rule entirely.

**The shape to aim for** — a parameter object that gives the cluster a name:

```ruby
class Notification
  attr_reader :user, :title, :body, :channel, :priority, :deliver_at

  def initialize(user:, title:, body:, channel: :email, priority: :normal, deliver_at: Time.current)
    @user = user
    @title = title
    @body = body
    @channel = channel
    @priority = priority
    @deliver_at = deliver_at
  end
end

def send_notification(notification)
  # One object, and it can answer questions about itself.
end
```

The win is not that the count went down. It is that `Notification` now has somewhere to put the
validation and the defaults that were previously scattered across every caller.

**What a long list is telling you**: the same three or four parameters travelling together through
several methods (Reek calls this `DataClump` and reports it once a third method takes the same
cluster); primitives standing in
for a concept; a method that needs so much context it probably belongs in another class.

---

## Rule 4: A controller action instantiates one object

**Principle**: controllers orchestrate. Instantiating several objects means the assembly logic is in
the controller, where it cannot be tested or reused.

**Metz's own statement continues past the rule**, and the continuation is a consequence rather than a
fifth rule:

> "Controllers can instantiate only one object. **Therefore,** views can only know about one
> instance variable and views should only send messages to that object."

Both halves matter, and the second half's Law-of-Demeter clause — *send messages to that object* —
is the part most often dropped.

**Relocating the instantiations does not discharge the rule.** Moving five `new` calls out of the
controller and into a service leaves a service that instantiates five objects; the controller got
thinner, which is a real gain, but rule 4 is about assembly, not about which file it happens in.
What discharges it is letting one object build its own graph:

```ruby
class Order < ApplicationRecord
  belongs_to :user
  has_one :payment
  has_one :shipping_address

  accepts_nested_attributes_for :payment, :shipping_address
end

class OrdersController < ApplicationController
  def create
    # One object. Order builds its own payment and shipping_address.
    @order = Current.user.orders.new(order_params)

    if @order.save
      redirect_to @order
    else
      redirect_to new_order_path, alert: @order.errors.full_messages.to_sentence
    end
  end

  private

  def order_params
    params.expect(order: [:product_id,
                          payment_attributes: [:token],
                          shipping_address_attributes: [:line1, :postal_code]])
  end
end
```

`Current.user` is what the Rails 8.1 authentication generator provides; `current_user` comes from
Devise and does not exist in a generated 8.1 app. `params.expect` is the 8.1 form — see the
`rails-8-idioms` skill's "Strong parameters: pick the form from the shape of the incoming params"
section for when `expect` is right and when a bare `permit` is.

**Counting**: count `new`, `create`, `create!`, `build`, and finder calls that assign to an instance
variable. Association builders on the one object you already have (`@order.build_payment`, nested
attributes) do not add to the count — they are that object assembling itself.

### The consequence: one instance variable in the view

**Detection** — count *distinct* instance variables, not `@` occurrences:

```bash
rg -o '@[a-z_]+' app/views/users/show.html.erb | sort -u
```

Counting occurrences flags the fix as well as the problem: a view refactored onto a single presenter
mentions `@presenter` on every line.

**The shape to aim for** — one object the view talks to, which answers everything the page needs:

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def show
    @presenter = UserProfilePresenter.new(User.find(params.expect(:id)))
  end
end

# app/presenters/user_profile_presenter.rb
class UserProfilePresenter
  def initialize(user)
    @user = user
  end

  def name = @user.name
  def recent_posts = @user.posts.recent
  def recent_comments = @user.comments.recent
  def follower_count = @user.followers.count
end
```

```erb
<h1><%= @presenter.name %></h1>
<%= render @presenter.recent_posts %>
<%= render @presenter.recent_comments %>
<p>Followers: <%= @presenter.follower_count %></p>
```

A plain PORO presenter is enough; there is no need for a decorator gem, and this skill's own guidance
is to match whatever the codebase already uses rather than introduce a third pattern.

### The Inertia analogue — house extrapolation, no external source

Rules 4 and its consequence are written for ERB. An Inertia + React app has no `app/views` layer to
count instance variables in, and its controllers pass a props hash rather than assigning instance
variables, so the consequence has nothing to measure.

The extrapolation that holds is **one page-props object per action**, built by a private
`serialize_x` method in the controller — the shape the `inertia_rails` scaffold itself generates.
The extrapolation that does **not** hold is "pass one prop": a page legitimately receives several
top-level props, and squeezing them into one is not what the rule was about. Label this as
extrapolation when you cite it, because Metz published nothing about Inertia.

---

## Law of Demeter

**"Only talk to your immediate friends."** An object may send messages to itself, to objects passed
to it as parameters, to objects it creates, and to its own direct components.

**The shape to aim for** — each object answers for its own neighbourhood, so no caller reaches
through it:

```ruby
class Order < ApplicationRecord
  belongs_to :user

  delegate :tax_rate, to: :user
end

class User < ApplicationRecord
  has_one :shipping_address

  delegate :tax_rate, to: :shipping_address
end
```

`order.tax_rate` now works, and each class knows only its neighbour. `delegate` is Rails'; in plain
Ruby, write the one-line method.

**What to look for**: three or more dots on one expression through association names —
`order.user.shipping_address.city.tax_rate`, `@post.author.profile.avatar_url`. Two dots is usually
fine; the signal is depth through *associations*, not chained scopes
(`Post.published.recent.limit(10)` is one object answering four times) and not chained enumerables.

**Why it matters**: every dot is a class your caller now depends on. Change `ShippingAddress` and the
`order.user.shipping_address.city.tax_rate` call site breaks, even though nothing about orders
changed.

---

## Tell, Don't Ask

**Principle**: objects make their own decisions. Ask an object for its state, decide something, and
act on it from outside, and you have put that object's logic in the caller — where the next caller
will duplicate it.

```ruby
class Account < ApplicationRecord
  def withdraw(cents)
    return false unless sufficient_funds?(cents)

    update!(balance_cents: balance_cents - cents)
  end

  private

  def sufficient_funds?(cents) = balance_cents >= cents
end
```

The caller writes `account.withdraw(cents)` and checks the return value. The conditional is gone from
the caller and there is exactly one place that knows what "sufficient funds" means.

**What to look for**: a caller that reads a predicate or an attribute off an object and then branches
— `if user.subscription.active? && user.subscription.expires_at > Time.current`. Give the object the
question instead: `user.entitled_to?(:premium)`.

**Where it stops**: presentation choices are the caller's, not the model's. Picking which dashboard
component or which page to render belongs to the controller or the presenter; a model that knows
three view class names and calls `render` has traded one coupling for a worse one, and moving an
`if admin? / elsif premium?` chain from the controller into the model has not removed the conditional
at all — it has only changed which layer owns presentation.

---

## Code smells

Four groups, thirteen smells. Each one is a prompt to look, and the ones a tool measures name the
tool and its default.

**Structural**

- **Long Method** — `Metrics/MethodLength` `Max: 10` lines; Reek's `TooManyStatements` allows 5
  statements.
- **Large Class** — `Metrics/ClassLength` `Max: 100` lines; Reek's `TooManyMethods` allows 15
  methods.
- **Long Parameter List** — `Metrics/ParameterLists` `Max: 5` counting keywords; Reek's
  `LongParameterList` allows 3.
- **Data Clump** — the same parameters travelling together. Reek's `DataClump` allows the clump in 2
  methods (`max_copies`) and reports it in a third, with a clump size of 2 parameters or more
  (`min_clump_size`).

**Coupling**

- **Feature Envy** — a method that uses another object's data more than its own. Reek has a
  `FeatureEnvy` detector.
- **Message Chains** — Law of Demeter violations, above.
- **Inappropriate Intimacy** — two classes that each reach into the other's internals.

**Conditional logic**

- **Conditional Complexity** — nested `if/elsif`. `Metrics/CyclomaticComplexity` `Max: 7`,
  `Metrics/PerceivedComplexity` `Max: 8`, `Metrics/BlockNesting` `Max: 3`.
- **Case statements on a type** — a polymorphism candidate. See `solid-principles.md`, OCP.
- **Speculative Generality** — an abstraction with one caller, added for a future that has not
  arrived.

**Naming**

- **Vague names** — `Manager`, `Handler`, `Processor`, `Data`. A hint to look, not a finding: say
  which two jobs the class holds before you call it one.
- **Methods with "and" in the name** — usually two methods.
- **Flag parameters** — a boolean that selects between two behaviours. Two methods, named for what
  they do.

**On comments**: a comment that restates what the code does is a naming problem. Explanations of
*why* a change was made belong in the commit message, which is where a future maintainer will look
for them. Four kinds of comment do earn their place in the code, and it is worth naming them
precisely rather than reaching for the generic what/why split:

1. **Clarification**, where more expressive code is not available — a standard-library quirk, a
   gnarly regex.
2. **Warning of consequences**, where a maintainer might not see what changing this breaks — a race
   condition, a thread-safety constraint.
3. **Amplification**, where a reader would plausibly simplify or delete something load-bearing — an
   apparently redundant `.dup` that stops a caller's array being mutated.
4. **TODO**, for work already agreed to be deferred.

---

## Shameless Green

From 99 Bottles of OOP:

1. **Start with Shameless Green** — the simplest code that passes, however repetitive.
2. **Wait for the duplication** to tell you what varies.
3. **Follow the Flocking Rules** — find the things that are most alike, find the smallest difference
   between them, make the simplest change that removes that difference.
4. **Converge on the abstraction**, rather than guessing it up front.

**"Make the change easy, then make the easy change."**

Step 1, Shameless Green — the conditional is right there in the open, and that is fine:

```ruby
def verse(n)
  if n.zero?
    "no more bottles of beer on the wall"
  elsif n == 1
    "1 bottle of beer on the wall"
  else
    "#{n} bottles of beer on the wall"
  end
end
```

Steps 2 and 3, the duplication named and the Flocking Rules applied. Each difference now has a
method, and the sentence appears once:

```ruby
def verse(n)
  "#{quantity(n)} #{container(n)} of beer on the wall"
end

def quantity(n) = n.zero? ? "no more" : n.to_s

def container(n) = n == 1 ? "bottle" : "bottles"
```

Step 4, the abstraction converged on. It is polymorphism here, once the conditionals all sit on
the same axis:

```ruby
class BottleNumber
  attr_reader :number

  def self.for(number)
    case number
    when 0 then BottleNumber0
    when 1 then BottleNumber1
    else BottleNumber
    end.new(number)
  end

  def initialize(number)
    @number = number
  end

  def quantity = number.to_s
  def container = "bottles"
  def to_s = "#{quantity} #{container} of beer on the wall"
end

class BottleNumber0 < BottleNumber
  def quantity = "no more"
end

class BottleNumber1 < BottleNumber
  def container = "bottle"
end
```

`BottleNumber` is concrete, holds the shared behaviour, and needs both `initialize` and a `number`
reader for `self.for` and `quantity` to work. `self.for` is the one place that maps a value to a
class — the same seam `solid-principles.md`'s OCP section describes, and the honest answer to "where
did the conditional go".

---

## Breaking the rules

Rule zero already grants this; these are the cases that come up most.

1. **Rule 1, 100 lines** — an algorithm that reads better whole than split across collaborators.
2. **Rule 2, 5 lines** — a configuration or DSL block, a method that is one long literal.
3. **Rule 3, 4 parameters** — a signature a framework or a published API dictates.
4. **Rule 4, one instantiation** — a generated scaffold action, simple CRUD.

Say why in the commit message, where it is a fact about a decision and stays findable. Put it in a
code comment only when a maintainer would otherwise "simplify" the code and break it — that is the
amplification case above, and it is a different sentence from the rationale.
