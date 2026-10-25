---
title: Measure Before Animating an SVG Wrapper Instead of the Element
impact: LOW
impactDescription: unverified at current browser versions; measure before applying
tags: rendering, svg, css, animation, performance
---

## Measure Before Animating an SVG Wrapper Instead of the Element

The claim: some browsers do not promote an animated SVG element to its own compositor layer, where
they would promote an animated `<div>`, so animating a wrapper is smoother.

**Treat this as unverified.** No primary source was found for it at current browser versions, and it
was not reproduced here. It also has a cost that is certain where the benefit is not: one extra DOM
element per icon, which on a list of icons is a real addition to the tree. So check it in the
Performance panel — look for whether the animation stays off the main thread — before applying it,
and do not apply it as a sweep.

If you do apply it, the shape is:

```tsx
function LoadingSpinner() {
  return (
    <div className="animate-spin">
      <svg 
        width="24" 
        height="24" 
        viewBox="0 0 24 24"
      >
        <circle cx="12" cy="12" r="10" stroke="currentColor" />
      </svg>
    </div>
  )
}
```

The claim, where it holds, would cover the compositable properties — `transform`, `opacity` and the
individual transform properties. Animating anything else (`width`, `top`, a `filter`) runs on the
main thread whichever element carries it, and moving it to a wrapper changes nothing; that part is
not in doubt and is the more useful rule to remember.
