# Draft comments

Step 7 of `SKILL.md` sends you here, in the reply that holds the drafts.

A draft is written to the author, not to the user. The finding carries the evidence.
The draft carries the ask alone. Repeat no line number, no commit, and no provenance
trail from the finding, because the author can open the file.

Write in a neutral, direct register. Describe what the code does, in the words the author
uses for it. Give no verdict on the author's choice, such as "wrong" or "correct",
because a verdict reads as harsh. Add no praise to soften the ask, because praise reads
as filler.

Build every draft in this order:

1. Open with severity and scope. Label a nit as a nit. Where the problem predates the
   PR, say so in the first clause.
2. State the observation in one sentence, from what the author sees on screen.
3. Put the one change you ask for in one question: "What do you think of", followed by
   the author's action as an `-ing` verb. Examples are "adding a sort on the person id"
   and "finding out how long one domain query takes". Name the change, not the steps to
   make it, because a question leaves the change the author's to make. The question is
   the offer, so it closes the draft. Only a hunch from the next step comes after it.
4. Mark a hunch as a hunch, in one sentence, then stop. Attach no evidence to it.
   Assign no follow-up task.

A draft carries an example only where the user asks for one. Put it after the
observation from step 2: one input, and what happens to it. Give one example only,
because a list of failing inputs reads as a verdict.

A draft for an overlapping finding is a reply in that comment's thread. It refers to
the comment in words, as in "the check it suggests". It carries only the finding's
**Adds**, and it states the **Their fix** value in its own words. Where **Adds** is
"nothing", offer the user a 👍 reaction on the comment, or a one-line reply, in place
of a draft.

Cap a draft at two paragraphs and six sentences. A draft above that cap is a finding
you did not yet reduce to one ask.

Start every draft with 🤖 and a space, ahead of the severity label. A one-line reply
that you offer in place of a draft starts with 🤖 too. The emoji marks each comment
that Claude Code writes. Readers can then tell it apart from a comment that a person
writes.

Print the drafts in a section of their own, keyed by finding number, so each draft names
the finding it answers:

```markdown
## Draft comments

**Finding 1** — `file:line`

> 🤖 <the comment, written to the author>
```
