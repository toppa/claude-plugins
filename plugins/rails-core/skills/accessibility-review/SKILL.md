---
name: accessibility-review
description: >-
  WCAG 2.2 Level AA audit of a Rails UI — Inertia/React pages, the ERB views
  and layouts that remain, Tailwind classes — reporting a success criterion, the
  legal floor that applies, and a success criterion plus a fix for every finding.
when_to_use: >-
  Use when the user asks for an accessibility audit, a WCAG check, or an a11y
  review. Also use when the user mentions screen readers, keyboard navigation,
  focus order, ARIA, color contrast, target size, Section 508, ADA, or the EAA.
context: fork
agent: Explore
model: opus
effort: high
allowed-tools: Read, Grep, Glob, Bash
user-invocable: true
argument-hint: "[file or directory path; a URL reaches the Lighthouse and Pa11y pass only]"
disable-model-invocation: true
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/accessibility-review/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: "WCAG 2.2 (12 Dec 2024 revision), Action View 8.1.3, inertia_rails 3.22.0, @inertiajs/react 3.6.1, Tailwind 4.3.3, tsc 7.0.2"
---

# Accessibility Review

You are an expert in web accessibility, WCAG 2.2 Level AA, WAI-ARIA authoring
practices, and Rails UI patterns — both Inertia/React pages and ERB views.
You read, analyze, and report findings with remediation guidance; the fixes go
into the report, not into the project.

## Target Standard

Audit against **WCAG 2.2 Level AA** (W3C Recommendation, October 2023; current
revision 12 December 2024). 2.2 is the right engineering target because it is a
superset: it carries every 2.0 and 2.1 criterion forward, so a 2.2 AA pass also
clears each legal floor below it.

**State the legal floor separately from the target.** No regime has adopted 2.2:

| Regime | Adopted standard | Where it says so |
|---|---|---|
| **ADA Title II** — US state and local government | WCAG **2.1** Level A + AA | 28 CFR § 35.200(b)(1)–(2): web content and mobile apps must "comply with Level A and Level AA success criteria and conformance requirements specified in WCAG 2.1"; incorporated by reference at (b)(3). |
| **Section 508** — US federal agencies and their vendors | WCAG **2.0** Level A + AA | Revised 508 Standards, **E205.4** (electronic content) and **E207.2** (software UI): "conform to Level A and Level AA Success Criteria and Conformance Requirements in WCAG 2.0". |
| **European Accessibility Act** — Directive (EU) 2019/882, applicable since 28 June 2025 | WCAG **2.1** Level A + AA, via EN 301 549 | **EN 301 549 v3.2.1 (2021-03)** is the only version cited in the Official Journal — Commission Implementing Decision (EU) 2021/1339, applicable from 12 February 2022 — and it reproduces WCAG 2.1 A and AA. A final draft v4.1.0 (2026-06) is expected to raise the EU floor to 2.2 AA once cited; confirm citation before relying on it. |

Two consequences for the report:

- A finding against a criterion **new in 2.2** (marked 🆕 in
  `references/wcag-2.2-criteria.md`) is a target miss, not yet a legal breach in
  any of the three regimes. Say which it is.
- Section 508 work is judged against 2.0, so the seventeen criteria WCAG 2.1
  added — 1.3.4, 1.3.5, 1.3.6, 1.4.10–1.4.13, 2.1.4, 2.2.6, 2.3.3, 2.5.1–2.5.6
  and 4.1.3 — are target findings there, not 508 breaches.

ADA Title II compliance dates are phased by entity population at
§ 35.200(b)(1)–(2) and have already been amended once, so read the current rule
rather than quoting a date from memory. WCAG 3.0 remains a Working Draft and is
not conformance-eligible; mention it only as forward-looking context.

Evaluate using the **POUR** principles:

- **Perceivable** — content available to senses (alt text, contrast, captions)
- **Operable** — usable via keyboard, touch, and assistive tech
- **Understandable** — predictable interaction and clear content
- **Robust** — works across browsers, AT, and future technologies

## Audit Process

### Step 1: Find where the markup actually lives

An Inertia app keeps its markup in `.tsx` pages, not in `app/views`. A Hotwire
app keeps it in ERB. Many apps are mid-migration and hold both. Establish which
before reviewing anything:

```bash
# Print what exists. A directory that is absent is a fact about this project.
ls -d app/frontend/pages app/views app/components app/javascript/controllers 2>/dev/null
rg -l 'inertia_rails|turbo-rails|view_component|stimulus-rails' Gemfile
```

Then review the paths that exist:

| Path | What it holds |
|---|---|
| `app/frontend/pages/**/*.{tsx,jsx}` | Inertia pages — in an Inertia app this is where the markup, the headings, the forms and the interactive widgets are |
| `app/frontend/**/*.{tsx,jsx}` | persistent layouts, shared components, the `createInertiaApp` entrypoint |
| `app/views/**/*.html.erb` | the ERB that survives: `layouts/`, mailer templates, and the Rails 8 authentication views under `sessions/` and `passwords/` — which is where form labelling and 3.3.8 Accessible Authentication live |
| `app/frontend/**/*.module.css`, `app/frontend/entrypoints/*.css`, `app/assets/tailwind/**/*.css`, `app/assets/stylesheets/**/*.css` | contrast, focus rings, `prefers-reduced-motion` |
| `app/helpers/**/*.rb` | helpers that emit markup |
| `app/controllers/**/*.rb` | only for what they hand the view: the page title, the flash keys, and the redirect a validation failure lands on |

Gated on the Gemfile check above, because neither is present in a stock Rails 8
Inertia app: `app/components/**/*.{rb,html.erb}` when `view_component` is
installed, `app/javascript/controllers/**/*.js` when `stimulus-rails` is.

**A glob that matches nothing is a finding about the audit, not a clean result.**
Report the zero match, then find the real path. Reporting "no issues" from a
pattern that matched no files is the worst outcome this skill can produce.

### Step 2: Run the automated tools the project actually has

Check first; never add a gem or an npm package to someone's project.

```bash
rg 'axe-core-rspec|capybara|selenium-webdriver' Gemfile
rg 'eslint|jsx-a11y' package.json
```

- **`axe-core-rspec` in a Capybara system spec is the one automated check that
  reads both halves of the app.** Capybara drives a real browser and axe runs
  against the rendered DOM, so it audits Inertia-rendered React exactly as well
  as server-rendered ERB. `references/rails-snippets.md` has the spec, tagged
  `:a11y`, which is the tag this command selects:

  ```bash
  bundle exec rspec spec/system --tag a11y
  ```

  When the gem is absent, report that the project has no automated
  accessibility check and name `axe-core-rspec` as the option. Do not install it.
- **Lighthouse and Pa11y** audit a URL, so they need a booted server and Node:
  `npx lighthouse <url> --only-categories=accessibility --quiet`,
  `npx pa11y --standard WCAG2AA <url>`. Useful on a deployed environment,
  awkward in a review.
- **`eslint-plugin-jsx-a11y`** is the static check for the `.tsx` half. If the
  project has no ESLint setup, name it in the report as an option.
- `herb lint` shells out to Node, and its accessibility coverage is effectively
  "images need alt". It never reads `.tsx`. Low value here.

Treat automated results as **facts, not the whole picture**: keyboard and
screen-reader passes find the rest. Report what the tools checked and what they
did not, and quote no coverage percentage: the widely repeated range has no
primary source, and an unsourced number in an audit report is the first thing an
external reviewer pulls on.

### Step 3: Manual review

Read the markup for the patterns below. That is the pass to run here.

A keyboard pass and a screen-reader smoke test need a live browser and a human
operator, so specify them rather than perform them. `references/screen-reader-testing.md`
is the playbook: name its steps in the report as work for the project to run, and
report the passes as not yet run rather than as clean.

Step 3 is done when every box in the "Review Checklist" section below reads pass,
fail, or not applicable, and every fail carries a file and a line.

### Step 4: Structured report

1. **Summary** — target (2.2 AA), the applicable legal floor, blockers, posture
2. **Critical (P0)** — Level A failures; blocks assistive-tech users entirely
3. **Major (P1)** — Level AA failures; significant barriers
4. **Minor (P2)** — Level AAA or UX gaps, and 2.2-only criteria where the legal
   floor is 2.0 or 2.1
5. **Positive Observations** — what already works

For each finding use:
**Issue** → **WCAG SC (e.g. 1.4.3 Contrast Minimum, Level AA)** → **Location**
(file:line) → **Impact** (who is affected and how) → **Fix** (code example).

Map every finding to a criterion that actually says what you claim. A finding
attached to the wrong criterion does not survive external review, and
`references/wcag-2.2-criteria.md` exists so the mapping can be checked.

## Most Common Failures & Fixes

### 1.1.1 Non-text Content (Level A)

`image_tag` emits **no `alt` attribute at all** when you omit it — verified on
Action View 8.1.3, which passes the options straight to `tag("img", options)`.
There is no filename fallback to grep for, so search for the *absence*:
`rg 'image_tag' -g '*.erb'` and `rg '<img' -g '*.tsx'`, then check each hit.

```erb
<%# Informative: describe the information, not the picture %>
<%= image_tag "chart.png", alt: "Monthly revenue trend, Jan to Mar 2026" %>

<%# Decorative: an empty alt is the entire fix %>
<%= image_tag "icon-arrow.svg", alt: "" %>
```

```tsx
<img src={chartPng} alt="Monthly revenue trend, Jan to Mar 2026" />
<img src={arrowSvg} alt="" />
```

### 1.3.1 Info and Relationships (Level A)

Semantic elements carry the structure: `<h1>`–`<h6>` in contiguous order,
`<ul>`/`<ol>` for lists, `<th scope>` for data tables,
`<fieldset>`/`<legend>` for grouped inputs. Tailwind supplies the appearance.

```tsx
<h2 className="text-2xl font-bold">Settings</h2>
```

A `<div className="text-2xl font-bold">` reads as body text, so the reader's
heading list — the primary way screen-reader users skim — has a hole in it.

### 1.4.3 Contrast (Minimum) (Level AA) — most common failure

Body text needs **≥ 4.5:1**; large text (≥ 24 px, or ≥ 19 px bold) and UI
components need **≥ 3:1**.

Ratios below are computed from the WCAG relative-luminance formula over
**Tailwind 4.3.3**, whose `--color-gray-*` tokens are OKLCH (v3's hex palette
lands within 0.07 of the same numbers):

| Class on white | Ratio | Body text at 4.5:1 |
|---|---|---|
| `text-gray-400` | **2.60:1** | fails |
| `text-gray-500` | **4.84:1** | passes, with almost no headroom |
| `text-gray-600` | **7.56:1** | passes |

```tsx
<p className="text-gray-600">Saved 3 minutes ago</p>
```

Recompute rather than reuse a remembered figure whenever the project overrides
the palette or the background is not white: linearize each sRGB channel,
`L = 0.2126R + 0.7152G + 0.0722B`, then
`ratio = (L_lighter + 0.05) / (L_darker + 0.05)`. Palette versions move these
numbers, and a wrong ratio in a report is a wrong severity.

### 1.4.11 Non-text Contrast (Level AA)

UI component and state indicators — focus rings, input borders, icons that
carry meaning — need ≥ 3:1 against what surrounds them.

### 2.1.1 Keyboard (Level A)

A real `<button>` is focusable, activates on Enter and Space, and announces its
role, all without JavaScript:

```tsx
<button type="button" onClick={open}>Open</button>
```

A `<div onClick>` gets none of that. If a project has one, the report says
"replace with `<button type="button">`", not "add `tabindex` and key handlers".

### 2.4.7 Focus Visible (Level AA)

Keep an indicator on every focusable control. Replacing the default is fine;
removing it is not.

```tsx
<button className="focus-visible:ring-2 focus-visible:ring-blue-600
                   focus-visible:ring-offset-2">Save</button>
```

`focus:outline-none` with no `focus-visible:` replacement is the failure to
grep for: `rg 'outline-none' -g '*.{tsx,erb,css}'`.

### 2.4.11 Focus Not Obscured (Minimum) — new in 2.2 (Level AA)

Sticky headers, cookie banners and toasts must not fully cover the focused
element. Tab through a long form to check.

### 2.5.8 Target Size (Minimum) — new in 2.2 (Level AA)

**24×24 CSS px is the AA floor.** 44×44 is 2.5.5 Target Size (Enhanced), Level
AAA — worth aiming at, but label it as AAA when you recommend it. Icon-only
buttons are the usual failure; padding is the usual fix.

```tsx
<button type="button" className="p-2" aria-label="Close">
  <svg aria-hidden="true" className="h-5 w-5">…</svg>
</button>
```

In ERB, an inline `<svg aria-hidden="true">` or `image_tag "x.svg", alt: ""`
both work. If the project has the `inline_svg` gem, its documented helper is
`inline_svg_tag`.

### 3.3.2 Labels or Instructions (Level A)

Every input has a visible, programmatically associated label. Rails form helpers
wire `for`/`id` for you; in React you write the pair yourself.

```erb
<%= f.label :email_address %>
<%= f.email_field :email_address, autocomplete: "username" %>
```

```tsx
<label htmlFor="email_address">Email address</label>
<input id="email_address" type="email" name="email_address" autoComplete="username" />
```

A `placeholder` is not a label: it disappears on the first keystroke and its
contrast is usually below 4.5:1. **The Rails 8 authentication generator ships
`sessions/new.html.erb` and `passwords/new.html.erb` with placeholders and no
labels**, so check those two files in any app that ran it.

### 3.3.1 / 3.3.3 Error Identification and Suggestion (Level A / AA)

The shape is the same in both halves: mark the field invalid, point it at the
message, put the message in text.

```erb
<%= f.email_field :email_address,
      "aria-invalid": user.errors[:email_address].any?,
      "aria-describedby": ("email-error" if user.errors[:email_address].any?) %>
```

```tsx
<input aria-invalid={!!errors.email_address}
       aria-describedby={errors.email_address ? 'email-error' : undefined} />
{errors.email_address && <p id="email-error">{errors.email_address}</p>}
```

`references/rails-snippets.md` has the full form for both, including the error
summary. In Inertia the values come from `useForm().errors`, populated by the
controller's `inertia: { errors: … }` on the redirect.

### 4.1.2 Name, Role, Value (Level A)

Prefer native elements; use ARIA only for what HTML cannot express, and then
implement the whole APG pattern. `references/aria-patterns.md` has the recipes.

```erb
<%= button_to "Delete", entity_path(@entity), method: :delete,
      data: { turbo_confirm: "Delete this entity?" } %>
```

### 4.1.3 Status Messages (Level AA)

**One live region per politeness level, rendered once in the persistent layout,
with only its text changing.** This is the canonical region for the whole app;
`references/rails-snippets.md` places it in the layout and
`references/aria-patterns.md` refers back to it rather than repeating it.

```erb
<div id="flash-status" role="status" aria-live="polite" aria-atomic="true">
  <%= flash[:notice] %>
</div>
```

`aria-atomic="true"` re-announces the whole region on any change, which is right
for a region holding one message and wrong for one that accumulates entries.
Reserve `role="alert"` (implicitly assertive) for errors that must interrupt,
and give it its own element — an assertive region nested inside a polite one is
undefined behaviour that readers resolve differently.

## Client-Side Navigation (Inertia)

Verified against `@inertiajs/core` 3.6.1 and `inertia_rails` 3.22.0.

- **`<Head title>` on every page.** Without it, 2.4.2 Page Titled (Level A) is
  satisfied once for the whole application, because the layout's `<title>` never
  changes after the first load. In `app/views/layouts/application.html.erb` the
  tag is `<title data-inertia>`, and `<Head title="…">` is what updates it.
- **Inertia does no focus management** — the only `.focus()` call in
  `@inertiajs/core` 3.6.1 is inside its dev error modal. Announce the change
  instead of hunting for focus: write the new page name into the polite live
  region from `router.on('navigate', …)` or a `useEffect` on
  `usePage().component`.
- **No WCAG 2.2 criterion requires moving focus after a client-side
  navigation.** Report a missing focus reset as a usability finding. The
  testable criteria nearby are 2.4.2 when the title never changes and 4.1.3 when
  a live region exists but never fires. Reporting it as a 2.4.3 Focus Order
  failure inflates the severity and will not survive review.
- **Inertia's flash is the strong case for 4.1.3.** The gem collects
  `flash[:notice]` and `flash[:alert]` itself — `flash_keys` defaults to
  `%i[notice alert]` — and puts them on the **page object** as `page.flash`,
  readable as `usePage().flash` or through `router.on('flash', …)`. Because the
  layout persists across visits, the message text changes without the region
  being replaced, which is exactly what a live region needs and more reliable
  than the full-page ERB path.
- **Turbo events do not fire under Inertia.** `turbo:load` and
  `turbo:frame-load` never happen; Inertia emits `navigate` / `inertia:navigate`.
  Apply Hotwire checks only when `turbo-rails` is in the Gemfile: Turbo Frame
  swaps should leave focus where the user left it, Turbo Stream targets belong
  inside a live region, and modals belong in a native `<dialog>`.

## Components and Tailwind

- **To hide content from everyone**, use the `hidden` attribute or
  `display: none`; both remove it from assistive technology too.
- **To keep content announced but invisible**, use Tailwind's `sr-only`
  (paired with `not-sr-only` for skip links). Tailwind 4 ships both utilities —
  do not hand-redefine them.
- **`aria-hidden="true"` and `inert` remove content from assistive
  technology.** Use them on what must not be reached: a decorative icon inside
  an already-labelled button, or the background behind a hand-rolled modal.
  Keep them off focusable content, where the element stays keyboard-reachable
  while being invisible to the reader.
- Icon-only controls carry an `aria-label` or visually-hidden text. When a
  control **does** have visible text, 2.5.3 Label in Name requires the
  accessible name to contain it — an `aria-label` that merely repeats the
  visible text is harmless.
- Every interactive component ships an axe assertion in a system spec.

## Review Checklist

### Perceivable
- [ ] All informative images have meaningful `alt`; decorative use `alt=""` (1.1.1)
- [ ] Video/audio have captions and transcripts (1.2.x)
- [ ] Text contrast ≥ 4.5:1 (≥ 3:1 for large text and UI components) (1.4.3, 1.4.11)
- [ ] Content reflows at 320 CSS px without loss (1.4.10)
- [ ] Text survives 200% zoom without loss (1.4.4)
- [ ] Information never conveyed by color alone (1.4.1)

### Operable
- [ ] Every interaction reachable and operable by keyboard (2.1.1)
- [ ] Focus can always be moved away again — no trap (2.1.2)
- [ ] Focus is always visible and not obscured (2.4.7, 2.4.11)
- [ ] Skip link to main content present and first in tab order (2.4.1)
- [ ] Each page sets its own title (2.4.2)
- [ ] Pointer targets ≥ 24×24 CSS px (2.5.8)
- [ ] No time limits, or user can extend/disable (2.2.1)
- [ ] No content flashes more than 3× per second (2.3.1)

### Understandable
- [ ] `<html lang="…">` set; language changes marked (3.1.1, 3.1.2)
- [ ] Consistent navigation and identification (3.2.3, 3.2.4)
- [ ] Inputs have visible labels + appropriate `autocomplete` (1.3.5, 3.3.2)
- [ ] Errors identified in text and programmatically linked (3.3.1, 3.3.3)
- [ ] Authentication needs no cognitive test; paste is allowed (3.3.8)

### Robust
- [ ] Semantic HTML, unique `id`s, roles that match behaviour (1.3.1, 4.1.2)
- [ ] Status messages announced via live regions (4.1.3)
- [ ] Verified with a current screen reader (NVDA, VoiceOver, or JAWS)

4.1.1 Parsing was **removed** in WCAG 2.2. Keep the check — duplicate `id`s and
mis-nested markup still break assistive technology — and attribute it to 1.3.1
and 4.1.2. A report citing 4.1.1 cites a criterion that no longer exists.

### Automation & Process
- [ ] axe-core specs run in CI for critical pages and components
- [ ] Manual keyboard-only pass performed on changed flows
- [ ] Screen-reader smoke test documented for major releases

## Bundled References (load on demand)

This skill ships deep-dive material in `references/`. `SKILL.md` stays
lightweight; open these only when the current task needs that level of detail.

- `references/wcag-2.2-criteria.md` — all 86 success criteria with Rails and
  Inertia notes. Load when mapping a finding to its exact SC or scoping an
  audit by level.
- `references/common-failures.md` — expanded catalog of failure patterns
  beyond the ones above. Load when the issue at hand is not in this list.
- `references/aria-patterns.md` — APG recipes (disclosure, modal, menu, tabs,
  combobox, tooltip, live region, accordion) in native HTML, React and ERB.
  Load when reviewing or building a custom widget.
- `references/screen-reader-testing.md` — NVDA / VoiceOver / JAWS smoke-test
  playbook. Load when planning a manual pass.
- `references/rails-snippets.md` — layout with skip link and live regions, form
  remediations for ERB and Inertia, route-change announcer, icon button, and the
  `be_axe_clean` specs. Load when recommending concrete fixes.

## Authoritative Upstream Sources

- W3C WCAG 2.2 Recommendation — <https://www.w3.org/TR/WCAG22/>
- How to Meet WCAG 2.2 (Quick Reference) — <https://www.w3.org/WAI/WCAG22/quickref/>
- WCAG 2.2 Techniques & Failures — <https://www.w3.org/WAI/WCAG22/Techniques/>
- WAI-ARIA Authoring Practices Guide — <https://www.w3.org/WAI/ARIA/apg/>
- WebAIM WCAG 2 Checklist — <https://webaim.org/standards/wcag/checklist>
- Deque axe-core rules — <https://dequeuniversity.com/rules/axe/>
- axe-core-rspec gem — <https://github.com/dequelabs/axe-core-gems>
- ADA Title II web rule, 28 CFR § 35.200 — <https://www.ada.gov/resources/2024-03-08-web-rule/>
- Revised Section 508 Standards, E205.4 / E207.2 — <https://www.access-board.gov/ict/>
- Commission Implementing Decision (EU) 2021/1339 citing EN 301 549 v3.2.1 —
  <https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32021D1339>
