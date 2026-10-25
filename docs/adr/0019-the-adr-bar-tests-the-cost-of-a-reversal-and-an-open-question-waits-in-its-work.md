# 0019 — The ADR bar tests the cost of a reversal, and an open question waits in its work

## Context

ADR [0018](README.md) kept only the core of what the guide says about ADRs. Its decision 8 says:
"An ADR holds one decision with the alternative that lost. An open question is a proposed ADR."
The guide, `plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md`,
then stated the core in "The homes". The old guide had three tests for an ADR: the decision is
hard to reverse, it surprises a reader who lacks the context, and it came from a real trade-off.
The guide's core still carries the second and the third test, as "a reasonable person would
otherwise argue again" and "the alternative that lost". The first test dropped out.

The first adoption of the guide ran on a copy of a private Rails 8.1, Inertia, and React
application. A fresh agent then judged the result, and its judgment holds the evidence:

- The adoption wrote 45 ADRs, 35 accepted and 10 proposed. The application had 26.
- 12 of the 35 accepted ADRs fail the old first test, because a constant, a seed, a component,
  or nothing built yet reverses them. 4 more are borderline.
- 9 of the 10 proposed ADRs name a plan that settles them. The old guide sent such a question
  to "the plan or the epic that will settle it, or a proposed ADR where none will".

The judgment also names the passages of the guide that led to these ADRs. Four of them set what
enters `docs/adr/`: the core in "The homes", "An open question is a proposed ADR", the priority
note "Where the decision had a real alternative", and drift kind 3, "makes a real decision and
records no ADR".

## Decision

**An ADR holds one decision that passes the ADR bar, with the alternative that lost.** The bar
has two tests. A reasonable person would otherwise argue the decision again, and its reversal
costs real work. The cost of a reversal is the change that undoes the decision. It does not
include the work that the change then triggers, such as a rerun of a job. A decision that one
edit reverses, such as a constant, a seed value, or one component or class, gets no ADR.

**An open question waits in the work that will settle it, such as a plan, an epic, or an
issue.** A decision to wait for a later measurement is an open question too. A decision about a
part of the project that does not exist yet waits in the work that builds that part. When that
work finishes, the decision moves to its standing home, and the bar applies to it then. So a
decision made before its code exists still reaches an ADR, at the time when its reversal costs
real work. Where no tracked work will settle an open question, the open question is a proposed
ADR only where its answer will pass the bar.

**The guide states the bar once, in "The homes".** The priority note in "The map" and drift
kind 3 in "Drift" point at it. `docs/adr/README.md` takes the same bar and the same rule for an
open question, for this repository.

This decision narrows two parts of ADR 0018, and it changes nothing else in it:

- Decision 8, both halves: "An ADR holds one decision with the alternative that lost. An open
  question is a proposed ADR." An ADR now also needs a reversal that costs real work. An open
  question is a proposed ADR only where no tracked work will settle it, and its answer will pass
  the bar.
- The paragraph that opens "A rule, or an automated test, holds what every later change must
  keep", and its sentence "Where the decision had a real alternative, it also needs an ADR". A
  real alternative is no longer enough. The decision needs an ADR where it passes the bar.

ADR 0018 is accepted, so its text stays as it is. Where the two disagree, this ADR holds.

## The alternatives that lost

**The core alone, as ADR 0018 kept it.** The core alone keeps the guide shorter. But each
project that adopts the guide then writes more ADRs. Under the core alone, the first adoption
wrote 45 ADRs where the application had 26, and 12 of its 35 accepted ADRs fail the old first
test.

**Every open question as a proposed ADR, as ADR 0018 kept it.** Under that rule, the first
adoption proposed 10 ADRs, and 9 of them name a plan that settles them. The plan is the work
that answers the question, and its decisions move to their standing homes before it finishes.
So a proposed ADR for such a question adds one more file to `docs/adr/`, and the plan settles
the question without it.
