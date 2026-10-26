# inertia-react

`inertia-react` gives Claude guidance for a Rails 8.1 application that renders its pages with
Inertia and React. Inertia is the layer that sends the props of a Rails controller action to a
React page component. The plugin covers controllers that render Inertia pages, page components
and layouts, forms, and navigation and prefetching. It also covers TypeScript types, request
specs, server-side rendering, and React performance and component design. It is for a
developer who uses Claude Code in a Rails project with an Inertia and React front end.

The plugin works with the `rails-core` plugin. Several skills point at `rails-core` skills for
the Ruby side, and the `frontend` agent leaves Ruby to the `rails` agent in `rails-core`.

The plugin does not cover these subjects:

- **Vue and Svelte.** The plugin is React only. ADR [0006](../../docs/adr/) records this
  decision.
- **The first install of Inertia in an application.** No skill is about it.
- **Tests of React components.** The `inertia-rails-testing` skill covers request specs on the
  Rails side only.

## Model-invoked

- **[inertia-rails-architecture](skills/inertia-rails-architecture/SKILL.md)**: Where a piece of data or state belongs, when you start Inertia work.
- **[inertia-rails-controllers](skills/inertia-rails-controllers/SKILL.md)**: A controller action that renders an Inertia page: its props, shared data, flash, and redirects.
- **[inertia-rails-forms](skills/inertia-rails-forms/SKILL.md)**: A form, a delete button, a multi-step wizard, or a file upload in an Inertia page.
- **[inertia-rails-pages](skills/inertia-rails-pages/SKILL.md)**: A page component, a persistent layout, navigation, and prefetching.
- **[inertia-rails-performance](skills/inertia-rails-performance/SKILL.md)**: A large prop payload, a list that shows stale data after a write, and a bundle split across pages.
- **[inertia-rails-ssr](skills/inertia-rails-ssr/SKILL.md)**: Meta tags for search engines and link previews, and server-side rendering.
- **[inertia-rails-testing](skills/inertia-rails-testing/SKILL.md)**: A request spec for an action that renders an Inertia page.
- **[inertia-rails-typescript](skills/inertia-rails-typescript/SKILL.md)**: Types for shared props, flash, errors, and page props, and fixes for TypeScript errors in an Inertia component.
- **[react-composition](skills/react-composition/SKILL.md)**: A component that collects boolean props or modes, or props that pass through components that do not use them.
- **[react-performance](skills/react-performance/SKILL.md)**: A component that renders too often, imports that grow the bundle, and slow scrolling or typing.

## Agents

### The `frontend` agent

The `inertia-react:frontend` agent does Inertia and React work in a Rails 8 application, and it
starts with these skills in its context:

- `inertia-rails-architecture`
- `inertia-rails-controllers`
- `inertia-rails-forms`
- `inertia-rails-pages`
- `inertia-rails-typescript`

## Installation

```bash
/plugin marketplace add toppa/claude-plugins
/plugin install inertia-react
```

Written for Rails 8.1 applications with `inertia_rails` 3 and React 19. The `metadata:` block of
each skill names the exact versions that its facts were checked against.
