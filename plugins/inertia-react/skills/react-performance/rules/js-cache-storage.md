---
title: Cache Storage API Calls
impact: LOW-MEDIUM
impactDescription: reduces synchronous storage reads on a hot path
tags: javascript, localStorage, storage, caching, performance
---

## Cache Storage API Calls

`localStorage`, `sessionStorage` and `document.cookie` are synchronous. A read on a hot path
— inside a render, a scroll handler, a list map — is worth caching in memory. A read that
happens once per page is not; `localStorage.getItem` is fast enough that a cache around a
single call is more code than it saves.

**Cache the reads you make repeatedly, and keep writes going through the same place:**

```typescript
const storageCache = new Map<string, string | null>()

function getLocalStorage(key: string) {
  if (!storageCache.has(key)) {
    storageCache.set(key, localStorage.getItem(key))
  }
  return storageCache.get(key)
}

function setLocalStorage(key: string, value: string) {
  localStorage.setItem(key, value)
  storageCache.set(key, value)
}
```

A module-level `Map` rather than a hook, so utilities and event handlers can use it too.

**Keep the key set closed.** In an Inertia app the module lives for the whole session across
every visit, so a cache keyed on anything user-supplied grows for as long as the tab is
open. Cache a fixed set of known keys — `theme`, `sidebar`, a feature flag — not arbitrary
strings.

**Cookies: split on the first `=` only.**

```typescript
let cookieCache: Record<string, string> | null = null

function getCookie(name: string) {
  if (!cookieCache) {
    cookieCache = Object.fromEntries(
      document.cookie.split('; ').map((pair) => {
        const eq = pair.indexOf('=')
        return [pair.slice(0, eq), decodeURIComponent(pair.slice(eq + 1))]
      })
    )
  }
  return cookieCache[name]
}
```

`pair.split('=')` truncates every value containing an `=`, which includes Rails' own
base64 session payloads and anything URL-encoded. Executed against
`_shop_session=BAh7CE=--9f8a2b3c%3D%3D; theme=dark; token=abc=def`, `split('=')` yields
`{ _shop_session: 'BAh7CE', theme: 'dark', token: 'abc' }` — two of the three values
silently wrong — while the `indexOf` version above returns all three intact. The
`decodeURIComponent` matters for the same reason.

**Invalidate the `storageCache` key that changed, not the whole cache. Nothing invalidates
`cookieCache`, so cache only cookies the server does not rewrite:**

```typescript
window.addEventListener('storage', (event) => {
  if (event.key) storageCache.delete(event.key)
})
```

The `storage` event fires only for *other* tabs, which is exactly the case a same-tab write
cannot cover. Do not clear the whole cache on `visibilitychange`: a tab that is switched
away from and back gets a full cold cache, which discards the reason the cache existed. If a
value can be changed by the server, get it from Rails as a shared prop instead of a cookie —
then Inertia's page object is the cache and it is invalidated by every visit.
