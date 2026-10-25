---
name: review-ruby-code
description: Review Ruby and Rails code by reading a diff — Sandi Metz's four rules, SOLID, the code smells you find by reading, the Rails pattern to expect for each anti-pattern, per-diff security sinks, and test coverage.
when_to_use: >-
  Use when reviewing Ruby or Rails code — a diff, a branch, or a pull request — when
  checking for design problems or the code smells you find by reading, when a diff shows
  N+1 loading, a SQL injection sink, or unescaped output (XSS), and when the user
  mentions Sandi Metz, POODR, 99 Bottles, Shameless Green, SOLID, Law of Demeter, or
  "Tell, Don't Ask". For a measured smell count, complexity or duplication score, use the
  `rails-core:rubycritic` skill; for the whole-app security properties, the
  `rails-core:security-audit` skill.
metadata:
  upstream_repo: el-feo/ai-context
  upstream_path: plugins/ruby-rails/skills/review-ruby-code/SKILL.md
  upstream_ref: ae77f01b54c90589d8a16bbeb1afadd2f6fbd2fc
  upstream_version: ruby-rails 0.4.0
  synced: 2026-08-08
  verified_against: "Rails 8.1.3.1, Ruby 3.4.5, rubocop 1.89.0 via rubocop-rails-omakase 1.1.0, reek 6.5.0 and flog 4.9.4 via rubycritic 5.0.0, simplecov 1.1.0"
---

# Ruby Code Review

## Workflow

### 1. Detect scope

Keep this in one shell call. **Shell state does not persist between calls**, so a `BASE` assigned in
one call is empty in the next — and an empty `BASE` makes the range `...HEAD`, which git resolves as
`HEAD...HEAD`, an empty diff, with exit status 0.

```bash
BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | cut -d/ -f2)
BASE=${BASE:-$(git rev-parse --verify --quiet main >/dev/null && echo main || echo master)}
git diff --name-only --diff-filter=ACMR "$BASE...HEAD" | grep '\.rb$'
```

`git symbolic-ref` reads local refs and needs no network. `refs/remotes/origin/HEAD` is often unset
even in a healthy clone, which is what the fallback is for; do not run `git remote set-head` to fix
it, because that writes to someone else's repository.

If the command prints nothing, you are not on a feature branch with Ruby changes. Review the files
the user names instead.

### 2. Run analysis tools, if the project has them

**Check the `Gemfile` first.** Run what the project already has, and leave its `Gemfile` alone.

```bash
grep -E "^[[:space:]]*gem [\"'](rubycritic|simplecov)[\"']" Gemfile
```

Where `rubycritic` is in the bundle, pass it the changed files explicitly and **check that the list is
non-empty first**, because a run with no file arguments analyzes the whole application and still exits 0.
For coverage, read `spec/spec_helper.rb` for the gate the project wired up, because **SimpleCov reads no
`COVERAGE` variable of its own**. Both invocations, and the shell trap that empties the diff range, are in
[references/tool-runs.md](references/tool-runs.md) (~34 lines).

**When a tool is missing, say so once and review without it.** Steps 3 and 4 need no gems and carry
most of the value.

### 3. Analyze each changed file

**OOP Design** — Sandi Metz's four rules and SOLID:

| Signal | Aim for | Comment above | Published by |
|---|---|---|---|
| Class body | 100 lines | 100 lines | `Metrics/ClassLength` `Max: 100`, rubocop 1.89.0; Metz's rule 1 agrees |
| Method body | 5 statements | 10 lines | Metz's rule 2 says 5 **lines**; Reek 6.5.0's `TooManyStatements` allows 5 **statements**; `Metrics/MethodLength` allows 10 **lines** |
| Parameters | 4 | 5 | `Metrics/ParameterLists` `Max: 5` with `CountKeywordArgs: true`; Metz's rule 3 says 4 and counts hash options |
| Instance variables in a class | 4 | 4 | Reek 6.5.0's `TooManyInstanceVariables`. **Not a Metz rule** |
| Objects one controller action instantiates | 1 | 1 | Metz's rule 4 |

The class measure applies to models, controllers, and services alike. Metz's rule 4 continues
"**therefore** views can only know about one instance variable and views should only send messages to
that object" — one rule with a consequence, not two rules.

**The RuboCop numbers are review ceilings, not build failures**, because `rubocop-rails-omakase`
disables the `Metrics` department. [references/sandi-metz-rules.md](references/sandi-metz-rules.md),
"What each number is, and what publishes it", sources every row above; the `extraction-timing`
skill's "Extraction Thresholds" section sources the two length rows and owns the call on whether a
class has grown enough to extract. Reach
a cop deliberately with `bin/rubocop --only Metrics/MethodLength`, which overrides the inherited
disable. Reek's numbers do run wherever `rubycritic` is in the bundle, since it vendors Reek.

Also check: SRP, Open/Closed, Liskov, Interface Segregation, Dependency Inversion; the Law of Demeter
("only talk to your immediate friends"); and Tell, Don't Ask (objects make their own decisions). See
[references/sandi-metz-rules.md](references/sandi-metz-rules.md) (~511 lines) for the four rules with
their real source and rule zero, Law of Demeter, Tell Don't Ask and Shameless Green, and
[references/solid-principles.md](references/solid-principles.md) (~452 lines) for one executable
example per principle and the question that settles each.

**Code Smells** — the ones you find by reading, in four groups. `rubycritic` reports the ones a tool
can measure; this is the other half.

- Structural: Long Method, Large Class, Long Parameter List, Data Clump
- Coupling: Feature Envy, Message Chains, Inappropriate Intimacy
- Conditional: conditional complexity, a `case` on a type (a polymorphism candidate), speculative
  generality
- Naming: vague names (`Manager`, `Handler`, `Processor`, `Data`), methods with "and", flag parameters
- See [references/sandi-metz-rules.md](references/sandi-metz-rules.md), "Code smells" section, which
  names the Reek detector and default for each smell a tool can measure

**Rails Patterns** — expect these forms:

- Association reads inside a loop paired with `includes`, `preload`, or `eager_load`
- `normalizes` for attribute normalization; side effects explicit in a service or job rather than in
  `after_create` / `after_save`
- Business logic in services, complex queries in query objects, formatting in presenters
- Indexes on the columns queries filter and order by, partial where the column is not selective
- See [references/rails-patterns.md](references/rails-patterns.md) (~484 lines) for N+1 loaders,
  `normalizes`, service and query objects, indexes and caching

**Security** — read the diff for the ten sink classes, each of which has one canonical safe form:
SQL injection, cross-site scripting, over-broad serialization, mass assignment, unsafe reflection,
path traversal, open redirect, server-side request forgery, command injection, and uploaded file
types. The forms to expect: values handed to Active Record so it binds them; values printed in ERB so
the default escaping applies, with nothing opting out; `params.expect(model: [...])` for a nested
model key and `params.permit(...)` for flat root scalars; a fixed map rather than `constantize` on
request data; and a host allowlist rather than `allow_other_host: true`. See
[references/security-checklist.md](references/security-checklist.md) (~260 lines), which states each
safe form once and gives the grep pattern for the unsafe one.

Authorization and ownership scoping live elsewhere: `security-audit` owns broken access control, and
`authentication-flow` owns credentials and sessions. Invoke the one that fits.

**Test Coverage**

- Untested methods and uncovered lines — cross-reference with SimpleCov where it ran
- Missing edge case and error path coverage
- Test quality: behavior rather than implementation, and mocking that has not replaced the subject

### 4. Check codebase patterns

Before making suggestions, understand the patterns already in use:

```bash
ls app/services/ app/queries/ app/decorators/ app/presenters/ app/policies/ 2>/dev/null
```

Match recommendations to those patterns — naming conventions, abstraction layers, test framework. Name
the pattern the codebase already uses: presenters where it has presenters, decorators where it has those.

### 5. Report

Give every code reference a clickable link, so the reader can jump to the line:

```markdown
[description](file:///absolute/path/to/file.rb#L42)
```

Rank findings by severity:

- **Error** — security problems, reaching into another object's internals, tight coupling
- **Warning** — a rule violation that should be fixed
- **Info** — a suggestion
- **Pass** — code that follows the principles, worth naming

See [references/vscode-links.md](references/vscode-links.md) for the format and a link checker.

## Related skills

- `rubocop` — the cop configuration behind the numbers above, and how omakase changes them
- `rubycritic` — the smells and complexity a tool measures, and what its score means
- `brakeman` — running the security scanner and reading its warnings
