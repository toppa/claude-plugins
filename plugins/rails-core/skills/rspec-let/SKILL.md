---
name: rspec-let
description: >-
  `let` conventions for RSpec — when a value earns extraction into `let`, how
  many declarations one context carries, which context owns a declaration, and
  what belongs in `before` instead. `let!`, `subject`, and `subject!` each get
  the rules that fit them.
when_to_use: >-
  Use when you write or edit any RSpec spec, including one that declares no
  memoized helper yet, because Rule 1 decides whether a value earns one at all.
  Also use it when you add examples to a legacy spec whose existing declarations
  break these rules, and when the user asks where a `let` belongs or whether
  setup stays inline. Also use it when an RSpec suite is slow, when a spec wants
  profiling, or when `let_it_be` is named: Rule 4 states that a misplaced `let!` pays
  its cost once per example, and this skill's Related skills section names the profiler
  skill the user can invoke.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here so it travels with the Rails work.
  synced: 2026-08-10
  verified_against: rubocop-rspec 3.7.0, rspec-core 3.13.6
---

# RSpec `let` conventions

## Rule 1: Start inline, extract on the third use

Write setup inline in the `it` block first. Extract it into `let` after 3 or more
examples use the identical value. `let` is a refactoring tool, and the third
duplicate is what earns it. **3 is a house heuristic with no external source**;
Rule 2's ceiling is the number a tool sets.

## Rule 2: 1 to 3 `let` calls per context

Aim for 1 to 3 declarations in a context. Keep the count at 5 or fewer, which is
where RuboCop's `RSpec/MultipleMemoizedHelpers` cop draws its default line. The cop
counts a parent's declarations again inside every child, so the way to bring a count
down is to distribute declarations across sibling contexts and leave the parent
holding none. Moving one declaration from a parent into one child lowers the parent's
count and leaves that child's count where it already was.

## Rule 3: Give each child context its own declaration

When two child contexts need different values, declare the value in each child
rather than in the parent. A child that redeclares a parent's `let` reads as a
mystery until you find both sites, and the two sites drift apart as the file grows.
Rule 1 still decides whether the value has earned a declaration: in a child with one
or two examples, write the value inline in each `it`.

## Rule 4: Declare a value where every example uses it

Put a `let` at the narrowest level whose examples all use it, so a reader finds the
value beside the examples that depend on it instead of hunting for a mystery guest.
A lazy `let` that no example references never evaluates, so a misplaced `let` costs
reading time. A misplaced `let!` costs runtime as well, because it runs for every
example in its group.

## Rule 5: Put actions in `before`

`let` defines a value. A `before` block performs an action. Creating a record is a
value, so `let` or `let!` owns it. An API call, a payment, or an email is an action,
so `before` owns it, where a reader sees it happen.

## `let!`, `subject`, and `subject!`

- **`let!`** is `let` plus `before { the_helper }` (rspec-core 3.13.6,
  `memoized_helpers.rb:400-403`), so all five rules govern it, and Rule 4 carries the
  most weight: it runs in every example of the group that declares it.
- **`subject`** follows Rules 2, 3, and 4. Rule 1 does not gate it: a single
  `subject(:service) { described_class.new }` is worth naming even in a one-example
  group, which is the form `RSpec/NamedSubject` expects at its default
  `EnforcedStyle: always`. And `RSpec/MultipleMemoizedHelpers` defaults to
  `AllowSubject: true`, so a subject does not count toward Rule 2's ceiling.
- **`subject!`** is `subject` plus `before { subject }` (`memoized_helpers.rb:510-513`),
  and performing the call eagerly is its whole purpose. Reach for it when every
  example in the group needs the call made and then asserts on what it did — that is
  the one place an action belongs in a declaration rather than in `before`.

## Editing a legacy spec

Keep your new examples self-contained, so the file's existing violations stay where
they are.

1. **The surrounding context is consistent** — one uniform pattern, and any
   redeclaration sits at a single nesting level. Follow what the file already does.
2. **The surrounding context is inconsistent** — mixed patterns, redeclarations
   scattered across nesting levels. Set up inline in the `it` block:
   `org = create(:organization, name: 'Redwood Books')`.
3. **You are adding several scenarios** — open a sibling `context` block rather
   than nesting deeper.

Add a `let` at the file's top level only when most of the file's examples use it.

## Related skills

- **A slow suite, a profiler run, or `let_it_be`** — the `rails-core:testprof` skill owns
  these, in its "When to reach for `let_it_be` vs `let`" and "Diagnostic decision tree"
  sections. It is user-invoked only, so name it for the user to run and carry on with the
  spec in front of you. Where the user does run it, `let_it_be` is eager and group-scoped,
  so its cost is paid once per group while Rule 4's is paid per example — that skill states
  the tradeoff, and Rule 4 still places every ordinary `let`.
