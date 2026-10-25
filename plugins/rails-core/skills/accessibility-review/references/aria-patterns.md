# ARIA Authoring Practices — Rails and React Recipes

Source of truth: <https://www.w3.org/WAI/ARIA/apg/patterns/>. Each pattern below
leads with the form to ship. Where native HTML does the job, that is the recipe;
ARIA appears only where the platform has no element for the job, and then the
pattern is implemented completely, because partial ARIA is worse than none.

General rules:

- Let each element keep its native role: a `<button>` for an action, an
  `<a href>` for a destination. When both are plausible, ask whether the control
  navigates.
- Every custom widget is reachable by keyboard and answers the key map its role
  implies.
- `aria-expanded`, `aria-selected`, `aria-current` and `aria-controls` are
  updated by the same code that changes the visual state — a state attribute
  that never changes is a lie the reader repeats.
- `tabindex="0"` adds a non-native control to the tab order; `tabindex="-1"`
  makes an element focusable only in code. Those are the two values that behave
  predictably.
- Return focus to the invoking element when a transient widget closes.
- Reserve `aria-hidden="true"` and `inert` for content that must not be reached
  at all, so nothing focusable is ever inside them.

## 1. Disclosure (Show/Hide)

Native HTML has the whole pattern, keyboard and AT exposure included, with no
JavaScript and no ARIA:

```erb
<details>
  <summary>Shipping details</summary>
  <p>Ships in 2 business days.</p>
</details>
```

Reach for a scripted disclosure only when you need a transition or a shared open
state. Then the trigger owns `aria-expanded` and `aria-controls`:

```tsx
function Disclosure({ id, label, children }: {
  id: string; label: string; children: React.ReactNode
}) {
  const [open, setOpen] = useState(false)
  return (
    <div>
      <button type="button" aria-expanded={open} aria-controls={id}
              onClick={() => setOpen(!open)}>
        {label}
      </button>
      <div id={id} hidden={!open}>{children}</div>
    </div>
  )
}
```

Keys: Enter and Space toggle; focus stays on the trigger.

**If you write the ERB equivalent as a partial**, pass the content as a local.
`<%= yield %>` inside a plain partial renders nothing — it resolves to
`content_for(:layout)` — so it silently produces an empty panel. Rendering the
partial with `render layout: "shared/disclosure" do … end` does yield the block
correctly (verified on Action View 8.1.3), which is the only form of `yield` a
partial supports.

## 2. Modal Dialog

Prefer the native `<dialog>` element opened with `showModal()`. It moves focus
in, cycles Tab inside, closes on Escape, and returns focus to the opener — the
four requirements of the APG Dialog pattern.

```erb
<dialog id="confirm-delete"
        aria-labelledby="confirm-delete-title"
        aria-describedby="confirm-delete-desc">
  <h2 id="confirm-delete-title">Delete this entity?</h2>
  <p id="confirm-delete-desc">This action cannot be undone.</p>

  <div class="flex gap-2">
    <form method="dialog">
      <button value="cancel">Cancel</button>
    </form>

    <%= button_to "Delete", entity_path(@entity), method: :delete,
          class: "bg-red-600 text-white" %>
  </div>
</dialog>
```

**Keep the destructive action outside the `method="dialog"` form.** `button_to`
emits its own `<form>`, and the HTML parser drops a nested form's start tag: the
Delete button would become a submit button for the `method="dialog"` form, so it
would close the dialog and never issue the DELETE. Siblings inside a layout
`<div>` keep both forms intact.

In React the same element works, opened through a ref:

```tsx
const ref = useRef<HTMLDialogElement>(null)
// ref.current?.showModal() to open, ref.current?.close() to dismiss
<dialog ref={ref} aria-labelledby="confirm-title">…</dialog>
```

Roll your own only if `<dialog>` is unavailable, and then implement focus trap,
Escape, and focus restoration end to end.

## 3. Navigation menus and action menus

Most "menus" are navigation: a list of links inside a labelled landmark. That is
the pattern to ship, and it costs no keyboard work because links already behave.

```erb
<nav aria-label="Account">
  <ul>
    <li><%= link_to "Profile", profile_path %></li>
    <li><%= link_to "Settings", settings_path %></li>
    <li><%= button_to "Sign out", session_path, method: :delete %></li>
  </ul>
</nav>
```

`role="menu"` is for an application-style action menu, and it buys a full key
map obligation: Down/Up between items, Home/End to the ends, Escape to close and
return focus to the trigger, Tab to close and move on, Enter/Space to activate.
Its children must be `menuitem` elements that perform actions — not links to
other pages.

```tsx
<button type="button" aria-haspopup="menu" aria-expanded={open}
        aria-controls="row-actions" onClick={toggle}>Actions</button>

<ul id="row-actions" role="menu" hidden={!open}>
  <li role="none"><button role="menuitem" type="button" onClick={duplicate}>Duplicate</button></li>
  <li role="none"><button role="menuitem" type="button" onClick={archive}>Archive</button></li>
</ul>
```

If the menu is only links, delete the roles and use the `<nav>` form above.

## 4. Tabs

```tsx
<div role="tablist" aria-label="Account sections">
  <button role="tab" id="tab-profile" aria-selected={tab === 'profile'}
          aria-controls="panel-profile" tabIndex={tab === 'profile' ? 0 : -1}>Profile</button>
  <button role="tab" id="tab-security" aria-selected={tab === 'security'}
          aria-controls="panel-security" tabIndex={tab === 'security' ? 0 : -1}>Security</button>
</div>

<section role="tabpanel" id="panel-profile" aria-labelledby="tab-profile"
         tabIndex={0} hidden={tab !== 'profile'}>…</section>
<section role="tabpanel" id="panel-security" aria-labelledby="tab-security"
         tabIndex={0} hidden={tab !== 'security'}>…</section>
```

Key map (roving `tabindex`): Left/Right or Up/Down move selection, Home/End jump
to the ends, Tab moves into the active panel.

**Tab only reaches the panel because the panel carries `tabindex="0"`.** Without
it, Tab skips from the tab list to whatever follows the panel, and the documented
behaviour never happens. Give it to every panel, or to the visible one.

## 5. Combobox / Autocomplete

For a static list, `<input list>` with `<datalist>` gives you keyboarding and AT
exposure from the browser. For dynamic results, follow the APG Combobox pattern:

- `role="combobox"` on the input, with `aria-expanded`,
  `aria-controls="listbox-id"` and `aria-autocomplete="list"`.
- `role="listbox"` on the result container, `role="option"` on each child,
  `aria-selected="true"` on the active option, and `aria-activedescendant` on the
  input pointing at that option's id.
- Keys: Down/Up move through options without moving DOM focus, Enter selects,
  Escape closes and restores the typed value.

## 6. Tooltip

A tooltip holds text only, and its trigger is focusable so the tooltip can be
reached without a pointer.

```erb
<button type="button" aria-describedby="tip-save">Save</button>
<div id="tip-save" role="tooltip" hidden>Saves without publishing.</div>
```

Show on focus and hover; hide on blur, mouseleave, or Escape. Anything
interactive belongs in a popover or dialog instead, where it can be reached.

## 7. Toast / Live Region

Announce through the app's single live region rather than moving focus — see
`SKILL.md`, section "4.1.3 Status Messages", for the canonical region, and
`references/rails-snippets.md` for where it sits in the layout. Errors that must
interrupt get their own `role="alert"` element, kept out of the polite region.

## 8. Accordion

Grouped disclosures, each trigger a `<button>` inside its heading. The panel is
named by the button, so **the `aria-labelledby` IDREF must be the button's own
`id`** — pointing it at an id that exists nowhere leaves the region with no
accessible name, which is the entire point of the pattern.

```erb
<h3>
  <button type="button" id="acc-header-1"
          aria-expanded="false" aria-controls="acc-panel-1">
    Billing
  </button>
</h3>
<div id="acc-panel-1" role="region" aria-labelledby="acc-header-1" hidden>…</div>
```

Grep every `aria-labelledby` and `aria-describedby` value for a matching `id`
before shipping; a dangling IDREF fails silently in every browser.
