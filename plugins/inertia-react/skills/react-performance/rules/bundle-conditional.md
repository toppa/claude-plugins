---
title: Conditional Module Loading
impact: HIGH
impactDescription: loads large data only when needed
tags: bundle, conditional-loading, lazy-loading
---

## Conditional Module Loading

Load a large module or data file only when the feature that needs it is switched on. For a
component, `React.lazy` already does this — see `rules/bundle-dynamic-imports.md`. This rule
is for the case where the thing you are deferring is *not* a component: a frame table, a
locale bundle, a parser.

```tsx
function AnimationPlayer({ enabled }: { enabled: boolean }) {
  const [frames, setFrames] = useState<Frame[] | null>(null)

  useEffect(() => {
    if (!enabled || frames) return

    let cancelled = false
    void import('./animation-frames.js').then((mod) => {
      if (!cancelled) setFrames(mod.frames)
    })
    return () => {
      cancelled = true
    }
  }, [enabled, frames])

  if (enabled && !frames) return <Skeleton />
  if (!frames) return null
  return <Canvas frames={frames} />
}
```

Two things this shape gets right. The effect owns the load, so the component holds its own
state rather than calling a setter its parent passed in — a child that turns its parent's
flag off from a `.catch` makes the failure invisible and the retry impossible. And the
cleanup flag means a resolve after unmount does not set state.

**A `typeof window !== 'undefined'` guard does not affect what gets bundled.** Rollup builds
the module graph from the `import()` specifier at build time, so the chunk exists either
way; a runtime `typeof` check runs after the bundle is already built. Guards like that are
worth writing only where server code genuinely reaches the line — and inside `useEffect` or
an event handler it never does, because neither runs during `renderToString`. Leave them
out.

Where the module *does* need a real SSR guard is at import time in module scope. Move the
work into an effect instead, and the question does not arise.
