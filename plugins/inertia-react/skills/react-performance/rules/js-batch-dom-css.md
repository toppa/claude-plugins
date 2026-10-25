---
title: Avoid Layout Thrashing
impact: HIGH
impactDescription: one forced layout instead of one per read/write pair
tags: javascript, dom, css, performance, reflow, layout-thrashing
---

## Avoid Layout Thrashing

Batch the style writes, then take the layout reads. Interleaved, they force a synchronous reflow: a layout property read (like `offsetWidth`, `getBoundingClientRect()`, or `getComputedStyle()`) between two style changes makes the browser recalculate before it answers.

**This is OK (browser batches style changes):**
```typescript
function updateElementStyles(element: HTMLElement) {
  // Each line invalidates style, but browser batches the recalculation
  element.style.width = '100px'
  element.style.height = '200px'
  element.style.backgroundColor = 'blue'
  element.style.border = '1px solid black'
}
```

**Incorrect (interleaved reads and writes force reflows):**
```typescript
function layoutThrashing(element: HTMLElement) {
  element.style.width = '100px'
  const width = element.offsetWidth  // Forces reflow
  element.style.height = '200px'
  const height = element.offsetHeight  // Forces another reflow
}
```

The rule is that reads and writes do not interleave. Either order satisfies it, so pick by which values you need.

**Correct — writes first, when you want the measurement that reflects them:**
```typescript
function updateElementStyles(element: HTMLElement) {
  // Batch all writes together
  element.style.width = '100px'
  element.style.height = '200px'
  element.style.backgroundColor = 'blue'
  element.style.border = '1px solid black'
  
  // Read after all writes are done (single reflow)
  const { width, height } = element.getBoundingClientRect()
}
```

**Correct — reads first, when you need the values from before the writes:**
```typescript
function avoidThrashing(element: HTMLElement) {
  // Read phase - all layout queries first
  const rect1 = element.getBoundingClientRect()
  const offsetWidth = element.offsetWidth
  const offsetHeight = element.offsetHeight
  
  // Write phase - all style changes after
  element.style.width = '100px'
  element.style.height = '200px'
}
```

**Better: use CSS classes**
```css
.highlighted-box {
  width: 100px;
  height: 200px;
  background-color: blue;
  border: 1px solid black;
}
```
```typescript
function updateElementStyles(element: HTMLElement) {
  element.classList.add('highlighted-box')
  
  const { width, height } = element.getBoundingClientRect()
}
```

**React example:**
```tsx
// Incorrect: interleaving style changes with layout queries
function Box({ isHighlighted }: { isHighlighted: boolean }) {
  const ref = useRef<HTMLDivElement>(null)
  
  useEffect(() => {
    if (ref.current && isHighlighted) {
      ref.current.style.width = '100px'
      const width = ref.current.offsetWidth // Forces layout
      ref.current.style.height = '200px'
    }
  }, [isHighlighted])
  
  return <div ref={ref}>Content</div>
}

// Correct: toggle class
function Box({ isHighlighted }: { isHighlighted: boolean }) {
  return (
    <div className={isHighlighted ? 'highlighted-box' : ''}>
      Content
    </div>
  )
}
```

Prefer CSS classes over inline styles when the value is one of a fixed set of states. CSS files are cached by the browser, and classes provide better separation of concerns and are easier to maintain.

A value that changes continuously — a pointer position, a scroll offset — cannot be a class. Write it to the node from a ref, as `rules/rerender-use-ref-transient-values.md` does, and keep the layout read out of the same handler. Turning that shape into a `className` toggle forces the value back into React state and restores a render per event.

**Why this is ranked HIGH while most of the `js-` rules are not.** The cost here is not a constant
factor: a style write invalidates layout, and a layout read forces the browser to recompute it
before it can answer. Interleaved in a loop over *n* elements, that is *n* forced synchronous
layouts instead of one — the work grows with the number of elements you touch. That is why this one
rule can dominate a frame while the micro-optimisations elsewhere in this category cannot, and why
it is worth restructuring code for. No multiplier is quoted here because the size depends entirely
on how much layout your page has; measure it in the Performance panel, where forced reflows are
labelled as such.

See [this gist](https://gist.github.com/paulirish/5d52fb081b3570c81e3a) and [CSS Triggers](https://csstriggers.com/) for more information on layout-forcing operations.
