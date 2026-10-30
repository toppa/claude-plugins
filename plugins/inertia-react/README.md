# inertia-react

## Overview

This plugin gives Claude expertise in Inertia and React for Ruby on Rails. It includes an agent, and skills covering controllers that render Inertia
pages, page components and layouts, forms, navigation, and prefetching. It also covers
TypeScript types, request specs, server-side rendering, and React performance and component
design.

The plugin works in conjunction with the `rails-core` plugin. Several skills point at
`rails-core` skills for the Ruby side.

The plugin does not cover these subjects:

- **Vue and Svelte.** The plugin is React only.
- **Setting up Inertia in a Rails application.**
- **Tests of React components.** The `inertia-rails-testing` skill covers request specs on the
  Rails side only.

## Notes

- 🎯 The plugin targets Rails 8.1 with `inertia_rails` 3 and React 19.
- 👯 The skills in this plugin all started in public skill packs, and I edited them for correctness
  and agent readability. [`NOTICE.md`](NOTICE.md) names the sources.
- 🤖 I write and maintain my skills using
  [Matt Pocock's writing-for-agents skill](https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents)
  so they are optimized for agent understanding.
- ✍️ I write and maintain this README by hand, so it's optimized for human understanding.

## Model-invoked skills

- **[inertia-rails-architecture](skills/inertia-rails-architecture/SKILL.md)**: the
  architecture for where data and state belong.
- **[inertia-rails-controllers](skills/inertia-rails-controllers/SKILL.md)**: controller
  actions that render Inertia pages: props, shared data, flash, redirects, etc.
- **[inertia-rails-forms](skills/inertia-rails-forms/SKILL.md)**: forms, buttons, multi-step
  wizards, file uploads, etc.
- **[inertia-rails-pages](skills/inertia-rails-pages/SKILL.md)**: page components, persistent
  layouts, navigation, prefetching, etc.
- **[inertia-rails-performance](skills/inertia-rails-performance/SKILL.md)**: solutions for
  large prop payloads, lists that show stale data after a write, bundles split across pages,
  etc.
- **[inertia-rails-ssr](skills/inertia-rails-ssr/SKILL.md)**: meta tags for search engines and
  link previews, server-side rendering, etc.
- **[inertia-rails-testing](skills/inertia-rails-testing/SKILL.md)**: request specs for
  actions that render Inertia pages.
- **[inertia-rails-typescript](skills/inertia-rails-typescript/SKILL.md)**: types for shared
  props, flash, errors, page props, and fixing TypeScript errors in Inertia components.
- **[react-composition](skills/react-composition/SKILL.md)**: solutions for components that
  collect boolean props or modes, props that pass through components that do not use them,
  etc.
- **[react-performance](skills/react-performance/SKILL.md)**: components that render too
  often, imports that grow the bundle, slow scrolling or typing, etc.

## The `frontend` agent

The `inertia-react:frontend` agent starts with these skills in its context, and reaches for
the others only when needed:

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
