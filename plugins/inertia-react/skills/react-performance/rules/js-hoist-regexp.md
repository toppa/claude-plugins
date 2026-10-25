---
title: Hoist RegExp Creation
impact: LOW-MEDIUM
impactDescription: avoids recompiling a pattern, and keeps a /g regex from being shared
tags: javascript, regexp, optimization, memoization
---

## Hoist RegExp Creation

Put a constant pattern at module scope, and build a pattern that depends on props inside a
`useMemo`:

```tsx
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function Highlighter({ text, query }: Props) {
  const regex = useMemo(
    () => new RegExp(`(${escapeRegex(query)})`, 'gi'),
    [query]
  )
  const parts = text.split(regex)
  return <>{parts.map((part, i) => ...)}</>
}
```

`escapeRegex` around an interpolated value is not optional: a user-typed `(` or `*` otherwise
either throws a `SyntaxError` or silently changes what the pattern matches.

**A `/g` regex carries mutable state, so hoisting one changes behaviour.** `lastIndex` persists
between calls on the same object:

```typescript
const regex = /foo/g
regex.test('foo')  // true, and lastIndex is now 3
regex.test('foo')  // false — the search starts at index 3
```

Executed in node 24.3.0, exactly as shown. So the rule has a limit worth stating: hoist a `/g`
pattern to module scope only if every caller resets `lastIndex` or uses a method that ignores it
(`String#split`, `String#replace`, `String#matchAll`). For `test` or `exec` on a `/g` pattern,
build it where it is used — a per-render `new RegExp` is the correct choice there, not a
pessimisation. Without `/g` there is no shared state and hoisting is free.
