---
name: react-composition
description: >-
  Eight rules for React component API design from Vercel Engineering: give each mode its
  own component instead of a boolean prop, build compound components over a shared
  context so state reaches a sibling without prop drilling, use children rather than
  `renderX` props, and take `ref` as a plain prop on React 19.
when_to_use: >-
  Use when a component collects boolean props or flags, when one component grows several
  modes, when a component takes too many props or you are passing props through a middle
  component that does not use them (prop drilling), when you want to extract a component
  from one that has got complicated, or when a sibling outside the visual tree needs
  another component's state.
license: MIT
metadata:
  upstream_repo: vercel-labs/agent-skills
  upstream_path: skills/composition-patterns/
  upstream_ref: 7c180d9044c9ae2b442b567aad4e42a28dd5ed62
  synced: 2026-08-08
  verified_against: "React 19.2.8, @types/react 19.2.17, @inertiajs/react 3.6.1, TypeScript 7.0.2"
---

# React Composition

Component API design for React, from Vercel Engineering. Eight rules in four categories.
No rule here is a performance rule; `react-performance` owns that. One passage names a
re-render cost, because a composition choice creates it: the context split in
`state-context-interface`, under "When one context value costs too much".

## The stack these rules run in

Every rule below uses one worked example: a chat composer with several modes, written in
web elements (`<textarea>`, `onChange`, `onClick`) against React 19.

**Where state comes from here.** Three of the eight rules (`state-`) put the composer's
state in a provider so any component inside the provider can read it. That technique is
sound and it is what you want for a component's own UI state — an open panel, a selected
tab, a draft that several sibling controls share. It is not a reason to add a client-side
state library: page data arrives from Rails through `usePage().props`, and form state
belongs to `<Form>` or `useForm`. `state-context-interface` and
`state-decouple-implementation` therefore contrast two providers behind the same interface: a
local `useState` one, and one whose values come from `usePage().props`. `state-lift-state`
asks a different question — where the state lives — so it stays on `useState` throughout.

**`useFormContext` already solves the form case.** The provider-boundary insight in
`state-context-interface` — a component can read shared state from anywhere inside the
provider, whatever the visual nesting — is exactly what `@inertiajs/react` gives you for
a form. `useFormContext()` returns the enclosing `<Form>`'s state and methods
(`processing`, `isDirty`, `errors`, `submit`, `reset`, …) or `undefined` when there is no
`<Form>` above. So a submit bar or an error summary rendered outside the form's own
markup needs no lifted state and no provider of your own. Write your own provider for
state that is not a form's. `inertia-rails-forms` holds the API surface, in its "Reading form
state from a nested child with `useFormContext`" section.

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
|----------|----------|--------|--------|
| 1 | Component Architecture | CRITICAL–HIGH | `architecture-` |
| 2 | State Management | HIGH–MEDIUM | `state-` |
| 3 | Implementation Patterns | MEDIUM | `patterns-` |
| 4 | React 19 APIs | MEDIUM | `react19-` |

The priority order and the `impact:` value in each rule file are upstream's editorial
ranking. Nothing parses them; they are a reading order, not a measurement.

## Quick Reference

### 1. Component Architecture (CRITICAL–HIGH)

- `architecture-avoid-boolean-props` - Give each mode its own component; keep the shared
  parts composable (CRITICAL)
- `architecture-compound-components` - Structure a complex component as parts over a
  shared context (HIGH)

### 2. State Management (HIGH–MEDIUM)

- `state-context-interface` - Define the context as `state`, `actions`, `meta`, and read
  it through one guard hook (HIGH)
- `state-lift-state` - Put the state in a provider so a sibling outside the UI can reach
  it (HIGH)
- `state-decouple-implementation` - Keep the knowledge of where state comes from in the
  provider (MEDIUM)

### 3. Implementation Patterns (MEDIUM)

- `patterns-explicit-variants` - Name each variant as its own component and wire its own
  provider
- `patterns-children-over-render-props` - Pass `children` for structure; keep `renderX`
  for the case where the parent supplies the data

### 4. React 19 APIs (MEDIUM)

- `react19-no-forwardref` - Take `ref` as a plain prop, and read context with `use()`

This section applies where the project runs React 19 or later. Its rule was verified against
React 19.2.8.

## How to Use

Read individual rule files for detailed explanations and code examples:

```
rules/architecture-avoid-boolean-props.md
rules/patterns-explicit-variants.md
```

Each rule file states the form to write, shows it, and says what it buys.

## Related Skills

| Need | Skill |
|---|---|
| Wasted renders, bundle size, hot-path JavaScript | `react-performance` |
| Page components, layouts, props from Rails | `inertia-rails-pages` |
| Form state, `useFormContext`, `<Form>` versus `useForm` | `inertia-rails-forms` |
