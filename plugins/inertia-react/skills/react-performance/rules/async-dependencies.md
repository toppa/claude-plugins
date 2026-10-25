---
title: Dependency-Based Parallelization
impact: CRITICAL
impactDescription: 2-10× improvement
tags: async, parallelization, dependencies
---

## Dependency-Based Parallelization

For operations with partial dependencies, create every promise first and await them
together. Each task then starts at the earliest moment its own input allows.

**Incorrect (profile waits for config unnecessarily):**

```typescript
const [user, config] = await Promise.all([
  fetchUser(),
  fetchConfig()
])
const profile = await fetchProfile(user.id)
```

**Correct (config and profile run in parallel):**

```typescript
const userPromise = fetchUser()
const profilePromise = userPromise.then(user => fetchProfile(user.id))

const [user, config, profile] = await Promise.all([
  userPromise,
  fetchConfig(),
  profilePromise
])
```

The `better-all` package expresses the same graph declaratively. It earns a dependency
only when the chain gets deep enough that the `.then` form stops reading clearly.

Reference: [https://github.com/shuding/better-all](https://github.com/shuding/better-all)
