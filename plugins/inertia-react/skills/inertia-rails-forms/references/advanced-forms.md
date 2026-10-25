# Advanced Form Patterns

Advanced form handling for Inertia.js + Rails + React.

## Table of Contents

- [useForm Hook](#useform-hook)
- [Form Component Props](#form-component-props)
- [Data Transforms](#data-transforms)
- [Remember State](#remember-state)
- [Nested Data](#nested-data)
- [Multiple Forms on One Page](#multiple-forms-on-one-page)
- [Conditional Submission](#conditional-submission)
- [Reset and Clear Patterns](#reset-and-clear-patterns)
- [Dynamic Fields](#dynamic-fields)
- [Multi-Step Forms](#multi-step-forms)
- [Cache Tag Invalidation](#cache-tag-invalidation)
- [Real-Time Validation with Precognition](#real-time-validation-with-precognition)
- [Reading form state with useFormContext](#reading-form-state-with-useformcontext)
- [Driving a form from outside with formRef](#driving-a-form-from-outside-with-formref)
- [useHttp](#usehttp)
- [Optimistic updates](#optimistic-updates)

---

## useForm Hook

Use `useForm` when the submitted data has to live **outside** the `<Form>` element:

- **Multi-step wizards** — one form state shared across step components
- **Live preview** — form data drives a sibling preview panel (populate product fields, watch the store page update in real time)
- **Dynamic fields** — the user adds and removes inputs, so the field list is state

A component *inside* the `<Form>` that only needs to read `errors`, `processing` or `validate`
does not need `useForm` — it calls `useFormContext`. `useForm` is for data that lives outside
the element or that code has to manipulate.

```tsx
import { useForm } from '@inertiajs/react'

export default function ProductEditor({ product }: { product: Product }) {
  const form = useForm({
    name: product.name,
    price: product.price,
    description: product.description,
  })

  return (
    <div className="grid grid-cols-2 gap-8">
      <form onSubmit={e => { e.preventDefault(); form.put(`/products/${product.id}`) }}>
        <input value={form.data.name} onChange={e => form.setData('name', e.target.value)} />
        {form.errors.name && <span>{form.errors.name}</span>}
        {/* ... more fields */}
        <button disabled={form.processing}>Save</button>
      </form>

      {/* Preview consumes form.data outside the form */}
      <ProductPreview product={form.data} />
    </div>
  )
}
```

**For everything else, use `<Form>`** — it handles CSRF, redirects, errors, transforms, file detection, and history state with zero setup.

### useForm API

```tsx
const {
  data,              // Current form data
  setData,           // (key, value) or (values) or (callback)
  submit,            // (method, url, options?) — the general form
  post,              // (url, options?) — POST request
  put,               // (url, options?) — PUT request
  patch,             // (url, options?) — PATCH request
  delete: destroy,   // (url, options?) — DELETE request
  cancel,            // () — abort the request in flight
  processing,        // boolean
  errors,            // { field: message } — the value type is ErrorValue
  hasErrors,         // boolean
  setError,          // (field, value) or (errors) — for an error with no server rule
  progress,          // Progress | null; percentage, progress and total may be undefined
  reset,             // (...fields) — reset to the current defaults
  resetAndClearErrors, // (...fields) — both at once
  clearErrors,       // (...fields) — clear specific errors
  setDefaults,       // () or (field, value) or (fields) — make the current data the reset target
  isDirty,           // boolean
  transform,         // (callback) — transform data before send
  optimistic,        // (callback) — revise page props before the response; call before submit
  dontRemember,      // (...fields) — keep these fields out of the remembered state
  wasSuccessful,     // boolean
  recentlySuccessful,// boolean, true for 2,000 ms (form.recentlySuccessfulDuration default)
  withPrecognition,  // (method, url) — adds validate/invalid/valid/touch/validating
} = useForm({ /* initial data */ })
```

The write helpers take **options** as their second argument, because the payload is
already in `data`: `form.post('/users', { invalidateCacheTags: ['users'] })`. The bare
`router` helpers differ — `router.post(url, data, options)` takes the payload second — so
a `router` snippet does not move onto a form unchanged.

`useForm`'s reset target is set by `setDefaults()`. The `<Form>` ref's equivalent is
`defaults()`; the names differ between the two.

## Form Component Props

`<Form>` carries the visit options that `useForm` passes per submit. Everything here is a
prop on the element.

| Prop | Effect |
|---|---|
| `disableWhileProcessing` | Sets `inert` on the `<form>` while the request is in flight, so a second submit cannot start. Replaces `disabled={processing}` on the submit button |
| `resetOnSuccess` | `true` for every field, or an array of field names. Runs after your `onSuccess` |
| `resetOnError` | Same shape, on the error path |
| `setDefaultsOnSuccess` | Makes the submitted values the new reset target, so `isDirty` returns to false |
| `onSubmitComplete` | `({ reset, defaults }) => void`, called after a successful submit — the hook for "clear the form and keep the user here" |
| `errorBag` | Namespaces this form's errors; see Multiple Forms on One Page |
| `invalidateCacheTags` | See Cache Tag Invalidation |
| `options` | Carries `only`, `except`, `preserveScroll`, `preserveState`, `preserveUrl`, `replace`, `reset`, `viewTransition`, `async`. These go inside `options`, never at the top level: `<Form options={{ only: ['users'] }}>` compiles, where `<Form only={['users']}>` is `TS2322` |
| `validationTimeout` | Debounce before a Precognition validation request, in milliseconds. The gem's default is 1,500 |
| `validateFiles` | Send file inputs with Precognition validation requests. Off by default: the validator strips files from the payload and logs "Precognition file validation is not active" if you validate a file field |
| `withAllErrors` | Keep **every** message for a field instead of only the first. Off, the validator runs `toSimpleValidationErrors`, which takes `errors[key][0]` |
| `transform` | `(data) => data` before the request; see Data Transforms |
| `optimistic` | Revise the page props before the response arrives |
| `component` / `instant` | Render the destination component before the response arrives. `instant` reads the `component` off an `action` pair, so it does nothing when `action` is a plain string |

`withAllErrors` decides the shape of `errors`, so it travels with the app's `errorValueType`
augmentation: turn it on app-wide in `createInertiaApp`'s `defaults.form` and `ErrorValue`
becomes `string[]`, and `{errors.name}` renders an array unless the JSX joins it.

`action` accepts either a URL string or a `{ url, method }` pair, and the pair supplies the
method, so `<Form action={{ url: '/users', method: 'post' }}>` needs no `method` prop.

```tsx
<Form
  method="post"
  action="/users"
  disableWhileProcessing
  resetOnSuccess
  setDefaultsOnSuccess
  options={{ preserveScroll: true, only: ['users'] }}
>
  {({ errors, processing }) => (
    <>
      <input name="name" />
      {errors.name && <span className="error">{errors.name}</span>}
      <button type="submit">{processing ? 'Creating…' : 'Create User'}</button>
    </>
  )}
</Form>
```

## Data Transforms

Transform data before it's sent to the server. Useful for formatting
dates, removing empty fields, or restructuring data.

### With `<Form>` component:
```tsx
<Form
  method="post"
  action="/events"
  transform={(data) => ({
    ...data,
    start_date: formatISO(data.start_date),
    tags: data.tags.filter(Boolean),
  })}
>
```

### With `useForm` hook:
```tsx
const form = useForm({ name: '', price: '' })

const handleSubmit = (e: React.FormEvent) => {
  e.preventDefault()
  form.transform((data) => ({
    ...data,
    price: parseFloat(data.price) * 100, // cents
  }))
  form.post('/products')
}
```

## Remember State

Persist form data across navigations so users don't lose their input
when they navigate away and come back.

```tsx
// useForm with remember key
const form = useForm('create-user', {
  name: '',
  email: '',
  role: 'member',
})
// Data persists in history state under the key 'create-user'
```

The first argument is a unique key for the form state. When the user
navigates away and back, the form data is restored.

## Nested Data

Nested attributes take three pieces, and the model macro is the one that makes the other two
mean anything. **Start with the model:**

```ruby
class User < ApplicationRecord
  has_one :address
  accepts_nested_attributes_for :address
end
```

`accepts_nested_attributes_for` is what defines the `address_attributes=` writer. Without it
`User.new(user_params)` reaches `attribute_writer_missing` and raises
`ActiveModel::UnknownAttributeError: unknown attribute 'address_attributes' for User`, no
matter how the params were permitted.

Then structure the form data to match.

### With `useForm`:
```tsx
const form = useForm({
  user: {
    name: '',
    email: '',
    address_attributes: {
      street: '',
      city: '',
      zip: '',
    },
  },
})

// Update nested field
form.setData('user.address_attributes.city', 'New York')
```

### With `<Form>` component:
```tsx
<Form method="post" action="/users">
  {({ errors }) => (
    <>
      <input name="user[name]" />
      <input name="user[email]" />
      <input name="user[address_attributes][street]" />
      <input name="user[address_attributes][city]" />
    </>
  )}
</Form>
```

Rails controller — the fields arrive nested under a model key, so this is `expect`'s shape:
```ruby
def user_params
  params.expect(
    user: [
      :name, :email,
      address_attributes: [:street, :city, :zip]
    ]
  )
end
```

`expect` raises `ActionController::ParameterMissing` — a 400 — when the **root** key is
missing, empty, or not a hash, which is its win over `require(:user).permit`: the same
spoofed `user=notahash` is a `NoMethodError` and a 500 under `require`. A *nested* key of the
wrong shape is filtered out **silently**, so `expect` guards the root, not the nested shape.

For a `has_many`, declare the collection as an array of permitted hashes, and index the
inputs — `name="order[lines][0][sku]"`, `name="order[lines][1][sku]"` — because the
numeric-key hash is the encoding `expect` accepts as an array:

```ruby
params.expect(order: [:note, { lines: [[:sku, :qty]] }])
# lines arriving as { "0" => { sku:, qty: } } → kept
# lines arriving as a plain { sku:, qty: }    → dropped, no exception
```

The strong-parameters rule by incoming shape belongs to `rails-core:rails-8-idioms`, in its
"Strong parameters: pick the form from the shape of the incoming params" section; this is the
nested case only.

## Multiple Forms on One Page

Use error bags to namespace errors when multiple forms appear on the
same page (e.g., login + register on the same screen).

```tsx
<Form method="post" action="/login" errorBag="login">
  {({ errors }) => (
    <>
      <input name="email" />
      {errors.email && <span>{errors.email}</span>}
    </>
  )}
</Form>

<Form method="post" action="/register" errorBag="register">
  {({ errors }) => (
    <>
      <input name="email" />
      {errors.email && <span>{errors.email}</span>}
    </>
  )}
</Form>
```

## Conditional Submission

Confirm before submitting, or conditionally prevent submission.

```tsx
<Form
  method="delete"
  action={`/users/${user.id}`}
  onBefore={() => confirm('Delete this user?')}
>
  {({ processing }) => (
    <button type="submit" disabled={processing}>Delete</button>
  )}
</Form>
```

With `useForm`:
```tsx
const handleSubmit = (e: React.FormEvent) => {
  e.preventDefault()
  if (!confirm('Submit?')) return
  form.post('/users')
}
```

## Reset and Clear Patterns

`reset`, `clearErrors` and `resetAndClearErrors` each take field names, or nothing for the
whole form, and are identical on `useForm` and on `<Form>`'s render function. `setDefaults`
closes the block below because it writes the baseline the other three reset to. Its shape
differs: it takes a field **and** a value, or an object, or nothing for the whole form, and it
throws when a function defines the form data (`@inertiajs/react` `dist/index.js:501-517`):

```tsx
const form = useForm({ name: '', email: '', role: 'member' })

form.reset('name', 'email')     // named fields back to the defaults
form.clearErrors()              // every error
form.resetAndClearErrors()      // both, whole form
form.setDefaults()              // current values become the reset target; isDirty → false
```

Prefer the declarative props for the common cases: `resetOnSuccess` after a successful
submit, `setDefaultsOnSuccess` to keep the submitted values as the new baseline.

## Dynamic Fields

Adding/removing fields dynamically requires `useForm` (not `<Form>`).

```tsx
const form = useForm({
  items: [{ name: '', quantity: 1 }],
})

const addItem = () => {
  form.setData('items', [...form.data.items, { name: '', quantity: 1 }])
}

const removeItem = (index: number) => {
  form.setData('items', form.data.items.filter((_, i) => i !== index))
}

return (
  <form onSubmit={e => { e.preventDefault(); form.post('/orders') }}>
    {form.data.items.map((item, index) => (
      <div key={index}>
        <input
          value={item.name}
          onChange={e => {
            const items = [...form.data.items]
            items[index] = { ...items[index], name: e.target.value }
            form.setData('items', items)
          }}
        />
        <button type="button" onClick={() => removeItem(index)}>Remove</button>
      </div>
    ))}
    <button type="button" onClick={addItem}>Add Item</button>
    <button type="submit">Submit</button>
  </form>
)
```

## Multi-Step Forms

Use `useForm` (not `<Form>`) with a remember key. Track the current step
with `useState`. Validate per step with `setError`/`clearErrors`, submit
once at the final step.

```tsx
const [step, setStep] = useState(1)

// Remember key preserves progress across navigation
const form = useForm('onboarding', {
  email: '', password: '',  // step 1
  name: '', company: '',    // step 2
  plan: 'starter' as const, // step 3
})

function nextStep() {
  form.clearErrors()
  // Per-step client-side validation
  if (step === 1 && !form.data.email) {
    return form.setError('email', 'Required')
  }
  setStep(s => s + 1)
}

// Single POST at the end — Rails sees one standard action
const submit = (e: React.FormEvent) => {
  e.preventDefault()
  form.post('/onboarding')
}
```

Each step renders its own fields gated by `{step === N && (...)}`.
Back/forward buttons call `setStep`. Only the final step has
`<button type="submit">`.

## Cache Tag Invalidation

After a form submission, invalidate prefetch caches for pages that show the
affected data. Use `invalidateCacheTags` on `<Form>` or `useForm` submit options:

```tsx
// With <Form>
<Form method="post" action="/users" invalidateCacheTags={['users', 'dashboard']}>
  {({ errors, processing }) => (
    <>{/* fields */}</>
  )}
</Form>

// With useForm
form.post('/users', {
  invalidateCacheTags: ['users', 'dashboard'],
})
```

Tags must match `cacheTags` set on `<Link prefetch cacheTags="...">` — see the "Cache Tags"
section of `inertia-rails-pages`' navigation reference for prefetch tag setup.

## Real-Time Validation with Precognition

Precognition runs the real Active Record validations for one field, over the wire, and
stops the action before it writes. Prefer it to a hand-written `setError` check, which
duplicates the model's rules in JavaScript and then drifts from them.

### Rails side

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    precognition!(@user)

    if @user.save
      redirect_to @user
    else
      redirect_to new_user_path, inertia: { errors: @user.errors }
    end
  end
end
```

`precognition!` halts a validation request and returns `false` on a real submit, so the
rest of the action runs normally. Put it above every write, every mail, and every
enqueued job. One action allows one `precognition!` call — to validate two models,
build a single form object with `ActiveModel::API`.

Set `config.precognition_prevent_writes = true` in the initializer to make a stray write
during a validation request raise `ActiveRecord::ReadOnlyError`.

**Pass the bare `errors` object on the submit path, so both paths render the same string.**
`inertia_rails`' Precognition path calls `errors.errors.to_hash` with **no argument** and
offers no override point, which yields the short message (`"can't be blank"`). Handing the
redirect `errors.to_hash(true)` yields the full message (`"Name can't be blank"`), so a form
using both live validation and submit-time errors would show the field one string while the
user types and a different one after they submit. The short, keyed hash is also the shape
that maps to inputs. `inertia-rails-controllers` owns the rule; this is the clause that
makes it non-arbitrary, because Precognition is documented here.

### React side

`<Form>` needs no client-side opt-in — it builds its form with `withPrecognition` internally
from its own `method` and `action` — so `validate`, `invalid`, `valid`, `touch`, `touched` and
`validating` are on the render function from the start. Only the Rails side has to opt in,
with `precognition!`.

```tsx
<Form action="/users" method="post">
  {({ errors, invalid, validate, validating }) => (
    <>
      <input id="name" name="name" onChange={() => validate('name')} />
      {invalid('name') && <p>{errors.name}</p>}
      {validating && <p>Checking…</p>}
      <button type="submit">Create User</button>
    </>
  )}
</Form>
```

Validation requests are debounced by `validationTimeout`, 1,500 ms by default. File inputs
are excluded until you pass `validateFiles`.

`useForm` does need `.withPrecognition(method, url)`, which widens its return type from
`InertiaFormProps` to `InertiaPrecognitiveFormProps` — that is the name to annotate with when
the form is passed between components:

```tsx
import { useForm } from '@inertiajs/react'
import type { InertiaPrecognitiveFormProps } from '@inertiajs/react'

type Fields = { name: string; email: string }

export function useUserForm(): InertiaPrecognitiveFormProps<Fields> {
  return useForm<Fields>({ name: '', email: '' }).withPrecognition('post', '/users')
}
```

Alongside the six helpers above, the precognitive form also carries `setValidationTimeout`,
`setErrors`, `forgetError`, `validateFiles`, `withoutFileValidation` and `withAllErrors`.

`setError` and `clearErrors` still exist for an error that has no server rule behind it,
such as a confirmation field the model does not validate.

## Reading form state with useFormContext

`<Form>` publishes its slot props on a React context, so a field in its own component reads
`errors`, `processing` and `validate` without the parent lifting state. The hook returns
`FormComponentRef<TForm> | undefined`, so guard the call site with `?.`.

```tsx
import { Form, useFormContext } from '@inertiajs/react'

type Fields = { name: string; email: string }

function EmailField() {
  const form = useFormContext<Fields>()

  return (
    <>
      <input name="email" onBlur={() => form?.validate('email')} />
      {form?.errors.email && <span className="error">{form.errors.email}</span>}
    </>
  )
}

export default function CreateUser() {
  return (
    <Form<Fields> method="post" action="/users" disableWhileProcessing>
      {() => (
        <>
          <input name="name" />
          <EmailField />
          <button type="submit">Create User</button>
        </>
      )}
    </Form>
  )
}
```

## Driving a form from outside with formRef

The ref carries the render function's slot props plus `getData()` and `getFormData()`. Both
buttons sit outside the `<Form>`, which is what keeps the click handler from submitting twice:

```tsx
import {useRef} from 'react'
import {Form} from '@inertiajs/react'
import type {FormComponentRef} from '@inertiajs/core'

export default function CreateUser() {
  const formRef = useRef<FormComponentRef>(null)

  return (
    <>
      <Form ref={formRef} method='post' action='/users'>
        {() => <input type='text' name='name'/>}
      </Form>
      <button onClick={() => formRef.current?.submit()}>Submit</button>
      <button onClick={() => formRef.current?.reset()}>Reset</button>
    </>
  )
}
```

## useHttp

For a request whose response is not an Inertia page. Both type arguments are supplied, so
`onSuccess`'s `response` is typed rather than `unknown`:

```tsx
import { useHttp } from '@inertiajs/react'

type NewUser = { name: string; email: string }
type CreatedUser = { token: string }

export default function ApiKeyForm() {
  const { data, setData, post, processing } =
    useHttp<NewUser, CreatedUser>({ name: '', email: '' })

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    void post('/api/users', { onSuccess: (response) => setToken(response.token) })
  }

  return (
    <form onSubmit={submit}>
      <input value={data.name} onChange={(e) => setData('name', e.target.value)} />
      <button disabled={processing}>Create</button>
    </form>
  )
}
```

## Optimistic updates

`<Form optimistic>` — the page-specific key is asserted at the use site, because the
callback's `props` is typed from the page object:

```tsx
type Todo = { id: number; name: string; done: boolean }

<Form
  action="/todos"
  method="post"
  optimistic={(props, data) => ({
    todos: [...(props.todos as Todo[]), { id: Date.now(), name: String(data.name), done: false }],
  })}
>
```

`router.optimistic` for an action with no form, with its type argument supplied:

```tsx
type Post = { id: number; likes: number }

router
  .optimistic<{ post: Post }>((props) => ({ post: { ...props.post, likes: props.post.likes + 1 } }))
  .post(`/posts/${post.id}/like`)
```

`useForm`'s `optimistic()` takes the same page-props callback and is called before the
submit. `useHttp`'s takes `(currentData: TForm) => Partial<TForm>` and revises the form's own
data instead.
