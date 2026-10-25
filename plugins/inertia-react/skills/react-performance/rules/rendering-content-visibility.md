---
title: CSS content-visibility for Long Lists
impact: HIGH
impactDescription: faster initial render
tags: rendering, css, content-visibility, long-lists
---

## CSS content-visibility for Long Lists

Apply `content-visibility: auto` to defer off-screen rendering.

**CSS:**

```css
.message-item {
  content-visibility: auto;
  contain-intrinsic-size: 0 80px;
}
```

**Example:**

```tsx
function MessageList({ messages }: { messages: Message[] }) {
  return (
    <div className="overflow-y-auto h-screen">
      {messages.map(msg => (
        <div key={msg.id} className="message-item">
          <Avatar user={msg.author} />
          <div>{msg.content}</div>
        </div>
      ))}
    </div>
  )
}
```

The browser skips layout, style and paint for the items that are off screen, so a list of a
thousand rows does that work for the handful on screen instead of all thousand. The size of the
win depends on how expensive one row is; measure it in the Performance panel rather than
assuming a multiple (house heuristic, no external source — the number this rule used to quote
had none).

**`contain-intrinsic-size` is not optional.** Without it a skipped element has zero height, so
the scrollbar is wrong and the scroll position jumps as rows are rendered. Give it your best
estimate of a row's height.

**`content-visibility: auto` turns on layout, style and paint containment, and that containment
applies even when the element is not being skipped.** Consequences to check before applying it
to an existing list: a descendant can no longer affect the size of anything outside the
container, `position: fixed` and `position: absolute` inside it resolve against the container
rather than the viewport, and margins do not collapse through it. It also makes the subtree
unsearchable by the browser's find-in-page while skipped. This is a layout change, not only a
performance flag.

**It is not a substitute for `WhenVisible` or `InfiniteScroll`, and it does not compete with
them.** Those two belong to `inertia-rails-pages`, in its "`<WhenVisible>` Component" and
"`<InfiniteScroll>` Component" sections, and they defer *fetching* the data from Rails; this
defers *rendering* rows you already have. A long list that is already in props is this rule's
case.
