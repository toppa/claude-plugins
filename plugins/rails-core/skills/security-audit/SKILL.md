---
name: security-audit
description: Rails security audit — the whole-app properties an application either has or lacks (CSRF, mass assignment, access control, session and cookie flags, CSP, TLS, filtered logs), the OWASP Top 10 frame, the P0–P3 report format, and which skill owns each class of finding.
when_to_use: >-
  Use when the user asks for a security audit, a security review or an OWASP
  assessment, when the user mentions CSRF, mass assignment, IDOR or authorization,
  and when reviewing an action that loads a record by an ID from `params`. To run
  Brakeman or bundler-audit, use the brakeman skill; for credentials and sessions,
  the authentication-flow skill.
metadata:
  upstream_repo: ThibautBaissac/rails_ai_agents
  upstream_path: .claude/skills/security-audit/SKILL.md
  upstream_ref: 03622f23b4c6c6934b7c4862a5b5895a9cfd4b2d
  synced: 2026-08-08
  verified_against: Rails 8.1.3.1, inertia_rails 3.22.0
---

# Security Audit

This is the whole-app audit against the OWASP Top 10; the skills named at the end hold the per-sink code.
Report on credentials, secrets and production files rather than editing them.

## Audit process

**1. Read the `Gemfile` for the tools this project already has.** Brakeman and bundler-audit are Rails 8.1
defaults: `rails new` writes both into the `Gemfile`, generates `bin/brakeman` and `bin/bundler-audit`, and runs
both from `config/ci.rb`. Older projects predate that — brakeman was in 3 of 27 measured `Gemfile`s. Run what the
project has, read code for the rest, and leave the `Gemfile` as you found it.

**2. Scope it, and report the scope.** Audit the files the change touches, plus `config/` and every controller
reachable from `config/routes.rb`; add `app/models/`, `app/jobs/`, `app/mailers/`, `db/seeds.rb` and
`Gemfile.lock` when the change reaches them.

**3. Report.** **Vulnerability** → **Location** (file:line) → **Risk** → **Fix** (code example), prioritized
P0 (critical) → P1 (high) → P2 (medium) → P3 (low).

## Broken access control

Finding a record is not authorizing it. Every action that loads a record by an
ID from `params` must also check that the current user may act on it.

```ruby
@entity = current_user.entities.find(params[:id])
```

Scoping the lookup through what the user owns is the cheapest correct answer and needs no
library, where a bare `Entity.find(params[:id])` lets any signed-in user read any row. When
rules outgrow scoping, add an authorization layer. Which library is a project decision:
check what the project already uses before introducing one, and be consistent.

## Configuration — check the property, not the line

- [ ] **TLS end to end** — `config.force_ssl = true`, or a TLS-terminating proxy plus `config.assume_ssl = true`.
  Rails 8.1 comments `force_ssl` out under Kamal, so absence alone is no finding. HSTS follows
  `force_ssl` where Rails terminates TLS. Behind a proxy the header is the proxy's and usually sits
  outside this repository, so report which of the two shapes the app has and where HSTS belongs;
  do not report a missing header you cannot see.
- [ ] **CSRF protection on** — the default since `load_defaults "5.2"`, so the finding is an unexplained
  `skip_forgery_protection` or `protect_from_forgery with: :null_session`.
- [ ] **A Content Security Policy** — the generated initializer ships wholly commented out, so a stock app has none.
- [ ] **Sensitive parameters filtered** — 8.1 fills `filter_parameters` with twelve partial matches, covering
  request parameters and attribute inspection but not a string you interpolate: log an identifier, not the value.
- [ ] **Session cookie flags** — `httponly` and `same_site: :lax` are defaults; `secure` comes from the SSL
  middleware, so it follows from the TLS property above.

## Code

- [ ] Strong parameters on every write action, bounding mass assignment to an explicit key list.
- [ ] Bound parameters in every query: `where(email: params[:email])`.
- [ ] User text renders as `<%= value %>` in ERB, which escapes it. `sanitize` is for values meant to carry
  markup: it lets a tag list through, so it is strictly weaker.
- [ ] A serialised response names its attributes explicitly. `render json: @user` and an Inertia prop given a
  whole record both ship every column of that row. Under Inertia the disclosure is the widest: every prop of
  the initial page is serialised into the HTML document, readable from view-source with no JavaScript. Under
  Hotwire the template picks the fields, so look instead for a whole record handed to `to_json` in a helper,
  a Turbo Stream, or a `data-` attribute. The `rails-architecture` skill's "Response mode" section says which
  of the three a project is in.
- [ ] File uploads validate content type and size.

## Where each finding class is owned

- **A scanner's invocation and exit status** — the `brakeman` skill.
- **Per-diff Ruby sinks** (command injection, unsafe reflection from `params`, path traversal, open
  redirect, SSRF, and five more) — `security-checklist.md` in the `review-ruby-code` skill, which
  states the safe form and a grep pattern for each of its ten sink classes.
- **Deserialization** — the `brakeman` skill. Its `Deserialize` check runs **by default** and covers
  `Marshal.load`, `YAML.load` and `CSV.load`, in the table in "Warning types that apply to any Rails
  version". Treat the warning as a real remote-code-execution finding. One carve-out is documented,
  and it is narrow: `YAML.load` on psych 5.3.1, in "The exception worth knowing: `YAML.load`".
  `Marshal.load` has no equivalent defence.
- **Credentials, sessions, password reset, API tokens** — `authentication-flow`. `has_secure_password` issues a
  signed, expiring reset token needing no database column, so a persisted reset-token column is the finding.
- **Inertia prop breadth** — the canonical rule is in `inertia-react:inertia-rails-controllers`,
  its "Serializing Props" section.
