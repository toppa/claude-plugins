# Decision Trees

Quick flowcharts for common Inertia.js + Rails decisions.

**About the timings below.** Every timing and frequency figure in this file is a house heuristic
with no external source — no Inertia, Rails, or browser default sets any of them. They are
here to give a judgment call a starting point, not to be enforced. Measure the query and
override them freely.

## "I need data in my component"

```
Is this data specific to this page?
├── YES → Controller prop: render inertia: { key: value }
│   └── Is it expensive to compute?
│       ├── >500ms → InertiaRails.defer { ... }
│       ├── <100ms → Regular prop (defer overhead not worth it)
│       └── 100-500ms → Judgment call — defer if page has fast props to show first
├── NO, it's needed on every page → inertia_share
└── NO, it's from an external API → Dedicated API endpoint
    (a Stripe subscription status, a shipping quote)
```

`render inertia: { … }` with a Hash first argument is legal and is what the gem's own
generator writes: the Hash is the props, and the component resolves from
`controller_path/action_name`. Name the component explicitly —
`render inertia: 'Users/Show', props: { … }` — whenever the file does not sit at the
lowercased path that resolver produces.

## "I need to update data"

```
Is this a form submission (create/update/delete)?
├── YES → <Form> component + controller action + redirect
│   └── Need programmatic control? → useForm hook instead
└── NO
    ├── Need to refresh page data? → router.reload({ only: [...] })
    ├── Need real-time updates?
    │   ├── Core feature (chat, live feed)? → ActionCable + router.reload
    │   └── MVP/prototype or no ActionCable yet? → usePoll(interval, { only: [...] })
    ├── Need optimistic UI? → router.optimistic(fn).post(...) — Inertia rolls back for you
    ├── Need a response body rather than a page? → useHttp
    └── Need search/filter? → router.visit with query params (preserveState)
```

Let Inertia own the optimistic rollback rather than pairing `useState` with an `onError`
handler. It applies your change to the props, then reverts it on a 422, on a server error,
or when a new visit interrupts the request. See `inertia-react:inertia-rails-forms` for the
`<Form>` and `useForm` equivalents.

## "I need state in my component"

```
Where does the data come from?
├── Server → It's a prop, not state
├── User interaction the URL should carry (a dialog, a tab) → controller reads params → prop
├── User interaction the URL should not carry (a dropdown, a hover) → useState
├── Form data → <Form> component (or useForm for complex cases)
├── Shared across pages (auth) → usePage().props (from inertia_share)
└── Multiple components need it → Lift to closest common parent as prop
    └── Still unwieldy? → Consider React Context (rare in Inertia apps)
```

That last step is about **client** state several siblings read. Server-owned global data
belongs in `inertia_share`, which is a different question — the
`inertia-react:inertia-rails-architecture` skill's "Three choices that are genuinely close"
section has the split.

## "Should I prefetch / poll / defer / use ActionCable?"

```
PREFETCH — preload page data before navigation:
├── Frequently visited page (dashboard, main nav)? → YES, prefetch on mount
├── Likely next click (nav links)? → YES, prefetch on hover (the default)
├── Data changes constantly per user? → NO — the cache will be stale immediately
├── Page requires POST data to load? → NO — prefetch is GET-only, and Inertia throws otherwise
└── Multiple pages share data? → YES, and give them one cache tag so a write can drop them together

POLL — auto-refresh data on an interval:
├── Dashboard counters, queue status, leaderboard? → YES, usePoll with only: [...]
├── Query is expensive (>1s)? → NO — use ActionCable push instead
├── Updates are rare (<1/hour)? → NO — manual refresh or ActionCable
├── Need real-time (<1s latency)? → NO — use ActionCable/WebSockets
└── Need user control? → pass { autoStart: false } as the third argument, then start/stop

DEFER — load expensive data after initial render:
├── Query >500ms? → YES, defer
├── Query <100ms? → NO — defer overhead not worth it
├── Data critical for initial render (form defaults, auth)? → NO — regular prop
└── 100-500ms? → Defer if page has fast props to show first

ACTIONCABLE — server pushes updates to client:
├── Core real-time feature (chat, live feed, collaboration)? → YES
├── Updates must arrive <1s after change? → YES
├── Multiple users see the same resource? → YES — broadcast on change
├── Only current user's data, low frequency? → usePoll is simpler
└── Pattern: ActionCable receives event → router.reload({ only: [...] })
```

This tree decides **whether** to prefetch. `inertia-react:inertia-rails-pages` owns the
API that carries it out — the `prefetch`, `cacheFor` and `cacheTags` attributes on
`<Link>`, and `router.prefetch`. `inertia-react:inertia-rails-performance` owns the
cross-page half: one tag spanning several pages, and the write that invalidates it.

`usePoll`'s third argument is the one to remember: `keepAlive`, `autoStart` and `mode` are
`PollOptions` and belong there, while `only` and `except` are reload options and belong in
the second. `usePoll(30000, { only: ['x'] }, { keepAlive: true })`.

## "I need to navigate"

```
Is this a link the user clicks?
├── YES, to a page in this app → <Link href={...}> (with prefetch for common destinations)
├── NO, programmatic after action → router.visit / router.get
├── External URL from server? → inertia_location (CRITICAL — not redirect_to)
├── External URL from client? → window.location.href
└── Need to update URL params? → router.visit with preserveState
```

## "I need to show a notification"

```
Is it a one-time message (success, error)?
├── YES → Rails flash + usePage().flash
│   └── Need custom keys beyond notice/alert? → config.flash_keys
├── Need it to persist across navigations? → inertia_share (shared prop)
└── Client-side only (no server round trip)? → router.flash('key', 'value')
```

`flash` is a top-level key on the page object, so it is `usePage().flash` — a sibling of
`props`, not a member of it. It is also not written into history state, so it does not
reappear on a back navigation.

## "I need to redirect after a mutation"

```
Is the destination inside the Inertia app?
├── YES → redirect_to path (standard Rails redirect)
│   └── With flash? → redirect_to path, notice: "Done!"
└── NO, external URL (Stripe, OAuth, etc.)
    └── inertia_location url (returns 409 + X-Inertia-Location header)
```

`inertia_location` is the one that works for an external destination: it sets
`X-Inertia-Location` and `head :conflict`, and the client turns that 409 into a real
browser navigation (inertia_rails 3.22.0, `lib/inertia_rails/controller.rb:171-174`). A plain
`redirect_to` to an external URL is followed by the XHR instead, and the adapter receives HTML
it cannot parse as a page.
