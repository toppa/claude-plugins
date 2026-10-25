# Custom Cops Guide

Writing a project-specific cop. Every listing here was executed against rubocop
1.89.0, rubocop-ast 1.50.0 and rspec-core 3.13.6.

Reach for a custom cop when a rule is mechanical, project-specific, and worth
enforcing on every file — a deprecated internal API, a house naming rule. If the
rule needs judgement, it belongs in review, not in a cop.

## The cop

```ruby
# lib/rubocop/cop/custom/prefer_new_method.rb
# frozen_string_literal: true

module RuboCop
  module Cop
    module Custom
      class PreferNewMethod < Base
        extend AutoCorrector

        MSG = "Use `new_method` instead of `old_method`."
        RESTRICT_ON_SEND = [:old_method].freeze

        def_node_matcher :old_method_call?, <<~PATTERN
          (send _ :old_method ...)
        PATTERN

        def on_send(node)
          return unless old_method_call?(node)

          add_offense(node.loc.selector) do |corrector|
            corrector.replace(node.loc.selector, "new_method")
          end
        end
      end
    end
  end
end
```

Three details carry weight.

**The receiver placeholder is `_`, not `...`.** Write
`(send ... :old_method ...)` and the pattern compiles, runs, and **silently
misses every call that has arguments**. rubocop-ast reduces that pattern to
`:old_method === node.children[-1]` — a test against the *last* child, which is
the method name only when there are no arguments. Measured:

| Source | `(send ... :old_method ...)` | `(send _ :old_method ...)` |
|---|---|---|
| `a.old_method` | `true` | `true` |
| `a.old_method(1)` | `nil` | `true` |
| `a.old_method(1, 2)` | `nil` | `true` |

A cop built on the first pattern passes a hand-test on the no-argument case and
then never fires in production.

**`RESTRICT_ON_SEND` is a performance gate, not a filter.** It stops `on_send`
being called for unrelated method names. The pattern still has to do the real
check.

**Offend on the range you intend to correct.** `add_offense(node)` underlines the
whole expression, including the receiver and arguments; `node.loc.selector` is
just the method name, which is what the corrector replaces here. The two should
agree, or the caret in the output points somewhere the fix does not touch.

## Loading it

```yaml
# .rubocop.yml
require:
  - ./lib/rubocop/cop/custom/prefer_new_method.rb

Custom/PreferNewMethod:
  Enabled: true
  Description: 'Use new_method instead of old_method'
```

**`require:` is the correct key for a project file; `plugins:` is not.**
`plugins:` expects a lint_roller plugin class and fails on a plain path with
*"the corresponding plugin class could not be determined for instantiation"* —
and RuboCop's own error message tells you to switch to `require:`. The
deprecation of `require:` applies to gem extensions, not to local files.

Verified end to end:

```
probe.rb:3:8: C: [Correctable] Custom/PreferNewMethod: Use new_method instead of old_method.
client.old_method(1, 2)
       ^^^^^^^^^^
```

## Reading the AST

```bash
# Prints the AST. This is the tool for pattern work.
ruby-parse -e "client.old_method(1, 2)"
# (send
#   (send nil :client) :old_method
#   (int 1)
#   (int 2))
```

`rubocop --debug` does **not** print an AST. It prints the configuration
inheritance chain and the files being scanned, which is the right tool for "which
config am I actually using" and no help at all here.

## The spec

This spec is RSpec. Check the `Gemfile` before writing it, as `extensions_guide.md` says for
the `RSpec/*` cops.

```ruby
# spec/rubocop/cop/custom/prefer_new_method_spec.rb
# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/custom/prefer_new_method"

RSpec.describe RuboCop::Cop::Custom::PreferNewMethod, :config do
  let(:config) { RuboCop::Config.new }

  it "registers an offense and corrects a call with arguments" do
    expect_offense(<<~RUBY)
      client.old_method(1, 2)
             ^^^^^^^^^^ Custom/PreferNewMethod: Use `new_method` instead of `old_method`.
    RUBY

    expect_correction(<<~RUBY)
      client.new_method(1, 2)
    RUBY
  end

  it "registers an offense on a call with no arguments" do
    expect_offense(<<~RUBY)
      client.old_method
             ^^^^^^^^^^ Custom/PreferNewMethod: Use `new_method` instead of `old_method`.
    RUBY

    expect_correction(<<~RUBY)
      client.new_method
    RUBY
  end
end
```

Both examples pass. Four things make the difference between this and a spec that
cannot run:

- **`require "rubocop/rspec/support"`.** It is what defines `expect_offense` and
  `expect_correction`, and it registers the `:config` metadata hook.
- **`:config` plus `let(:config)`.** Without them the cop is built with no
  configuration, and any cop that reads a parameter raises. `described_class.new`
  by hand has the same problem.
- **The annotation includes the cop name.** `expect_offense` compares against the
  full displayed message, so the caret line must read
  `Custom/PreferNewMethod: Use ...`, not just `Use ...`. Omitting the prefix is
  the most common first failure, and its diff is a one-character-looking
  mismatch that is actually a missing prefix.
- **`expect_correction` takes only the corrected source, and must follow an
  `expect_offense` in the same example.** It reads the source that
  `expect_offense` already parsed; it has no second heredoc for a "before"
  state.

Write the second example. A pattern bug of the kind above passes the
no-argument case and fails only the with-arguments case, so a single example is
exactly the coverage that hides it.

## Running it

```bash
rspec spec/rubocop/cop/custom/prefer_new_method_spec.rb
rubocop --config .rubocop.yml --only Custom/PreferNewMethod app
```

## References

- [RuboCop AST](https://github.com/rubocop/rubocop-ast)
- [Node Pattern](https://github.com/rubocop/rubocop/blob/master/docs/modules/ROOT/pages/node_pattern.adoc)
- [Development Guide](https://docs.rubocop.org/rubocop/development.html)
