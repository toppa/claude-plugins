# File Uploads

File upload handling for Inertia.js + Rails with Active Storage.

## Table of Contents

- [Basic Upload with Form Component](#basic-upload-with-form-component)
- [Upload with useForm](#upload-with-useform)
- [Progress Tracking](#progress-tracking)
- [Active Storage Backend](#active-storage-backend)
- [Multiple Files](#multiple-files)
- [Image Preview](#image-preview)
- [Direct Uploads](#direct-uploads)

---

## Basic Upload with Form Component

Inertia auto-detects file inputs and switches to `multipart/form-data`.

```tsx
<Form method="post" action="/avatars" disableWhileProcessing>
  {({ progress }) => (
    <>
      <input type="file" name="avatar" accept="image/*" />
      {progress && (
        <progress value={progress.percentage ?? 0} max="100">
          {progress.percentage ?? 0}%
        </progress>
      )}
      <button type="submit">Upload</button>
    </>
  )}
</Form>
```

Inertia builds the `FormData` and sets the headers.

The input's `name` is what the controller reads, so `name="avatar"` arrives as
`params[:avatar]` and `name="user[avatar]"` arrives inside `params[:user]`. Pick one and keep
the form and the controller on the same shape — both appear below, in that order.

## Upload with useForm

```tsx
const form = useForm<{ avatar: File | null }>({
  avatar: null,
})

const handleSubmit = (e: React.FormEvent) => {
  e.preventDefault()
  form.post('/avatars', {
    forceFormData: true, // ensure FormData even if no file selected
  })
}

return (
  <form onSubmit={handleSubmit}>
    <input
      type="file"
      onChange={e => form.setData('avatar', e.target.files?.[0] ?? null)}
    />
    {form.progress && (
      <progress value={form.progress.percentage ?? 0} max="100" />
    )}
    <button disabled={form.processing}>Upload</button>
  </form>
)
```

## Progress Tracking

Both `<Form>` and `useForm` provide upload progress automatically.

```tsx
// Form component
<Form method="post" action="/documents" onProgress={(progress) => {
  console.log(`${progress?.percentage ?? 0}% uploaded`)
}}>
  {({ progress }) => (
    progress && <ProgressBar value={progress.percentage ?? 0} />
  )}
</Form>
```

The `progress` object is `@inertiajs/core`'s `Progress`, an alias for `HttpProgressEvent`.
**Only `loaded` is always a number:**
```typescript
{
  progress?: number   // 0-1, undefined when the total length is unknown
  percentage?: number // 0-100, undefined when the total length is unknown
  loaded: number      // bytes uploaded
  total?: number      // total bytes, undefined when the server sends no length
}
```

So read `progress.percentage ?? 0`. The bare `progress.percentage` type-checks in a JSX
attribute that accepts `undefined` and fails the moment the value flows anywhere that wants a
`number` — `const pct: number = progress.percentage` is
`TS2322: Type 'number | undefined' is not assignable to type 'number'`.

`onProgress`'s own argument is `Progress | undefined` (the callback is
`GlobalEventCallback<'progress'>`, whose parameter tuple is `[Progress | undefined]`), so it
needs `progress?.` as well.

## Active Storage Backend

A standalone upload, matching the `name="avatar"` form above:

```ruby
# app/controllers/avatars_controller.rb
class AvatarsController < ApplicationController
  def create
    current_user.avatar.attach(params.expect(:avatar))
    redirect_to profile_path, notice: "Avatar uploaded!"
  end
end

# app/models/user.rb
class User < ApplicationRecord
  has_one_attached :avatar
end
```

When the file submits alongside other fields, the input is `name="user[avatar]"` and the file
is permitted like any other attribute — an uploaded file is a permitted scalar
(`ActionDispatch::Http::UploadedFile` is in strong parameters' `PERMITTED_SCALAR_TYPES`), so
it needs no special declaration:

```ruby
def user_params
  params.expect(user: [ :name, :email, :avatar ])
end
```

## Multiple Files

```tsx
<Form method="post" action="/documents">
  {({ progress }) => (
    <>
      <input type="file" name="documents[]" multiple />
      {progress && <progress value={progress.percentage ?? 0} max="100" />}
      <button type="submit">Upload All</button>
    </>
  )}
</Form>
```

Rails side — `documents[]` arrives as an array of `UploadedFile`, and `attach` takes the
whole array:

```ruby
def create
  documents = params.expect(documents: [])
  current_user.documents.attach(documents)
  redirect_to documents_path, notice: "#{documents.size} files uploaded"
end
```

## Image Preview

`useState` for preview is local UI state — still use `<Form>`, not `useForm`:

```tsx
function AvatarUpload() {
  const [preview, setPreview] = useState<string | null>(null)

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      setPreview(URL.createObjectURL(file))
    }
  }

  return (
    <Form method="post" action="/avatars">
      {({ progress, processing }) => (
        <>
          {preview && <img src={preview} alt="Preview" className="w-24 h-24 rounded-full" />}
          <input type="file" name="avatar" accept="image/*" onChange={handleFileChange} />
          {progress && <progress value={progress.percentage ?? 0} max="100" />}
          <button type="submit" disabled={processing}>Upload</button>
        </>
      )}
    </Form>
  )
}
```

## Direct Uploads

For large files, use Active Storage direct uploads to upload directly
to the storage service (S3, GCS) instead of through the Rails server.

**`DirectUpload` comes from the `@rails/activestorage` npm package, which a Vite + Inertia
Rails app does not install** — `vite_rails` replaces the Sprockets asset pipeline that used to
supply it, and it is not a dependency of `@inertiajs/react`. Check `package.json` for
`@rails/activestorage` before writing this code, and if it is absent, report that the package
has to be added rather than adding it.

```tsx
import { DirectUpload } from '@rails/activestorage'

function uploadFile(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const upload = new DirectUpload(file, '/rails/active_storage/direct_uploads')
    upload.create((error, blob) => {
      if (error) reject(error)
      else resolve(blob.signed_id)
    })
  })
}
```

Then submit the signed ID via Inertia form:
```tsx
const form = useForm({ avatar: '' })

const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
  const file = e.target.files?.[0]
  if (file) {
    const signedId = await uploadFile(file)
    form.setData('avatar', signedId)
  }
}
```
