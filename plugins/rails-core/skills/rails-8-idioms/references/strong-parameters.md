# What `params.expect` checks, and what it silently drops

The rules are in `SKILL.md`, section "Strong parameters: pick the form from the shape of the incoming
params". This file holds the mechanism behind them. Every claim here was executed against actionpack
8.1.3.1 on Ruby 3.4.5.

`expect` collects the top-level keys and calls `require` on the permitted result
(`strong_parameters.rb:772-777`), so it guards root keys only: a nested key of the wrong shape is filtered
out by `permit` and never checked.

```ruby
# `lines` arrives as a plain hash where an array of hashes was declared
params.expect(order: [:note, { lines: [[:sku, :qty]] }])
# => {"note" => "n"} — no raise, and `lines` is silently gone
```

A `fields_for` hash with numeric-string keys (`lines: { "0" => {...}, "1" => {...} }`) is a legitimate array
encoding and both `expect` and `permit` keep it, so the shape `expect` drops is specifically a *plain* nested hash where an
array was declared.
