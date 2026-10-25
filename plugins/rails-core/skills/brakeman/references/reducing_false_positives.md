# Reducing False Positives in Brakeman

Strategies and techniques for minimizing false positives while maintaining security coverage.

## Understanding False Positives

False positives occur when Brakeman reports a potential vulnerability that isn't actually exploitable. This happens because static analysis must make conservative assumptions without runtime context.

**Common causes of false positives:**
- Custom sanitization methods Brakeman doesn't recognize
- Database values treated as unsafe by default
- Indirect data flow Brakeman can't track
- Business logic that prevents exploitation
- Already-secured code patterns Brakeman doesn't understand

**Important**: Always investigate warnings before dismissing them as false positives. Many "false positives" are actually real vulnerabilities.

## Strategy 1: Triage in confidence order

`-w3`, `-w2` and `-w1` are a reading order for a first pass, not a filter to
commit. `SKILL.md` has the mapping and the inversion.

The one point specific to false positives: a standing `-w2` in CI hides every
`Weak` warning, and `Redirect` matters on this stack at that level. On a
`load_defaults 7.0`-or-later app it fires only when someone passed
`allow_other_host: true`. Keep the default `-w1` in CI and use the higher levels
while working through a backlog. `Unscoped Find` is `Weak` too, but `-w1` alone
does not surface it: it is an optional check and needs `-E UnscopedFind` or `-A`.

## Strategy 2: Mark Safe Methods

Tell Brakeman about custom sanitization or escaping methods.

### Command-line Approach

```bash
# Mark methods as safe for HTML output
brakeman --safe-methods sanitize_user_input,escape_html

# Mark methods as safe for URLs
brakeman --url-safe-methods normalize_url,safe_url
```

### Configuration File Approach

The values must be YAML **symbols**. The command-line parser converts names to
symbols (`options.rb:187`), and the checks merge them into a `Set` of symbols
(`check_cross_site_scripting.rb:298`), but the YAML loader permits `Symbol`
without converting `String` (`brakeman.rb:175-178`). A list of plain strings is
therefore accepted and has no effect — verified: with plain strings the warning
remained, and with symbols it was suppressed.

```yaml
# config/brakeman.yml
---
:safe_methods:
  - :sanitize_user_input
  - :escape_html
  - :clean_content
:url_safe_methods:
  - :normalize_url
  - :validate_url
:sql_safe_methods:
  - :quoted_range
```

`brakeman --safe-methods sanitize_user_input -C` prints the correct YAML, which is
the reliable way to get this right.

### Example Scenario

**Your code:**
```ruby
# app/helpers/sanitizer_helper.rb
module SanitizerHelper
  def sanitize_user_input(text)
    ActionController::Base.helpers.sanitize(text, 
      tags: %w[p br strong em],
      attributes: %w[href title]
    )
  end
end

# app/views/posts/show.html.erb
<%= raw sanitize_user_input(@post.content) %>
```

The `raw` is what makes this a Brakeman question. `<%= sanitize_user_input(...) %>`
on its own produces no warning at Rails 8.1, because ERB escapes the result —
verified by scan. So reach for `--safe-methods` only where the output genuinely
must not be escaped again, which means the method itself has to return safe
markup.

**Without marking as safe**: Brakeman warns about unescaped output at Weak
confidence.

**After marking as safe**:
```bash
brakeman --safe-methods sanitize_user_input
```

No warning — verified. Which puts the whole guarantee inside your method, so read
it before you register it.

## Strategy 3: Fix a database-value warning at the render site

Brakeman treats a database value as potentially unsafe, because the column may carry user
input. Where that warning is wrong, the render site is what changes. The
`--ignore-model-output` flag at the end of this section is the last resort, not the first move.

**Escape at the render site first.** Rails 8.1 escapes `<%= value %>` by default,
so a model attribute rendered normally produces no warning at all. A
`Cross-Site Scripting` warning on a model attribute means the template asked for
raw output, and the render site is where to fix it:

```erb
<%= @post.content %>
```

Where the column genuinely holds markup that must render, sanitize at the render
site and register the helper, so the original value stays intact and every
existing row is covered:

```ruby
# app/helpers/posts_helper.rb
module PostsHelper
  def rendered_post_body(post)
    sanitize(post.content, tags: %w[p br strong em a], attributes: %w[href title])
  end
end
```

That form scans clean on Rails 8.1 without any configuration — verified — so reach
for `--safe-methods rendered_post_body` only if your helper does something
Brakeman flags, such as returning `raw` output.

Sanitizing in a `before_validation` instead destroys the original irreversibly,
leaves every row written before the callback existed untouched, and reaches into
`ActionController::Base.helpers` from a model.

### Ignore Model Output (last resort)

```bash
# Consider every model attribute XSS-safe
brakeman --ignore-model-output
```

This is class-wide: it suppresses database-sourced XSS across the whole
application, including columns added later. Reach for it only where you can say
which columns exist and why none of them can carry markup — which on a young
application with no production data is not yet knowable.

## Strategy 4: Run Specific Checks

Focus on the most critical vulnerability types for your application.

```bash
# Security-critical checks only. Command injection is the Execute check.
brakeman -t SQL,CrossSiteScripting,Execute,MassAssignment,UnsafeReflection

# Exclude a check that does not apply to this application
brakeman -x DefaultRoutes
```

**When to use**: When specific check types produce many false positives but you still want coverage of critical issues.

**Available checks**:
```bash
brakeman --checks
brakeman --optional-checks
```

Check names on the command line are written without the `Check` prefix; the
option parser adds it. A name that resolves to nothing exits 6 —
`brakeman -t Authentication` reports `Could not find specified check:
CheckAuthentication`, because the `Authentication` **warning type** comes from
`CheckSecrets` and `CheckSkipBeforeFilter`. `warning_types.md` (beside this file) maps
every warning type to its check class.

Two exclusions to skip: `LinkTo` is gated to Rails 2.0-2.9.9 so excluding it does
nothing on this stack, and the check people mean by that name — `LinkToHref` — is
one you want on. Excluding `Redirect` on a `load_defaults 7.0`-or-later app
removes the one warning that tells you someone passed `allow_other_host: true`.

**Cost of a committed exclusion**: `-x` and `:skip_checks:` also exclude every
future improvement to that check, so keep exclusions in the command you type
rather than in the config you commit.

## Strategy 5: Skip Problematic Code

Some legacy or generated code may produce unavoidable false positives.

Values are literal paths, not globs: `AppTree.regex_for_paths` runs each entry
through `Regexp.escape` (`app_tree.rb:37-55`), so a `*` matches a literal
asterisk and `db/migrate/*` matches nothing. Give the directory, ending in `/`.

```bash
# Skip specific files or directories
brakeman --skip-files lib/legacy/,db/seeds/

# Skip a whole generated directory, and one file by name
brakeman --skip-files db/migrate/,db/schema.rb
```

### Configuration File

```yaml
# config/brakeman.yml
---
:skip_files:
  - lib/legacy/
  - app/models/auto_generated.rb
```

`vendor/` is already skipped by default (`--skip-vendor`), and listing it adds an
unanchored substring match. `node_modules/` sits outside the paths Brakeman
scans.

**Best practice**: Use sparingly and document why files are skipped.

## Strategy 6: Use Interactive Ignore Tool

The interactive ignore tool helps you review and document false positives systematically.

```bash
brakeman -I
```

### Interactive Workflow

Brakeman asks for the ignore file first, then shows the opening menu.

1. **Opening menu**, four choices (`interactive.rb:57-79`):
   - `1` - Inspect all warnings
   - `2` - Inspect new warnings
   - `3` - **Prune obsolete ignored warnings** — this deletes every fingerprint
     that no longer matches code, and saving writes the deletion
   - `4` - Skip, and use the current ignore configuration

2. **For each warning** (`interactive.rb:109-119`, verbatim):
   - `i` - Add warning to ignore list
   - `n` - Add warning to ignore list and add note
   - `s` - Skip this warning (will remain ignored or shown)
   - `u` - Remove this warning from ignore list
   - `a` - Ignore this warning and all remaining warnings
   - `k` - Skip this warning and all remaining warnings
   - `q` - Quit, do not update ignored warnings
   - `?` - Display this help

3. **Before saving**, when obsolete entries exist, Brakeman offers to prune them,
   then presents the save menu.

To leave without changing anything, `4` at the opening menu and `q` per warning
both do that. `3` is the pruning option, not the bail-out.

`-I` needs a TTY. HighLine is vendored inside the gem
(`brakeman-8.0.5/bundle/`, loaded by `Brakeman.load_brakeman_dependency`), so no
extra gem is needed.

### Best Practices for Notes

Let `-I` write the file and edit the notes in place. Brakeman's `save_to_file`
emits the full warning hash for every entry plus a `:brakeman_version` key, so a
hand-written file gets rewritten wholesale the next time you run `-I`, and an
entry with no `note` key at all raises `NoMethodError` under
`--ensure-ignore-notes`, which calls `i[:note].strip`.

A written entry looks like this, abridged — the note is the part you author:

```json
{
  "ignored_warnings": [
    {
      "warning_type": "Dynamic Render Path",
      "warning_code": 15,
      "fingerprint": "a71bd849b9200e92ee95ea7de89060fe98512c1e9565a4eb2afd75b4a3d006f4",
      "check_name": "Render",
      "message": "Render path contains parameter value",
      "file": "app/controllers/reports_controller.rb",
      "line": 12,
      "confidence": "Weak",
      "note": "Template name comes from REPORT_TEMPLATES.fetch, so the set is fixed"
    }
  ],
  "brakeman_version": "8.0.5"
}
```

Write notes that name the mechanism, not a location. A note saying "validated in
application_controller.rb line 45" is wrong the moment anyone edits that file;
"the value passes through `REPORT_TEMPLATES.fetch`, which raises on anything else"
stays true. `SKILL.md` covers how far one entry reaches, which is the other reason
to name the mechanism: the entry follows the method rather than the line.

## Strategy 7: Put the guarantee in the code

When business logic is what prevents exploitation, express it in the query rather
than in a comment beside the query.

```ruby
def show
  @user = viewable_users.find(params[:id])
end

private

def viewable_users
  current_user.admin? ? User.all : current_user.managed_users
end
```

A comment naming another file and line is wrong the moment anyone edits that file,
and no check can read it. Where a warning genuinely has to stay, the justification
belongs in the ignore entry's `note`, versioned next to the fingerprint it
explains.

## Strategy 8: Refactor to shapes Brakeman can follow

The refactorings below are worth doing on their own merits. Two notes on what
Brakeman actually reports, so the reason you give matches the tool's behaviour.

### Example 1: Scoped Finds

`Post.find(params[:id])` does **not** warn on a default scan. `Unscoped Find` is
an optional check (`-E UnscopedFind` or `-A`), it only inspects models with a
non-optional `belongs_to`, and it reports at Weak confidence. So scope the query
because it is the authorization boundary, not because the scanner asked.

```ruby
def destroy
  post = current_user.posts.find(params[:id])
  post.destroy
end
```

### Example 2: Explicit Rendering

`render params[:template]` is a High-confidence `Dynamic Render Path` warning —
verified by scan. Map the parameter to a template you name, so the reachable set
is written down:

```ruby
REPORT_TEMPLATES = { "summary" => "reports/summary", "detail" => "reports/detail" }.freeze

def show
  render REPORT_TEMPLATES.fetch(params[:view], "reports/summary")
end
```

### Example 3: Strong Parameters

`User.create(params[:user])` is a `Mass Assignment` warning. Filter the
attributes:

```ruby
def create
  User.create(user_params)
end

private

def user_params
  params.expect(user: [:name, :email])
end
```

`params.expect` is the current form at Rails 8.1. Which of `expect`, `permit` and
`params[...]` fits a given action depends on the parameter shape; the
`rails-8-idioms` skill states that rule in its "Strong parameters: pick the form from the shape
of the incoming params" section.

## Strategy 9: Regular Review Cycles

Revisit the ignore configuration on a cycle; it is not a set-and-forget file.

### Review process

1. **Read the ignored warnings.** The HTML and JSON reports always include them,
   so any report you already generate shows the list:
   ```bash
   brakeman -o tmp/review.html
   ```
   For the text report, `--show-ignored` adds them
   (`report_text.rb:24`), and it does not change the exit code:
   ```bash
   brakeman --show-ignored --no-pager
   ```

2. **Question each ignored warning**:
   - Is the justification still valid?
   - Has the code changed?
   - Could we refactor to eliminate the warning?

3. **Update ignore list**:
   ```bash
   brakeman -I
   ```

4. **Look for patterns, and write the list down**:
   - Where several ignored warnings share a `warning_type`, name the shared cause and
     the one code change that would retire all of them together.
   - Where the same false positive recurs across files, propose the sanitizer or the
     wrapper that stops Brakeman flagging it, rather than another ignore entry.
   - This step ends with a written list. An empty list is a valid result; report it
     rather than leaving the step silent.

## Strategy 10: Layered Defense

Accept that some false positives will remain, but layer other defenses.

### Complementary Security Measures

1. **Code review**: Human review catches what tools miss
2. **Dynamic testing**: Penetration testing and security scans
3. **WAF rules**: Web Application Firewall protects at runtime
4. **Input validation**: Strong input validation at boundaries
5. **Output encoding**: Consistent encoding in views
6. **Security headers**: CSP, X-Frame-Options, etc.
7. **Dependency scanning**: bundler-audit, Dependabot
8. **Security testing**: Automated security test suites

**Philosophy**: Brakeman is one tool in a comprehensive security program.

## Common False Positive Patterns

### Pattern 1: Admin-Only Endpoints

**Issue**: Brakeman doesn't understand authorization logic.

```ruby
class AdminController < ApplicationController
  before_action :require_admin

  def destroy_user
    User.find(params[:id]).destroy
  end
end
```

This warns only when `UnscopedFind` is enabled (`-E UnscopedFind` or `-A`), only
because `User` has a non-optional `belongs_to`, and then at Weak confidence — so
on a default scan there is nothing to triage here.

**Solutions**, in order:
1. Scope the query to the set the current user may act on, which makes the
   authorization visible in the code.
2. If the `before_action` genuinely is the whole guarantee, ignore the warning
   with a note naming the callback and what it enforces.

### Pattern 2: Enum Values

**Issue**: Brakeman doesn't track that params contain only enum values.

**Example**:
```ruby
class User < ApplicationRecord
  enum :status, { active: 0, inactive: 1, pending: 2 }
end

User.where("status = '#{params[:status]}'")  # Warns about SQL injection
```

**Solution**: pass the value as a bind parameter and let the enum type map the
name:

```ruby
User.where(status: params[:status])
```

That clears the warning, which is what this section is about.

Note what it does not do. `EnumType#serialize` is `subtype.serialize(mapping.fetch(value, value))`
(`enum.rb:195-197`), and an unmapped string serializes to `nil` — verified
against ActiveRecord 8.1.3.1 — so an unknown status becomes `WHERE status IS NULL`
and matches nothing rather than raising. `ArgumentError: 'bogus' is not a valid
status` comes from `assert_valid_value`, which runs on assignment, not in `where`.
`User.statuses[params[:status]]` has the same nil outcome for a different reason.
When an unrecognised value should be an error rather than an empty result, say so:

```ruby
def filter_status
  User.statuses.key?(params[:status]) ? params[:status] : (raise ActionController::BadRequest)
end
```

### Pattern 3: Internal Data

**Issue**: Data from internal APIs treated as unsafe.

**Example**:
```ruby
# Data from internal microservice
response = InternalAPI.fetch_user_data(user_id)
render json: response.body.html_safe  # Warns about XSS
```

**Solutions**:
1. Return the response as data rather than as markup; `html_safe` on an API response is
   the defect
2. Parse and re-encode: `render json: JSON.parse(response.body)`
3. If truly safe, mark the API method as safe

### Pattern 4: Path Validation

**Issue**: Brakeman doesn't see path validation logic.

**Example**:
```ruby
def download
  file = params[:file]
  if file =~ /\A[a-z0-9_\-]+\.pdf\z/i
    send_file "downloads/#{file}"  # Still warns
  end
end
```

**Solutions**:
1. Use more explicit path construction:
   ```ruby
   filename = File.basename(params[:file])
   safe_path = Rails.root.join('downloads', filename)
   send_file safe_path if File.exist?(safe_path)
   ```
2. Document validation in ignore note

### Pattern 5: Constant Values

**Issue**: Brakeman conservative about what's truly constant.

**Example**:
```ruby
TEMPLATE_MAP = {
  'profile' => 'users/profile',
  'settings' => 'users/settings'
}

render TEMPLATE_MAP[params[:view]]  # May warn
```

**Solution**: Brakeman resolves a literal constant and usually stays quiet. Where it still
warns, add an ignore entry whose note names the constant, because the value can only be one
of the map's own strings.

## A committed configuration that keeps coverage

Keep every check enabled and put the accepted findings in the ignore file, where
each one carries a note and a fingerprint. A committed `:run_checks:` allow-list
is the opposite trade: a ten-entry list turns off roughly seventy of the
seventy-nine checks — `LinkToHref`, `ContentTag`, `RenderInline`, `I18nXSS`,
`SanitizeConfigCve`, `Redirect`, `Deserialize`, `YAMLParsing`,
`TemplateInjection`, `SessionSettings`, `SSLVerify`, `EOLRails`,
`PermitAttributes` and `VerbConfusion` among them — and it silently excludes every
check added by a future release.

```yaml
# config/brakeman.yml
---
# Every check on, warnings and errors both fail the build. All three are the
# defaults; they are written out here so a reader can see the intent.
:exit_on_warn: true
:exit_on_error: true
:min_confidence: 2

# The accepted findings live here, each with a note
:ignore_file: config/brakeman.ignore

# Generated code that produces unavoidable noise
:skip_files:
  - db/migrate/
  - db/schema.rb

# Sanitizers Brakeman does not know about, as symbols
:safe_methods:
  - :sanitize_user_input

:quiet: true
```

Three details this template exists to get right:

- **`:min_confidence:`, not `:confidence_level:`.** The latter is not an option,
  and an unrecognised key is merged and ignored, so it filters nothing. The
  values are inverted: `0` is High only, `1` is High and Medium, `2` is
  everything.
- **`:output_format:` takes a symbol**, and it cannot be combined with more than
  one `:output_files:` entry — that raises `Cannot specify output format if
  multiple output files specified`. Give the output files their extensions and
  omit `:output_format:` entirely.
- **Check names in YAML carry the `Check` prefix.** `:run_checks: [SQL]` exits 6;
  `:run_checks: [CheckSQL]` runs. The command line is the other way around.

Generate the file rather than typing it: `brakeman <your flags> -C` prints the
config equivalent of the flags you just used, with the right keys, the right
inversion, and the right symbols.

Enforce the hygiene in CI instead of asking a human to remember it:

```bash
brakeman --ensure-ignore-notes --ensure-no-obsolete-ignore-entries
```

Those exit 8 and 9 respectively, so "we always add notes" and "we review the
list" become build failures rather than intentions.

## Progressive Improvement Strategy

### Phase 1: Establish Baseline (Week 1)
```bash
# 1. Run initial scan
brakeman -w3 -o baseline-high.json -o baseline-high.html

# 2. Fix all high confidence warnings (or document why not)
brakeman -I

# 3. Commit ignore file
git add config/brakeman.ignore
```

### Phase 2: Medium Confidence (Week 2-4)
```bash
# 1. Review medium confidence
brakeman -w2 -o baseline-medium.json

# 2. Fix real issues, ignore false positives with notes
brakeman -I

# 3. Update ignore file
git add config/brakeman.ignore
```

### Phase 3: Weak Confidence (Month 2)
```bash
# 1. Review remaining warnings
brakeman -w1 -o baseline-all.json

# 2. Triage systematically
brakeman -I
```

### Phase 4: Maintain (Ongoing)
```bash
# 1. The gate. On a Rails 8.1 app this is bin/ci's Brakeman step.
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error

# 2. Ignore-file hygiene, enforced rather than scheduled
brakeman --ensure-ignore-notes --ensure-no-obsolete-ignore-entries

# 3. Periodic comprehensive scan, optional checks included
brakeman -A -w1 --no-pager
```

## Red Flags: When It's NOT a False Positive

Be especially careful dismissing warnings in these cases:

1. **User input flows to sensitive operations**: SQL queries, system commands, file operations
2. **Authentication/authorization bypasses**: access control issues, which no check covers
3. **Mass assignment on sensitive models**: User, Admin, Payment models
4. **Eval-family functions**: `eval`, `instance_eval`, `class_eval`
5. **`Marshal.load` on anything a request can reach**: still arbitrary object
   construction, with no safe mode
6. **Anything reached from a sink Brakeman does not check at all** — SSRF and XML
   entity expansion have no check, so a clean report says nothing about them

**When in doubt, treat it as real and prove otherwise.**

### The exception worth knowing: `YAML.load`

Brakeman reports `YAML.load(params[:data])` as `Remote Code Execution` at High
confidence. On this stack that is a false positive with a checkable
justification: psych 5.3.1's `YAML.load` already refuses unlisted classes and
aliases — verified, `YAML.load("--- !ruby/object:Time {}")` raises
`Psych::DisallowedClass` and an alias raises `Psych::AliasesNotEnabled`. Record
that in the ignore note, and keep `permitted_classes` explicit at the call site so
the note stays true:

```ruby
YAML.safe_load(params[:data], permitted_classes: [Date])
```

`Marshal.load` is a different matter and has no equivalent defence.

## Tools for Validation

After marking something as a false positive, validate your assumption. Item 2 is the one to
write here, and it is what makes the claim checkable. Items 1, 3 and 4 need a person, so name
them in the report as work for the team rather than reporting them done:

### 1. Manual Testing
Try to exploit the vulnerability yourself.

### 2. Security Test
Write a request spec that asserts the property you claimed:
```ruby
# spec/requests/posts_spec.rb
RSpec.describe "Posts", type: :request do
  it "escapes markup in post content" do
    post = Post.create!(content: "<script>alert('xss')</script>")

    get post_path(post)

    expect(response.body).to include("&lt;script&gt;")
    expect(response.body).not_to include("<script>alert")
  end
end
```

### 3. Code Review
Have another developer review the warning and your justification.

### 4. Penetration Testing
Include in penetration test scope.

## Summary: Balanced Approach

1. **Start conservative**: Review all high confidence warnings
2. **Mark judiciously**: Only ignore with clear justification
3. **Document everything**: Future you will thank present you
4. **Review regularly**: Ignored warnings should be revisited
5. **Refactor when possible**: Better code beats configuration
6. **Layer defenses**: Static analysis is one tool among many
7. **Stay skeptical**: Most "false positives" deserve investigation

Remember: The goal isn't zero warnings. The goal is understanding every warning and making informed decisions about risk.
