# Inertia Rails Configuration

Verified against `inertia_rails` 3.22.0 and `@inertiajs/core` 3.6.1.

## Table of Contents

- [Initializer](#initializer)
- [Initial page carrier](#initial-page-carrier)
- [Version Tracking](#version-tracking)
- [Flash Keys](#flash-keys)
- [History Encryption](#history-encryption)
- [Error Handling](#error-handling)
- [SSR Configuration](#ssr-configuration)
- [Middleware](#middleware)

---

## Initializer

These five lines are what `rails generate inertia:install` writes
(`generators/inertia/install/templates/initializer.rb`):

```ruby
# config/initializers/inertia_rails.rb
InertiaRails.configure do |config|
  # Asset version — triggers a full page reload when the frontend bundle changes
  config.version = ViteRuby.digest

  # Encrypt browser history state (default: false)
  config.encrypt_history = true

  # Always include an errors hash in the response (default: nil)
  config.always_include_errors_hash = true

  # Render initial page data in a <script type="application/json"> element (default: false)
  config.use_script_element_for_initial_page = true

  # Mark Inertia-managed <head> tags with data-inertia (default: false)
  config.use_data_inertia_head_attribute = true
end
```

The generator writes nothing else, so every option below is at its gem default in a freshly
installed app (`configuration.rb:8-82`). Each line shows the value to write when you want to
change one, with its default in the comment:

```ruby
# Flash keys exposed to the client (default: %i[notice alert]; nil disables Rails flash)
config.flash_keys = %i[notice alert toast]

# Combine same-key hashes across shared data instead of replacing them (default: false)
config.deep_merge_shared_data = true

# When to rewrite the XSRF-TOKEN cookie on protected requests (default: :always)
config.xsrf_cookie_refresh = :lazy
```

`default_render` also exists, at `false` (`configuration.rb:13`) and untouched by the
generator. Leave it there and write `render inertia: true` in the action, so the action says
what it renders without depending on an initializer being read first.

`component_path_resolver` and `root_dom_id` also exist, but their defaults —
`->(path:, action:) { "#{path}/#{action}" }` and `'app'` — are what an app wants unless it
puts page components somewhere other than a directory per controller.

## Initial page carrier

The initial page object is serialized into the HTML document either way, so every prop of
the first render is readable from view-source with JavaScript disabled.
`use_script_element_for_initial_page` chooses the carrier:

- `true`, which the install generator writes, puts the JSON in a
  `<script type="application/json">` element (`helper.rb:38-48`).
- The gem default `false` (`configuration.rb:59`) puts it in a `data-page` attribute on the
  root div (`helper.rb:50`).

The `true` setting is defence in depth for CSP; **it hides nothing.** The control that works
is the prop list — see the skill body's "Serializing Props".

## Version Tracking

Inertia uses version tracking to detect asset changes and trigger
full page reloads when the frontend bundle changes.

```ruby
# With ViteRuby (recommended) — a digest of the built manifest
config.version = ViteRuby.digest

# With Propshaft
config.version = Rails.application.config.assets.version

# Manual version string
config.version = '1.0.0'
```

A lambda is evaluated per request in controller context (`configuration.rb:180-185`), which
matters when the value can change while the process is running:

```ruby
config.version = -> { ViteRuby.digest }
```

`Rails.application.config` has no `version` or `asset_version` attribute, so reaching for
one raises `NoMethodError` on every Inertia render. The two real sources are `ViteRuby.digest`
and `Rails.application.config.assets.version`.

## Flash Keys

Controls which Rails flash keys are exposed to the Inertia client. This allowlist is
`inertia_rails`' own (`configuration.rb:69`) — Rails' flash has none. The generator does not
set it, so a fresh install is on `%i[notice alert]` and a `flash[:toast]` you set goes
nowhere until you widen it or use `flash.inertia`.

```ruby
# Default: only notice and alert
config.flash_keys = %i[notice alert]

# Add custom keys
config.flash_keys = %i[notice alert toast]

# nil disables Rails flash integration; only flash.inertia values reach the page
config.flash_keys = nil
```

Access on the client at `usePage().flash.notice`, `usePage().flash.alert`. Flash is a
top-level key on the page object (`renderer.rb:140-141`), not a member of `props`.

For a value one action sends once, `flash.inertia[:key] = value` bypasses the allowlist
(`controller.rb:176-185`) — see the skill body.

## History Encryption

Encrypts page data in browser history state. Without it, props are stored in plaintext in
`history.state` and readable via back/forward navigation or devtools.

**Set it in every environment.** The install generator already writes it unconditionally
(`install/templates/initializer.rb:5`), against a gem default of `false`
(`configuration.rb:26`):

```ruby
config.encrypt_history = true
```

**Clear history** on logout to lock the back button out of the previous session's pages:

```ruby
# Server-side — the client clears its encryption key on the next page
def destroy
  terminate_session
  redirect_to root_path, inertia: { clear_history: true }
end
```

```tsx
// Client-side — clear history programmatically (rotates the encryption key)
import { router } from '@inertiajs/react'
router.clearHistory()
```

**Encryption is the prerequisite for clearing, not an optimisation.** `clear_history` works
by deleting the encryption key and IV from `sessionStorage` (`@inertiajs/core` 3.6.1
`dist/index.js:1507-1510`), which makes encrypted entries undecryptable; an entry that was
stored in plaintext is untouched. Gate `encrypt_history` on `Rails.env.production?` and the
logout protection does nothing in development, which is exactly where you would try to
confirm it works.

**When to send `clear_history`:** logout, role change, account switching — any moment when
the previous session's data should not be reachable from the back button.

`terminate_session` above is the Rails 8.1 authentication generator's API. Check the
project's own session helpers before copying the name.

## Error Handling

```ruby
# Include an errors hash on every response, even when empty
config.always_include_errors_hash = true
```

**A generated app already has this on** — the install generator writes `true`
(`install/templates/initializer.rb:6`), even though the *gem* default is still `nil` at
3.22.0 (`configuration.rb:53`). So write the on-state's consequences, not the default's:
`errors` is a key on every response, empty when nothing is wrong, and
`inertia.props[:errors]` is always there to read. Pair it with `preserveErrors` on a
partial reload, because an always-present empty hash overwrites client-side errors — see
`inertia-rails-pages`, its `preserveErrors` note under "Navigation".

Only an app older than the generator sits on `nil`, and `nil` logs a 4.0 deprecation warning
on every render with no errors (`controller.rb:151-158`), so set it explicitly there.

Custom error page for Inertia and non-Inertia requests alike:
```ruby
# app/controllers/application_controller.rb
rescue_from ActiveRecord::RecordNotFound do |e|
  if request.inertia?
    render inertia: 'errors/not-found', props: { message: e.message }, status: 404
  else
    render file: Rails.public_path.join('404.html'), status: 404
  end
end
```

`status:` reaches the Inertia renderer: `_process_options` runs before the renderer block
(`actionpack-8.1.3.1` `renderers.rb:158,161`) and the renderer sends `status: @response.status`
(`renderer.rb:52`).

## SSR Configuration

`inertia-rails-ssr` owns this subject — bundle building, the Puma plugin, error handling,
and the newer `ssr_bundle`, `ssr_cache`, `ssr_runtime`, `ssr_raise_on_error` and
`on_ssr_error` options. The one line to know here is that `ssr_url` defaults to
`DEFAULT_SSR_URL = 'http://localhost:13714'` (`configuration.rb:5`), so setting it to that
value configures nothing:

```ruby
config.ssr_enabled = true
```

## Middleware

`InertiaRails::Middleware` is inserted by the engine and does four things that explain
behaviour you would otherwise try to configure.

**It rewrites 301 and 302 to 303** — but only when `X-Inertia` is present *and* the request
method is PUT, PATCH or DELETE (`middleware.rb:39,62-72`). 307 and 308 are left alone,
because they preserve the method by design. This is why an Inertia write redirect needs no
`status:` of its own, and why passing `status: :see_other` is redundant at 3.22.0 — and
worse below it, since 3.21.x and earlier discarded `inertia: { errors: }` when
`redirect_to` was given an explicit non-302 status (CHANGELOG 3.22.0).

**It answers a stale GET with 409 instead of the page.** When the client's
`X-Inertia-Version` does not match `config.version`, a GET gets a 409 carrying
`X-Inertia-Location: <the original URL>`, and the middleware calls `flash.keep` first so
the message survives the forced reload (`middleware.rb:110-113`). Non-GET requests are not
version-checked.

**It cleans up the Inertia session keys.** `inertia_errors`, `inertia_clear_history` and
`inertia_preserve_fragment` are deleted once a non-redirect response goes out, so a stashed
errors hash is consumed by exactly one render. Every redirect status keeps them, which is
what lets the errors survive a redirect chain.

**It copies `X-XSRF-TOKEN` into `X-CSRF-TOKEN`** (`middleware.rb:115-117`), which is the
other half of the `XSRF-TOKEN` cookie the controller sets in an `after_action`. Together
they mean CSRF needs no prop and no client-side wiring.
