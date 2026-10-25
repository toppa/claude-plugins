---
title: Cache Repeated Function Calls
impact: LOW
impactDescription: avoids recomputing a pure result for an input already seen
tags: javascript, cache, memoization, performance
---

## Cache Repeated Function Calls

Cache a pure function's result in a module-level `Map` when the same input recurs often enough to
pay for the entry, and when the key space is bounded:

```typescript
// Module-level cache
const slugifyCache = new Map<string, string>()

function cachedSlugify(text: string): string {
  if (slugifyCache.has(text)) {
    return slugifyCache.get(text)!
  }
  const result = slugify(text)
  slugifyCache.set(text, result)
  return result
}

function ProjectList({ projects }: { projects: Project[] }) {
  return (
    <div>
      {projects.map(project => {
        // One entry per unique name — but these names do not recur; see below
        const slug = cachedSlugify(project.name)
        
        return <ProjectCard key={project.id} slug={slug} />
      })}
    </div>
  )
}
```

A module-level `Map` rather than a hook, so utilities and event handlers can use it too.

**Both conditions in that first sentence are load-bearing.**

*The input has to actually recur.* In the example above it does not: `projects.map` calls
`cachedSlugify` once per project, so on a first render every call is a miss and the cache has cost
you a `Map` and two extra calls per row. It pays from the second render onwards, and only for
names it has already seen. If the list is rendered once per visit, `useMemo` on the mapped array
is the better tool; if the value is stable per row, have Rails send the slug as part of the prop.

*The key space has to be bounded.* In an Inertia app the module lives for the whole session across
every visit, so nothing evicts these entries. A cache keyed on a project name is fine — the set is
small and repeats. A cache keyed on a search string, a URL, or anything else the user types grows
for as long as the tab is open. Either key it on a bounded set or give it an explicit cap.

**Do not cache authentication state this way.** A module-level `isLoggedIn` flag invalidated by a
hand-called `onAuthChange()` is a correctness hazard dressed as a simplification: every future
code path that changes auth state has to remember to call it, and the one that forgets produces a
UI that believes the user is still signed in. In this stack auth state is not a client-side
computation at all — it arrives from Rails as a shared prop on every visit, so
`usePage().props.auth` is already the cache, and Inertia invalidates it for you. See
`inertia-rails-typescript`, its "InertiaConfig Module Augmentation" section, for typing it.

Reference: [How we made the Vercel Dashboard twice as fast](https://vercel.com/blog/how-we-made-the-vercel-dashboard-twice-as-fast)
