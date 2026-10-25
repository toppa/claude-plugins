# 0010 — The guide's rule files are `UNTESTABLE-RULES.md` and `UNTESTABLE-CONVENTIONS.md`

## Context

`plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md` gives a project
two files for its rules: one for a rule about the product, and one for a rule about how we write
the code. Before 2026-10-09 the guide named them `RULES.md` and `CONVENTIONS.md`. Those names
came before the guide treated a test as documentation.

A private Rails 8.1, Inertia, and React application adopted the guide. Its sorting test then
gained a step that sends a rule to a spec, a lint rule, a type, or a database constraint, before
the rule reaches either file. On 2026-10-06 one commit in that application moved a rule out of
`RULES.md` and into a spec, and another replaced a comment with a spec. So each file now holds
only the rules that no automated test can hold.

An adopter who sees `RULES.md` reads a complete list of the project's rules. Where the file has
no entry, that reader concludes that no rule exists, though a spec may hold one.

## Decision

**The guide names the two files `UNTESTABLE-RULES.md` and `UNTESTABLE-CONVENTIONS.md`.** An
automated test is a spec, a lint rule, a type, or a database constraint that runs in CI and goes
red on the wrong change. A script that a person runs by hand is not one. The guide's section "The
homes" holds that definition, and its table of homes has a row for the automated tests.

**The id prefixes stay `R-` and `C-`.** Each prefix comes from the last word of the file's name,
so no citation in an adopting project changes.

**"Untestable" claims more than is true, and the error is useful.** A test could hold some
entries, at a cost. A reader who finds such a test moves the rule into it and deletes the entry,
as the guide's section "Rules" asks.

## The alternatives that lost

**Keep the names, and state the scope in the map row and in each file's opening line.** The
name reaches a reader in every directory listing and every citation. The map row reaches them
once. The guide still states the scope in both places, in addition to the name.

**`PRACTICES.md`, `HOUSE-RULES.md`, `GUIDELINES.md`, or `POLICIES.md`.** None of them says that
the file is partial. `POLICIES.md` also collides with the policy layer of a Rails application.

**`META-RULES.md`.** "Meta" means rules about rules, and few entries are that.

**`UNCHECKED-RULES.md`.** "Unchecked" reads as "not reviewed". A person reviews every entry, and
a document script checks some of them, such as one adopting project's rule on the wrap width of
a document.
