---
title: Guard a Conditional Render When the Left Side Is a Number
impact: LOW
impactDescription: keeps 0 and NaN from rendering as text
tags: rendering, conditional, jsx, falsy-values
---

## Guard a Conditional Render When the Left Side Is a Number

When the left side of a conditional render can be a **number**, compare it rather than relying on
truthiness:

```tsx
function Badge({ count }: { count: number }) {
  return <div>{count > 0 && <span className="badge">{count}</span>}</div>
}
```

`{count && …}` evaluates to `0` when `count` is `0`, and React renders `0` as text — so the badge
disappears and a stray zero takes its place. `NaN` behaves the same way. Turning the left side into a
real boolean (`count > 0`, `items.length > 0`, `Boolean(value)`) fixes it, and a ternary with `null`
does too.

**`&&` is not the problem and does not need replacing generally.** react.dev's Pitfall on this is
narrow — "Don't put **numbers** on the left side of `&&`" — and keeps `&&` as the idiom for
conditional rendering. `{user && <Profile user={user} />}` is correct and idiomatic: an object or
`undefined` on the left renders nothing when falsy. So this rule fires on a *numeric* condition, not
on every `&&` in the file, and a sweep replacing `&&` with ternaries would be churn.

Strings are the other case worth knowing: `{name && <h1>{name}</h1>}` renders nothing for `''`,
which is usually what you want — but it is truthiness on a non-boolean, so if `''` should render
something, compare explicitly.
