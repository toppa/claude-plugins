# Accessibility Snippets — Rails 8.1 + Inertia/React + Tailwind 4

Drop-in remediations. Adapt names to the project; check the Gemfile and
`package.json` before recommending anything that needs a dependency the project
does not have.

## 1. Layout skeleton

One layout, one skip link, one live region per politeness level. In an Inertia
app this layout is rendered once and the React tree persists across visits, so
the regions below survive every navigation — which is exactly what a live region
needs.

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title data-inertia><%= content_for(:title) || "Your app" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>

    <%= stylesheet_link_tag :app %>
    <%= vite_client_tag %>
    <%= vite_react_refresh_tag %>
    <%= vite_typescript_tag "inertia.tsx" %>
    <%= inertia_ssr_head %>
  </head>

  <body class="min-h-dvh bg-white text-gray-900">
    <a href="#main"
       class="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2
              focus:z-50 focus:bg-white focus:px-3 focus:py-2 focus:rounded
              focus:ring-2 focus:ring-blue-600">
      Skip to main content
    </a>

    <%# The canonical polite region. Text changes; the element does not. %>
    <div id="flash-status" role="status" aria-live="polite" aria-atomic="true"></div>

    <%# Errors that must interrupt get their own element, never nested in the above. %>
    <div id="flash-alert" role="alert"></div>

    <header><%= render "shared/navbar" %></header>
    <main id="main"><%= yield %></main>
    <footer><%= render "shared/footer" %></footer>
  </body>
</html>
```

Key points:

- `lang` on `<html>` satisfies 3.1.1 Language of Page (Level A). **The Rails 8
  generated layout has no `lang` attribute**, so this is a real finding in a
  freshly generated app.
- The skip link is the first focusable element (2.4.1).
- `<header>`, `<main>`, `<footer>` already expose the `banner`, `main` and
  `contentinfo` roles. Adding `role="banner"` or `role="contentinfo"` to them
  changes nothing and contradicts "prefer native elements".
- `aria-atomic="true"` on the polite region re-announces its whole content on
  change, which is right for a region that holds one message at a time. Drop it
  if the region accumulates entries.
- `sr-only` and `not-sr-only` ship with Tailwind 4 — use them, do not redefine
  them.

## 2. Per-page title and heading

```tsx
// app/frontend/pages/settings/index.tsx
import { Head } from '@inertiajs/react'

export default function SettingsIndex() {
  return (
    <>
      <Head title="Settings" />
      <h1 className="text-2xl font-bold">Settings</h1>
      …
    </>
  )
}
```

`<Head title>` is what updates `<title data-inertia>` after the first load.
Without it, 2.4.2 Page Titled (Level A) is met once for the whole application.
The `<h1>` is separate: the title names the document, the heading names the page.

## 3. Route-change announcer

Inertia does no focus management, and no criterion requires a focus reset — so
announce instead of moving focus. Mount this once, inside the persistent layout.

```tsx
// app/frontend/components/RouteAnnouncer.tsx
import { router } from '@inertiajs/react'
import { useEffect } from 'react'

export function RouteAnnouncer() {
  useEffect(() =>
    // router.on returns its own unsubscribe function, so it is the cleanup.
    router.on('navigate', (event) => {
      const region = document.getElementById('flash-status')
      if (region) region.textContent = `${document.title} loaded`
      // event.detail.page.component is the page that was just rendered.
    }), [])

  return null
}
```

Write into the region that already exists rather than rendering a new one: a
region added to the DOM at the same moment as its text is unreliable, and a
region that is replaced on every navigation announces nothing at all.

Under Hotwire the equivalent hook is `turbo:load`. Under Inertia that event
never fires; the DOM event here is `inertia:navigate`.

## 4. Flash announcements

Nothing to write on the server: `inertia_rails` 3.22.0 collects the flash itself.
`flash_keys` defaults to `%i[notice alert]`, and `renderer.rb` puts the result on
the **page object** as `page.flash` — not in `props`, so do not reach for
`inertia_share` to expose it.

On the client, either read it from the page or listen for the event:

```tsx
// Reading the current page's flash. Its type comes from the app's own
// `flashDataType` augmentation of '@inertiajs/core' — the one in
// app/frontend/types/globals.d.ts. Without that augmentation `flash.notice` is
// `{}` and TypeScript rejects assigning it to textContent (checked on tsc 7.0.2).
const { flash } = usePage()

useEffect(() => {
  const status = document.getElementById('flash-status')
  if (status && flash.notice) status.textContent = flash.notice
  const alertRegion = document.getElementById('flash-alert')
  if (alertRegion && flash.alert) alertRegion.textContent = flash.alert
}, [flash])
```

```tsx
// Or event-driven, which also catches router.flash() calls made client-side
useEffect(() => router.on('flash', (event) => {
  const { notice, alert } = event.detail.flash
  …
}), [])
```

The ERB equivalent renders `flash[:notice]` inside `#flash-status` and
`flash[:alert]` inside `#flash-alert`. Either way the message text goes into an
existing region, and a `role="alert"` element is never nested inside a polite one.

## 5. Form with accessible errors

This is the one full copy; `SKILL.md` and `references/common-failures.md` point
here rather than repeating it.

```erb
<%= form_with model: @user, class: "space-y-4" do |f| %>
  <% if @user.errors.any? %>
    <div class="rounded-md bg-red-50 p-4 text-red-900" tabindex="-1"
         id="error-summary">
      <h2 class="font-semibold">
        <%= pluralize(@user.errors.count, "error") %> prevented this save
      </h2>
      <ul class="list-disc pl-5">
        <% @user.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :email_address, class: "block font-medium" %>
    <%= f.email_field :email_address,
          required: true,
          autocomplete: "username",
          "aria-invalid": @user.errors[:email_address].any?,
          "aria-describedby": ("email-error" if @user.errors[:email_address].any?),
          class: "mt-1 block w-full rounded border-gray-400
                  focus-visible:ring-2 focus-visible:ring-blue-600" %>
    <% if @user.errors[:email_address].any? %>
      <p id="email-error" class="mt-1 text-sm text-red-700">
        <%= @user.errors[:email_address].to_sentence %>
      </p>
    <% end %>
  </div>

  <%= f.submit "Save", class: "rounded bg-blue-600 px-4 py-2 text-white
                               focus-visible:ring-2 focus-visible:ring-offset-2
                               focus-visible:ring-blue-600" %>
<% end %>
```

Moving focus to `#error-summary` after a failed submit is the reason for its
`tabindex="-1"`. It is a response to the user's own submit, so it is a requested
context change; do it from the code that handles the response, not from a
controller that fires on every mount.

The Inertia form is the same shape with `useForm`:

```tsx
const { data, setData, errors, post, processing } = useForm({ email_address: '' })

<form onSubmit={(e) => { e.preventDefault(); post('/users') }}>
  <label htmlFor="email_address" className="block font-medium">Email address</label>
  <input id="email_address" type="email" required autoComplete="username"
         value={data.email_address}
         onChange={(e) => setData('email_address', e.target.value)}
         aria-invalid={!!errors.email_address}
         aria-describedby={errors.email_address ? 'email-error' : undefined} />
  {errors.email_address && (
    <p id="email-error" className="mt-1 text-sm text-red-700">{errors.email_address}</p>
  )}
  <button type="submit" disabled={processing}>Save</button>
</form>
```

`errors` is populated by the controller redirecting with
`inertia: { errors: @user.errors }` **to the page that renders this form** — a
redirect elsewhere delivers the errors to a component that ignores them.

## 6. Icon button

```tsx
export function IconButton({ label, children, ...props }: {
  label: string; children: React.ReactNode
} & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button type="button" aria-label={label}
            className="inline-flex items-center justify-center rounded
                       min-h-11 min-w-11 focus-visible:ring-2
                       focus-visible:ring-blue-600 focus-visible:ring-offset-2"
            {...props}>
      <span aria-hidden="true">{children}</span>
    </button>
  )
}
```

`min-h-11 min-w-11` is 44×44 px, which satisfies 2.5.5 Target Size (Enhanced),
Level AAA. **The Level AA floor is 24×24 (2.5.8)** — say which one you are
recommending when this reaches a report.

For the ERB half, the same markup works with an inline `<svg aria-hidden="true">`
or `image_tag "x.svg", alt: ""`. Where the project has `view_component`, wrap it
in a component; where it has `inline_svg`, the documented helper is
`inline_svg_tag`.

## 7. Utilities worth adding

Tailwind 4 already ships `sr-only` and `not-sr-only`, so the only addition worth
making is the reduced-motion guard. This is the single copy;
`references/common-failures.md` points here.

```css
/* app/frontend/entrypoints/application.css, after the Tailwind import */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

`0.01ms` rather than `none` so that `animationend` handlers still fire, which
keeps scripted transitions from hanging.

Where the project uses `@tailwindcss/forms`, check the focus styles it applies to
inputs against 1.4.11 (≥ 3:1) before recommending a change to them.

## 8. axe-core system specs

Requires `axe-core-rspec` in the Gemfile. Report it as an option if absent;
never add it.

```ruby
# spec/system/accessibility/settings_spec.rb
require "rails_helper"
require "axe-rspec"

RSpec.describe "Accessibility — settings", :js, :a11y, type: :system do
  it "has no axe violations" do
    visit settings_path
    expect(page).to be_axe_clean
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :wcag22aa)
  end
end
```

Capybara drives a real browser, so this audits the rendered DOM — it works
identically for an Inertia page and for an ERB view.

The `:a11y` tag is what `bundle exec rspec spec/system --tag a11y` selects, and
`:js` is what gets a real browser. A spec missing either is a spec the documented
command does not run.

```ruby
# spec/support/shared_examples/accessible_page.rb
RSpec.shared_examples "an accessible page" do |path|
  it "has no axe violations up to WCAG 2.2 AA" do
    visit path
    expect(page).to be_axe_clean
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :wcag22aa)
  end
end
```

**Pass the whole tag list, every time.** Exactly one axe-core rule carries the
`wcag22aa` tag — `target-size` — so `according_to(:wcag22aa)` on its own checks
target size and nothing else while reporting itself as a WCAG 2.2 AA pass. The
earlier tags are what cover contrast, names, roles and labels.

`.skipping("color-contrast")` is available while design tokens are being fixed.
Say so in the report when a suite uses it, because a green suite that skips
contrast hides the most common failure there is.

## 9. Process recommendations for the report

These change shared project infrastructure, so they belong in the report as
recommendations with their cost stated — not in a diff produced by an audit.

- **Scaffold templates.** Overriding `lib/templates/erb/scaffold/` makes new ERB
  forms ship with labels, `autocomplete` and error wiring by default. In an
  Inertia app the equivalent is the page templates the `inertia_rails` generator
  uses, so name whichever the project actually generates from.
- **A pre-merge check.** `bundle exec rspec spec/system --tag a11y` in CI is the
  cheapest durable guard, because it uses the specs the project already runs.
  `pa11y-ci` or Lighthouse CI need a booted server and Node, so price that in.
- **Start non-blocking.** Whichever check is added, run it advisory until the
  baseline is green; a red-on-arrival gate gets disabled.

## 10. Language switcher

```erb
<nav aria-label="Language">
  <ul class="flex gap-2">
    <% I18n.available_locales.each do |locale| %>
      <li>
        <%= link_to t("languages.#{locale}"),
              url_for(locale: locale),
              lang: locale.to_s,
              "aria-current": ("true" if I18n.locale == locale) %>
      </li>
    <% end %>
  </ul>
</nav>
```

`lang` on each link marks the language of that link's text (3.1.2);
`aria-current` announces which choice is active (4.1.2).
