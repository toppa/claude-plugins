# Common WCAG 2.2 Failures — Expanded Catalog

Beyond the failures in `SKILL.md`. Each entry gives its WCAG success criterion, then the
form to ship. Where the failure is hard to see in source, a **Look for** line between them
says what to search for. Every criterion here is quoted at its real level in
`references/wcag-2.2-criteria.md`; check the mapping before it reaches a report.

## Images and media

### Image with no `alt` attribute
- **SC**: 1.1.1 (A)
- **Look for**: `image_tag` in ERB or `<img` in `.tsx` with no `alt:` / `alt=`.
  Action View emits **no `alt` at all** when you omit it (verified on 8.1.3), so
  there is no placeholder text to search for — the attribute is simply absent.
- **Ship**: `alt:` describing the information for informative images, `alt: ""`
  for decorative ones.

### Logo linking home has no name
- **SC**: 2.4.4 (A), 4.1.2 (A)
- **Look for**: an `<a href="/">` whose only child is an image with `alt=""`.
- **Ship**: `alt: "Acme — home"` on the image, or an `aria-label` on the link.

### Video without captions
- **SC**: 1.2.2 (A)
- **Ship**: `<track kind="captions" srclang="en" src="…">` on every `<video>`.
  Live captions are 1.2.4 (AA) and apply to live media streams.

## Structure

### Styled `<div>` used as a heading
- **SC**: 1.3.1 (A)
- **Ship**: `<h1>`–`<h6>`, styled with Tailwind utilities. Tag choice carries the
  structure; classes carry the appearance.

### Skipped heading levels
- **SC**: 1.3.1 (A)
- **Look for**: `<h1>` followed by `<h4>`.
- **Ship**: contiguous levels within a landmark.

### No `<h1>`, or a heading that does not describe its section
- **SC**: 2.4.6 (AA) covers headings and labels being **descriptive**; 1.3.1 (A)
  covers the markup being real headings.
- **No criterion requires exactly one `<h1>` per page** — one is a strong
  convention and worth recommending, but report it as a convention, not as a
  2.4.6 failure. The reportable failures are a page with no heading structure at
  all, and headings like "Section 1".
- **Ship**: a visible `<h1>` naming the page. In Inertia that is the page
  component's own markup; the document title is separate and belongs to
  `<Head title>` (2.4.2).

### Layout tables
- **SC**: 1.3.1 (A)
- **Ship**: CSS grid or flex. Reserve `<table>` for tabular data.

### Data table without headers
- **SC**: 1.3.1 (A)
- **Ship**: `<th scope="col">` / `<th scope="row">`; `id`/`headers` for complex
  tables.

## Forms

### Placeholder used as a label
- **SC**: 3.3.2 (A), 1.3.1 (A), 4.1.2 (A)
- **Why**: the placeholder disappears on the first keystroke, its contrast is
  usually below 4.5:1, and some AT ignores it.
- **Ship**: a visible `<label>` associated with the input. Rails' `f.label` +
  `f.email_field` wire `for`/`id` automatically; in React write
  `<label htmlFor="…">` and a matching `id`.
- **Where it lives today**: the Rails 8 authentication views
  (`sessions/new.html.erb`, `passwords/new.html.erb`, `passwords/edit.html.erb`)
  ship placeholders and no labels.

### Label not associated with its input
- **SC**: 1.3.1 (A), 4.1.2 (A)
- **Look for**: a `<label>` with no `for`, or a React `<label>` with no `htmlFor`.
- **Ship**: the `for`/`id` pair, or wrap the input in the label.

### Grouped radios / checkboxes without `<fieldset>`
- **SC**: 1.3.1 (A)
- **Ship**:
  ```erb
  <fieldset>
    <legend>Notification frequency</legend>
    <%= f.collection_radio_buttons :frequency, Frequencies.all, :id, :name %>
  </fieldset>
  ```

### Required field not announced
- **SC**: 3.3.2 (A), 4.1.2 (A)
- **Ship**: the HTML `required` attribute — readers announce it — plus a visible
  indication.

### Autocomplete missing
- **SC**: 1.3.5 (AA)
- **Ship**: `autocomplete: "email"`, `"username"`, `"current-password"`,
  `"street-address"`, and the rest of the HTML token list.

### Errors unreachable from the field
- **SC**: 3.3.1 (A), 3.3.3 (AA)
- **Ship**: `aria-invalid` on the field, `aria-describedby` pointing at the
  message element, and the message in text. The full form for ERB and for
  Inertia's `useForm().errors` is in `references/rails-snippets.md`, section
  "Form with accessible errors" — one copy, so the two never drift.

## Interaction

### `<div>` with a click handler
- **SC**: 2.1.1 (A), 4.1.2 (A)
- **Ship**: `<button type="button">`. It is focusable, activates on Enter and
  Space, and announces its role with no extra attributes.

### Submit rendered as a link
- **SC**: 4.1.2 (A)
- **Ship**: `button_to` (or a real `<button>`) for actions; `link_to` for
  navigation.

### Focus indicator removed
- **SC**: 2.4.7 (AA), 1.4.11 (AA)
- **Look for**: `outline: none` or `focus:outline-none` with no replacement.
- **Ship**: `focus-visible:ring-2 focus-visible:ring-blue-600
  focus-visible:ring-offset-2`, at ≥ 3:1 against both backgrounds.

### Tab order does not match reading order
- **SC**: 2.4.3 (A)
- **Look for**: positive `tabindex` values, or DOM order that disagrees with the
  visual order (CSS `order`, absolute positioning).
- **Ship**: DOM order that matches the visual order, with `tabindex="0"` and
  `tabindex="-1"` as the only values used.

### Keyboard trap in a custom widget
- **SC**: 2.1.2 (A)
- **What 2.1.2 says**: if focus can move *into* a component, it must be able to
  move *out* using the keyboard. It is violated by a trap you cannot escape —
  **a missing focus trap in a modal does not violate 2.1.2.**
- **Ship**: Escape closes, Tab cycles inside a modal and returns focus to the
  opener on close. A modal that lets Tab wander into the page behind it is a
  2.4.3 Focus Order finding and a usability problem; a modal you cannot Tab out
  of is the 2.1.2 failure.

## Color and contrast

### Gray text on white
- **SC**: 1.4.3 (AA)
- **Ship**: `text-gray-600` (7.56:1) for body text; `text-gray-500` is 4.84:1
  and clears the 4.5:1 floor with almost no headroom; `text-gray-400` is 2.60:1
  and fails. Ratios computed over Tailwind 4.3.3 — see `SKILL.md`, section
  "1.4.3 Contrast (Minimum)", for the formula to recompute after a palette
  override.

### Link distinguished only by color
- **SC**: 1.4.1 (A)
- **Ship**: an underline in prose, or a second visual cue.

### Placeholder text too light
- **SC**: 1.4.3 (AA)
- **Ship**: ≥ 4.5:1 whenever the placeholder carries information (and a real
  label regardless).

### Focus ring too faint
- **SC**: 1.4.11 (AA), 2.4.7 (AA)
- **Ship**: a ring at ≥ 3:1 against both the control and the page background.

## Client-side navigation (Inertia)

### Title never changes between pages
- **SC**: 2.4.2 (A)
- **Look for**: `.tsx` pages with no `<Head title>`. The layout's
  `<title data-inertia>` is set once on first load.
- **Ship**: `<Head title="…" />` in each page component.

### Route change is silent
- **SC**: 4.1.3 (AA) when a live region exists but never fires; otherwise a
  usability finding. **No WCAG 2.2 criterion requires moving focus after a
  client-side navigation**, so do not file it as 2.4.3.
- **Ship**: write the new page name into the polite live region from
  `router.on('navigate', …)` or a `useEffect` on `usePage().component`.
  `references/rails-snippets.md` has the announcer, in section "Route-change announcer".

### Flash arrives with no live region to announce it
- **SC**: 4.1.3 (AA)
- **Look for**: a page rendering `usePage().flash` (or `flash[:notice]` in ERB)
  into a plain element. `inertia_rails` collects `notice` and `alert` onto the
  page object by default, so the data is usually already there.
- **Ship**: one polite region in the persistent layout that the message text is
  written into, plus a separate assertive region for errors.

### Validation errors arrive on a page that does not render them
- **SC**: 3.3.1 (A)
- **Look for**: a controller redirecting with `inertia: { errors: … }` to a page
  whose component ignores `errors` — the props arrive and nothing displays them.
- **Ship**: redirect to the form's own page, and render `errors` there.

## Hotwire (only when `turbo-rails` is in the Gemfile)

Turbo's events do not exist under Inertia's router, which emits `navigate` /
`inertia:navigate` instead — check the Gemfile before filing any of these.

### Turbo Frame swap loses the user's place
- **SC**: 2.4.3 (A)
- **Ship**: leave focus where the user put it. A frame usually updates a small
  region, so capture `document.activeElement` before the swap and restore it, or
  move focus to a sensible element **inside** the new frame. Moving focus to
  `<main>` on a frame load throws the user out of the region they were working
  in, and a frame that loads for a non-user reason makes that an unrequested
  context change (3.2.1, 3.2.2, both Level A).

### Turbo Stream update interrupts or goes unheard
- **SC**: 4.1.3 (AA)
- **Ship**: the stream target lives inside a polite live region, so insertions
  are announced without stealing focus.

### Modal Turbo Frame with no dialog semantics
- **SC**: 4.1.2 (A), 2.4.3 (A)
- **Ship**: native `<dialog>` + `showModal()` — focus moves in, Escape closes,
  focus returns to the opener.

### Stimulus toggle without `aria-expanded`
- **SC**: 4.1.2 (A)
- **Ship**: update `aria-expanded` in the same action that changes the visual
  state.

## Components (React components, ERB partials, ViewComponents)

### Icon-only control has no name
- **SC**: 4.1.2 (A)
- **Ship**: `aria-label` on the control, or visually-hidden text inside it, with
  the icon marked `aria-hidden="true"`.

### Content that should be announced is hidden from AT
- **SC**: 4.1.3 (AA) when it is a status message; 1.3.1 (A) when it is content.
- **How the mechanisms differ**: the `hidden` attribute and `display: none`
  remove content from assistive technology as well as from the screen — that is
  what they are for. `visibility: hidden` also removes it. To keep something
  announced while invisible, use `sr-only`. To keep something rendered and
  measurable but unannounced, `aria-hidden="true"`.
- **Ship**: `sr-only` for text meant only for readers; `hidden` for content
  meant for nobody yet.

### Component with no accessibility assertion
- **SC**: process gap, not a criterion
- **Ship**: a Capybara system spec with `be_axe_clean` covering the component's
  page. See `references/rails-snippets.md`, section "axe-core system specs".

## Motion and preferences

### Animation ignores `prefers-reduced-motion`
- **SC**: 2.3.3 (AAA); when the motion is decorative and continuous, 2.2.2 (A)
  applies instead.
- **Ship**: the reduced-motion block in `references/rails-snippets.md`, section
  "Utilities worth adding" — one implementation, so the two files cannot drift.

### Autoplaying carousel with no pause
- **SC**: 2.2.2 (A)
- **Ship**: a visible pause control, and no autoplay when the user has
  `prefers-reduced-motion: reduce`.

## Authentication (new in 2.2)

### CAPTCHA that requires solving a puzzle
- **SC**: 3.3.8 (AA)
- **Ship**: a non-cognitive alternative — email link, passkey, device trust.

### Code must be transcribed from another app, with paste blocked
- **SC**: 3.3.8 (AA)
- **Ship**: allow paste, or use WebAuthn / passkeys.
