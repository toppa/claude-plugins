---
name: inertia-rails-typescript
description: >-
  TypeScript types for Inertia Rails and React — the `InertiaConfig` module augmentation
  in `globals.d.ts` that types shared props, flash, errors and layout props globally, and
  the `type`-not-`interface` rule for page props.
when_to_use: >-
  Use when you set up TypeScript for an Inertia app, add a shared prop, type a page
  component's props, type flash, errors or layout props, decide whether a validation error is
  a string or an array of strings, or fix a TS2344, TS2339, TS18046 or TS2717 error in an
  Inertia component.
metadata:
  upstream_repo: inertia-rails/skills
  upstream_path: skills/inertia-rails-typescript/SKILL.md
  upstream_ref: 6b63b3731a06ad3d01c515477b6b8852708871a6
  synced: 2026-08-08
  verified_against: >-
    TypeScript 7.0.2, "@inertiajs/core" 3.6.1, "@inertiajs/react" 3.6.1,
    "@types/react" 19.2.17, inertia_rails 3.22.0, vite-plugin-ruby 5.2.2
---

# Inertia Rails TypeScript Setup

Every claim below was compiled with TypeScript **7.0.2** against `@inertiajs/core` 3.6.1 and
`@types/react` 19.2.17.

## InertiaConfig Module Augmentation

Declare the config once, globally. `InertiaConfig` property names are exact:

| Key | Types | Default when you do not set it |
|---|---|---|
| `sharedPageProps` | `usePage().props` | `PageProps` — an index signature, so every read is `unknown` |
| `flashDataType` | `usePage().flash` | `PageFlashData` — likewise `unknown` |
| `errorValueType` | each value in `usePage().props.errors` | `string` |
| `layoutProps` | `setLayoutProps(props)` | `Record<string, unknown>` |
| `namedLayoutProps` | `setLayoutProps(name, props)` | `Record<string, Record<string, unknown>>` |

Those five are the whole set — `@inertiajs/core` 3.6.1 declares them as
`DefaultInertiaConfig`, and `InertiaConfigFor<K>` prefers your override over the default.

```typescript
// app/frontend/types/globals.d.ts
import type { FlashData, SharedProps } from '@/types'

declare module '@inertiajs/core' {
  export interface InertiaConfig {
    sharedPageProps: SharedProps   // types usePage().props
    flashDataType: FlashData       // types usePage().flash
    errorValueType: string[]       // errors are arrays of strings
  }
}
```

`errorValueType: string[]` is what Rails sends on a redirect-with-errors: `inertia_rails` puts
`errors.to_hash` in the session (`controller.rb:192`) and ActiveModel's `to_hash` returns
`{ attribute => [messages] }`. But that is only half of the decision — see below.

```typescript
// app/frontend/types/index.ts
export type FlashData = {
  notice?: string
  alert?: string
}

export type SharedProps = {
  auth: { user?: { id: number; name: string; email: string } }
}
```

**Use `type`, not `interface`, for these two.** `sharedPageProps` is fed to
`Page<SharedProps extends PageProps>`, and `PageProps` is an index signature. A `type`
alias satisfies it implicitly; an `interface` does not, which produces **16 × TS2344**
inside `@inertiajs/core`'s and `@inertiajs/react`'s own `.d.ts` files —
*"Type 'SharedProps' does not satisfy the constraint 'PageProps'"*. The generator's
`tsconfig.app.json` sets `skipLibCheck: true`, which suppresses all sixteen, so an
`interface` appears to work until someone turns `skipLibCheck` off. The generator's own
`types/index.ts` writes `type`.

**Convention:** use `auth: { user: … }` as the shared-props key, matching the Rails
`inertia_share` convention (`{ auth: { user: current_user } }`). The `auth` namespace keeps
authentication data from colliding with a page's own `user` prop, and the other skills in
this plugin assume it.

## Where each value lives on the page object

`usePage()` returns the whole page object, and only `props` holds props. These are its
siblings, not members of `props`:

```tsx
const { props, flash, component, url, sharedProps, clearHistory, encryptHistory,
  preserveFragment } = usePage()
```

`flash` is the one that catches people out — `usePage().flash`, a sibling of `props`.
`errors` is the opposite: it *is* on `props`, as `usePage().props.errors`.

**`usePage().props.flash` does not error where you would want it to.** `PageProps` has an
index signature, so the read compiles and yields `unknown`; the error surfaces later, at
the point of use, as **TS18046** (*"'flash' is of type 'unknown'"*) or **TS2322** when you
assign it somewhere typed. The same index signature swallows a typo:
`usePage().props.athu` compiles clean. Treat any `unknown` coming out of `props` as a sign
you either mistyped a key or read something that lives on the page object instead.

The same holds for `flash` itself before the augmentation is in place: `PageFlashData` is
also an index signature, so `usePage().flash.notice` is `unknown` and
`el.textContent = usePage().flash.notice` is a **TS2322**. Add `flashDataType` and it
becomes `string | undefined`.

## Two augmentations that must match a runtime setting

`flashDataType` and `errorValueType` share a failure mode: each describes a value the *runtime*
decides, so a declaration that disagrees with the runtime produces no error at the point of use.
The type is simply wrong and everything compiles.

**`flashDataType` must match `flash_keys`.** Rails only puts the keys in
`config.inertia.flash_keys` onto the page object (`%i[notice alert]` by default). Declaring
`flashDataType: { toast: Toast }` without adding `:toast` to `flash_keys` gives you a
`Toast`-typed read of a key that is never sent, and `usePage().flash.toast` is `undefined` at
runtime with no complaint from the compiler.

**`errorValueType` must match `withAllErrors`**, and this one is easy to get wrong because one
setting is a runtime default and the other a type declaration, in two different files.

There are two paths by which errors reach the frontend, and they do not agree by default:

| Path | What arrives | Governed by |
|---|---|---|
| Redirect with `inertia: { errors: @user.errors }` → `usePage().props.errors` | `string[]` — ActiveModel's `to_hash` returns arrays | Rails; always arrays |
| `<Form>` / `useForm` client-side validation and a 422 JSON response → `form.errors` | `string[]` **or** `string` | `withAllErrors` |

`@inertiajs/react` picks between them explicitly, at `dist/index.js:679` (live validation)
and `:1870` (the 422 response):
`withAllErrorsEnabled() ? validator.errors() : toSimpleValidationErrors(validator.errors())`,
where `toSimpleValidationErrors` keeps `errors[key][0]` — the first message only
(`laravel-precognition/dist/validator.js:402-406`). And **`withAllErrors` defaults to
`false`** (`@inertiajs/core/dist/index.js:39`).

So one configuration is coherent and three misstate a type:

- **`withAllErrors: true` plus `errorValueType: string[]`** — coherent. Both paths deliver
  arrays. This configuration takes two settings. An entrypoint such as
  `app/frontend/entrypoints/inertia.tsx` sets `withAllErrors: true` inside
  `createInertiaApp`'s `defaults.form`, and a declaration file such as
  `app/frontend/types/globals.d.ts` declares `errorValueType: string[]`. Check both files in
  your own application before you rely on it. **Render `errors.name?.[0]`, or map the array —
  never the bare value.**
- **`withAllErrors` off plus no `errorValueType`** — the default on both halves, and right for
  `form.errors` alone. `usePage().props.errors` is still typed `string` while Rails sends an array,
  because the redirect path ignores `withAllErrors`.
- **`withAllErrors` off plus `errorValueType: string[]`** — a type that lies. `form.errors.name`
  is declared `string[]` and holds a `string`, so `errors.name[0]` type-checks and yields the
  first *character*.
- **`withAllErrors: true` with the default `errorValueType`** — the reverse lie. The value is
  declared `string` and holds `string[]`.

**No lie here shows up as an error, and one of them is nearly invisible.** Rendering a `string[]`
as a React child concatenates the elements with no separator (verified with
`renderToStaticMarkup` on react-dom 19.2.8): a single-message array renders exactly like the
string, so a one-error form looks correct, and it is only the second validation message on the
same field that appears as `can't be blankis too short`. `.length` flips meaning silently too —
message count rather than character count — so `errors.name.length` reads as a plausible guard
either way.

Decide once, write both halves in the same change, and prefer `withAllErrors: true` with
`errorValueType: string[]`: it is the only combination where a field's full error list is
available and both paths agree. `inertia-rails-forms` owns `withAllErrors` as a per-form
prop, in the "Form Component Props" table of its advanced-forms reference.

## Extending the config

Leave the name `PageProps` to `@inertiajs/core`: a local declaration of it shadows the real
one and detaches every read from it.

**Adding a shared prop touches one file.** `InertiaConfig` references `SharedProps` by
name, so extend the type in `index.ts` and leave `globals.d.ts` alone:

```typescript
// app/frontend/types/index.ts
export type SharedProps = {
  auth: { user?: { id: number; name: string; email: string } }
  notifications: { unread_count: number }
}
```

**A second `declare module '@inertiajs/core'` is legal.** Two augmentation files declaring
*different* keys merge cleanly. The one case that conflicts is the *same* key declared with
two different types — **TS2717**, *"Subsequent property declarations must have the same
type"* — and `skipLibCheck: true` hides even that when the declarations sit in `.d.ts`
files. Keeping the whole config in one `globals.d.ts` is worth doing because it is the one
place to look, not because a second file breaks.

## The file holding the augmentation must be a module

A module augmentation only augments from inside a module — a file with a top-level `import`
or `export`. `globals.d.ts` qualifies because of its `import type` line, and a plain `.ts`
file with exports qualifies too (verified: the augmentation applies and `usePage().props`
is typed).

**A `.d.ts` file with no imports or exports is the failure case, and it fails silently.**
Such a file is a global script, so `declare module '@inertiajs/core'` in it is not an
augmentation — it is an ambient declaration that *replaces* the package's types. Every real
export of `@inertiajs/core` then disappears: with `skipLibCheck: false` you get a wall of
TS2305 (*"Module '@inertiajs/core' has no exported member 'Page'"*) from inside
`@inertiajs/react`, and with the generator's `skipLibCheck: true` you get no errors at all
and `usePage()` quietly degrades to an unchecked type. If your augmentation seems to have
"worked" while every other type went slack, check for the missing import first.

The fix is one line at the top of the file — `import '@inertiajs/core'` is enough, and is
what `@inertiajs/core`'s own doc comment for `InertiaConfig` shows.

## Page-Specific Props

A page's own `type Props` names the page's own props and stops there: `usePage<T>()` returns
`Page<T & SharedPageProps>`, so the shared ones are already intersected in.

### `type` vs `interface` for page props

`usePage<T>()` constrains `T` to `PageProps`, which is an index signature — a `type` alias
satisfies it implicitly, and an `interface` is **TS2344**.

`usePage<Required<Props>>()` compiles, and it is the wrong fix: `Required<>` strips `?`
from genuinely optional props too, so `page.props.filter.length` type-checks against a
declaration that says `filter?: string` and throws at runtime. Change the declaration to a
`type` alias instead. An `interface` remains fine everywhere else — as an ordinary function
parameter type, for instance, including a page component's own props parameter.

```tsx
type Props = {
  users: User[]         // the page's own props, and only those
}

export default function Index({ users }: Props) {
  const { props, flash } = usePage()
  // props.auth and flash.notice are both typed via InertiaConfig
  return <UserList users={users} />
}
```

## Layout props

`setLayoutProps` and `resetLayoutProps` are typed from the same config:
`setLayoutProps(props)` takes `Partial<LayoutProps>` and `setLayoutProps(name, props)`
takes `Partial<NamedLayoutProps[name]>`. Declare them the same way as the rest:

```typescript
declare module '@inertiajs/core' {
  export interface InertiaConfig {
    layoutProps: { title: string; showSidebar: boolean }
    namedLayoutProps: { app: { title: string }; content: { maxWidth: string } }
  }
}
```

Without these two keys the calls still compile, against `Record<string, unknown>`, so a
misspelled layout prop goes unnoticed. `inertia-rails-pages` covers what layout props do,
in its "Persistent Layouts" section.

## Common TypeScript Errors

| Error | Cause | Fix |
|-------|-------|-----|
| **TS2344** on `usePage<Props>()` | `interface` has no index signature | Declare it as `type Props = { … }` |
| **TS2344** inside `@inertiajs/core`'s `.d.ts` | `SharedProps` declared as an `interface` | Declare it as `type SharedProps = { … }` |
| **TS2339** `'auth' does not exist on type Page<…>` | Destructuring `auth` straight off `usePage()` | `auth` is on `props`: `usePage().props.auth` |
| **TS18046** `'flash' is of type 'unknown'` | Reading `usePage().props.flash` | Flash is a page-object key: `usePage().flash` |
| **TS18046** on a shared prop | `sharedPageProps` not declared | Add the augmentation, or check the key's spelling |
| **TS2322** assigning `usePage().flash.x` | `flashDataType` not declared, so the value is `unknown` | Add `flashDataType` to `InertiaConfig` |
| No error, but an error message renders as two messages run together | `errorValueType` is `string[]` and the value is being rendered bare | Render `errors.name?.[0]` or map the array |
| No error, but `errors.name[0]` is a single character | `errorValueType: string[]` declared while `withAllErrors` is off | Set `withAllErrors: true`, or drop the `string[]` override |
| **TS2717** on an `InertiaConfig` key | The same key declared twice with different types | Keep one declaration per key |
| **TS2305** `'@inertiajs/core' has no exported member …` | The augmentation sits in a `.d.ts` with no imports or exports | Add `import '@inertiajs/core'` to that file |
| Types correct but the IDE disagrees | `globals.d.ts` outside `tsconfig.app.json`'s `include` | Check `tsconfig.app.json`'s `include` covers the types directory |
| **TS2305** `postsPath` not found in `@/routes` | The generated `js-routes` file is stale | `rails generate js_routes:middleware` once — it installs the dev middleware that regenerates the file and injects the build hook into the `Rakefile`, so no rake task needs wiring by hand. (The task itself is `js:routes`; `js:routes:typescript` only warns and delegates, deprecated at js-routes 2.4.1.) |
| `@/` imports do not resolve | Aliases present in Vite, absent from TypeScript | `vite-plugin-ruby` 5.2.2 already supplies the `@/` and `~/` Vite aliases; add the `paths` to `tsconfig.app.json`, which is the half that is missing them |

## Related Skills
- **Shared props and flash on the Rails side** → `inertia-rails-controllers`, its "Shared Data
  (`inertia_share`)" and "Flash Messages" sections, plus the "Flash Keys" section of that
  skill's configuration reference
- **Page component props and layout props** → `inertia-rails-pages`
- **Form and error types** → `inertia-rails-forms`
