---
title: Calculate Derived State During Rendering
impact: MEDIUM
impactDescription: avoids redundant renders and state drift
tags: rerender, derived-state, useEffect, state
---

## Calculate Derived State During Rendering

If a value can be computed from current props/state, do not store it in state or update it in an effect. Derive it during render to avoid extra renders and state drift. Do not set state in effects solely in response to prop changes; prefer derived values or keyed resets instead.

**Derive it during render:**

```tsx
function NameSummary() {
  const [firstName, setFirstName] = useState('First')
  const [lastName, setLastName] = useState('Last')
  const fullName = `${firstName} ${lastName}`

  return <p>{fullName}</p>
}
```

The shape to move away from is a third `useState` for `fullName` kept in step by a `useEffect`. It
costs an extra render every time either input changes — React renders with the stale `fullName`,
then the effect sets it, then it renders again — and it can drift, because any code path that
updates `firstName` without going through the effect leaves the two disagreeing.

The same reasoning covers a value derived from props: derive it, do not mirror it into state. When
you genuinely need to *reset* state as a prop changes, give the component a `key` rather than
writing an effect.

**A note on this stack:** with `<Form>` the inputs are uncontrolled, so there is no `firstName`
state to derive from — you read the values at submit, or from `useFormContext()`. This rule applies
to a component's own local state, and the example above is deliberately not a form.

References: [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
