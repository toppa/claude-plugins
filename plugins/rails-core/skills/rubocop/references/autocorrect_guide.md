# RuboCop Autocorrect Guide

Safe versus unsafe correction, and the specific cops whose corrections need a
human. Verified against rubocop 1.89.0 and rubocop-performance 1.26.1.

**Every command here rewrites source files, so run the project's own RuboCop.** The
commands below are written `rubocop` for brevity. Write `bin/rubocop` where the binstub
exists, otherwise `bundle exec rubocop` — a bare `rubocop` takes whichever version is
first on `PATH`, and a different version corrects differently. `SKILL.md`, section
"Start here: what is actually enabled", states the rule.

## The three modes

```bash
rubocop -a    # --autocorrect: corrections marked SafeAutoCorrect
rubocop -A    # --autocorrect-all: every available correction
rubocop -x    # --fix-layout: the Layout department, safe corrections only
```

`-a` applies only corrections whose cop does not set
`SafeAutoCorrect: false`. `-A` additionally applies the ones that do — the ones
RuboCop itself marks as able to change what the program does.

**Run `-A` one cop at a time, from a clean working tree, and read the diff.**

```bash
git status --porcelain     # confirm nothing else is pending
rubocop -A --only Performance/Detect
git diff                  # read every hunk
bin/rails test            # or rspec
```

`rubocop -A` with no `--only` rewrites semantics across the whole project in one
pass, in files nobody asked you to touch, and the diff is then too large to
review honestly. `-a` across the project is fine; `-A` across the project is not.

## The safe sequence

```bash
# 1. Safe corrections, whole project.
rubocop -a

# 2. Read them.
git diff

# 3. Run the tests.
bin/rails test

# 4. One unsafe cop, deliberately.
rubocop -A --only Performance/Detect

# 5. Read and test again.
git diff && bin/rails test
```

A red run at step 3 or step 5 means the correction is wrong for this code. Discard it with
`git checkout -- .` — the clean tree at step 1 is what makes that safe — then either exclude
the cop for that path or make the change by hand. Never layer a fix on top of a correction
that broke the suite.

Committing is the user's call — offer the diff and let them decide. Where the user does ask
for a commit, name the files you reviewed: `git add -A` stages every unrelated change in the
tree, which is the opposite of one cop per commit.

## Which mode a cop needs

**Read the cop's config, not its name.** `--show-cops` prints `Safe` and
`SafeAutoCorrect` **only when the cop's own config sets them**, so grepping for
"safe" returns nothing both for a genuinely safe cop and for one whose safety is
undeclared. Verified: `--show-cops Style/StringLiterals | grep -i safe` prints
nothing; `--show-cops Performance/Detect | grep -i safe` prints
`SafeAutoCorrect: false`.

So the reliable check is the run itself:

```bash
# Reports how many offenses -a left behind for -A.
rubocop --only Style/FrozenStringLiteralComment
# => "1 more offense can be corrected with `rubocop -A`"
```

That sentence in the summary is the answer: if it appears, `-a` is not enough for
what remains.

Or ask for the full config and read it:

```bash
rubocop --show-cops Performance/Detect
# SafeAutoCorrect: false   <- -A only
```

## Safe corrections, in practice

```ruby
# Before
def method( x,y )
result=x+y
end

# After `rubocop -a`
def method(x, y)
  result = x + y
end
```

```ruby
# Style/StringLiterals with EnforcedStyle: double_quotes (omakase's setting)
# Before
message = 'Hello'
# After
message = "Hello"
```

```ruby
# Style/TrailingCommaInArrayLiteral with consistent_comma
array = [
  1,
  2,
  3,
]
```

**`Style/FrozenStringLiteralComment` is not in this group**, despite being a
one-line comment insertion. It carries `SafeAutoCorrect: false`, because
`default.yml`'s own comment on the `always` style says *"It is possible that this
will create errors"* — freezing every literal in a file can break a caller that
mutates one. Verified: `-a` leaves the file untouched and reports the offense;
`-A` adds the comment. So adding the magic comment across a project is an `-A`
job with tests after it, not a formatting pass.

## Corrections that need review

### `Performance/Detect`

```ruby
# Before
users.select { |u| u.admin? }.first

# After `rubocop -A --only Performance/Detect`
users.find { |u| u.admin? }
```

Two things to know. **The correction writes `find`, not `detect`**, because the
cop reads `Style/CollectionMethods`' `PreferredMethods` map, whose shipped entry
is `detect: find` (`detect.rb:124-125`). And **it rewrites the method name and
drops the `.first`; it does not touch the block** — a block is not converted to
`&:admin?`.

Why it needs review: `select` evaluates the block for every element and `find`
stops at the first match, so a block with side effects behaves differently.

```ruby
seen = []
users.select { |u| seen << u; u.admin? }.first   # seen gets every user
users.find    { |u| seen << u; u.admin? }        # seen stops at the first admin
```

The cop's own `@safety` note names a second case: it assumes the receiver is an
Array, and a Hash receiver can produce a false positive.

`Performance/Count` is the neighbouring cop with the ActiveRecord caveat — before
Rails 5.1, `count` ignored a block on a relation — and its own source says so.
`Performance/Detect` does not carry that warning.

### `Rails/FindBy`

```ruby
# Before
User.where(email: email).take

# After `rubocop -A --only Rails/FindBy`
User.find_by(email: email)
```

**The form this cop flags by default is `where(...).take`, not
`where(...).first`.** It ships `IgnoreWhereFirst: true`, so `where(...).first`
passes untouched — verified by invocation on both forms, and its
`RESTRICT_ON_SEND` is `%i[first take]` with an explicit
`return if ignore_where_first? && node.method?(:first)`. The cop's own
documentation gives the reason: *"`where(...).first` can return different results
from `find_by`. (They order records differently, so the 'first' record can be
different.)"* Set `IgnoreWhereFirst: false` to flag it anyway, and accept that
the correction can change which record you get.

### `Performance/FlatMap`

```ruby
# Before
array.map { |x| [x, x * 2] }.flatten(1)

# After `rubocop -A --only Performance/FlatMap`
array.flat_map { |x| [x, x * 2] }
```

**Bare `.flatten` with no argument is not flagged by default.** The cop ships
`EnabledForFlattenWithoutParams: false`, and the reason is the semantic gap:

```ruby
[[1, [2]]].map { |x| x }.flatten   # => [1, 2]     flattens all the way down
[[1, [2]]].flat_map { |x| x }      # => [1, [2]]   flattens one level
```

`flatten(1)` and `flat_map` do agree, which is why that form is the one the cop
corrects. Verified: `map { }.flatten` produces no offense, `map { }.flatten(1)`
does.

## Turning correction off

Per cop, keeping the report:

```yaml
Style/StringLiterals:
  Enabled: true       # keep reporting the offense
  AutoCorrect: false  # never rewrite it
```

Verified: the offense is reported and the file is unchanged under `-a`.

**There is no global equivalent.** `AllCops: AutoCorrect: false` passes
validation, because `AutoCorrect` is a common parameter, and then does nothing —
`AllCops` is never merged into per-cop configuration, so no cop ever reads it.
Verified: with that setting, `-a` still rewrote `'a'` to `"a"`. To skip
correction for a run, simply do not pass `-a` or `-A`; that is the default.

To vary a cop by path, use a per-directory `.rubocop.yml`. Declaring the same cop
twice in one file does not work — YAML keeps only the last block, and RuboCop
reports `'Style/StringLiterals' is concealed by line N`.

## Selective correction

```bash
rubocop -a --only Style/StringLiterals
rubocop -a --only Style/StringLiterals,Layout/TrailingWhitespace
rubocop -a --only Layout                     # a whole department
rubocop -a app/models                        # a path
```

`--only` also overrides an inherited `Enabled: false`, so on an omakase project
this is how you correct one cop the config does not run.

## The todo-file route

For an existing codebase, `.rubocop_todo.yml` beats a mass correction: the cop
goes live for new code immediately and the backlog shrinks one cop per commit.

```bash
rubocop --auto-gen-config
# .rubocop.yml: inherit_from: .rubocop_todo.yml

rubocop -a --only Style/StringLiterals
# review, test, commit, delete that cop's entry from .rubocop_todo.yml
```

## Editor integration

```bash
# Corrected source on stdout, diagnostics on stderr.
printf 'def bad( x,y )\n  x+y\nend\n' | rubocop -a --stdin - --stderr

# With a filename, so path-scoped Include/Exclude rules apply.
rubocop -a --stdin app/models/user.rb --format quiet
```

Both forms are verified. The filename form matters on an omakase project, where
`Style/StringLiterals` only applies under `app/`, `config/`, `lib/`, `test/` and
`Gemfile` — pass `-` and the path-scoped cops do not fire.

## Troubleshooting

**Nothing was corrected.** Check, in order: is the cop enabled
(`--show-cops <Cop>`); does it support correction at all (`--show-cops` prints
`# Supports --autocorrect` above cops that do, and no `Metrics` cop does); does
it need `-A` (the run summary says so); is `AutoCorrect: false` set for it.

**Corrections conflict.** RuboCop makes several passes but does not always reach
a fixed point. Run `-a` again; if the second run still reports offenses in the
same place, two cops disagree and one of them needs disabling.

**The diff is larger than expected.** Almost always `-A` without `--only`, or a
department-level `Enabled: true` added in the same change. Reset, enable one cop,
and repeat.
