# Divergences from upstream — inertia-react

This file lists where each derived skill in `inertia-react` differs from its upstream on
purpose, and why. Read a skill's section before you act on an upstream diff;
`docs/upstream-sync.md` holds the procedure. When an edit adds or removes a divergence, revise
the entry in place. This file is not a log.

## `inertia-rails-architecture`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-architecture/SKILL.md`.

- **Changed: the frontmatter.** Upstream put four rules in capitals into `description`. The
  body states all four, so `description` says what the skill is, and `when_to_use` says when
  to load it.
- **Changed: `when_to_use` names page components under `app/frontend/pages`.** In a Rails
  app, "a feature" and "a CRUD flow" also match a model, a migration, a query, or a job. Do
  not widen the trigger back to those words, because the skill then fires on Rails-only work.
- **Changed: the Skill Map.** We cut the `shadcn-inertia` and `alba-inertia` rows, because
  the plugin does not ship those skills ([0006](../adr/)). The map gives each skill its scoped
  name, and it says which four skills the `frontend` agent already holds.
- **Changed: `references/AGENTS.md` is `references/rules-expanded.md`.** Several tools read
  a file named `AGENTS.md` as agent instructions, and this file holds rules with examples. Do
  not restore the upstream name on a re-sync.
- **Changed: the `MANDATORY — READ ENTIRE FILE` trigger on `rules-expanded.md` is a
  read-on-demand pointer.** The body already holds the eleven rules that the file expands, and
  the `frontend` agent preloads the body. A mandatory read restates text that is in context.
- **Changed: the rules and the decision matrix lead with the correct form.** Upstream gave
  each matrix row a "NOT This" cell, and `AGENTS.md` opened sections with a full incorrect
  implementation. Three contrasts stay as prose, because two Inertia mechanisms compete in
  each: `flash` against a shared prop, where `flash` lives, and `inertia_share` against React
  Context.
- **Changed: the `axios` ban is a statement of what Inertia's client does.** `<Form>`,
  `useForm`, `router`, and `useHttp` attach the CSRF token, follow the redirect, and map a 422
  into `errors`. Inertia 3 keeps axios as an opt-in adapter, so a flat ban is false.
- **Changed: five examples where upstream holds a defect we reproduced.** Do not take
  upstream's side on these lines in a merge, because each one brings the defect back.
  1. `router.post` with the payload in the options slot. It compiles, and it posts
     `{ data: …, only: […] }` as the request body.
  2. `usePoll` with `keepAlive` in the second argument. `keepAlive` is a `PollOptions` key,
     and it goes in the third argument.
  3. Rule 2 with Devise's `before_action :authenticate_user!`. The generated Rails 8.1 concern
     makes `require_authentication` global, so the example uses
     `allow_unauthenticated_access`.
  4. Rule 9, which sets `page.default.layout` in a `resolve` callback. The generated entry
     point has no `resolve` callback, so the example uses the `layout` option.
  5. `inertia_share` on `ApplicationController`. It sits on `InertiaController`, so a
     non-Inertia response does not compute shared data.
- **Cut: "third-party webhook" as a source of component data, in `decision-trees.md`.** A
  webhook is an inbound request to the app, and no component reads one.
- **Changed: the four latency thresholds in `decision-trees.md` are a house heuristic.** They
  have no external source, so the file labels them and tells the reader to measure.
- **Added: Inertia 3 content.** `SKILL.md` states the stack and the React 19 floor.
  `references/decision-trees.md` gives `router.optimistic` in place of upstream's `useState`
  and `onError` rollback, and the matrix gains a `useHttp` row. When upstream adopts version
  3, replace our passage with upstream's. Do not keep both, because two copies of one fact
  drift apart.

## `inertia-rails-controllers`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-controllers/SKILL.md`.

- **Changed: the frontmatter.** Upstream put rules in capitals into `description`. The fields
  now describe the skill, and `when_to_use` gives the layer question to
  `rails-core:rails-architecture`.
- **Cut: the `shadcn-inertia` and `alba-inertia` rows in Related Skills** ([0006](../adr/)).
  Upstream's "Authorization as Props" section also pointed at this skill from inside it. It
  now points at `references/authorization.md`.
- **Cut: the `NEVER` block at the top.** It spelled out three wrong method names, and the
  body enters context on every `frontend` spawn. Affirmative rules replace it.
- **Cut: the `csrf: InertiaRails.always { form_authenticity_token }` prop.** The gem sets
  the CSRF cookie and the middleware copies the header back, so the prop is not necessary. As
  an `always` prop it also went into every partial reload, the encrypted history state, and
  the SSR payload. Do not restore it as a harmless example.
- **Cut: the prop that reads `Rails.application.config.version`, and any use of
  `config.asset_version`.** Neither is a Rails configuration attribute, so each raises
  `NoMethodError` at request time.
- **Changed: `config.encrypt_history = true` in every environment.** Upstream gated it on
  `Rails.env.production?` because of an HMR problem that the docs, the gem, and its CHANGELOG
  do not mention. Under that gate, `clear_history` protects nothing in development.
- **Changed: what `merge: true` composes with.** Upstream says it works on `defer`,
  `optional`, and `always`. It works on `defer`. On `optional` or `once` it does nothing and
  raises nothing, and `always(merge: true)` raises `ArgumentError`.
- **Changed: `InertiaRails.scroll` takes the pagination metadata.** Upstream's bare
  `InertiaRails.scroll { … }` raises `MissingMetadataAdapterError` on the first page load.
- **Changed: an action that loads no data writes `render inertia: true`.** Upstream's
  `def index; end` renders a page only under `config.default_render = true`, and the install
  generator does not set it.
- **Changed: a validation failure passes the bare `@user.errors` and redirects to the form's
  own page.** With `to_hash(true)`, the Precognition path and the submit path show different
  strings for one failure. `redirect_back_or_to` reads the referer, so the errors can arrive
  on a page that does not show them.
- **Changed: instance variables become props only under `use_inertia_instance_props`.**
  Upstream tied this to the `alba-inertia` gem, which is not the mechanism.
- **Changed: `references/authorization.md` checks the `Gemfile` first** and gives one row for
  each authorization gem ([0009](../adr/)). Upstream defaulted to Action Policy, and
  `allowed_to?` raises `NoMethodError` in a project with no authorization gem.
- **Changed: smaller corrections.** Logout calls `terminate_session`, the Rails 8.1
  generator's API, not Devise's `sign_out`. Pagy's redesign boundary is 43.0.0, not 42.
  `ssr_url` set to `http://localhost:13714` configures nothing, so that section points at
  `inertia-rails-ssr`.
- **Cut: the `js-routes` `TS2305` troubleshooting row.** It is in `inertia-rails-typescript`,
  where a reader looks up a `.tsx` import error. Do not restore it here on a re-sync.
- **Added: the "Shared Data (`inertia_share`)" section in `SKILL.md`.** Upstream pointed at
  `references/configuration.md`, and that file does not hold the topic.
- **Added: `references/redirects-and-errors.md`, and the middleware section in
  `references/configuration.md`.** The new file has no upstream counterpart. The middleware
  section is the target of upstream's dead `#middleware` anchor.
- **Added: one clause that names a Hotwire controller's opposite redirect habit**, with a
  pointer at `rails-core:rails-8-idioms` ([0004](../adr/)). This is a deliberate double
  statement. Do not cut it as a duplicate.
- **Added: Inertia 3 content.** `SKILL.md` adds `flash.inertia` and the three version 3
  initializer flags. `references/configuration.md` corrects the `always_include_errors_hash`
  note and adds two flags. When upstream adopts version 3, replace our passage with
  upstream's. Do not keep both, because two copies of one fact drift apart.

## `inertia-rails-forms`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-forms/SKILL.md`.

- **Changed: the frontmatter**, split into `description` and `when_to_use`.
- **Cut: the "Vue / Svelte" section, `references/vue.md`, and `references/svelte.md`**
  ([0006](../adr/)). An upstream diff to those files needs no action.
- **Cut: the `shadcn-inertia` row in Related Skills** ([0006](../adr/)).
- **Cut: the `NEVER` block.** One statement of the choice between `<Form>` and `useForm`
  replaces it, and it names which input model each one takes.
- **Changed: the reason that `<Form>` takes `defaultValue` and `defaultChecked`.** Upstream
  blamed `isDirty`, but `isDirty` reads `FormData` and cannot tell `value` from
  `defaultValue`. The real cause is that `reset()` and `defaults()` write to the DOM, and React
  undoes that write when the value is bound to React state.
- **Changed: the checkbox rule.** Each checkbox pairs with a hidden field of the same `name`
  and `value="0"`. An unchecked checkbox is absent from `FormData`, so without the pair the
  attribute never returns to `false`. Upstream's casting reason for `value="1"` is false.
- **Cut: the `_method` troubleshooting row.** Rack parses a multipart body for any request
  method, and `@inertiajs/core` 3.6.1 never sends `_method`. The double-submit row now names
  the real cause, a submit button whose `onClick` also calls `submit()`.
- **Changed: argument positions are stated for each helper.** `form.post(url, options)` and
  `router.post(url, data, options)` differ, so a line copied between them posts its options
  as the payload.
- **Changed: typed examples.** `useHttp` takes both type arguments, `<Form optimistic>` and
  `router.optimistic` type the key they touch, `only` sits in `options`, and every progress
  field except `loaded` is guarded.
- **Added: a "Form Component Props" section in `references/advanced-forms.md`, and
  `useFormContext` in `SKILL.md`.** The upstream pointer promised seven topics, and the file
  held two.
- **Changed: two Rails corrections in `references/advanced-forms.md`.** The nested-attributes
  example adds `accepts_nested_attributes_for`, without which `assign_attributes` raises.
  Strong parameters use `params.expect`, not `params.require(...).permit`.
- **Changed: the Precognition example passes the bare `errors` object and redirects to
  `new_user_path`.** This agrees with `inertia-rails-controllers`, which owns the rule.
- **Added: the Direct Uploads block in `references/file-uploads.md` tells the reader to check
  for `@rails/activestorage`.** A compile failure on that import is the gap the block names,
  not a defect in the code.
- **Added: Inertia 3 content and two coverage gaps.** `SKILL.md` adds `useHttp`,
  `.optimistic()`, and `useForm` timing, and `useHttp` replaces upstream's "raw `fetch` for
  large datasets". `references/advanced-forms.md` adds both halves of Precognition, in place
  of the hand-written `setError` code. When upstream adopts version 3 or covers Precognition,
  replace our passage with upstream's. Do not keep both, because two copies of one fact drift
  apart.

## `inertia-rails-pages`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-pages/SKILL.md`.

- **Changed: the frontmatter.** `description` claims prefetching in full. `when_to_use` cedes
  cross-page cache invalidation to `inertia-rails-performance`, and it carries the
  accessibility words that route to `rails-core:accessibility-review`.
- **Cut: the "Vue / Svelte" section, `references/vue.md`, `references/svelte.md`, and three
  inline framework asides** ([0006](../adr/)).
- **Cut: the two `shadcn-inertia` rows in Related Skills** ([0006](../adr/)). The pagination
  row points at `inertia-rails-performance`.
- **Cut: the five `NEVER` bullets and the two `BAD` blocks.** The troubleshooting table holds
  their diagnostic value. One bullet named `useSearchParams`, a React Router API absent from
  this stack, only to forbid it.
- **Added: `<InfiniteScroll>`'s `data` takes the prop name as a string.**
  `cole-robertson/inertia-rails-skills` passed the array, and the live guide agrees with us.
- **Changed: layouts lead with the `layout` option on `createInertiaApp`.** Upstream's
  `Page.layout = null` does not opt a page out of a default layout. The adapter falls through
  to the default on `null`.
- **Changed: a bare arrow-function layout takes the array form, `Page.layout = [Layout]`.**
  Inertia reads an arrow function as a render function, so the page body disappears with no
  error.
- **Changed: `<Deferred>`'s render function receives `{ reloading }`.** The `rescue` prop
  and the required `fallback` are stated, so the skill no longer tells the reader to build a
  `router`-event indicator.
- **Changed: every `router` write helper takes the payload as the second argument.**
  Upstream's `router.post('/users', { data: … })` compiles, and it posts a field named
  `data`.
- **Changed: `references/navigation.md`'s cache control uses `fresh: true`, `router.flush`,
  and `router.flushAll`.** Upstream's `cache: false` visit option does not exist. The global
  event list holds all sixteen events, and the hand-wired NProgress example is cut.
- **Changed: the `type`-versus-`interface` rule is narrowed and points at
  `inertia-rails-typescript`.** An `interface` fails only as the generic argument to
  `usePage`.
- **Added: nested and named layouts in `references/layouts.md`.** Upstream's table of
  contents links a `#nested-layouts` anchor with no heading. The named-layout form and the
  four-way prop precedence make `setLayoutProps(name, …)` usable.
- **Added: this skill owns prefetching.** `references/navigation.md` holds the three modes,
  `cacheFor`, cache tags, `router.prefetch`, and flushing.
- **Added: a Related Skills pointer at `rails-core:accessibility-review`.** Do not add a
  promise that the target covers a focus move after a `<Link>` visit. The target states that
  no WCAG 2.2 criterion requires one.
- **Added: Inertia 3 content.** `SKILL.md` adds `setLayoutProps`, `preserveErrors`, and the
  `<Deferred>` change. `references/layouts.md` adds the `setLayoutProps` variants and the
  arrow-layout array rule. When upstream adopts version 3, replace our passage with
  upstream's. Do not keep both, because two copies of one fact drift apart.

## `inertia-rails-performance`

Upstream: `cole-robertson/inertia-rails-skills`, `skills/inertia-rails-performance/SKILL.md`.

- **Cut: most of the upstream file, and the rest is rewritten.** This upstream reasons from
  the shape of the docs, not from the gem, and three of its kept sections stated the
  opposite of what the gem does. Treat an upstream change as a prompt to re-verify against
  the installed gem, not as a patch to apply.
- **Cut: each section that `inertia-rails/skills` already owns.** These are deferred props,
  partial reloads, `<WhenVisible>`, `once` props, scroll preservation, and scroll regions. The
  skill opens with the name of the skill that owns each one.
- **Cut: the `<InfiniteScroll data={posts} component="posts">` example.** The documented
  API takes the prop name as a string.
- **Cut: the prefetch API section.** `inertia-rails-pages` owns `<Link prefetch>`,
  `cacheFor`, and `router.prefetch`. This skill keeps the design question: which pages go
  stale together, and so which cache tags a write invalidates.
- **Cut: polling.** It duplicated `inertia-rails-architecture` line for line, and neither
  resident field said "polling", so no match could reach it. Do not restore it on a re-sync.
- **Cut: general fragment caching, HTTP ETags, and the `around_action` request timer.**
  The caching belongs to `rails-core:caching-strategies`. The skill keeps `router.on` timing,
  which measures an Inertia visit, not a Rails action.
- **Added: four gem mechanics from `rails-core:caching-strategies`.** These are
  `InertiaRails.cache` with `RawJson`, the gem's `config.cache_store`, per-prop key
  suffixes, and the gem's own ETag variant. Only an `inertia_rails` install can use them.
- **Changed: pagination leads with the `Hash` adapter, which needs no paginator gem.**
  Upstream prescribed Pagy, then Kaminari twelve lines later. Pagy and Kaminari appear only
  where the `Gemfile` already has one ([0009](../adr/)).
- **Changed: a lambda in a shared prop runs on every full visit.** Upstream said that it
  runs only when the prop is sent. `InertiaRails.optional` is the selective tool.
- **Changed: instant visits.** `pageProps` replaces the shared props on the intermediate
  frame, and does not add to them. The section leads with `component` alone.
- **Changed: code splitting teaches `lazy: false`.** `lazy` already defaults to `true`, and
  the hand-written `import.meta.glob` resolver and `path: './pages'` are cut.
- **Changed: three examples that did not compile.** `showProgress` is not a
  `ProgressOptions` key. `router.reload` forces `preserveScroll` and `preserveState`. A visit
  has no `startTime`, so the timing example keeps the timestamp outside the handler.
- **Changed: asset versioning shows `config.version = ViteRuby.digest`, the generator's
  form.** A stale POST, PUT, PATCH, or DELETE still runs against the new code, so a version
  bump protects only a GET.

## `inertia-rails-ssr`

Upstream: `cole-robertson/inertia-rails-skills`, `skills/inertia-rails-ssr/SKILL.md`.

- **Changed: the whole file is a rewrite, not a copy.** An upstream diff is a diff against
  text we already rejected. Verify each change against the installed gem and the live
  `inertia-rails.dev` guide, and do not merge the diff. Where the two disagree, the installed
  Ruby decides, because the guide is generic.
- **Changed: production runs the SSR server with the Puma plugin, `plugin :inertia_ssr`.**
  Upstream gave a systemd unit, a PM2 command, and a Dockerfile line instead.
- **Changed: the entry point is `createInertiaApp({ pages: '../pages' })`, with no `resolve`
  or `setup` callback.** Upstream registered `@inertiajs/vite` and then wrote the manual code
  that the plugin replaces. Do not add an `inertia.resolvePages` call, because no such helper
  exists.
- **Cut: the full manual `resolve` and `setup` example.** It contradicted the "no `resolve`
  callback" rule and gave the model a full example to copy. The build output shows that the
  plugin injects all five pieces. The short "Keeping a hand-written `setup` callback" section
  stays as the escape route.
- **Changed: meta tags lead the file.** Upstream's `meta:` with one hash of three keys
  renders one meaningless element. `meta:` takes one hash per tag, and it prints nothing on
  a successful SSR render, so `<Head>` carries the tags under SSR.
- **Changed: the options table.** It adds `ssr_runtime`, and it states `ssr_url`'s default.
  `ssr_enabled` defaults to `false`, and `ssr_bundle` is a gate that fails with no signal.
- **Changed: the build lands at `public/vite-ssr/ssr.js`, and the SSR plugin needs
  `ssr: { entry: … }` in a `vite_ruby` app.** Without the entry, every development render
  falls back to client rendering with no error.
- **Changed: the per-controller `ssr_enabled` value is a zero-argument block.** The gem calls
  it with `instance_exec` and no argument, so upstream's lambda with a parameter raises.
- **Changed: the hydration-mismatch example is React.** Upstream's example was Vue. The
  section adds the whitespace hazard between the ERB layout and the root node, and
  `suppressHydrationWarning`.
- **Cut: `Sentry.capture_exception(error) if defined?(Sentry)`.** The reference `Gemfile`
  has no `sentry-ruby`, and the branch is speculative.

## `inertia-rails-testing`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-testing/SKILL.md`.

- **Changed: the frontmatter.** Upstream put its two sharpest rules into `description`, in
  capitals. The fields now trigger on "request spec", props, and flash without the word
  Inertia, and they state that the skill is Rails-side only.
- **Cut: `references/minitest.md` and its pointer.** This plugin is for RSpec projects, so
  the body is RSpec throughout.
- **Changed: `have_props` takes a literal or a block, never an RSpec matcher in a value
  position.** `have_props` compares with `==`, and a matcher implements `===`. Upstream's
  `hash_including(...)` examples fail, and its "ALWAYS use matchers" rule bans the form that
  works.
- **Changed: the block form uses braces.** With `do … end`, the block binds to `to`, and the
  matcher raises `NoMethodError` far from the cause.
- **Changed: sign-in goes through the app's own session endpoint.** Upstream's `sign_in(user)`
  is Devise's, and the Rails 8.1 generator writes no RSpec sign-in helper.
- **Changed: the unauthenticated example asserts on the redirect.**
  `require_authentication` sends a 302 before any Inertia render, unless the action calls
  `allow_unauthenticated_access`.
- **Changed: "no errors" is `expect(inertia.props[:errors]).to be_empty`.** The generator
  writes `always_include_errors_hash = true`, so `have_no_prop(:errors)` fails.
- **Changed: smaller corrections.** A deferred prop is absent, so the example uses
  `have_no_prop`. Each partial-reload helper makes a real GET, so each example has its own
  assertion. `be_inertia_response` takes the `inertia` helper. Examples sit in a
  `type: :request` group.
- **Added: optional props.** A spec sees one only after a partial reload or under
  `InertiaRails::Testing.evaluate_optional_props`. That setting is global, so the example sets
  it in an `around` hook.
- **Changed: the "NEVER Test These" list is an assertion guide.** It names the assertion to
  write for each case.
- **Changed: "Deferred and shared props" points at `inertia-rails-controllers`.** A reader
  of a request spec needs the server side.

## `inertia-rails-typescript`

Upstream: `inertia-rails/skills`, `skills/inertia-rails-typescript/SKILL.md`.

- **Changed: the frontmatter**, split into `description` and `when_to_use`.
- **Cut: "Accessing shared props in Vue and Svelte", and the framework asides around the
  `type`-versus-`interface` rule** ([0006](../adr/)).
- **Cut: the "Typelizer Integration" section and the `alba-inertia` row.** The section
  applies only with the `alba` and `typelizer` gems, and it pointed at a skill we do not ship
  ([0006](../adr/)). Do not restore it on a re-sync.
- **Changed: `SharedProps` and `FlashData` are `type` aliases.** Upstream's `interface`
  gives 16 `TS2344` errors inside `@inertiajs/core`'s own `.d.ts` files. `skipLibCheck: true`
  hides them, so the defect is latent.
- **Changed: the `declare module` rule.** The host file must be a module. In a `.d.ts` with
  no import or export, the declaration replaces the package's types, and one
  `import '@inertiajs/core'` line fixes it.
- **Changed: error codes.** A read of `usePage().props.flash` fails at the point of use as
  `TS18046`, not `TS2339`. `TS2339` is right only for `const { auth } = usePage()`.
- **Cut: the `usePage<Required<Props>>()` recommendation.** `Required<>` strips `?` from
  optional props, so it trades a compile error for a runtime `undefined`.
- **Changed: a second `declare module` is legal.** `TS2717` fires only for one key declared
  with two different types.
- **Added: the `layoutProps` and `namedLayoutProps` config keys**, and the two augmentations
  that must match a runtime setting: `flashDataType` with `flash_keys`, and
  `errorValueType` with `withAllErrors`.
- **Added: flash is a page-object key, not a prop.** The table of page-object siblings moved
  here from `inertia-rails-architecture`, and so did the `type`-versus-`interface` rule from
  `inertia-rails-pages`.
- **Added: the `js-routes` `TS2305` troubleshooting row**, from `inertia-rails-controllers`. A
  reader looks up a `.tsx` import error here. The row keys on the `TS2305` symptom, so it
  fires only for a project that has the gem.
- **Added: the `@/` alias row**, from upstream's `inertia-rails-setup` skill
  ([0006](../adr/)).

## `react-composition`

Upstream: `vercel-labs/agent-skills`, `skills/composition-patterns/`.

- **Cut: `AGENTS.md` and four build files**: `README.md`, `metadata.json`,
  `rules/_sections.md`, and `rules/_template.md`. All eight rule files stay.
- **Changed: all eight rule files are rewritten.** An upstream change to any rule is a
  decision to make again, not a line to merge.
- **Changed: the worked example uses web elements, not React Native.** `<TextInput>`,
  `onPress`, and `onChangeText` became `<textarea>`, `onClick`, and `onChange`. If a re-sync
  brings the React Native examples back, restore the React Native warning in each file with
  them.
- **Changed: every part reads context through one `useComposer()` hook, which throws when the
  provider is absent.** Upstream's `use(ComposerContext)` against a `null` default does not
  compile under `strict`.
- **Changed: the ref type is `RefObject<HTMLTextAreaElement | null>`.** React 19's types make
  a bare `RefObject<T>` a `TS2322` error.
- **Changed: one compound object and one provider signature across all files.** Upstream
  gave four signatures for one provider in four files.
- **Changed: the `state-` rules contrast a local `useState` provider with one that reads
  `usePage().props`.** Upstream assumed a client-side store and named Zustand, which is a
  non-default dependency. Inertia replaces a global synced store. The technique is unchanged.
- **Added: `useFormContext` in the stack header.** It is the framework's own answer to the
  form case, and `inertia-rails-forms` holds the API.
- **Cut: the rule that marked a top-level `useContext` call as incorrect.** `useContext`
  carries no deprecation, and react.dev distinguishes `use` only by where it can be called.
- **Changed: the `forwardRef` guidance.** Write new components with `ref` as a prop, and
  convert an existing one when you edit it. `forwardRef` is not deprecated at
  `@types/react` 19.2.17.
- **Changed: each rule file leads with the form to write.** The anti-pattern blocks are cut.
- **Changed: the priority table carries ranges, and `description` and `when_to_use` name
  "prop drilling", "too many props", and "extract a component".** The rule files use "prop
  drilling" as the name of the problem this skill solves.
- **Kept: two rule pairs that teach one lesson.** These are
  `architecture-avoid-boolean-props` with `patterns-explicit-variants`, and
  `architecture-compound-components` with `patterns-children-over-render-props`. Do not merge
  a pair or rename `react19-no-forwardref.md`, because that changes the "eight rules in four
  categories" count. Each pair is differentiated in place instead.

## `react-performance`

Upstream: `vercel-labs/agent-skills`, `skills/react-best-practices/`.

- **Changed: the name, from `react-best-practices`.** Upstream's `name:` is
  `vercel-react-best-practices`. Neither name says that the skill holds 56 client-side
  performance rules. Do not restore the upstream name on a re-sync.
- **Cut: the Server-Side Performance section, ten rule files.** Each one assumes a Next.js
  server, which this stack does not have. An upstream diff to these files needs no action.

  ```
  rules/server-after-nonblocking.md        rules/server-no-shared-module-state.md
  rules/server-auth-actions.md             rules/server-parallel-fetching.md
  rules/server-cache-lru.md                rules/server-parallel-nested-fetching.md
  rules/server-cache-react.md              rules/server-serialization.md
  rules/server-dedup-props.md              rules/server-hoist-static-io.md
  ```

- **Cut: four rule files from sections 1 and 4.** `client-swr-dedup` is a doctrine
  conflict, not a stack mismatch: `inertia-rails-architecture` rule 1 bans client-side data
  fetching.

  ```
  rules/async-api-routes.md            — a Next.js route handler
  rules/async-suspense-boundaries.md   — streaming from a server component
  rules/client-swr-dedup.md            — prescribes the SWR library for data fetching
  rules/client-event-listeners.md      — a global listener registry, keyed to SWR's model
  ```

- **Cut: `AGENTS.md` and four build files.** `AGENTS.md` is the compiled copy of every
  rule, the 14 cut rules included, so an upstream diff shows a change to it on every rule
  edit. `README.md`, `metadata.json`, `rules/_sections.md`, and `rules/_template.md` serve a
  `pnpm build` that we do not run.
- **Changed: six rules that prescribed a Next.js API.** Each one now uses the API this stack
  has.

  ```
  bundle-dynamic-imports         next/dynamic → React.lazy plus Suspense
  bundle-defer-third-party       next/dynamic in a root layout → React.lazy in a layout
  bundle-barrel-imports          optimizePackageImports → direct subpath imports, MEDIUM
  bundle-analyzable-paths        process.cwd() and output tracing → import paths only
  rendering-script-defer-async   next/script → the Rails ERB layout and vite_javascript_tag
  async-dependencies             better-all first → plain promise chaining first
  ```

- **Changed: three rules gained a scope line.** The two `rendering-hydration-` rules apply
  only when Inertia SSR is on. `rendering-resource-hints` calls its hints in a persistent
  layout.
- **Changed: the frontmatter.** Upstream named Next.js twice and triggered on every frontend
  task. The fields now cover client-side rendering and bundle cost, and they send query and
  response time to Rails.
- **Added: a stack header with five consequences.** The third consequence states that
  Inertia wins where `rerender-use-deferred-value`'s controlled input meets
  `inertia-rails-forms`' `defaultValue` rule.
- **Changed: seven categories, not eight, and `async-` moved from first to fifth.** The
  `async-` examples are server-handler code, which is Ruby's job here. The CRITICAL values in
  those files stay as upstream wrote them.
- **Changed: four rules that a re-sync is most likely to break again.** Upstream still states
  the false mechanism in each. Do not take upstream's side on these lines in a merge, because
  that brings back a defect we reproduced.
  1. `rerender-memo-with-default-value`: a destructuring default never breaks `memo`. The
     rule keeps a different reason and is LOW.
  2. `bundle-conditional` and `bundle-preload`: a `typeof window` guard cannot keep a module
     out of the bundle.
  3. `client-passive-event-listeners`: listeners on `document` are already passive, so the
     example uses a scroll container.
  4. `rendering-resource-hints`: `preloadModule('/dashboard.js')` cannot resolve a Vite
     content-hashed file.
- **Changed: two rules that were bugs.** `js-cache-storage` split cookies on `=` and
  truncated values. `js-length-check-first` compared sorted joins and mutated its inputs.
- **Changed: every number states its engine, version, input size, and role, or it is cut.**
  The cut figures include `js-index-maps`' "1M ops → 2K ops", `js-batch-dom-css`' 67×, and
  `rendering-content-visibility`'s "10× faster". Do not restore them, because none has a
  source.
- **Changed: `rendering-conditional-render` keeps `&&`.** It fires only on a numeric left
  side, as react.dev's Pitfall does.
- **Added: four gaps.** `rerender-defer-reads` covers `usePage()` re-renders, and
  `rendering-activity` states the hidden-mode contract. Rule pairs with opposite answers name
  each other. `advanced-event-handler-refs` leads with `useEffectEvent`.
- **Changed: four rules that fought the stack.** Two declared a local `Form` that posted to
  a JSON endpoint, and now show a non-form example. `js-request-idle-callback` and
  `js-cache-function-results` no longer fetch or cache auth state inside a component.
- **Changed: `bundle-dynamic-imports` is HIGH, not CRITICAL.** Under SSR, `renderToString`
  ships a `lazy` boundary's fallback above the fold.
- **Kept: the upstream Incorrect and Correct pair, against the house rule to lead with the
  correct form.** 22 of the 56 rule files still carry it. Do not apply the house rule to
  every file in a sweep, because that changes the skill's documented format, and a format
  change is a decision.
- **Kept: three duplicate clusters, unmerged and unrenamed.** `advanced-use-latest` is a
  subset of `advanced-event-handler-refs`, `js-set-map-lookups` overlaps `js-index-maps`, and
  the two `rendering-hydration-` files overlap. Do not merge them, because that changes the
  "fifty-six" count in `description`. Each file names its partner. The `impact:`,
  `impactDescription:`, and `tags:` values stay, made consistent with `SKILL.md`, because
  their removal is a schema decision.
