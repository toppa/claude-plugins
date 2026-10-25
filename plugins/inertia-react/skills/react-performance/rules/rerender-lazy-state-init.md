---
title: Use Lazy State Initialization
impact: MEDIUM
impactDescription: wasted computation on every render
tags: react, hooks, useState, performance, initialization
---

## Use Lazy State Initialization

Pass a function to `useState` for expensive initial values. Without the function form, the initializer runs on every render even though the value is only used once.

**Incorrect (runs on every render):**

```tsx
function FilteredList({ items }: { items: Item[] }) {
  // buildSearchIndex() runs on EVERY render, even after initialization
  const [searchIndex, setSearchIndex] = useState(buildSearchIndex(items))
  const [query, setQuery] = useState('')
  
  // When query changes, buildSearchIndex runs again unnecessarily
  return <SearchResults index={searchIndex} query={query} />
}

function UserProfile({ settingsJson }: { settingsJson: string }) {
  // JSON.parse runs on every render
  const [settings, setSettings] = useState(JSON.parse(settingsJson))
  
  return <SettingsForm settings={settings} onChange={setSettings} />
}
```

**Correct (runs only once):**

```tsx
function FilteredList({ items }: { items: Item[] }) {
  // buildSearchIndex() runs ONLY on initial render
  const [searchIndex, setSearchIndex] = useState(() => buildSearchIndex(items))
  const [query, setQuery] = useState('')
  
  return <SearchResults index={searchIndex} query={query} />
}

function UserProfile({ settingsJson }: { settingsJson: string }) {
  // JSON.parse runs only on initial render
  const [settings, setSettings] = useState(() => JSON.parse(settingsJson))
  
  return <SettingsForm settings={settings} onChange={setSettings} />
}
```

Use lazy initialization when building a data structure (an index, a map), parsing a large prop, or performing a heavy transformation.

**A browser-only read does not belong in an initializer at all.** The initializer runs during the first render, and under Inertia SSR that first render happens on the server. `localStorage.getItem`, a `sessionStorage` read, and a DOM read each throw there. `rules/rendering-hydration-no-flicker.md` prescribes the form that works, with a synchronous script that runs before React hydrates.

For simple primitives (`useState(0)`), direct references (`useState(props.value)`), or cheap literals (`useState({})`), the function form is unnecessary.
