---
name: inertia-rails-ssr
description: >-
  SEO and server-rendered HTML for Inertia Rails and React — the `meta:` option and the two
  layout helpers that put title, description and Open Graph/Twitter card tags in the
  document (`meta:` and `inertia_meta_tags` work without SSR), then full server-side rendering: the `@inertiajs/vite`
  SSR entry, the `InertiaRails.configure` SSR options, the Puma plugin that runs the Node
  process in production, SSR response caching, and hydration-mismatch debugging.
when_to_use: >-
  Use when a page must be indexable by a search engine, when a shared link must render a
  correct social preview, when you turn SSR on or off, when the SSR server does not answer,
  or when React reports a hydration mismatch.
metadata:
  upstream_repo: cole-robertson/inertia-rails-skills
  upstream_path: skills/inertia-rails-ssr/SKILL.md
  upstream_ref: 77d0172e1390ae746f759c0c75d4b95aacbbd429
  synced: 2026-08-08
  verified_against: >-
    inertia_rails 3.22.0, vite_ruby 3.10.2, "@inertiajs/vite" 3.6.1,
    "@inertiajs/react" 3.6.1, react-dom 19.2.8, TypeScript 7.0.2, Vite 8.1.5,
    puma 8.0.2, Ruby 3.4.5
---

# Inertia Rails Server-Side Rendering

Two separate mechanisms answer "a crawler needs to see this page", and only one of them
needs a Node process. Decide which you need before turning anything on.

| What the crawler needs | What to use | Cost |
|---|---|---|
| Title, description, Open Graph and Twitter card tags, on a page that is not server-rendered | `meta:` on the render, plus `inertia_meta_tags` in the layout | None — both are Rails |
| The same tags on a server-rendered page | `<Head>` in the component, plus `inertia_ssr_head` in the layout | Whatever SSR costs |
| The page's body content in the HTML | SSR: `ssr_enabled` plus a Node process | A Node process per deploy target |

Crawlers and social-preview scrapers want tags far more often than they want body content,
and tags alone cost nothing. Reach for SSR when the *content* has to be in the document — a
public blog post, a product page, a landing page — or when readers on slow connections
should see content before the bundle arrives.

The two tag routes are not interchangeable: **`meta:` and `<Head>` reach the document
through different branches of the renderer**, and the next section is where that bites.

Every TypeScript block below compiles under TypeScript 7.0.2 in `strict` mode against
`@inertiajs/react` 3.6.1.

## Title and meta tags

Set them from the controller. The server owns the data, so it owns the tags.

**`meta:` takes an array of hashes, one hash per tag.** `MetaTagBuilder#add` turns each
hash into exactly one element, and `MetaTag#shortened_title_tag?` treats a hash as a
`<title>` only when its keys are exactly `[:title]`
(`meta_tag.rb:15-26,77-79`, `meta_tag_builder.rb:14-24`).

```ruby
def show
  post = Post.find(params[:id])

  render inertia: 'Posts/Show',
         props: { post: post.as_json(only: [:id, :title, :content]) },
         meta: [
           { title: post.title },
           { name: 'description', content: post.excerpt },
           { property: 'og:title', content: post.title },
           { property: 'og:image', content: post.cover_image_url },
         ]
end
```

That renders what a scraper reads:

```html
<title inertia="title">Post title</title>
<meta name="description" content="Excerpt" inertia="meta-name-description">
<meta property="og:title" content="Post title" inertia="meta-property-og-title">
<meta property="og:image" content="https://…" inertia="meta-property-og-image">
```

One hash carrying `title`, `description` and `og_image` together renders a single
`<meta title="…" description="…" og-image="…">` — no `<title>` element and no `name` or
`property` attribute, so nothing a crawler looks for is present. It fails silently, which
is why it is worth checking against View Source rather than the React tree.

### Which helper carries which tags

There are two layout helpers and they serve **different branches of the same `if`**. The
renderer sets `@_inertia_ssr_head` when an SSR render succeeds and `@_inertia_page`
otherwise (`renderer.rb:53-64`), and each helper reads only its own ivar. Put both in the
layout:

```erb
<%# app/views/layouts/application.html.erb %>
<%= inertia_ssr_head %>
<%= inertia_meta_tags %>
```

Each is blank on the branch it does not serve, so having both is what makes the page
correct either way — including on an SSR fallback, which takes the non-SSR branch.

The gem's installer writes only `<%= inertia_ssr_head %>`. That is the defect to look for
first: on a stock install with SSR off, `meta:` produces tags that nothing prints.

The consequence in the other direction matters as much. `meta:` is a **Rails-side**
feature: it reaches the document only through `inertia_meta_tags`, which reads
`inertia_page.dig(:props, :_inertia_meta)` (`helper.rb:24-32`). The JavaScript adapters have
no notion of `_inertia_meta` — it appears nowhere in `@inertiajs/core` or `@inertiajs/react`
— so on a **successful SSR render** `@_inertia_page` is never set and `meta:` emits nothing.

**Under SSR, `<Head>` is the route.** Its elements arrive in the SSR response's `head` array
and `inertia_ssr_head` prints them. Verified by POSTing a page to a built SSR bundle: a
component wrapping three tags in `<Head>` returned
`head: ["<meta name=\"description\" …>", "<meta property=\"og:title\" …>", "<title …>Hello World</title>"]`.

```tsx
import { Head } from '@inertiajs/react'

export default function Show({ post }: Props) {
  return (
    <>
      <Head>
        <title>{post.title}</title>
        <meta name="description" content={post.excerpt} />
        <meta property="og:title" content={post.title} />
      </Head>
      <article><h1>{post.title}</h1></article>
    </>
  )
}
```

Without SSR, `<Head>` writes into the document from React, so its tags exist only after
hydration and a crawler that does not run JavaScript sees none of them.

So: `meta:` for a page rendered without SSR, `<Head>` for a page rendered with it, and **both**
for a page that can go either way — which is the case whenever `ssr_raise_on_error` is `false`,
because any SSR failure silently takes the other branch. The two never fire together: `meta:`
emits nothing on a successful SSR render, and `<Head>` reaches a non-JS crawler only through
the SSR response. `<Head>` alone leaves the fallback branch with no tags for that crawler.

A default title template belongs in the entry point:

```tsx
createInertiaApp({
  pages: '../pages',
  title: (title) => (title ? `${title} - My App` : 'My App'),
})
```

## SSR setup with `@inertiajs/vite`

**Start by checking what is already there.** The gem's install generator adds
`@inertiajs/vite` to `package.json` and writes both the import and `inertia(),` into
`vite.config.*` (`install_generator.rb:90-94`). On a generator-installed app the plugin is
already registered and there is nothing to install. Where `vite.config.*` carries no
`inertia()` call, add the package and the plugin yourself, in the shape step 1 shows.

### 1. Point the plugin at the SSR entry, and keep `react()`

```ts
// vite.config.ts
import react from '@vitejs/plugin-react'
import inertia from '@inertiajs/vite'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    inertia({ ssr: { entry: 'entrypoints/inertia.tsx' } }),
    react(),
  ],
})
```

`entry` is relative to Vite's root, which `vite-plugin-ruby` sets to `sourceCodeDir` —
`app/frontend`. **This option is what registers the development SSR endpoint.** The
plugin's own auto-detection looks only for Laravel paths (`resources/js/ssr.*`,
`src/app.*`, `dist/index.js:448-465`), none of which exist here, so without an explicit
`entry` the plugin logs no `Inertia SSR dev endpoint: /__inertia_ssr` and development SSR
requests get a 404 that falls back to client rendering.

`@vitejs/plugin-react` must stay in the list — the generator installs and registers it
(`frameworks.yml:13-14`) and without it a React app loses the JSX transform and Fast
Refresh.

### 2. Tell Vite Ruby which file the SSR build starts from

```json
// config/vite.json — merge into the existing "all" object
{
  "all": {
    "ssrEntrypoint": "~/entrypoints/inertia.tsx"
  }
}
```

`config/vite.json` is keyed by mode at the top level and the generated template ships no
`"production"` key, so merge rather than replace. `ssrEntrypoint` defaults to
`~/ssr/ssr.{js,ts,jsx,tsx}`; `bin/vite build --ssr` globs that pattern and raises if it
matches nothing, so it has to name a file that exists. Setting it to the browser entry
point lets one file serve both, which is the arrangement the plugin is built for.

### 3. Keep the entry point minimal

```tsx
// app/frontend/entrypoints/inertia.tsx
import { createInertiaApp } from '@inertiajs/react'

void createInertiaApp({ pages: '../pages' })
```

**One file, no `resolve` callback and no `setup` callback** — unless you already have a `setup`
callback you mean to keep, which "Keeping a hand-written `setup` callback" below covers. For the
SSR build the plugin
rewrites this file into a complete server: it expands `pages` into a resolver, imports
`createServer` and `renderToString`, awaits `createInertiaApp`, calls
`createServer(renderPage)` and exports `renderPage` as the default. Verified by reading the
build output — `public/vite-ssr/ssr.js` contains all five of those and none of them are in
the source.

The file is `.tsx` or `.jsx` for React; the generator computes the extension as
`"inertia.#{typescript? ? 'ts' : 'js'}#{'x' if react?}"`, so `inertia.js` is not a React
entry point in any configuration.

### 4. Build both bundles

```bash
bin/vite build
bin/vite build --ssr
```

Use `bin/vite`, not an `npm run build` script. `bin/vite` passes the `VITE_RUBY_*`
environment that `vite-plugin-ruby` reads and it writes the build-cache metadata that
`ViteRuby.digest` — the value the generated initializer uses for `config.version` —
depends on. A raw `vite build` skips both, and an npm script gives the deploy two build
entry points that can disagree.

The SSR bundle lands at `public/vite-ssr/ssr.js`: `vite-plugin-ruby` names the SSR rollup
entry `ssr` and sets `outDir` to `ssrOutputDir`, whose default is `public/vite-ssr`.

### 5. Enable SSR in Rails

```ruby
# config/initializers/inertia_rails.rb
InertiaRails.configure do |config|
  config.ssr_enabled = true
  config.ssr_raise_on_error = !Rails.env.production?
end
```

## Configuration options

Defaults are from `configuration.rb`'s `DEFAULTS` hash.

| Option | Default | What it does |
|---|---|---|
| `ssr_enabled` | `false` | Turns SSR on. Nothing derives it from ViteRuby; set it yourself, or set `INERTIA_SSR_ENABLED` in the environment |
| `ssr_runtime` | `nil` → detected from the lockfile, else `node` | Picks node, bun, or deno |
| `ssr_bundle` | `nil` → skip detection and always attempt SSR | A path or array of paths. **It gates the renderer**: `SSRRenderer#render` starts `return unless bundle_exists?`, so a path that does not exist means SSR silently never runs |
| `ssr_url` | `nil` → `http://localhost:13714` | Where to POST the render request |
| `ssr_cache` | `nil` | Caches rendered responses. `true`, a Hash of `Rails.cache.fetch` options, or a zero-arity callable |
| `cache_store` | `nil` → `Rails.cache` | Backs `ssr_cache` |
| `ssr_raise_on_error` | `false` | Raises instead of falling back to client rendering |
| `on_ssr_error` | `nil` | Called with `(error, page)` **in addition to** the log line the renderer always writes |

Every option also reads an `INERTIA_<OPTION>` environment variable
(`configuration.rb:93-100`), which is the least invasive way to turn SSR off on one host.

`ssr_raise_on_error` is the setting that matters most in development. Left `false`, a broken
SSR render falls back to client rendering and you never learn it failed.

`on_ssr_error` adds a handler rather than replacing one. `ssr_renderer.rb:50-53` writes
`Rails.logger.error("[inertia-rails] SSR render failed: …")` unconditionally and *then*
calls the hook, so a handler that logs produces two entries for one failure.

```ruby
config.on_ssr_error = ->(error, page) {
  Rails.logger.error "SSR error for #{page[:component]}: #{error.message}"
}
```

## Running the SSR server in production

Use the Puma plugin. It starts and stops the Node process with Puma, waits up to
`BOOT_TIMEOUT = 30` seconds for `GET /health` to answer, restarts after a crash with
exponential backoff capped at 16 seconds, gives up after 10 consecutive crashes, and shuts
down with `POST /shutdown`, falling back to `TERM`.

```ruby
# config/puma.rb
plugin :inertia_ssr
```

It finds the bundle in this order (`puma/plugin/inertia_ssr.rb:136-151`):

1. the first existing path in `config.ssr_bundle`
2. `<ViteRuby ssr_output_dir>/*.js` — `public/vite-ssr/*.js`
3. `ssr/*.js`
4. `public/assets-ssr/*.js`

With a `vite_ruby` app the bundle is at step 2, so leave `ssr_bundle` unset and the plugin
finds it.

To run the process by hand — a one-off check, or under a process manager you already own:

```bash
bin/vite ssr
```

That is `node <ssrOutputDir>/ssr.{js,mjs,cjs}`. It looks for that filename only, and it
`exec`s a hardcoded `node` regardless of `ssr_runtime`, so a bun or deno runtime has to be
launched directly.

**In development there is no second process.** SSR renders through the Vite dev server:
`ssr_renderer.rb:77-78` sends the request to `<dev server>/__inertia_ssr` whenever the dev
server is up. That endpoint is registered by the `entry` option in step 1 of "SSR setup with
`@inertiajs/vite`" above.

## SSR response caching

Every page load sends a render request to Node. Cache the responses when the output does
not vary per reader.

```ruby
config.ssr_cache = true
config.ssr_cache = { expires_in: 1.hour }
config.ssr_cache = -> { { expires_in: action_name == 'index' ? 1.hour : 5.minutes } }
```

Override for one render:

```ruby
render inertia: 'Posts/Show', props: { post: @post.as_json }, ssr_cache: false
```

The cache key is `inertia_ssr/<MD5 of the page JSON>`, so it already varies with every prop
on the page — including a per-reader one. The risk runs the other way: a prop that is the
same for two readers who should see different HTML.

**Caching is inert while the Vite dev server is running.** `cache_options_hash` opens with
`return if vite_dev_server_url` (`ssr_renderer.rb:59`), so a cache configuration verified
locally with `bin/vite dev` up has not been exercised at all.

## Turning SSR off for some pages

```ruby
class InertiaController < ApplicationController
  inertia_config(ssr_enabled: false)
end

class PagesController < InertiaController
  inertia_config(ssr_enabled: Rails.env.production?)
end

class PostsController < InertiaController
  inertia_config(ssr_enabled: -> { request.path.start_with?('/blog') })
end
```

**Write the callable with no parameters.** `evaluate_option` calls
`controller.instance_exec(&value)` with zero arguments (`configuration.rb:180-185`), and a
lambda is strict about arity — `->(request) { … }` raises
`ArgumentError: wrong number of arguments (given 0, expected 1)`. You do not need the
parameter: the block runs in the controller, so `request`, `params` and `action_name` are
already in scope.

Admin screens behind a login gain nothing from SSR and they pay the Node round trip. Turn
them off — and remember from the meta-tag section above that a page with SSR off needs
`inertia_meta_tags` in the layout to emit any server-side tags.

## Troubleshooting

### The SSR server does not answer

1. **Check `ssr_bundle` first.** It is a gate, not just a path override, and it is the one
   failure that produces no signal at all: `SSRRenderer#render` returns before the `rescue`
   blocks, so a wrong path means no log line, no `on_ssr_error` call, and no raise even with
   `ssr_raise_on_error = true`. If it is set, confirm the file exists; if you do not need it,
   leave it `nil`.
2. Confirm the process runs. With the Puma plugin, it starts with Puma and logs its health
   checks.
3. Read the Rails log for `[inertia-rails] SSR render failed`, which the renderer writes on
   every caught failure.
4. Set `ssr_raise_on_error = true` in development, so the failure stops being silent.
5. In development, confirm `bin/vite dev` is running **and** that `vite.config.ts` passes
   `ssr: { entry: … }` — without it the `/__inertia_ssr` endpoint does not exist and every
   render request 404s.
6. Check `ssr_url`. `nil` means `http://localhost:13714`, so setting it to that value
   explicitly changes nothing. The renderer appends `/render` unless the URL already ends in
   `/render` or `/__inertia_ssr`, and the Puma plugin strips that suffix back off for its
   health-check base — so give it the base URL and let both do the rest.

### React reports a hydration mismatch

The server HTML and the first client render must match exactly. The usual causes:

1. A browser-only API read during the first render.
2. A value that changes between the two renders, such as the current time or a random ID.
3. Locale-dependent or timezone-dependent formatting.
4. Whitespace or a newline between the ERB layout and the React-generated HTML inside the
   root element — an Inertia-Rails hazard rather than a React one, and the one on this list
   you will not find by reading component code.

Render the varying value after mount, and mark the node when the difference is unavoidable:

```tsx
const [time, setTime] = useState<string | null>(null)
useEffect(() => setTime(new Date().toLocaleTimeString()), [])

return <span suppressHydrationWarning>{time}</span>
```

`suppressHydrationWarning` is React's named escape hatch for exactly this case: it silences
the warning for one element's text without turning off hydration checking anywhere else.

### Memory grows in the Node process

SSR renders share one process. Module-level mutable state accumulates across requests.
Keep state inside the render, and read request data from props.

## Keeping a hand-written `setup` callback

The plugin generates the client mount, the SSR entry and the hydration call, so a project
using it owes none of them. Take this path only when you already have a `setup` callback you
intend to keep — a custom provider tree, a third-party mount wrapper.

What you then owe: the client entry hydrates rather than renders, and you supply a second
file that calls `createServer` with `renderToString`.

```tsx
createInertiaApp({
  pages: '../pages',
  setup({ el, App, props }) {
    if (el) hydrateRoot(el, <App {...props} />)
  },
})
```

`el` is typed `HTMLElement | null` on the overload that takes `pages`, because the same file
may be loaded for SSR where there is no element — hence the guard. Writing an explicit
`resolve` callback instead selects the browser-only overload, where `el` is `HTMLElement`.

`ViteRuby.config.ssr_build_enabled` reads the `ssrBuildEnabled` key from `config/vite.json`
if you want the Rails side to follow the build configuration:

```ruby
config.ssr_enabled = ViteRuby.config.ssr_build_enabled
```

## Performance

1. Keep the SSR render cheap. Push heavy work to a deferred prop, which the client fetches
   after hydration and the SSR pass never sees.
2. Cache with `ssr_cache` for pages that do not vary per reader — see the caching section
   above for the key and the development caveat.
3. Turn SSR off per controller for screens behind a login.

For prop payload size, code splitting and cross-page cache invalidation, use
`inertia-react:inertia-rails-performance`.
