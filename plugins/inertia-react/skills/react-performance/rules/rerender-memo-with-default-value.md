---
title: Hoist a Non-primitive Default Prop Value to Module Scope
impact: LOW
impactDescription: gives the default a stable identity
tags: rerender, memo, optimization
---

## Hoist a Non-primitive Default Prop Value to Module Scope

When a component's optional prop defaults to a function, array or object, define that default
once at module scope:

```tsx
const NOOP = () => {}

const UserAvatar = memo(function UserAvatar({ onClick = NOOP }: { onClick?: () => void }) {
  // ...
});

<UserAvatar />
```

**What this does and does not fix.** It does not restore memoization, because memoization was
never broken. `<UserAvatar />` compiles to props `{}`, and a destructuring default in the
component's own parameter list is applied *inside the function body* — after `memo` has
compared props. Verified in the installed `react-dom` 19.2.8: `updateSimpleMemoComponent`
compares with `shallowEqual(prevProps, nextProps)`
(`cjs/react-dom-client.development.js:9814`), and `:9755` reads
`void 0 === type.defaultProps`, since `defaultProps` resolution was removed for function
components in React 19. The absent prop is absent in both objects, so they are equal and the
bailout happens.

What hoisting does buy is a stable identity for the value *inside* the component. A fresh
`() => {}` per render destabilises anything that closes over it: a dependency array that lists
it, and any memoized child it is forwarded to. That is the reason to write `NOOP`, and it
applies whether or not the outer component is wrapped in `memo`.

Because the payoff is identity rather than a bailout, this is a small rule. If your project
has [React Compiler](https://react.dev/learn/react-compiler) enabled it is moot: the compiler
handles the identity, and `memo` itself is largely unnecessary.
