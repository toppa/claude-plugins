---
title: Use defer or async on Script Tags
impact: HIGH
impactDescription: eliminates render-blocking
tags: rendering, script, defer, async, performance
---

## Use defer or async on Script Tags

**Impact: HIGH (eliminates render-blocking)**

Script tags without `defer` or `async` block HTML parsing while the script downloads and executes. This delays First Contentful Paint and Time to Interactive.

- **`defer`**: Downloads in parallel, executes after HTML parsing completes, maintains execution order
- **`async`**: Downloads in parallel, executes immediately when ready, no guaranteed order

Use `defer` for scripts that depend on DOM or other scripts. Use `async` for independent scripts like analytics.

In this stack the `<head>` lives in the Rails layout, not in React. Fix the tag there.

**Write the attribute, and let Rails write the URL:**

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%# Third party, independent of the DOM — async, and the URL is genuinely a literal %>
  <script src="https://example.com/analytics.js" async></script>

  <%# Own asset, DOM-dependent — defer, and let propshaft supply the digested path %>
  <%= javascript_include_tag "utils", defer: true %>
</head>
```

A hand-written `<script src="/scripts/utils.js">` is a second defect on the same line as the missing
attribute: it bypasses `javascript_include_tag`, so the asset is served without propshaft's digest
and is therefore uncacheable and unversioned. Where the `Gemfile` has both `propshaft` and
`vite_rails`, both pipelines are live. This rule was checked with `propshaft ~> 1.3` and
`vite_rails ~> 3.11`. Use `javascript_include_tag` for anything under `app/assets`, and the
`vite_*` helpers for anything Vite builds. Write a literal path only for a genuinely external
URL.

**Note:** `vite_javascript_tag` emits `type="module"`, and a module script defers by
default. The application bundle already follows this rule. Only hand-written tags need
the attribute.

Reference: [MDN - Script element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script#defer)
