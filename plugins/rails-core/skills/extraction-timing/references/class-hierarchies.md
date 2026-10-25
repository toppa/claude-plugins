# Class hierarchies: STI and delegated types

The rule is in `SKILL.md`, section "STI vs delegated types". This file holds the table shapes, the
declarations, and what Rails documents. Verified against activerecord 8.1.3.1.

Rails 8.1 documents three ways to map a class hierarchy onto tables: purely abstract classes (class-table
inheritance), single-table inheritance, and delegated types
(`activerecord-8.1.3.1/lib/active_record/delegated_type.rb:8-11,30`). `delegated_type` is the mechanism for
the divergent-subtype case, so it is STI's counterpart here. A polymorphic `belongs_to` is not on that list:
it lets one association point at several unrelated models, which is a different problem from sharing a
hierarchy's attributes.

| | STI | Delegated types |
|--|-----|-----------------|
| **Table** | One shared table with a `type` column | A concrete parent table holding the shared attributes, plus one table per subtype, linked by `<name>_type` and `<name>_id` |
| **Declared as** | `class Message < Entry` | `delegated_type :entryable, types: %w[ Message Comment ]` on the parent (`delegated_type.rb:43`) |

Rails states the boundary in its own words: "STI works best when there's little divergence between the
subclasses and their attributes", because the alternative it warns about is "a single mega table with all
the attributes from all subclasses. No matter how divergent" (`delegated_type.rb:25-28`). No source
publishes a threshold for how much divergence is too much; read the columns and judge.
