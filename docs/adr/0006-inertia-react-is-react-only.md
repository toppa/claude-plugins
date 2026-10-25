# 0006 — `inertia-react` is React only, and takes 10 skills from three upstream sets

## Context

`inertia-react` draws on three upstream repositories:

- **Set A**, `inertia-rails/skills`.
- **Set B**, `cole-robertson/inertia-rails-skills`.
- `vercel-labs/agent-skills`.

Sets A and B both cover React, Vue, and Svelte, and they overlap. A rejection is a decision.
Without a record, the next person to open those repositories works out each rejection again.

## Decision

**The plugin takes 10 skills.** Six come from Set A, two from Set B, and two from
`vercel-labs/agent-skills`. `NOTICE.md` names the source of each.

**The plugin is React only.** Every Vue and Svelte code block, section, and reference file is
deleted, and not left to sit unread. That removed four reference files, 25,766 bytes in total:
`inertia-rails-forms/references/vue.md` and `svelte.md`, and
`inertia-rails-pages/references/vue.md` and `svelte.md`. It also removed the "Vue / Svelte"
section in each of those two skills. An upstream diff will therefore show changes to files
that this plugin does not carry.

**Forms come from Set A only.** The two sets give opposite advice. Set A puts `<Form>` first,
with uncontrolled inputs, and bans `react-hook-form`. Set B puts `useForm` first, with
controlled inputs everywhere.

**Eleven upstream skills were not taken:**

| Skill | Why not |
|---|---|
| `shadcn-inertia` (Set A) | The project has not chosen shadcn/ui. Revisit it if the project does. |
| `inertia-rails-setup` (Set A) | See below. One fact was taken. |
| `alba-inertia` (Set A) | It needs the `alba` and `typelizer` gems. |
| `shadcn-vue-inertia`, `shadcn-svelte-inertia` (Set A) | Wrong framework, 19,172 bytes. |
| `inertia-rails-forms` (Set B) | It gives the opposite advice to Set A. |
| `inertia-rails-setup`, `inertia-rails-testing` (Set B) | They share their names with Set A's skills, and are weaker. |
| `inertia-rails-auth` (Set B) | It teaches Devise first, and the authorization half we want already ships as a reference file. It also calls `policy(user).edit?` against a policy that defines `update?`. |
| `inertia-rails-best-practices`, `inertia-rails-cookbook` (Set B) | They restate what Set A already owns. |

**No shipped skill points at a skill we do not ship.** A pointer at a skill that the reader
cannot load reads as a promise, so it is worse than no pointer.

### What we took from `inertia-rails-setup`

One row of its troubleshooting table went into `inertia-rails-typescript`: `@/` imports do not
resolve when the aliases go into `vite.config.ts`, because `vite-plugin-ruby` already supplies
the Vite aliases, so add the `@/` paths to `tsconfig.json` only. Every Set A example imports
from `@/types` or `@/layouts/app-layout`, so the aliases must work before any example compiles.

The rest of the skill stayed behind:

- **Its stack-detection step** reads the `Gemfile` and `package.json` to work out which
  patterns apply. The `frontend` agent's body, `inertia-rails-architecture`'s opening, and the
  project's own `CONTEXT.md` already state the stack. Ten of the table's 14 rows detect Vue,
  Svelte, alba, typelizer, shadcn, or Devise, and the plugin ships no skill for any of them.
- **Its dependency recommendations** cover alba, shadcn, `js-routes`, and Pagy. Alba and
  shadcn are rejected. `js-routes` and Pagy were each decided once, in conversation.
- **Its CLAUDE.md-generation step** finds or creates a `CLAUDE.md` and replaces a block
  inside it. The maintainer writes their own `CLAUDE.md`, so a skill that offers to rewrite it
  is a hazard.

## The alternative that lost

Take every framework and filter at use. The Vue and Svelte content would sit unread in every
install, and two of the reference files carried a `MANDATORY — READ THE MATCHING FILE`
pointer, so a model could load them anyway.
