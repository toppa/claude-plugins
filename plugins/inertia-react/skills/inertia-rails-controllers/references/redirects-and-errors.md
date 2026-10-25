# Redirects and Validation Errors — Mechanism

Why the rules in the skill body's "Redirects & Validation Errors" section hold. Verified
against `inertia_rails` 3.22.0 and Rails 8.1.3.1.

## Why no `status:` on a write redirect

`middleware.rb:39,62-72` rewrites 301 and 302 to 303, but only when `X-Inertia` is present
*and* the request method is PUT, PATCH or DELETE. So the status the Inertia protocol wants
arrives without you naming it.

Writing `status: :see_other` yourself is redundant at 3.22.0, and *discarded*
`inertia: { errors: }` at 3.21.x and earlier (CHANGELOG 3.22.0) — a validation failure then
redirected with no errors attached, which reads at the call site as though the front end
dropped them.

307 and 308 are left alone, because they preserve the method by design. The full middleware
behaviour is in [Middleware](configuration.md#middleware).

## Why the redirect target is fixed rather than `redirect_back_or_to`

`redirect_back_or_to` reads `request.referer`. A form in a modal over an index, or a submit
after a client-side navigation, therefore lands on a page whose component never renders the
`errors` prop: the errors arrive and nothing displays them. A fixed target —
`new_user_path` after a failed create, `edit_user_path(@user)` after a failed update — is
also the one a request spec can assert on.

## Why the bare `@user.errors` object

It responds to `to_hash` (`activemodel/errors.rb:253`), so the gem stores it with no
deprecation warning and the front end receives `{ name: ["can't be blank"] }`, keyed by
attribute name.

Short messages also match what live validation produces: the Precognition path calls
`errors.errors.to_hash` with no argument and no override point (`precognition.rb:34`), so
`to_hash(true)` in the submit path would render two different strings for the same failure.
`full_messages` drops the keys altogether, and the keys are what maps a message to its
input.

## What the gem does with `inertia: { errors: }`

You write the option; the gem runs the rest:

1. `controller.rb:187-199` stashes the hash in the session.
2. The middleware preserves it across the redirect chain, and deletes it once a
   non-redirect response goes out, so one render consumes it.
3. `controller.rb:144-160` lifts it into an `errors` prop on that next render.
4. `renderer.rb:163-168` wraps that prop in `always`, so a partial reload cannot drop it.

Step 4 is why a hand-fired `router.reload` needs `preserveErrors` to keep errors on screen —
see `inertia-rails-pages`, its `preserveErrors` note under "Navigation".
