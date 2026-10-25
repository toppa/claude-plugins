---
name: inertia-rails-forms
description: >-
  Full-stack Inertia form handling in React — the `<Form>` component, the `useForm` hook and
  the choice between them, `useFormContext`, validation error display, delete buttons,
  multi-step wizards, and file uploads with progress.
when_to_use: >-
  Use when you build or review a form, a delete button, a multi-step wizard, or a file
  upload in an Inertia page. Also use it when a form's errors do not appear beside the
  right field, when a checkbox can never submit `false`, or when a submit fires twice.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-forms/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, @inertiajs/react 3.6.1, @inertiajs/core 3.6.1, react 19.2.8,
    @types/react 19.2.17, typescript 7.0.2, rails 8.1.3.1, rack 3.2.6
---

# Inertia Rails Forms

## Which tool

**`<Form>` is the default.** It handles CSRF tokens, redirect following, error mapping from
Rails, processing state, file detection, history state and Precognition with no setup, so
prefer it to `react-hook-form`, which duplicates that machinery and fights Inertia's request
lifecycle. A nested child that needs `errors` or `processing` calls `useFormContext` rather
than lifting state.

`useState` alongside `<Form>` is right for UI that is not form data — a preview URL, a file
size, the current wizard step.

**Reach for `useForm` when the submitted data must live in React state:** a multi-step
wizard, fields the user adds and removes, or data a sibling component reads (a live preview
panel). One `useForm` per logical form.

**A request that is not a form submission at all:**
- **A lookup that re-renders the current page** — a search box or a filter reloading part of
  the page's props. `router.get(url, params, options)`, debounced, with `preserveState: true`
  in the options. The payload is always the second argument and the options the third —
  `inertia-rails-pages` owns that rule in its "`<Link>` and `router`" section, along with
  what breaks when the two are swapped.
- **An inline single-field edit with no navigation** — `router.patch(url, data)`, or
  `useForm` when the field needs to show its own error.
- **A request whose response is not an Inertia page at all** — an external API, or a JSON
  endpoint in this app. Use the `useHttp` hook rather than raw `fetch`; see below.

## `<Form>` Component (Preferred)

`<Form>` collects its values from the inputs' `name` attributes, so give every control a
`name`. `data` belongs to `useForm`: `FormProps` intersects `React.AllHTMLAttributes`, so
`data="something"` type-checks as the HTML `data` attribute and `data={{ name: 'x' }}` fails
with `TS2322 … not assignable to type 'string'` rather than "unknown prop". For edit forms,
give inputs a `defaultValue` — see the edit form below for why.

**Use render function children** `{({ errors, processing }) => (...)}`, which is the only
way in to `errors`, `processing` and `progress`.

`disableWhileProcessing` sets `inert` on the `<form>` element while the request is in
flight, so a second submit cannot start.

```tsx
import { Form } from '@inertiajs/react'

export default function CreateUser() {
  return (
    <Form method="post" action="/users" disableWhileProcessing>
      {({ errors, processing }) => (
        <>
          <input type="text" name="name" />
          {errors.name && <span className="error">{errors.name}</span>}

          <input type="email" name="email" />
          {errors.email && <span className="error">{errors.email}</span>}

          <button type="submit">
            {processing ? 'Creating...' : 'Create User'}
          </button>
        </>
      )}
    </Form>
  )
}
```

### Delete Form

```tsx
<Form method="delete" action={`/posts/${post.id}`}>
  {({ processing }) => (
    <button type="submit" disabled={processing}>
      {processing ? 'Deleting...' : 'Delete Post'}
    </button>
  )}
</Form>
```

### Key Render Function Properties

| Property | Type | Purpose |
|----------|------|---------|
| `errors` | `Record<string, ErrorValue>` | Validation errors keyed by field name. `ErrorValue` is `string` unless the app widens it through the `InertiaConfig` augmentation |
| `processing` | `boolean` | True while request is in flight |
| `progress` | `Progress \| null` | Upload progress. `percentage`, `progress` and `total` are each `number \| undefined`; only `loaded` is always a number, so read `progress.percentage ?? 0` |
| `hasErrors` | `boolean` | True if any errors exist |
| `wasSuccessful` | `boolean` | True after last submit succeeded |
| `recentlySuccessful` | `boolean` | True for 2,000 ms after success — the gem's `form.recentlySuccessfulDuration` default. Ideal for "Saved!" feedback |
| `isDirty` | `boolean` | True when `new FormData(form)` differs from the snapshot taken on mount |
| `validating` | `boolean` | True while a Precognition validation request is in flight |
| `reset` | `(...fields) => void` | Restore fields to the mount-time DOM values |
| `clearErrors` | `(...fields) => void` | Clear specific errors or all errors |
| `validate` / `invalid` / `valid` / `touch` | see Precognition | Live field validation; needs `precognition!` on the Rails side |

Further `<Form>` props — `errorBag`, `resetOnSuccess`, `resetOnError`,
`setDefaultsOnSuccess`, and the `options` prop that carries `only`, `except`,
`preserveScroll`, `preserveState` and `replace` — are in the **Form Component Props** table of
`references/advanced-forms.md`, alongside `disableWhileProcessing` above; `onBefore` appears
there in the **Conditional Submission** example. See the **MANDATORY — READ ENTIRE FILE**
trigger for that file below. `only` goes inside `options`:
`<Form options={{ only: ['users'] }}>` compiles, where the top-level
`<Form only={['users']}>` is `TS2322`.

The visit callbacks `onStart`, `onProgress`, `onSuccess`, `onError`, `onFinish`, `onCancel`
and `onFlash` take the same arguments here as on a `router` visit, and are documented once,
in the **Visit Options** section of `inertia-rails-pages`' navigation reference.

### Edit Form (Pre-populated)

Use `method="patch"` and uncontrolled defaults:
- Text/textarea → `defaultValue`
- Checkbox/radio → `defaultChecked`
- Select → `defaultValue` on `<select>`

`defaultValue` rather than a controlled `value` because `reset()` and `defaults()` write
straight to the DOM elements (`resetFormFields` in `@inertiajs/core`), which React undoes on
its next render whenever the input's value is bound to React state. Controlled inputs are
`useForm`'s model, not `<Form>`'s.

**Pair every checkbox with a hidden field of the same `name` carrying `value="0"`.** An
unchecked checkbox is absent from `FormData` altogether, so without the hidden field the
parameter never arrives and the attribute can never be set back to `false` through the edit
form. This is the same pairing Rails' own `check_box` helper emits, and it survives Inertia's
JSON encoding: `formDataToObject` lets the later of two same-named entries win, so unchecked
sends `"0"` and checked sends `"1"` rather than an array of both.

The checked `value="1"` is for readability, not for casting: `"on"` is not in
`ActiveModel::Type::Boolean::FALSE_VALUES`, and the class documents that "All other values
will be coerced to `true`", so a bare checkbox already casts to `true`.

```tsx
<Form method="patch" action={`/posts/${post.id}`} disableWhileProcessing>
  {({ errors, processing }) => (
    <>
      <input type="text" name="title" defaultValue={post.title} />
      {errors.title && <span className="error">{errors.title}</span>}

      <label>
        <input type="hidden" name="published" value="0" />
        <input type="checkbox" name="published" value="1"
          defaultChecked={post.published} />
        Published
      </label>

      <button type="submit">
        {processing ? 'Saving...' : 'Update Post'}
      </button>
    </>
  )}
</Form>
```

### `transform` and `formRef`

The `transform` prop reshapes the data before submission with no `useForm`.

`ref` hands you the same `FormComponentSlotProps` object the render function receives, plus
`getData()` and `getFormData()`, typed `FormComponentRef` from `@inertiajs/core`. A button
that calls `formRef.current?.submit()` belongs **outside** the `<Form>`, or carries
`type="button"`: inside a form a button defaults to `type="submit"`, so the click handler
submits once and the browser's own submit fires `<Form>`'s `onSubmit`, which submits again.

The ref's reset-to-current-values method is `defaults()`. `useForm`'s equivalent is
`setDefaults()` — the two names differ, so a snippet does not move between them unchanged.

Worked examples: `references/advanced-forms.md`, sections "Data Transforms" and "Driving a
form from outside with formRef".

### Reading form state from a nested child with `useFormContext`

`<Form>` publishes its slot props on a React context, so a component nested anywhere inside
it reads `errors`, `processing`, `validate` and the rest without the parent lifting state or
switching to `useForm`. This is the answer when a field lives in its own component.

`useFormContext<TForm>()` returns `FormComponentRef<TForm> | undefined` — `undefined`
outside a `<Form>` — so the call site guards with `?.`. Worked example:
`references/advanced-forms.md`, section "Reading form state with useFormContext".

## `useForm` Hook

`processing` and `progress` clear in the `onFinish` callback, not the moment the
response arrives. A spinner bound to `processing` therefore stays up until `onFinish`.

**MANDATORY — READ ENTIRE FILE** when using the `useForm` hook, `transform`, `errorBag`,
`resetOnSuccess`, `options`, nested attributes, dynamic fields, multi-step forms, cache-tag
invalidation, or real-time field validation:
[`references/advanced-forms.md`](references/advanced-forms.md) (~650 lines) — the full
`useForm` API, the `<Form>` props not covered above, transform examples, error bag scoping,
nested attributes with the Rails side that makes them work, the multi-step wizard, cache tag
invalidation, Precognition, and the worked examples for `useFormContext`, `formRef`,
`useHttp` and optimistic updates. The `<Form>` examples above cover a create or edit form on
their own.

## `useHttp` Hook

`useHttp` sends a request that is **not** a page visit — an external API, or a JSON
endpoint that returns no Inertia response. It returns the same shape as `useForm` plus a
`response`, so reach for it instead of raw `fetch`.

**Supply both type arguments: `useHttp<TForm, TResponse>`.** `TResponse` defaults to
`unknown`, and the response body is the whole reason to reach for `useHttp`, so with one
argument `onSuccess`'s `response` is `unknown` and every field read on it is `TS18046`.

It does not update page props and a server redirect does nothing, so anything that renders an
Inertia page stays with `<Form>` or `useForm`. Worked example:
`references/advanced-forms.md`, section "useHttp".

## Optimistic Updates

Inertia applies your change to the page props at once. It reverts the change on a 422,
on a server error, and when a new visit interrupts the request, so prefer it to a
`useState` copy of the data with an `onError` rollback.

**The callback's `props` argument is typed from the page object, not from your page's
`Props`.** `<Form optimistic>` is `FormComponentOptimisticCallback<Page<SharedPageProps>['props'], TForm>`
and `PageProps` is `{ [key: string]: unknown }`, so a page-specific key arrives as `unknown`
and needs a type at the use site: assert the one key you touch, or widen `sharedPageProps`
through the `InertiaConfig` augmentation for keys that really are shared on every page — see
`inertia-rails-typescript`.

`useForm` returns an `optimistic()` method, called before the submit. For an action with no
form, chain `router.optimistic<TProps>(…).post(…)` — and pass that type argument, because
`Router.optimistic` declares no default and `props` is otherwise `unknown`.

`useHttp` also has an `optimistic()`, with a **different** contract:
`(currentData: TForm) => Partial<TForm>` — it revises the form's own data, not the page
props, so a snippet does not move between the two unchanged.

Worked examples: `references/advanced-forms.md`, section "Optimistic updates".

## File Uploads

Both `<Form>` and `useForm` auto-detect files and switch to `FormData`, and upload progress
arrives as `progress` in the render function alongside `errors` and `processing`.

A multipart `PUT` or `PATCH` needs no `_method` workaround here: Rack's `form_data?` matches
`multipart/form-data` for any request method, so Rails parses the body, and `_method` appears
zero times in `@inertiajs/core` 3.6.1.

**Choosing `<Form>` vs `useForm` for uploads:**
- **File submits with other fields** (avatar + name, one Save button) → file input inside `<Form>`
- **Standalone immediate upload** (uploads on select, no Save button) → `<Form>` + `formRef.submit()` on change
- **Drag-and-drop upload** → `useForm` (dropped files aren't in DOM inputs, `setData` is cleaner)

Preview and client-side validation → `useState` alongside either approach.

**MANDATORY — READ ENTIRE FILE** when you write an upload:
[`references/file-uploads.md`](references/file-uploads.md) (~225 lines) — the `<Form>` and
`useForm` upload examples, image preview, multiple files, progress tracking, and the Active
Storage and direct-upload setup.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No access to `errors`/`processing` | Plain children instead of render function | `<Form>` children should be `{({ errors, processing }) => (...)}` |
| Form sends GET instead of POST | Missing `method` prop | Add `method="post"` (or `"patch"`, `"delete"`) |
| A field never reaches the server | The control has no `name`, or it is `disabled` | `<Form>` submits `new FormData(form)`, which contains only named, enabled controls. Give the control a `name`; use `disableWhileProcessing` on the `<Form>` instead of `disabled` on the inputs |
| An attribute can never be set back to `false` | The unchecked checkbox is absent from `FormData` | Add a hidden field of the same `name` with `value="0"` before the checkbox |
| Errors don't clear after fixing field | Stale error state | Errors auto-clear on next submit; use `clearErrors('field')` for immediate clearing, or `validate('field')` under Precognition |
| `isDirty` stays false after typing | Same cause as a field never reaching the server | `isDirty` compares `new FormData(form)` against the mount-time snapshot, so a control with no `name` cannot make the form dirty |
| `reset()` does not visibly reset a field | The input's value is bound to React state | `reset()` writes to the DOM element and React's next render puts its own value back. Use `defaultValue` with `<Form>`, or move the form to `useForm` |
| `progress` is always `null` | No file input in form | Progress tracking only activates when `<Form>` detects a file input |
| A submit fires twice | A `type="submit"` button whose `onClick` also calls `submit()` | Give that button `type="button"`, or move it outside the `<Form>`. Add `disableWhileProcessing` so a second submit cannot start while the first is in flight |
| Reached for `useForm` to preview an upload | A file preview is local UI state, not submission data | `<Form>` plus `useState` for the preview |

## Related Skills
- **The controller half — the errors value, the redirect target after a write, and flash** →
  `inertia-rails-controllers`
- **Page props typing** → `inertia-rails-typescript` (`type Props` not `interface`, TS2344,
  and the `InertiaConfig` augmentation that types `sharedPageProps` and `flash`)
