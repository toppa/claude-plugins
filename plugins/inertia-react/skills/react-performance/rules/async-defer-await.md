---
title: Defer Await Until Needed
impact: HIGH
impactDescription: avoids blocking unused code paths
tags: async, await, conditional, optimization
---

## Defer Await Until Needed

Move `await` operations into the branches where they're actually used to avoid blocking code paths that don't need them.

**Incorrect (blocks both branches):**

```typescript
async function handleRequest(userId: string, skipProcessing: boolean) {
  const userData = await fetchUserData(userId)
  
  if (skipProcessing) {
    // Returns immediately but still waited for userData
    return { skipped: true }
  }
  
  // Only this branch uses userData
  return processUserData(userData)
}
```

**Correct (only blocks when needed):**

```typescript
async function handleRequest(userId: string, skipProcessing: boolean) {
  if (skipProcessing) {
    // Returns immediately without waiting
    return { skipped: true }
  }
  
  // Fetch only when needed
  const userData = await fetchUserData(userId)
  return processUserData(userData)
}
```

This optimization is especially valuable when the skipped branch is frequently taken, or when the
deferred operation is expensive.

**Do not extend it to two calls that are both usually needed — that reintroduces the waterfall.**
Consider a guard on one value and a check on the other:

```typescript
async function updateResource(resourceId: string, userId: string) {
  const resource = await getResource(resourceId)
  if (!resource) return { error: 'Not found' }

  const permissions = await fetchPermissions(userId)
  if (!permissions.canEdit) return { error: 'Forbidden' }

  return updateResourceData(resource, permissions)
}
```

That serialises two independent requests. It wins only on the rare path where `resource` is
missing; on the common path where both are needed it costs the sum of the two latencies, where
`Promise.all` would cost the larger of the two — so it is *slower* than the version that starts both
at once. `rules/async-parallel.md` prescribes the parallel form, and between the two rules the
parallel one governs whenever both values are usually needed.

**The reconciliation is to start both and await them where each is used:**

```typescript
async function updateResource(resourceId: string, userId: string) {
  const resourcePromise = getResource(resourceId)
  const permissionsPromise = fetchPermissions(userId)

  const resource = await resourcePromise
  if (!resource) {
    void permissionsPromise.catch(() => {})   // started; nobody is waiting on it
    return { error: 'Not found' }
  }

  const permissions = await permissionsPromise
  if (!permissions.canEdit) return { error: 'Forbidden' }

  return updateResourceData(resource, permissions)
}
```

Both requests are in flight immediately, and the early return still returns early. The `void …catch`
matters: an abandoned rejected promise is an unhandled rejection.

So the boundary between this rule and `async-parallel` is *whether the second call is usually
needed*. Defer the `await` when the guard usually short-circuits; start both when it usually does
not.

For `await getFlag()` combined with a cheap synchronous guard (`flag && someCondition`), see [Check Cheap Conditions Before Async Flags](./async-cheap-condition-before-await.md).
