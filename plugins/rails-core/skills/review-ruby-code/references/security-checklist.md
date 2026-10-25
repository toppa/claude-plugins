# Per-Diff Security Sink Catalogue

A per-diff catalogue of Ruby and Rails sinks: one safe form per class, plus what to grep for to find
the unsafe form. Verified against Rails 8.1.3.1 and Ruby 3.4.5 at `config.load_defaults 8.1`.

## Scope, and where the rest lives

This file covers what you can see in a diff. Read the rest where it lives:

- **`rails-core:security-audit`** — the whole-app audit: procedure, scope, P0–P3 report format, the
  configuration properties, and broken access control including ownership scoping.
- **`rails-core:authentication-flow`** — every credential and session mechanism: passwords, reset
  tokens, API tokens, session fixation, session expiry, `rate_limit`.
- **`rails-core:brakeman`** — running the scanner, reading its warnings, its exit codes.
- **`rails-core:rails-8-idioms`** — the full strong-parameters shape rule, in "Strong parameters:
  pick the form from the shape of the incoming params"; the redirect rule forks by response mode in a
  separate section there, "Redirect status codes".
- **`inertia-react:inertia-rails-controllers`** — Inertia page props, in its "Serializing Props"
  section: the same question as "Over-broad serialization" below.

## SQL injection

**Safe form** — hand values to Active Record and let it bind them:

```ruby
User.where(email_address: params[:email_address])
Post.where(status: "published", category: params[:category])
Post.where("published_at > ?", 1.week.ago)
Post.where("status = :status AND title = :title", status: "published", title: params[:q])
Post.where("title LIKE ?", "%#{Post.sanitize_sql_like(params[:q])}%")
```

`sanitize_sql_like` is the one reviewers miss: without it a user's `%` and `_` stay wildcards, so a
search for `100%_off` matches far more rows than asked for. With it the SQL reads
`WHERE (title LIKE '%100\%\_off%')`.

For `order`, `pluck`, `select`, `group` and `having`, Rails already refuses a string that is not a
plain column reference — `Post.order("title; DROP TABLE posts")` raises
`ActiveRecord::UnknownAttributeReference`. `Arel.sql` is the documented way out of that guard, so feed
it from a fixed map rather than a parameter:

```ruby
SORTS = { "newest" => "created_at DESC", "title" => "title ASC" }.freeze
Post.order(Arel.sql(SORTS.fetch(params[:sort], "created_at DESC")))
```

**Grep for**: `#{` inside any string argument to `where`, `order`, `pluck`, `select`, `group`, `having`,
`find_by_sql`, `exists?`, `update_all`, `delete_all` or `Arel.sql`; and `execute` / `exec_query` reached
through `with_connection` or `lease_connection` as well as `connection`, which is soft-deprecated at
8.1, so grepping `connection.execute` alone misses current code.

## Cross-site scripting

**Safe form** — print the value and let ERB escape it. This is the default, so the review item is
that nothing has opted out of it. Where the field really holds author-supplied markup, name the tags
and attributes you accept; to reach JavaScript, use a data attribute or `raw json_escape`:

```erb
<p><%= @user.bio %></p>
<%= sanitize @post.content, tags: %w[strong em a], attributes: %w[href] %>
<div id="chart" data-series="<%= @series.to_json %>"></div>
<script>const series = <%= raw json_escape(@series.to_json) %>;</script>
```

Line 1 turns `<script>alert('XSS')</script>` into `&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;`. Line 2
strips `<script>`, drops an `onclick` and removes a `javascript:` href — but it returns `html_safe` output,
so it is strictly weaker than line 1 and belongs to rich text only. Line 4's `raw json_escape` is required
rather than optional: a bare `<%= @series.to_json %>` in a `<script>` renders `&quot;label&quot;`, because
ERB escapes the JSON's quotes and HTML entities are not decoded there, so the script raises a `SyntaxError`.

**Grep for**: `.html_safe`, `raw(`, `<%==` (raw unescaped output in ActionView 8.1.3.1 today, not a legacy
spelling), `params[` inside a `<script>` block, and `to_json` in a `<script>` without `raw json_escape`.
Also grep `sanitize` with no `tags:` — a breadth question worth raising, not a vulnerability, since the
default allowlist already excludes script.

## Over-broad serialization

**Safe form** — name the columns the client needs:

```ruby
def serialize_user(user)
  user.as_json(only: [:id, :email_address, :name])
end
```

A bare `user.to_json` emits every column, the bcrypt digest and any admin flag included, and each new column
joins the payload silently — so the defect arrives in a later migration, not in the diff that leaks it.

**Grep for**: `to_json` or `as_json` with no `only:`, `render json:` given a record or a relation, and
a whole record passed to a view or a serializer. Inertia props are the same question — the canonical
rule and the disclosure mechanism are in `inertia-react:inertia-rails-controllers`, in its
"Serializing Props" section.

## Mass assignment

**Safe form** — choose by the shape of the params, not by the kind of API:

```ruby
params.expect(user: [:name, :email_address, :bio])   # nested under a model key
params.permit(:email_address, :password)             # flat scalars at the root
params.expect(:id)                                   # a required scalar
params[:page]                                        # an optional read where nil is right
```

Root-level forms use `permit` for a concrete reason: given several root scalars `expect` returns an **Array**
— `params.expect(:email_address, :password)` yields `["a@b.test", "s3cret"]` — which is useless to
`authenticate_by`. That, not "a plain attribute hash", is why the 8.1 auth generator writes `permit`.
`expect`'s win is at the root instead: `user: "notahash"` raises `ActionController::ParameterMissing` (400)
where `params.require(:user).permit(...)` raises `NoMethodError` (500). It is a root-key guard, not a
nested-shape validator — against `pets: [[:name]]` a nested `pets: { name: "hack" }` is dropped silently,
no exception. `rails-core:rails-8-idioms` carries the full rule, in "Strong parameters: pick the
form from the shape of the incoming params".

**Grep for**: `permit!`, `params[:model]` reaching `new` / `create` / `update` / `attributes=`, and any
loop assigning attributes from a params hash.

## Unsafe reflection

**Safe form** — map the input to a fixed set and fail closed:

```ruby
REPORTS = { "sales" => SalesReport, "signups" => SignupReport }.freeze

def report_class
  REPORTS.fetch(params[:report_type]) { raise ActionController::BadRequest }
end
```

Do the same for a method or column name — `SORTS = { "newest" => :created_at }.freeze`, then
`SORTS.fetch(...)`. The value crossing the boundary is a key you wrote, never a name the caller chose.
**`public_send` is not the fix**: it reaches every public method —
`Object.public_send(:const_get, :File)` returns `File` — and Brakeman treats it identically, since
`check_send.rb:11` lists `[:send, :try, :__send__, :public_send]`.

**Grep for**: `constantize`, `safe_constantize`, `const_get`, `classify`, `send`, `public_send`, `__send__`,
`try` and `eval`, wherever the argument traces back to `params`, a header, or a user-editable column. This
is the sink a new app introduces first, and the one most often missed, because a dispatch table keyed on
params looks like good design.

## Path traversal

**Safe form** — take no path from input: look up a record the user is allowed to see and let it name its own
file. When a path segment genuinely has to come from input, resolve first and assert containment:

```ruby
def show
  export = current_user.exports.find(params[:id])
  send_data export.file.download, filename: export.filename, disposition: :attachment
end

root = Rails.root.join("storage/exports")
path = root.join(params[:filename]).cleanpath
raise ActionController::BadRequest unless path.to_s.start_with?("#{root}/")
```

Resolve rather than filter: `../../../etc/passwd` cleanpaths three levels above the root and `a/../../b` one
level above, so both fail the prefix test. A filter that strips `..` must anticipate every encoding;
`cleanpath` plus a prefix test does not.

**Grep for**: params reaching `File.read`, `File.open`, `File.join`, `send_file`, `Pathname#join`,
`Dir.glob` or `render file:`; and any code that filters `..` instead of resolving the path.

## Open redirect

Rails 8.1 already closes this, so the safe form is the ordinary `redirect_to user_path(user)`. A
`redirect_to params[:url]` to another host raises `ActionController::Redirecting::OpenRedirectError` —
railties `configuration.rb:266` sets `action_controller.action_on_open_redirect = :raise` under
`load_defaults "7.0"`, which `8.1` inherits, and `:353` adds `action_on_path_relative_redirect = :raise`.

**The review item is `allow_other_host: true`**, which switches the guard off for that call — with it,
`redirect_to params[:url]` sends the browser to `https://attacker.test/x`. When an off-site return is
genuinely needed, allowlist the host and leave the framework's check on everything else:

```ruby
RETURN_TO_HOSTS = %w[docs.example.com].freeze

def return_to
  host = URI.parse(params[:return_to].to_s).host
  RETURN_TO_HOSTS.include?(host) ? params[:return_to] : root_path
rescue URI::InvalidURIError
  root_path
end
```

Parse the URL; do not match it with a regex. `URI.parse("//attacker.test/x").host` is `attacker.test`,
so parsing rejects the protocol-relative form that an anchored `\Ahttps?://ourhost` regex admits.

**Grep for**: `allow_other_host` anywhere, and `redirect_to` given a value from params, a cookie, the
session, or a user-editable column.

## Server-side request forgery

**No tool covers this.** Brakeman 8.0.5 has no SSRF check — 88 files under `lib/brakeman/checks/`,
zero hits for `ssrf` or `server.side.request` — so it is found by reading or not at all.

**Safe form** — fetch only URLs your own code composed. When a user supplies one, allowlist the scheme
and host, then check what the name resolves to:

```ruby
ALLOWED_HOSTS = %w[api.example.com].freeze

def internal?(address) = (ip = IPAddr.new(address)).loopback? || ip.private? || ip.link_local?

def fetchable?(candidate)
  uri = URI.parse(candidate)
  return false unless uri.is_a?(URI::HTTPS) && ALLOWED_HOSTS.include?(uri.host)

  addresses = Resolv.getaddresses(uri.host)
  addresses.any? && addresses.none? { |address| internal?(address) }
rescue URI::InvalidURIError, Resolv::ResolvError, IPAddr::InvalidAddressError
  false
end
```

That rejects `http://` for the scheme, `https://localhost/admin` as loopback,
`https://169.254.169.254/latest/meta-data/` as link-local — the cloud metadata endpoint, usually the
objective — and anything unparseable. Set a timeout, and follow no redirects or re-check per hop, since an
allowlisted host can 302 to an internal address (`Net::HTTP.get_response` does not follow them on its own).
It is a check, not a guarantee — the name can re-resolve between check and connection — so keep the request
behind an egress-restricted network path where one exists.

**Grep for**: `Net::HTTP`, `URI.open`, `Faraday`, `HTTParty`, `httpx` and `Down.download`, wherever the
URL came from params or a user-editable column: webhook targets, avatar URLs, "import from URL".

## Command injection

**Safe form** — pass argv, so no shell parses the string:

```ruby
output, status = Open3.capture2e("clamscan", "--no-summary", file.path)
raise "clamscan failed (#{status.exitstatus}): #{output}" unless status.exitstatus.zero?
```

With `file.path` set to `x; echo PWNED-INJECTION-WORKED`, argv hands the whole thing to `clamscan` as one
argument where a backtick command executes the `echo`. Read the exit status you branch on, too: `clamscan`
exits 1 for "found" and 2 for "error", so a bare `!= 0` treats a scanner crash as a detection.

**Grep for**: backticks, `%x(`, and `system`, `exec`, `spawn`, `IO.popen` or `Open3.*` given one
interpolated string instead of separate arguments.

## Uploaded file types

**Safe form** — validate the type the server identified, not the one the client declared. Active
Storage re-identifies from the first 4 KB on attach (`blob/identifiable.rb:23,28`, reached from
`attached/changes/create_one.rb:12`), so `blob.content_type` already holds the identified value:

```ruby
class Avatar < ApplicationRecord
  has_one_attached :image
  validate :image_must_be_an_image

  private
    def image_must_be_an_image
      return unless image.attached?
      return if image.blob.content_type.in?(%w[image/png image/jpeg])
      errors.add(:image, "must be a PNG or JPEG")
    end
end
```

A PHP script uploaded as `photo.png` declaring `image/png` is identified as `text/x-php` and rejected, on
both the direct `io:` attach and the signed-id direct-upload path.

**Grep for**: `params[:file].content_type` or `.original_filename` used as a decision, `identify: false`
(the documented bypass), an attachment under `public/`, a missing byte-size limit.
