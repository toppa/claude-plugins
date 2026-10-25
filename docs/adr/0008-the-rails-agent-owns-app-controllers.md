# 0008 — The `rails` agent owns `app/controllers`, and the `frontend` agent writes no Ruby

## Context

`rails-core` ships the `rails` agent, and `inertia-react` ships the `frontend` agent. Before
2026-08-11 their boundary contradicted itself. `rails.md` claimed `app/`. `frontend.md`
claimed "the Inertia half of a controller action", and its stop list omitted controllers.
Nothing decided between them. So the main session could send both agents to the same file, and
each one lacked the other's half of the knowledge.

## Decision

**`rails` owns `app/controllers` in full, including the Inertia response.** It owns
`inertia_share` too, because that is a class method on a controller, so it is Ruby in a
controller.

**`frontend` writes no Ruby.** It specifies the props contract in five parts:

1. Each prop key and its wrapper.
2. The TypeScript type behind each key.
3. Which keys every page needs, as against this action's keys.
4. Which flash keys the action sets.
5. Where a write redirects.

It reports the contract as a paste-ready `render inertia:` block, so the Ruby side is
mechanical. The two report lists are the two directions of one handoff: `frontend` reports
the contract, and `rails` reports every prop key it adds, renames, or removes.

**Each agent's `description` states its half.** The `description` is the only routing surface
that the main session has. `frontend`'s says "the props contract a controller action
renders". `rails`' says "controllers and the response an action renders". Edit the two
together. `scripts/check-skills.rb` checks both agents' `skills:` lists, and it reads neither
`description`, so nothing else catches a pair that drifts apart.

**The skill descriptions keep the same split.** `rails-core:rails-8-idioms` carries no Inertia
words in its `description`, because `inertia-rails-controllers` owns the index slot for an
action that renders Inertia. Inertia words there would make two skills claim one trigger.

**`rails` names `frontend` once, and routes nothing to it.** `frontend` ships in
`inertia-react`, which installs at project scope, so a pointer to it dangles in every other
Rails project. Work outside `rails`' scope goes back to the main session. A project without
`inertia-react` loses one sentence of context.

**A `.js` file needs no rule in `rails`.** The agent stops at a `.js`, `.ts`, or `.tsx` file or
a stylesheet, and reports it, and the main session routes it.

## The alternatives that lost

**Silence about the other agent.** Before 2026-08-11 `rails` named no other agent, because the
pointer dangles where `inertia-react` is absent. That silence caused the worse failure above.

**Widen `frontend`'s `description` to cover spec work**, so that it reaches the
`inertia-rails-testing` skill. Its description covers screens and `.tsx` review, and that
never causes a delegation to spec work. An Inertia request spec usually reaches `rails`. So
`frontend` invokes `inertia-rails-testing` only when a spec is already in its task.
