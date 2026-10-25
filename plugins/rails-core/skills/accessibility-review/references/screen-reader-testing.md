# Screen Reader Testing Playbook

Automated tools find a subset of WCAG failures — naming, order, announcement and
context are judged by a human with a keyboard and a screen reader. This playbook
is the minimum smoke test before shipping changed UI. (Do not quote a coverage
percentage in a report: the figures in circulation have no primary source.)

## When to run

- After any change to forms, modals, menus, tables, flashes, or navigation.
- Before releasing a feature with new page components or interactive widgets.
- After a change to client-side navigation, whether Inertia's router or Turbo.

## Reader + browser pairs to use

| OS       | Screen reader       | Browser  | Notes                                  |
|----------|---------------------|----------|----------------------------------------|
| Windows  | NVDA (free)         | Firefox  | Closest to real-world usage            |
| Windows  | JAWS (commercial)   | Chrome   | Enterprise target; optional but ideal  |
| macOS    | VoiceOver (built-in)| Safari   | `Cmd+F5` to toggle                     |
| iOS      | VoiceOver           | Safari   | Triple-press side button               |
| Android  | TalkBack            | Chrome   | Accessibility Suite                    |

Test **at least one desktop pair** per change. Test mobile when the feature
targets touch users.

## Universal keyboard-only smoke test (no reader required)

Run this first — if it fails, fix before spending screen-reader time.

1. Put the mouse away.
2. Tab from the top of the page. Every interactive element receives a **visible**
   focus ring, in an order that matches the visual layout.
3. `Shift+Tab` reverses the same path exactly.
4. Activate each control with `Enter` (links, buttons, submits) or `Space`
   (buttons, checkboxes). Each control performs its action exactly once, and
   `Space` activates it rather than scrolling the page.
5. Open each menu, modal and disclosure. `Escape` closes it and focus returns to
   the control that opened it.
6. Submit a form with errors. The error must be reachable from the keyboard and
   must identify which field is wrong.
7. Narrow the viewport to **320 CSS px** wide at 100% zoom. Content reflows with
   no horizontal scroll and nothing clipped (1.4.10 Reflow).
8. Separately, at your normal width, zoom text to **200%**. No text is lost or
   clipped (1.4.4 Resize Text).

Steps 7 and 8 are two different criteria with two different setups. Doing them
in one pass tests neither properly.

Failure of any step is a blocker.

## Reader commands worth memorising

| Reader | Next heading | Next landmark | Next form field | Element list |
|---|---|---|---|---|
| NVDA (modifier `Insert` or `CapsLock`) | `H` | `D` | `F` | `NVDA+F7` |
| VoiceOver (modifier `Ctrl+Option`) | rotor: `VO+U` | rotor: `VO+U` | `VO+Right` | `VO+U` |
| JAWS (modifier `Insert`) | `H` | `R` | `F` | `Insert+F6` |

Full key maps live in the WebAIM and Deque guides linked below rather than being
copied here, where they go stale.

## What to listen for

For each changed page, verify the reader announces:

1. **Page load** — the document title changed and the reader speaks it. In an
   Inertia app this depends on `<Head title>` per page.
2. **Landmarks** — the elements list shows `main`, `navigation`, `banner`,
   `contentinfo` and any `complementary` regions.
3. **Headings** — real headings, in contiguous order. A single `<h1>` naming the
   page is the convention to aim for; no criterion mandates it, so report a
   deviation as a convention rather than a 2.4.6 failure.
4. **Form fields** — every input announces label, type and state
   ("Email, edit text, required").
5. **Buttons vs links** — each control announces the role that matches what it
   does.
6. **Dynamic updates** — flash messages, inline validation and loading states
   announce through live regions, without focus moving.
7. **Images** — informative images announce meaningful alt text; decorative
   images stay silent.
8. **Tables** — data tables announce row and column headers as you move by cell.

## Client-side navigation checks

Under Inertia:

- After following a `<Link>`, does the reader speak the new page? It will only do
  so if the title changed (`<Head title>`) or a live region was written to.
- Does focus stay where the user left it? Inertia moves focus nowhere by itself,
  which is acceptable — a silent page is the finding, not an unmoved caret.
- Does a flash message announce once, and not re-announce on unrelated updates?
- Are validation errors, arriving via a redirect with `inertia: { errors: … }`,
  both announced and reachable?

Under Hotwire (only if `turbo-rails` is in the Gemfile — these events do not
exist under Inertia's router):

- **Turbo Drive**: does the reader announce the new page's title after a link
  click?
- **Turbo Frame swap**: was focus inside the frame preserved, or restored to
  something sensible inside the new content?
- **Turbo Stream append/replace**: is the target inside a live region, so
  insertions announce without stealing focus?
- **Modal in a frame**: is the dialog announced, does focus move in, does Escape
  close it, and does focus return to the opener?

## Recording findings

For each issue capture:

- Page / URL
- Component / file path
- Reader + browser pair
- Steps to reproduce
- Expected announcement vs actual
- WCAG success criterion, level, and whether it is also below the project's legal
  floor (see `SKILL.md`, section "Target Standard")

Feed each item into the priority sections of the report format in `SKILL.md`, section
"Step 4: Structured report".

## References

- WebAIM — Using NVDA to evaluate web accessibility:
  <https://webaim.org/articles/nvda/>
- WebAIM — Using VoiceOver to evaluate web accessibility:
  <https://webaim.org/articles/voiceover/>
- Deque — Screen reader keyboard shortcuts:
  <https://dequeuniversity.com/screenreaders/>
- WAI — Easy Checks for a first review:
  <https://www.w3.org/WAI/test-evaluate/easy-checks/>
