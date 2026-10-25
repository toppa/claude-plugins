# 0018 — The guide states each home's purpose, and trusts the agent's judgment

## Context

`plugins/standing-documents/skills/adopt/references/adopt-standing-documents.md` sets out the
standing-documents pattern. A project keeps a fixed set of homes, and `CLAUDE.md` is the map of
them. A home is a file or a place that holds one kind of documentation. The old guide called a
home a "destination". The homes work. The rest of the guide did not: by 2026-10-23 it was 2,092
lines, and it grew with nearly every pass on it.

**The cause is one decision of the 2026-09-04 rewrite plan.** Its decision 6 says: "A convention
enters `CONVENTIONS.md` where a reviewer can measure it, and a self-judging rule stays out." So
each rule needed proof, each proof needed a format, each format needed a check, and each check
needed exemptions and defined terms. Each review finding then asked for one more rule to close
one more gap.

A private Rails 8.1, Inertia, and React application is the pattern's testing ground. The Context
of a plan of 2026-10-14, to cut the cost of the standing documents, gives these figures, which it
measured from the session transcripts on 2026-10-13 and 2026-10-14:

- **The review.** One plan in that application is an ordinary product plan. Its 10 reviews and
  the closing review of an upgrade gave 145 findings and 125 edits. Only 20 of the edits stopped
  a concrete wrong action.
- **The checks.** They are 664 lines, and no fix that a check produced stopped a wrong action.
  26 commits changed them, and 18 of those changed code.

ADRs 0012 to 0016 came from that plan, on 2026-10-14 and 2026-10-15, and this decision deletes
them. They cut parts of the review, the checks, and the rules. The plan's work on the guide
started from a guide of 2,012 lines, and the guide was longer when that work stopped.

## Decision

**The guide states the purpose of each home, and the agent judges the edge cases.** The
maintainer settled the decisions below in a grilling on 2026-10-22 and 2026-10-23. The guide
carries them. In short form:

1. The guide is short. A tool of the old guide comes back only where a decision below keeps it.
2. The nine homes stay, with their file names, and so does the optional evidence layer. ADR
   [0010](README.md) holds the reason for the names of the rule files.
3. A rule goes into an automated test where a test can hold it. Otherwise it enters a rule file
   only where the writer can name a real mistake that it prevents, with a one-sentence reason.
   The agent judges whether the mistake is real. The bar and its three clauses go.
4. The map holds the table of homes, and a short list of priority notes for the cases where two
   homes both seem to fit. The sorting test goes.
5. A rule keeps its id, and a citation names the id. The guide prescribes no citation form.
6. The guide names four kinds of drift, and says which ones suit a script. The project chooses
   the means and the timing of its checks, and the checks run before a change merges. The guide
   specifies no script and no reviewer.
7. No text installs word for word. The map holds the working rules: the development practices
   that every task needs before it starts. The guide states what the documentation duties among
   them must cover, and each project writes them in its own words. For comments, the guide gives
   the core idea only.
8. For ADRs, the guide keeps the core. An ADR holds one decision with the alternative that lost.
   An open question is a proposed ADR. An index shows the status of each ADR.
9. The ninth home is where the project tracks work. Before the work finishes, each decision and
   reason that a later reader needs moves to its standing home.
10. A first adoption has four steps. Write the map. Move the existing content into its homes,
    and show the person the list of moves before any cut. Choose the drift checks. A person reads
    back the result.
11. The guide says nothing about upgrades yet, and a project records no edition of the guide.
    The old guide's diff mechanism needed a commit SHA, git commands, and a clone of this
    repository, and it existed to spare a reader 2,000 lines. How the guide gets versions, and
    how a project upgrades, is a later decision.
12. The guide has no "Terms" section. It defines each special word at its first use.
13. The guide has seven sections and a target of about 300 lines. The target is a house
    heuristic with no external source. Its job is to make growth something a person sees and
    decides on.

**This decision deletes ADRs 0012 to 0016.** They recorded parts of the old guide: the review,
its bands, the sorting test, the bar, and the checks. The old guide's last edition dates
from 2026-10-21. The private archive of the earlier history keeps the five
deleted ADRs at these paths, as ADR [0020](README.md) records:

- `docs/adr/0012-the-review-reports-a-hard-read-only-with-its-wrong-action-and-ranks-by-consequence.md`
- `docs/adr/0013-a-spec-description-states-what-its-example-tests-and-a-rules-reason-runs-the-sorting-test-again.md`
- `docs/adr/0014-a-rule-holds-what-every-later-change-must-keep-and-an-adr-holds-why.md`
- `docs/adr/0015-every-check-reports-only-defects-and-the-review-applies-the-rules-that-need-judgment.md`
- `docs/adr/0016-the-review-reports-no-rule-breach-without-a-wrong-action-and-a-check-holds-the-citation-form.md`

ADR [0010](README.md) stands.

**A rule, or an automated test, holds what every later change must keep, and an ADR holds why it
beat the alternatives.** ADR 0014 recorded this line first, and this decision keeps it. Where a
later change that goes the other way would be a mistake, the decision needs a rule or a test.
Where the decision had a real alternative, it also needs an ADR, and the rule cites the ADR. The
guide states this line in the priority notes of its section "The map".

## The alternatives that lost

**Nothing self-judging, as the 2026-09-04 rewrite plan decided.** Each rule then needs a measure
that a reviewer can apply, and each measure needs a format, a check, and exemptions. Each review
finding adds one more rule. That plan started from a guide of 1,289 lines, and the guide reached
2,092. The approach also wastes what a capable agent does well: it makes good decisions from
clear guidelines.

**Keep the old guide's four tools, and make each one lighter.** The four tools are the homes, the
sorting test, the checks, and the review of a change. ADRs 0012 to 0016, which this decision
deletes, took this path, and the guide still grew. Each lighter tool still needs its own format,
terms, and exemptions. So the homes stay, and each other tool comes back only where a decision
above keeps it.

**A decision about the product in an ADR alone.** An accepted ADR is frozen. So where the
decision changes, a reader must find the newest ADR to learn what holds now. A rule or a test
states what holds now in one place.
