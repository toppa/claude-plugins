---
title: Sort Into a New Array, Never in Place
impact: MEDIUM-HIGH
impactDescription: prevents mutation bugs in React state
tags: javascript, arrays, immutability, react, state, mutation
---

## Sort Into a New Array, Never in Place

This is a correctness rule, not a performance one. `.sort()` sorts in place, so sorting a
prop or a state array mutates the caller's data. Sort into a new array instead:

```typescript
function UserList({ users }: { users: User[] }) {
  const sorted = useMemo(
    () => [...users].sort((a, b) => a.name.localeCompare(b.name)),
    [users]
  )
  return <div>{sorted.map(renderUser)}</div>
}
```

Mutating a prop array breaks the model React works from — props and state are read-only —
and the damage is at a distance: the array the parent still holds is now in a different
order, so a later comparison against it, or a sibling reading the same array, sees the sorted
version.

**`.toSorted()` is the same thing more directly, and it needs `lib` raised first.**

```typescript
const sorted = users.toSorted((a, b) => a.name.localeCompare(b.name))
```

`toSorted`, `toReversed`, `toSpliced` and `with` are ES2023. Check your
`tsconfig.app.json` before you reach for one. Where it sets
`lib: ["ES2020", "DOM", "DOM.Iterable"]`, all four are
**TS2550** — *"Property 'toSorted' does not exist on type 'string[]'. … Try changing
the 'lib' compiler option to 'es2023' or later"* (verified with TypeScript 7.0.2 against that
exact `lib`). Raise `lib` to `ES2023` in `tsconfig.app.json` and they type-check; until then
`[...arr].sort(…)` is the form that compiles, and it is not a fallback for old browsers — the
runtime support is there (Chrome 110+, Safari 16+, Firefox 115+, Node 20+; MDN gives the
group a Baseline date of July 2023), it is only TypeScript's `lib` that is behind.
