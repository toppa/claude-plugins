---
title: Defer State Reads to Usage Point
impact: MEDIUM
impactDescription: avoids unnecessary subscriptions
tags: rerender, page-props, query-string, optimization
---

## Defer State Reads to Usage Point

If a value is only read inside a callback, read it inside the callback. Subscribing to it at
the top of the component re-renders the component every time it changes, for no visible
benefit.

**A query-string value read on click:**

```tsx
function ShareButton({ chatId }: { chatId: string }) {
  const handleShare = () => {
    const params = new URLSearchParams(window.location.search)
    shareChat(chatId, { ref: params.get('ref') })
  }

  return <button onClick={handleShare}>Share</button>
}
```

`window.location.search` is read at click time and nothing subscribes. The same applies to
`localStorage.getItem`, `document.cookie`, and any other value the component displays nowhere.

**`usePage()` is the version of this that matters most in an Inertia app.** `usePage` is
`use(PageContext)` (`@inertiajs/react/dist/index.js:346`), and the provider's value is
`current.page` — a fresh page object on every visit (`:199-201`). So **every component that
calls `usePage()` re-renders on every Inertia visit**, whether or not the prop it reads
changed. Two consequences:

- Read page props once, at the page component, and pass what a child needs as a prop. A leaf
  component calling `usePage()` for `auth.user.name` subscribes the leaf to every visit.
- Do not call `usePage()` just to reach a value inside a callback. There is nothing to defer
  to — the page object is already in memory — so pass the value in as a prop from the page
  root and the subscription disappears.

This is the largest single source of avoidable re-renders in this stack, and it does not look
like a subscription, which is why it is easy to miss.

`useSearchParams` is not available here — it belongs to `next/navigation` and react-router,
and it is absent from both `@types/react` 19.2.17 and `@inertiajs/react` 3.6.1. Inertia's
equivalents are the page URL (`usePage().url`) and `window.location.search`.
