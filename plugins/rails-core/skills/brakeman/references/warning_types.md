# Brakeman warning types — brakeman 8.0.5

Brakeman 8.0.5 ships 88 check files under `lib/brakeman/checks/` and emits **37
distinct `warning_type` strings**. Every row below was read out of the installed
gem: the `warning_type` string as the report prints it, the check class the
`-t`/`-x`/`-E` flags take, the numeric warning code, whether the check runs by
default, and the version window the warning applies to.

Those five columns are the reason to read this file. The `warning_type` string is
what appears in JSON, SARIF and `--text-fields category` output, so grepping or
filtering by anything else finds nothing — and the strings do not match the
headings you would guess. `Basic Auth` not "Basic Authentication",
`Dangerous Eval` not "Dangerous Evaluation", `Session Setting` singular,
`Divide by Zero` with a lowercase "by", `Unmaintained Dependency` singular.

The remediation for a warning is not here. The `security-audit` skill owns the
audit procedure and severity ranking, in its "Audit process" section, and the
`review-ruby-code` skill owns the per-diff catalogue of Ruby sinks and their
safe forms in `security-checklist.md`, which states the safe form and a grep
pattern for each of its ten sink classes.

## Warning types that apply to any Rails version

No row here is confined to a window of Rails versions, so a Rails 8.1 application
can reach any of them. Four carry a gate of their own, stated in the Notes
column: `BasicAuth` needs Rails ≥ 3.1, and `PageCachingCVE`,
`ModelAttrAccessible` and `Ransack` each need a gem or an API that a Rails 8.1
application does not have by default.

| `warning_type` | Check class | Code | Runs | Notes |
|---|---|---|---|---|
| Authentication | `SkipBeforeFilter` | 10 (`auth_blacklist`) | default | A `skip_before_action` that names an authentication filter |
| Authentication | `Secrets` | 101 (`secret_in_source`) | optional | A credential written as a string literal |
| Basic Auth | `BasicAuth` | 9 (`basic_auth_password`) | default | `http_basic_authenticate_with` with a literal password. Runs on Rails ≥ 3.1 |
| Command Injection | `Execute` | 14 (`command_injection`) | default | The check class is `Execute`, not `CommandInjection` |
| Cross-Site Request Forgery | `SkipBeforeFilter` | 8 (`csrf_blacklist`) | default | A `skip_before_action :verify_authenticity_token` |
| Cross-Site Scripting | `CrossSiteScripting` | 2 (`cross_site_scripting`) | default | Unescaped output in a template |
| Cross-Site Scripting | `ContentTag` | 53 (`xss_content_tag`) | default | Unescaped input through `content_tag` |
| Cross-Site Scripting | `LinkToHref` | 4 (`xss_link_to_href`) | default | User input in `link_to`'s href |
| Cross-Site Scripting | `RenderInline` | 84 (`cross_site_scripting_inline`) | default | `render inline:` |
| Cross-Site Scripting | `JSONEntityEscape` | 113, 114 | default | Reads `escape_html_entities_in_json` only |
| Dangerous Eval | `Evaluation` | 13 (`code_eval`) | default | |
| Dangerous Send | `Send` | 23 (`dangerous_send`) | default | `@send_methods` is `[:send, :try, :__send__, :public_send]` |
| Default Routes | `DefaultRoutes` | 11, 12 | default | A wildcard route |
| Denial of Service | `RegexDoS` | 76 (`regex_dos`) | default | User input inside a regex |
| Denial of Service | `SymbolDoS` | 59 (`unsafe_symbol_creation`) | optional | |
| Directory Traversal | `PageCachingCVE` | 115 | default | Gated on `actionpack-page_caching` ≤ 1.2.1 |
| Divide by Zero | `DivideByZero` | 104 (`divide_by_zero`) | optional | |
| Dynamic Render Path | `Render` | 15 (`dynamic_render_path`) | default | |
| File Access | `FileAccess` | 16 (`file_access`) | default | Any file API given user input |
| File Access | `SendFile` | 16 (`file_access`) | default | Subclasses `FileAccess`; same code |
| Format Validation | `ValidationRegex` | 30 (`validation_regex`) | default | `^`/`$` where `\A`/`\z` belongs |
| HTTP Verb Confusion | `VerbConfusion` | 118 | default | An `if request.get?` guard in an action, whose else branch a verb you did not intend can reach |
| Information Disclosure | `DetailedExceptions` | 61, 62 | default | Both codes come from this one check |
| Mass Assignment | `MassAssignment` | 17, 70, 112 | default | 112 is `permit!` |
| Mass Assignment | `ModelAttrAccessible` | 60 | default | Requires `attr_accessible`, a Rails 3 API |
| Mass Assignment | `PermitAttributes` | 105 (`dangerous_permit_key`) | default | A permitted key such as `admin` or `account_id` |
| Missing Authorization | `Ransack` | 129 (`ransack_search`) | default | Gated on `ransack` ≤ 3.99 |
| Missing Encryption | `ForceSSL` | 109 | optional | `config.force_ssl` off in production |
| Path Traversal | `Pathname` | 125 (`pathname_traversal`) | default | `Rails.root.join` or `Pathname#join` given immediate user input |
| Redirect | `Redirect` | 18 (`open_redirect`) | default | See the open-redirect note below |
| Remote Code Execution | `Deserialize` | 25 (`unsafe_deserialize`) | default | `Marshal.load`, `YAML.load`, `CSV.load` and friends |
| Remote Code Execution | `UnsafeReflection` | 24 (`unsafe_constantize`) | default | `constantize` / `safe_constantize` on user input |
| Remote Code Execution | `UnsafeReflectionMethods` | 119 | default | `method`, `instance_method` on user input |
| Remote Code Execution | `CookieSerialization` | 110 | default | Fires only on an explicit `:marshal` or `:hybrid` |
| Reverse Tabnabbing | `ReverseTabnabbing` | 111 | optional | `link_to … target: "_blank"` without `rel` |
| SQL Injection | `SQL` | 0, 1 | default | 1 is `limit`/`offset` |
| SSL Verification Bypass | `SSLVerify` | 71 | default | `VERIFY_NONE` |
| Session Manipulation | `SessionManipulation` | 89 (`session_key_manipulation`) | default | User input as a **session hash key**, and nothing else |
| Session Setting | `SessionSettings` | 26, 27, 29 | default | Fires on `httponly: false`, `secure: false`, or a literal secret |
| Template Injection | `TemplateInjection` | 117 (`erb_template_injection`) | default | |
| Unscoped Find | `UnscopedFind` | 82 (`unscoped_find`) | optional | Only on models with a non-optional `belongs_to`; Weak confidence |
| Weak Cryptography | `WeakRSAKey` | 126, 128 | default | Small key size, insecure padding mode |
| Weak Hash | `WeakHash` | 90, 91 | optional | MD5 or SHA1 for a digest or an HMAC |

Enable the optional ones with `-E CheckName` individually, or all of them with
`-A`. `--optional-checks` lists them.

## Warning types confined to a version window

Each of these reports a specific CVE or a framework behaviour that later versions
removed. They are still worth knowing, because they are what a legacy application
produces and because their absence from a modern scan is expected rather than
suspicious. On a Rails 8.1 application every row here is dormant.

| `warning_type` | Check class | Code | Window |
|---|---|---|---|
| Attribute Restriction | `ModelAttributes` | 19 | Rails 2.0–3.2.11, and silent whenever mass assignment is disabled, which Rails 4 made the default |
| Cross-Site Request Forgery | `ForgerySetting` | 7, 86, 33 | The whole check returns early when `default_protect_from_forgery?`, which Rails sets from `load_defaults 5.2`. CVE_2011_0447 (33) is Rails 2.1.0–3.0.3 |
| Cross-Site Request Forgery | `CSRFTokenForgeryCVE` | 116 | Rails ≤ 5.2.4.2, 6.0.0–6.0.3 |
| Cross-Site Scripting | `LinkTo` | 3 | Rails 2.0–2.9.9 |
| Cross-Site Scripting | `EscapeFunction` | 83 | Rails 2.0–2.3.13 |
| Cross-Site Scripting | `I18nXSS` | 63 | Rails 3.0.6–4.0.1 |
| Cross-Site Scripting | `JSONEncoding` | 87 | Rails 4.1.0–4.2.1 |
| Cross-Site Scripting | `NumberToCurrency` | 73, 74 | Rails 2.0–4.0.2 |
| Cross-Site Scripting | `SafeBufferManipulation` | 21 | Rails 3.0.0–3.2.1 |
| Cross-Site Scripting | `SanitizeConfigCve` | 124 | `rails-html-sanitizer` ≤ 1.4.2 |
| Cross-Site Scripting | `SanitizeMethods` | 106 | Rails ≤ 3.2.12, `rails-html-sanitizer` ≤ 1.0.3, `loofah` ≤ 2.2.0 |
| Cross-Site Scripting | `SelectTag` | 43 | Rails 3.0.0–3.2.7 |
| Cross-Site Scripting | `SelectVulnerability` | 22 | Rails 2.0–3.2.1 |
| Cross-Site Scripting | `SimpleFormat` | 67, 68 | Rails 4.0.0–4.0.1 |
| Cross-Site Scripting | `SingleQuotes` | 44 | Rails 2.0–3.2.7 |
| Cross-Site Scripting | `StripTags` | 36, 45, 98 | Rails 2.0–3.2.7 |
| Cross-Site Scripting | `TranslateBug` | 28 | Rails 2.3–3.1.1 |
| Cross-Site Scripting | `ContentTag` | 102 | Rails ≤ 6.1.5 (CVE_2016_6316 branch only; code 53 is ungated) |
| Default Routes | `FilterSkipping` | 34 | Rails 3.0.0–3.0.9 |
| Denial of Service | `DigestDoS` | 42 | Rails 3.0.0–3.2.5 |
| Denial of Service | `HeaderDoS` | 64 | Rails 3.0.0–4.0.1 |
| Denial of Service | `MimeTypeDoS` | 94 | Rails 3.0.0–4.2.5 |
| Denial of Service | `RenderDoS` | 75 | Rails 3.0.0–3.2.16 |
| Denial of Service | `RouteDoS` | 100 | Rails 4.0.0–4.2.5 |
| Denial of Service | `SymbolDoSCVE` | 55 | Rails 2.0–3.2.12 |
| Denial of Service | `XMLDoS` | 88 | Rails 2.0–4.2.1 |
| File Access | `FileDisclosure` | 85 | Rails 2.0–4.1.7 |
| File Access | `JRubyXML` | 57 | Rails 3.0.0–3.2.12, JRuby only |
| Mail Link | `MailTo` | 32 | Rails 2.3.0–2.3.10 and 3.0.0–3.0.3, and only with `encode: :javascript`. Reports CVE-2011-0446 |
| Mass Assignment | `CreateWith` | 80, 81 | Rails 4.0.0–4.1.4 |
| Mass Assignment | `WithoutProtection` | 54 | Needs `without_protection:`, removed in Rails 4 |
| Nested Attributes | `NestedAttributes` | 31 | Rails 2.3.9 and 3.0.0 exactly |
| Nested Attributes | `NestedAttributesBypass` | 95 | Rails 3.1.0–4.2.5 |
| Path Traversal | `SprocketsPathTraversal` | 108 | `sprockets` ≤ 3.7.1 |
| Remote Code Execution | `DefaultRoutes` | 77 | Rails 2.0–4.1.0 (CVE_2014_0130) |
| Remote Code Execution | `JSONParsing` | 52 | Rails ≤ 3.0.19 |
| Remote Code Execution | `ModelSerialize` | 50 | Rails 2.0–3.0.99 |
| Remote Code Execution | `RenderRCE` | 99 | Rails ≤ 4.2.5 |
| Remote Code Execution | `YAMLParsing` | 48 | Rails ≤ 3.2.10 |
| Response Splitting | `ResponseSplitting` | 37 | Rails 2.3.0–2.3.13 |
| SQL Injection | `DynamicFinders` | 92 | Rails 2.0–4.1.99, and only with the `mysql` gem |
| SQL Injection | `QuoteTableName` | 35 | Rails 2.0–3.0.9 |
| SQL Injection | `SQLCVEs` | 72 | Rails 4.0.0–4.0.2 |
| Timing Attack | `BasicAuthTimingAttack` | 93 | Rails ≤ 4.2.5 |
| Unmaintained Dependency | `EOLRails` | 120, 122 | Compares against `RAILS_EOL_DATES` (`check_eol_rails.rb:16-29`), whose newest entry is `8.0.0-8.0.99`, so it is quiet on Rails 8.1 |
| Unmaintained Dependency | `EOLRuby` | 121, 123 | `RUBY_EOL_DATES` runs to `3.4.0-3.4.99`, EOL 2028-03-31 |

`Unmaintained Dependency` is not a CVE scan. Brakeman has no vulnerable-gem
database; it compares your Rails and Ruby versions against end-of-life dates.
`bin/bundler-audit` is the CVE scan.

## Notes where the check's behaviour is not what the name suggests

### `Dangerous Send` — the fix is a dispatch table, not `public_send`

`check_send.rb:11` is `@send_methods = [:send, :try, :__send__, :public_send]`, so
all four dispatchers warn at High confidence:

```ruby
object.send(params[:method])
object.public_send(params[:method])
object.try(params[:method])
```

`public_send` blocks private methods and nothing else; `public_send("destroy")`
still destroys. The fix is a dispatch table keyed by the parameter, so the set of
reachable methods is written down:

```ruby
SORTS = { "name" => :name, "newest" => :created_at }.freeze

def sort_column
  SORTS.fetch(params[:sort], :name)
end
```

Brakeman clears the warning because the method name is now a literal, and a
reader can see the whole reachable set. Apply the same shape to `constantize`
(`UnsafeReflection`, code 24): map the parameter to a class you name, rather than
resolving whatever string arrives.

### `File Access` — removing the shell does not make the path safe

`FileUtils.rm_rf(params[:path])` is a High-confidence `File Access` warning —
verified by scan. Replacing a shell call with a Ruby file API removes
metacharacter injection and leaves arbitrary recursive deletion. Two separate
properties are needed: no shell, and a path the caller cannot choose.

```ruby
# One name from a set you control, resolved under a fixed root
DOWNLOAD_ROOT = Rails.root.join("storage", "downloads")

def download_path
  name = File.basename(params[:file].to_s)
  path = DOWNLOAD_ROOT.join(name)
  raise ActionController::BadRequest unless path.to_s.start_with?("#{DOWNLOAD_ROOT}/")

  path
end
```

For the shell itself, pass arguments as separate array elements —
`system("convert", src, dest)` — which never reaches `/bin/sh`.
`check_execute.rb:21-28` also treats `Shellwords.escape`, `shellescape` and
`shelljoin` as safe, so `system("cat #{Shellwords.escape(path)}")` scans clean.

### `Redirect` — on Rails 7.0 and later the warning inverts

`CheckRedirect#protected_by_raise?` (`check_redirect.rb:272-279`) suppresses the
warning when `action_controller.raise_on_open_redirects` is set, which
`load_defaults 7.0` does — **unless the call also passes
`allow_other_host: true`**, which switches the framework's guard off. Verified on
a `load_defaults 8.1` application:

```ruby
redirect_to params[:url]                            # no warning: the framework raises
redirect_to params[:url], allow_other_host: true    # Redirect, Weak confidence
```

So a `Redirect` warning on a modern app is a report that someone disabled the
framework's own protection, and it arrives at **Weak** confidence, which `-w2`
and `-w3` filter out. Take it seriously and read it at `-w1`.

The rule that follows: when you reach for `allow_other_host: true`, name the hosts
instead. A hand-rolled path check is weaker than the framework's — Rails'
`_url_host_allowed?` requires `start_with?("/") && !start_with?("//")`, so it
rejects the protocol-relative `//attacker.example` that a regex like
`/\A\/[a-z0-9_\-\/]+\z/i` accepts.

```ruby
ALLOWED_REDIRECT_HOSTS = ["app.example.com", "admin.example.com"].freeze

def safe_redirect_target
  host = URI.parse(params[:url].to_s).host
  ALLOWED_REDIRECT_HOSTS.include?(host) ? params[:url] : root_path
rescue URI::InvalidURIError
  root_path
end
```

### `Cross-Site Request Forgery` — the check is silent on this stack

`CheckForgerySetting#run_check` opens with
`return if tracker.config.default_protect_from_forgery?`, and Rails sets that
from `load_defaults 5.2`. Verified: an application at `load_defaults 8.1` with
`protect_from_forgery with: :null_session` in a controller produces no CSRF
warning at all. Rails 8.1 enables forgery protection for you, so a clean report
here means the check did not run rather than that the application was examined.

### `Authentication` — Brakeman does not look for missing authentication

The only two sources of the `Authentication` string are `CheckSecrets` (optional;
a credential written into source) and `CheckSkipBeforeFilter` (a
`skip_before_action` naming an auth filter, matched as a literal symbol — which is
the one place `authenticate_user!` is relevant, and does not imply the project
uses Devise). Nothing checks whether an action requires a session, and nothing
checks password rules. The `authentication-flow` skill owns both — `require_authentication`
and `allow_unauthenticated_access` in its "The API you get" section, and the minimum length
and complexity rules `has_secure_password` does not set, in its "Password rules" section.

### `Session Setting` and `Session Manipulation` are narrower than they read

`CheckSessionSettings` warns on a short list: `httponly: false` (also spelled
`http_only` or `session_http_only`), `secure: false`, a literal `:secret` or
`secret_token=`/`secret_key_base=`, and a plaintext `secret_key_base` under
`production:` in `config/secrets.yml`. It never asks for `same_site`, and its
`settings_target?` requires the `SomeApp::Application.config` receiver, so the
`Rails.application.config.…` form is not the form it reads. Rails 8.1 generates no
`session_store.rb` and no `secrets.yml` at all, which is why this check is quiet
on a new app. `CheckSessionManipulation` looks for one thing: user input used as a
**session hash key**.

Note that `secure: true` unconditionally breaks every session served over HTTP,
which includes local development on this stack.

### `Format Validation`

`^` and `$` match line boundaries, so a value containing a newline can satisfy a
validation that looks anchored. `\A` and `\z` match the string boundaries.

```ruby
validates :email, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }
```

### `Cross-Site Scripting` in a `<script>` block

`<%= @user.name.to_json %>` inside `<script>` does not produce working
JavaScript: `to_json` returns a String that is not `html_safe?`, ERB escapes it,
and inside HTML raw-text content `&quot;` is not decoded, so the browser raises a
`SyntaxError`. Pass data to the client through a `data-` attribute, or through
the Inertia page props, and read it in JavaScript rather than generating source.

## What Brakeman does not check

A clean report covers the checks that exist. These sinks are not among them, so
they stay a reading task.

- **SSRF.** No check, no partial coverage: `rg -in 'ssrf|server.side.request' lib/`
  over the gem returns nothing across all 88 check files. `Net::HTTP.get(URI(params[:url]))`
  and `URI.open(params[:url])` both scan clean. Allowlist the host, and resolve
  and re-check it before connecting.
- **XML entity expansion.** No check reads Nokogiri's parse options.
  `Nokogiri::XML(untrusted) { |c| c.noent.dtdload.huge }` scans clean. Nokogiri's
  default is safe — `parse_options.rb:75-77` records `noent` as "Off by default"
  with the comment "⚠ This option enables entity substitution, contrary to what
  the name implies" — so grep for the departures: `.noent`, `.dtdload`, `.huge`,
  and `Nokogiri::XSLT` applied to an untrusted stylesheet.
- **Vulnerable gem versions.** `bin/bundler-audit`.
- **Missing authorization on a record fetch.** `Unscoped Find` is optional, only
  inspects models with a non-optional `belongs_to`, and reports at Weak
  confidence. `current_user.posts.find(params[:id])` is the shape to write, and
  reading for it is the `security-audit` skill's job, in its "Broken access control" section.

## Interpreting a warning

1. Read the code in context and trace the value to its source. Brakeman reports
   reachable-looking data flow, not proven exploitability.
2. Check the confidence, then the version window in the tables above. A warning
   from a check gated to Rails 4 on a Rails 8 app deserves a second look at the
   detected version.
3. Match the `warning_type` string, not a heading, when you grep a JSON or SARIF
   report or filter with `--text-fields category`.
4. Fix it, or record it in `config/brakeman.ignore` with a note saying why. See
   `SKILL.md` for what one ignore entry actually suppresses.
