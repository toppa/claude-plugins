---
name: extraction-timing
description: Decides when and how to extract Rails code into services, queries, concerns, form objects, presenters, or Rails view components — and when to leave it inline. Component means a Rails ViewComponent here; the inertia-react plugin owns React component structure.
when_to_use: >-
  Use when deciding whether code should move out of where it is — refactoring,
  extraction, "where should this go" — when choosing between a service, a concern
  and a query object, or when weighing a base class. This skill answers the question
  before the move: whether the code has grown enough, and where it goes. For a
  before-and-after number on a refactor you already made, use the
  `rails-core:rubycritic` skill. For architecture-level layer design, use the
  `rails-core:rails-architecture` skill.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/extraction-timing/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: Rails 8.1.3.1 (activerecord, activemodel, railties), rubocop 1.89.0, rubocop-rails-omakase 1.1.0, reek 6.5.0, inertia_rails 3.22.0
---

# Extraction timing

## Skinny everything

Rails organization has moved beyond "Fat Models" to **skinny everything**: controllers orchestrate, models
persist, services hold business logic, views carry markup with zero logic. `rails-architecture` states what
each layer owns; the thresholds below say when a piece has outgrown the layer it is in.

## Extraction Thresholds

These rows are extraction triggers, not tool settings. Where a tool publishes a number for the same
signal, the tool's default at the installed version governs, and each row below cites it. For
configuring the cop or the detector, the wrapping skill owns that: `rubocop` for the `Metrics`
department, `rubycritic` for Reek and flog.

The role is either a **design target** (what you aim for while writing) or a **review ceiling** (what earns a
comment in review). A row marked **house heuristic** has no external source: read it as a prompt to look,
not as a gate.

Verified stack: Rails 8.1.3.1, Ruby 3.4.5, rubocop 1.89.0 through `rubocop-rails-omakase ~> 1.1`. Omakase
sets `Metrics: Enabled: false` (`rubocop-rails-omakase-1.1.0/rubocop.yml:23-24`), so on any app inheriting it
no `Metrics` number is enforced by the build. Each `Metrics` number below is therefore a review ceiling
with a published, checkable value rather than a limit the build enforces.

| Signal | Action | Source, unit, role |
|--------|--------|--------------------|
| Controller action carries more than 10 lines of business logic | Extract to service object | `Metrics/MethodLength`, `Max: 10` (rubocop 1.89.0, `config/default.yml:2870`); unit is lines of method body, comments excluded (`CountComments: false`); role is review ceiling. The design target is tighter: Reek 6.5.0's `TooManyStatements` allows 5 **statements** (`DEFAULT_MAX_STATEMENTS`), and `rubycritic` wraps Reek. |
| Model exceeds 100 lines | Extract business logic to services, complex queries to query objects | `Metrics/ClassLength`, `Max: 100` (rubocop 1.89.0, `config/default.yml:2843`); unit is lines of class body, comments excluded; role is review ceiling. |
| Query joins multiple tables or has conditional clauses | Extract to query object | No number. |
| Form writes to more than one model | Extract to form object. A custom rule on a single model stays in the model: `validate :method_name` and `validates_with` both live there (activemodel 8.1.3.1, `validations.rb:162`, `validations/with.rb:88`), so a custom rule on its own does not earn a new class | No number. |
| Display formatting logic in model | Extract to presenter | No number. |
| A UI element is needed in a second view | Extract to a ViewComponent when `view_component` is already in the Gemfile; otherwise use a logic-free partial, which is what `rails-architecture` states | House heuristic, no external source; unit is views using the element; role is a prompt to look. |
| A second model needs the same behavior | Ask whether both models will change for the same reason. If they will, extract a concern. If the resemblance is coincidental, keep both copies and decide again when a third case arrives | House heuristic, no external source; unit is models sharing the behavior; role is a prompt to look. |
| Several implementations already share behavior, not only shape | Extract a base class. Shared shape with nothing shared behind it is a template, not a superclass | No number: shared behavior is the condition, and counting implementations does not detect it. |
| One-off operation | Inline is fine. | No number. |

### What counts as business logic in an action

The 10-line ceiling measures the work an action does, not the shape of what it returns:

- **The argument to `render` is representation, not business logic.** A props hash, a JSON payload, or a
  template's locals does not count against the ceiling however many keys it has.
- **A value that takes more than one expression to build moves out** — into a private `serialize_x` method
  when it shapes one record, or into a query object when it chooses which records.

The three Rails 8.1 scaffolds hold the action to that size in three ways. The first two ship in
railties 8.1.3.1, under `lib/rails/generators/rails/scaffold_controller/templates/`. The ERB scaffold
assigns the record and renders a template by name — `render :new, status: :unprocessable_content`
(`controller.rb.tt:30`) — so the formatting sits in the ERB, and it moves to a presenter or a helper
once it carries logic. The API scaffold renders the record itself (`api_controller.rb.tt:22`). The
`inertia_rails` 3.22.0 scaffold has no template to hold the formatting, so it defines a private
`serialize_<model>` returning `as_json(only: [...])`
(`lib/generators/inertia/scaffold_controller/templates/controller.rb.tt:84-86`, below the `private` at
`:67`) and has each action render `serialize_<model>(record)` (`:22`). A JSON API response that needs
more than the bare record takes that same private `serialize_x`.

## Decision Tree: "Where Should This Code Go?"

```
Is it a database query?
  ├── Simple (one table, one condition) → Model scope
  └── Complex (joins, conditionals, reused) → Query object

Is it business logic?
  ├── Simple CRUD on one model → Controller inline (or model method)
  └── Multi-step, external API, or spanning models → Service object
      (wrap a write that spans models in a transaction)

Is it shared behavior?
  ├── Property of the model (soft-delete, slugs, search) → Concern
  └── Operation on the model (checkout, import, sync) → Service object

Is it display logic?
  ├── Formatting one model's data → Presenter (SimpleDelegator)
  ├── Reusable UI element → Partial, or a view component where the gem is installed
  └── Formatting that unrelated views share → Keep in helper

Is it validation?
  ├── One model, standard or custom rules → Model validation
  ├── A form writing to more than one model → Form object
  └── Business rule (not data integrity) → Service validation
```

## Settled Debates

### Concerns vs Service Objects

| | Concerns | Service Objects |
|--|---------|----------------|
| **Use for** | Simple shared model properties | Multi-step business operations |
| **Examples** | `SoftDeletable`, `Searchable`, `Sluggable` | `CreateOrder`, `ProcessRefund`, `ImportCsv` |
| **Size** | 30 lines is a house heuristic, no external source: a prompt to check for a second responsibility. The published number for a module is `Metrics/ModuleLength`'s `Max: 100` (rubocop 1.89.0, `config/default.yml:2881`), a review ceiling on lines of module body | A service is a class, so `Metrics/ClassLength`'s 100-line review ceiling applies as it does to any class (SRP still decides what belongs in it) |
| **Test via** | Including model's specs | Isolated unit specs |

### STI vs delegated types

Use STI where the subclasses diverge little and share nearly all their columns, and `delegated_type` where
each subtype has its own attributes and you still want one paginated list across all of them. A polymorphic
`belongs_to` solves a different problem: one association pointing at several unrelated models. For the table
shapes, the declarations and the boundary in Rails' own words, read
[references/class-hierarchies.md](references/class-hierarchies.md) (~21 lines).

### Callbacks vs explicit calls

**Rule:** a callback normalizes an attribute or guards a destroy. Everything else is an explicit call, in a
service. Where Rails 8.1 ships a declaration for the job, write the declaration.

| Job | Write |
|-----|-------|
| Normalize an attribute's value | `normalizes :email_address, with: ->(e) { e.strip.downcase }` |
| Give an attribute a default | A column default in the migration, or `attribute :status, :string, default: "draft"` |
| Refuse a destroy that would orphan records | `before_destroy :check_dependencies`, or `dependent:` on the association where that says what you mean |
| Send mail, enqueue a job, call an external API, or create related records with business logic | An explicit call in a service object |

For the mechanism behind each row — the `normalizes` save sequence, why an `after_initialize` default re-runs
on every loaded row, and why a destroy guard is the callback worth keeping — read
[references/callbacks-and-declarations.md](references/callbacks-and-declarations.md) (~25 lines).

## Before You Extract

- [ ] **The new class does something its name promises.** A service holds steps the caller should not have
      to know. When the body comes out as one `model.update!`, a method on the model is the extraction.
- [ ] **The concern has one responsibility**, nameable as a single adjective.
- [ ] **A helper holds only what unrelated views share.** Formatting for one model is the presenter's.
- [ ] **A caller needs it now.** Extract for the callers already in the code, and let an anticipated one
      arrive before designing for it.

## Related skills

- `rails-architecture` — which layer owns which responsibility, and what belongs in each.
- `review-ruby-code` — SOLID, Sandi Metz rules, and code smells, with reference files.
