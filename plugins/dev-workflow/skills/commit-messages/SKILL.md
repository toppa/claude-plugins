---
name: commit-messages
description: >-
  The text of a git commit — the Conventional Commits subject and its scope, a
  body that carries the why, Markdown footnotes for URLs, and the
  first-person-plural voice this house writes in.
when_to_use: >-
  Use when you draft a commit message, amend one, or rewrite one in a rebase.
  Also use it when the user asks what a commit should say, or which type or
  scope a change takes. For how the work is split across commits in the first
  place, use the `dev-workflow:organize-commits` skill.
metadata:
  upstream_repo: none
  origin: >-
    A house convention. Written before this plugin, carried in a personal
    skills directory, and moved here on 2026-08-15 so it travels with the
    rest of the planning and commit workflow.
  synced: 2026-08-15
  verified_against: Conventional Commits 1.0.0
---

# Commit messages

Use the [Conventional Commits](https://www.conventionalcommits.org) format. Present the
proposed message to the user for review before you run `git commit`.

## Format

```
type(scope): subject

body

footnotes
```

- **type** — one of `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`,
  `chore`, `style`. Append `!` for a breaking change, as in `refactor!`.
- **scope** — almost always include one. Name the **feature or domain** the commit is
  about, not the class or the file the change lives in. A change to `CaptchaHelper` in
  service of a Turnstile bypass is `feat(Turnstile):`, not `feat(CaptchaHelper):`.
  Title-case it: `Turnstile`, `Checkout`, `SignUp`. Omit the scope only where no single
  one fits.
- **subject** — see the rules below.

A blank line separates the subject, the body, and the footnotes.

## Subject

- 72 characters or fewer. **72 is a house limit**; the Conventional Commits specification
  sets no length at all.
- Imperative mood — "add", not "added"; "fix", not "fixes".
- Lowercase after the colon.
- No trailing period.
- It completes the sentence *"If applied, this commit will ___"*.

## Body

Explain **why**. The diff already shows what changed. A body earns its place when it
carries one of these:

- Context the reviewer needs to understand the change.
- The reasoning behind a decision the diff does not make obvious.
- A consequence, a tradeoff, or a follow-up worth flagging.

Wrap the body at 72 columns — **also a house limit**. Omit the body for a trivial change
whose subject speaks for itself. Match its length to the complexity of the reasoning: a
straightforward change takes a sentence or two, and a real tradeoff takes more.

Write for a future reader who has the repository and nothing else:

- Describe the change as the final diff shows it, not the path you took to reach it.
  Where code was written one way and revised before the commit, the message covers only
  what was committed.
- Explain the change on its own terms. A plan document or a step number is ephemeral, and
  the reader will not have it.
- Describe an approach the commit rejects by what goes wrong with it, in the present
  tense. An earlier attempt, such as an unmerged PR, is ephemeral too, and the reader has
  no record of it.

## A body that explains several things marks a commit that does several things

Count the independent things the body has to explain. Where the count passes two, the
commit has more than one subject, and no rewrite of the message fixes that. Propose the
split, then write one message for each part. **Two is a house heuristic with no external
source.**

The `organize-commits` skill applies the same test before the edit, in its "Walk through
bundled changes before making them" section. That test counts the steps you are about to
take. This one counts the explanations you owe afterwards, so it catches a commit the first
count let through.

## Read the body back as the reviewer

The reviewer has the repository and no way to ask you a question, so each sentence answers
for itself. Read the body back after you leave the code, and apply these tests.

**Each paragraph opens with the change it describes, and the reason follows.** A reason that
comes first hides the change, and the reader skims past the one sentence that matters. A
reader who stops after the first sentence of a paragraph still knows what the commit did.

**Every sentence about behavior says whether it describes the old code or the new code.**
Tense alone does not carry this. "The metadata used to sit in a block" places itself, and so
does "they are keyword arguments now". "A keyword argument runs at the call site" places
neither, and the reader cannot recover which one you mean.

**A contrast names both of its halves.** Write "we send the whole hash, and not the one key
the old block set". A reader cannot rebuild the unstated half of "X, not Y", and the word
"instead" on its own names nothing that it replaces.

**Replace a pronoun with its noun where the thing it names sits more than one sentence
back**, which leaves the reader nothing to guess. **One sentence is a house heuristic with
no external source.**

**Each paragraph closes on something the reader can act on or remember.** State the
consequence in the same paragraph that raises the detail. Where you cannot say what the
reader does differently for knowing the detail, take the paragraph out.

**A reason is one the reader already accepts.** Where the reader would ask "why is that
bad?" after your reason, the reason needs its own reason, and the body starts a chain. Give
a consequence the reader already accepts, or cut the reason.

**Every fact in the body is one the diff does not already carry.** `git show` gives the
reviewer the file count, the renamed methods, and every mechanical edit. A number belongs in
the body only where it scopes a claim the reader acts on, as in "the metadata on 32 of these
calls used to sit in a block".

**Where the project already has a convention, name the convention and move on.** The reader
follows the same convention, so a justification for it reads as a justification for
something else.

**A sentence that compresses a step states the step.** "A separate issue covers the narrower
rule" names what happens and where. "A narrower rule is filed separately" leaves the reader
to work out both.

**A word that the code taught you is replaced by the behavior it names.** A library gives
its own names to its concepts, and after a session in the code those names read as plain
English. Rack::Attack calls the value that a throttle counts requests by a "key", so "a
per-person key" names nothing to a reviewer who does not know Rack::Attack. Write "count
requests per signed-in person".

**A decision names the file it lives in.** "The noise filters come from the Storefront app"
does not tell the reviewer of a seventeen-file commit where to look. Name the file that holds
the filters, `app/javascript/config/error_reporting.ts`. This does not repeat the diff,
because the diff lists that file but does not say that the decision is in it. Cut the details
that the reader can get from the diff. Keep the name of the file that holds a decision. A
one-file commit is the exception, because the diff already names the only file.

## Check the draft before you commit

Reading the body back settles the tests above. It settles neither of these, and a command
settles both.

**A factual claim in the body is one you ran.** A message asserts things about the
repository: what a change leaves behind, how many call sites remain, which files a later
change still has to touch. Each of those is one search away from confirmed or disproved. A
wrong one survives review, because the reviewer reads the diff and not the whole repository.

**The 72-column wrap is measured and not eyeballed.** A 73-character line reads as a
72-character line.

## Footnotes

Where a URL or a side note adds context, use a Markdown footnote in place of an inline
link:

```
feat(Turnstile): verify challenge tokens on signup

Add server-side verification so bots cannot bypass the widget by
posting directly to the signup endpoint[^1].

[^1]: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
```

Leave ticket IDs out. This house does not carry them in commit messages.

## Voice

- Describe the change in the imperative mood, matching the subject: "Move the parser
  into…", not "Moved…" or "The parser was moved…".
- Use the first person plural for reasoning and tradeoffs: "we could have called X, but it
  would mix concerns, so…". This is where the reviewer's unasked question gets its answer.
- Say so where a commit is **pure reorganization** rather than a change in behavior.
- Note a forward-looking implication where one exists: "this sets us up for the next
  commit, which…".
- Write plain prose paragraphs. Use a bullet list only to enumerate the distinct changes
  inside one commit.

### Example

```
feat(Checkout): add support link to payment error messages

Add a link to Support in the "card declined" error a customer may get
at checkout. Any other error from the payment provider would be
unexpected, so add the link there too, in case that happens.

The error message is created in the Order model. We could call
`ActionController::Base.helpers.link_to` within the model to include the
link where the message is defined, but calling an ActionController
method in a model would mix concerns. So define a helper method to add
the link as needed instead.

This helper can be used anywhere we need to add a Support link to a
message.
```
