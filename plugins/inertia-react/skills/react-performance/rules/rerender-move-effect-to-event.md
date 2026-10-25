---
title: Put Interaction Logic in Event Handlers
impact: MEDIUM
impactDescription: avoids effect re-runs and duplicate side effects
tags: rerender, useEffect, events, side-effects, dependencies
---

## Put Interaction Logic in Event Handlers

If a side effect is triggered by a specific user action (submit, click, drag), run it in that event handler. Do not model the action as state + effect; it makes effects re-run on unrelated changes and can duplicate the action.

**Do it in the handler:**

```tsx
function RegisterButton() {
  const theme = use(ThemeContext)

  function handleClick() {
    router.post('/users')
    showToast('Registered', theme)
  }

  return <button onClick={handleClick}>Submit</button>
}
```

The shape to move away from is a `const [submitted, setSubmitted] = useState(false)` flag whose only
purpose is to trigger a `useEffect`. Two things go wrong with it. The effect lists everything it
reads, so an unrelated change — `theme` here — re-runs it and fires the action again. And the flag
has no way to represent "done", so it stays `true` and the next render re-triggers.

**In this stack, a form submission is not this rule's example.** `@inertiajs/react` exports `Form`,
and `inertia-rails-forms` makes `<Form>` the default in its "Which tool" section and prescribes
uncontrolled defaults in its "Edit Form (Pre-populated)" section; a locally-declared component
called `Form` that posts to a JSON endpoint teaches the opposite shape for the one case Inertia most
firmly owns. The rule itself is sound and general — it is about a button, a drag, a menu selection —
so the example above uses a button and Inertia's own `router.post`.

Reference: [Should this code move to an event handler?](https://react.dev/learn/removing-effect-dependencies#should-this-code-move-to-an-event-handler)
