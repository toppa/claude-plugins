# Authorization as Props

Pass permissions as props — the frontend decides what to **show**, the server decides what
to **allow**. Both are required: the `can` prop drives the UI, and `update`/`destroy`
authorize independently.

## Controller Pattern

The `can` shape is the subject here and it is gem-independent. Read the `Gemfile` first,
then write the checks with whatever the project already has.

```ruby
def show
  @user = User.find(params.expect(:id))
  render inertia: {
    user: serialize_user(@user),
    can: { edit: allowed_to_edit?(@user), delete: allowed_to_delete?(@user) },
  }
end
```

| In the `Gemfile` | The call to substitute |
|---|---|
| `action_policy` | `allowed_to?(:edit?, @user)` |
| `pundit` | `policy(@user).edit?` |
| `cancancan` | `can?(:edit, @user)` |
| none of them | a model predicate or a plain comparison, e.g. `@user == Current.user` |

`params.expect(:id)` is the Rails 8.1 scaffold's form for a required scalar from the path
(`railties-8.1.3.1` `scaffold_controller/templates/controller.rb.tt:52`).

## Frontend Pattern

```tsx
export default function Show({ user, can }: Props) {
  return (
    <>
      <h1>{user.name}</h1>
      {can.edit && <Link href={`/users/${user.id}/edit`}>Edit</Link>}
      {can.delete && <DeleteButton userId={user.id} />}
    </>
  )
}
```

## Key Rules

- **Enforce server-side as well** — `can` props control visibility, not access.
- **Per-record, not global** — a user may edit their own profile but not someone else's, so
  pass `can` per resource rather than a blanket `isAdmin` flag.
- **Send booleans, not policy objects**, so the component never learns which authorization
  library produced them.
