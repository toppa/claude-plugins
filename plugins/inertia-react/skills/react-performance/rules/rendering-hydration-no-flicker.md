---
title: Prevent Hydration Mismatch Without Flickering
impact: MEDIUM
impactDescription: avoids visual flicker and hydration errors
tags: rendering, ssr, hydration, localStorage, flicker
---

## Prevent Hydration Mismatch Without Flickering

This rule applies only when Inertia SSR is on, and only to a value the server genuinely cannot
know *and* that must be visibly correct on the first paint. When the difference is only formatting
that a warning complains about — a date, a locale, a random id — the cheaper remedy is
`rules/rendering-hydration-suppress-warning.md`.

**Try the Rails route first, because it usually applies.** Rails renders the document, so anything
Rails can read it can send: a theme in a cookie, a locale, a saved layout preference. Read it in the
controller, share it, and the value is in the first render on both sides — no mismatch to suppress,
no script to inject, and the value is typed.

```ruby
# app/controllers/application_controller.rb
inertia_share theme: -> { cookies[:theme].presence || "light" }
```

```tsx
function ThemeWrapper({ children }: { children: ReactNode }) {
  const { theme } = usePage().props
  return <div className={theme}>{children}</div>
}
```

That covers the common case. What is left for the rest of this rule is a value that only exists on
the client — something in `localStorage`, which is never sent to the server, or a value derived from
`window` — where you cannot make the server agree because the server cannot know.

When rendering content that depends on client-side storage, avoid both SSR breakage and
post-hydration flickering by injecting a synchronous script that updates the DOM before React
hydrates.

**Incorrect (breaks SSR):**

```tsx
function ThemeWrapper({ children }: { children: ReactNode }) {
  // localStorage is not available on server - throws error
  const theme = localStorage.getItem('theme') || 'light'
  
  return (
    <div className={theme}>
      {children}
    </div>
  )
}
```

Server-side rendering will fail because `localStorage` is undefined.

**Incorrect (visual flickering):**

```tsx
function ThemeWrapper({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState('light')
  
  useEffect(() => {
    // Runs after hydration - causes visible flash
    const stored = localStorage.getItem('theme')
    if (stored) {
      setTheme(stored)
    }
  }, [])
  
  return (
    <div className={theme}>
      {children}
    </div>
  )
}
```

Component first renders with default value (`light`), then updates after hydration, causing a visible flash of incorrect content.

**Correct (no flicker, no hydration mismatch):**

```tsx
function ThemeWrapper({ children }: { children: ReactNode }) {
  return (
    <>
      <div id="theme-wrapper">
        {children}
      </div>
      <script
        dangerouslySetInnerHTML={{
          __html: `
            (function() {
              try {
                var theme = localStorage.getItem('theme') || 'light';
                var el = document.getElementById('theme-wrapper');
                if (el) el.className = theme;
              } catch (e) {}
            })();
          `,
        }}
      />
    </>
  )
}
```

The inline script executes synchronously before showing the element, ensuring the DOM already has the correct value. No flickering, no hydration mismatch.

Two caveats on this last pattern:

- **It is only reliable on the initial document.** The script tag is part of the SSR'd HTML; on a
  subsequent client-side Inertia visit the component re-renders without the browser re-executing an
  inline script, so the class is applied once and then not maintained. If the value can change while
  the app is running, hold it in state as well.
- **A `<script>` in the Rails layout is the better home for it** when it applies to the whole
  document, because the layout runs before any React code and is not tied to a component's lifetime.
  Reach for the in-component version only when the element it patches is inside a page.

Use this for genuinely client-only data — a `localStorage` preference with no server-side
counterpart. For authentication state, do not: that comes from Rails as a shared prop on every visit,
so it is already in the first render.
