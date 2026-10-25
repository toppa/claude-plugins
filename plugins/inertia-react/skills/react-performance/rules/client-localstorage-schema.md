---
title: Version and Minimize localStorage Data
impact: MEDIUM
impactDescription: prevents schema conflicts, reduces storage size
tags: client, localStorage, storage, versioning, data-minimization
---

## Version and Minimize localStorage Data

Add version prefix to keys and store only needed fields. Prevents schema conflicts and accidental storage of sensitive data.

**Incorrect:**

```typescript
// No version, stores everything, no error handling
localStorage.setItem('userConfig', JSON.stringify(fullUserObject))
const data = localStorage.getItem('userConfig')
```

**Correct:**

```typescript
const VERSION = 'v2'

function saveConfig(config: { theme: string; language: string }) {
  try {
    localStorage.setItem(`userConfig:${VERSION}`, JSON.stringify(config))
  } catch {
    // QuotaExceededError, or SecurityError when storage is blocked
  }
}

function loadConfig() {
  try {
    const data = localStorage.getItem(`userConfig:${VERSION}`)
    return data ? JSON.parse(data) : null
  } catch {
    return null
  }
}

// Migration from v1 to v2
function migrate() {
  try {
    const v1 = localStorage.getItem('userConfig:v1')
    if (v1) {
      const old = JSON.parse(v1)
      saveConfig({ theme: old.darkMode ? 'dark' : 'light', language: old.lang })
      localStorage.removeItem('userConfig:v1')
    }
  } catch {}
}
```

Where the app also caches storage reads in memory — `rules/js-cache-storage.md` — route
`saveConfig` through that module's `setLocalStorage` rather than calling `localStorage.setItem`
directly. That file's cache is only correct while every same-tab write updates it, and its
`storage` listener fires for other tabs only, so a write that bypasses it leaves the cache
stale for the life of the tab.

**Store minimal fields from server responses:**

```typescript
// User object has 20+ fields, only store what UI needs
function cachePrefs(user: FullUser) {
  try {
    localStorage.setItem('prefs:v1', JSON.stringify({
      theme: user.preferences.theme,
      notifications: user.preferences.notifications
    }))
  } catch {}
}
```

**What actually throws, per the HTML Living Standard:** the `localStorage` *accessor* throws
`SecurityError` when storage is disabled or blocked, and `setItem` throws
`QuotaExceededError`. `getItem` has no throwing step of its own — so a `try` around a read is
there for the accessor, and for the `JSON.parse` of whatever was stored, which is the failure
you will actually see. Wrapping both is still the right shape; the reason is parse failure and
a blocked accessor, not a throwing `getItem`.

**Benefits:** Schema evolution via versioning, reduced storage size, prevents storing tokens/PII/internal flags.
