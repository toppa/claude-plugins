# Adopt the standing-documents pattern

Version 0.1.0 (alpha). The latest version and its changelog are at
`https://github.com/toppa/claude-plugins/tree/main/plugins/standing-documents/skills/adopt/references`.

## The problem, and what the pattern gives you

This guide is for an engineer who works with an AI coding agent. The agent loads one file at the
start of every task, before it knows what the task is. This guide calls that file `CLAUDE.md`. If
your agent loads `AGENTS.md` instead, read `AGENTS.md` wherever this guide says `CLAUDE.md`.

In most projects, one file mixes three kinds of content: what a word means, why a decision went
one way, and what to build next. So one fact sits in several files, and over time the copies
disagree. Each closed question keeps its full argument. The agent reads more and more text to
find the rules that hold now, and its context window has a fixed size. In the end, one piece of
work no longer fits in one context window.

The standing-documents pattern gives each kind of content one home. A home is a file or a place
that holds one kind of documentation. The standing documents are the homes that outlive any one
piece of work. `CLAUDE.md` is the map: it names each home, and it says what each home answers.
The pattern gives you three things:

- A reader knows where to look for each kind of fact, and finds one copy there.
- The agent reads less to learn the same rules, so more of the domain fits in its context.
- A settled decision keeps its reason, so nobody argues it again without the facts.

This guide states the purpose of each home, and it leaves the edge cases to the agent's
judgment. ADR [0018](https://github.com/toppa/claude-plugins/blob/main/docs/adr/0018-the-guide-states-each-homes-purpose-and-trusts-the-agents-judgment.md),
in the repository that holds this guide, records why the guide takes this approach.

## The homes

The table below lists nine homes. Two more homes sit outside the table: an optional evidence
layer, and code comments. The end of this section describes both.

One home is the automated tests. An automated test is a check that fails on the wrong change. It
runs on each change with no person to start it, for example in CI. A spec, a lint rule, a type,
and a database constraint are automated tests. A script that a person must remember to run is not
one.

| Home | What it answers |
|---|---|
| `README.md` | What this project is, and how to run it on your machine. |
| `CLAUDE.md` | Where each other home is, what each one answers, and the practices that every task needs. |
| `GLOSSARY.md` | What a word means in this project. |
| The automated tests | What must hold, where an automated test can hold it. |
| `UNTESTABLE-RULES.md` | What must hold in the product, where no automated test can hold it. |
| `UNTESTABLE-CONVENTIONS.md` | How we write the code and the documents, where no automated test can hold it. |
| `OPERATIONS.md` | How we run the deployed system, and how we diagnose it. |
| `docs/adr/` | Why a decision went one way, and which open questions no tracked work will settle. |
| Where the project tracks work | What to build next, and in what order. |

The examples below come from an imagined online bookshop.

**`README.md` is for a person who arrives at the project.** It says what the project is, how to
install it, and how to run it. Example: "Run `bin/setup` once. Then run `bin/dev`, and open
`http://localhost:3000`."

**`CLAUDE.md` is the map.** The agent loads it before it knows the task, so it holds what every
task needs first: where everything else is, and the working rules. "The map" below says what it
holds. Example, a row of its table: "`UNTESTABLE-RULES.md`: what must hold in the product, where
no automated test can hold it."

**`GLOSSARY.md` defines each word that the project uses in a special sense.** The other homes
use a defined word, and they do not define it again. Example: "**Backorder**: an order line for
a book that is out of stock. It ships when the stock arrives."

If your tools load the glossary from another file, such as `CONTEXT.md`, read that name wherever
this guide says `GLOSSARY.md`.

**The automated tests hold each rule that a test can hold.** A test fails on the wrong change,
so nobody has to remember the rule. Example: a database `CHECK` constraint that keeps an order
total at zero or more.

**`UNTESTABLE-RULES.md` holds each rule about the product that no automated test can hold.**
Where such a rule is dropped, the product is wrong. Example: "R-007: No page load calls the
supplier's API. Reason: the API is slow and rate-limited, so the page times out under load."

**`UNTESTABLE-CONVENTIONS.md` holds each rule about how we write the code and the documents,
where no automated test can hold it.** Where such a rule is dropped, the product still works,
but the code is harder to read or to change. Example: "C-002: Keep methods short. Reason: a long
method hides its steps from the next reader."

**The prefix "UNTESTABLE" says that each rule file is partial**, because the automated tests
hold the other rules. A reader who sees `RULES.md` expects a complete list. That reader then
concludes that no rule exists where the file has no entry. So the map row and the first line of
each file also say that the file holds only what no automated test can hold.

**`OPERATIONS.md` says how to run the deployed system.** It holds the operational rules, where
the logs go, and how to diagnose a fault. A project with several long procedures can add a
runbook directory, with one file for each procedure. Example: "The payment worker logs each
failed payment with its order id. To trace one, search the worker log for that id."

A project with nothing deployed has nothing to put in `OPERATIONS.md`. Its map names the file,
says that nothing is deployed yet, and names the work that will fill the file. A reader then
knows where that content goes, and that it does not exist yet. Any home can be empty in this way.

**`docs/adr/` holds the architecture decision records, or ADRs.** An ADR holds one decision that
passes the ADR bar, with the alternative that lost. The decision does not have to be about
architecture. Example: "0004: The shop takes payments through one provider. The alternative that
lost: two providers, for failover. It lost because each provider needs its own refund flow."

**The ADR bar has two tests.** A reasonable person would otherwise argue the decision again, and
its reversal costs real work. The cost of a reversal is the change that undoes the decision. It
does not include the work that the change then triggers, such as a rerun of a job or a new
import of data. A decision that one edit reverses, such as a constant, a seed value, or one
component or class, gets no ADR.

**An open question waits in the work that will settle it, such as a plan, an epic, or an
issue.** A decision to wait for a later measurement is an open question too. A decision about a
part of the project that does not exist yet waits in the work that builds that part. When that
work finishes, the decision moves to its standing home, and the ADR bar applies to it then. Where
no tracked work will settle an open question, the open question is a proposed ADR only where its
answer will pass the ADR bar.

A proposed ADR can start as one sentence, and it can change until it is accepted. After that,
its decision stays as it is. The directory keeps an index, such as `docs/adr/README.md`, that
shows the status of each ADR. The project chooses the file names, the layout of the index, and
how a later ADR withdraws or supersedes an earlier one.

**The place where the project tracks work holds what to build next, and in what order.** That
place can be plan files in the repository, or a tracker such as Linear or GitHub Issues. It can
also be something else, such as pull request descriptions. The map names what the project uses.
This guide dictates no way to manage the work. The `dev-workflow` plugin for Claude Code, in the
repository that holds this guide, gives one way. Its `write-plan` and `implement-plan` skills work
from plan files, and its `write-issue` and `implement-issue` skills work from a tracker.

Two ideas apply to any unit of work, such as a plan, an issue, or a pull request:

1. **Before the work finishes, each decision and reason that a later reader needs moves to its
   standing home.** This matters more for a tracker. The agent does not load an issue with the
   project, and the issue can outlive the tool. Example: a plan for gift cards decides that a
   gift card never expires. Before the plan finishes, that rule moves into a test or into
   `UNTESTABLE-RULES.md`.
2. **A record of finished work is not kept current.** A reader does not treat it as current. A
   finished plan or a closed issue says what was true when the work finished.

**An evidence layer is an optional home for what someone measured, gathered, or produced.**
Examples are `docs/research/` for research results and `docs/reference/` for gathered findings.
The map names each layer that the project declares, and what the layer holds. A directory that
the map does not declare has no stated content, so anything can collect in it. Example: a file
in `docs/research/` that records the supplier API's response times on one day.

A standing document says what holds now, and someone revises it in place. An evidence file says
what was true on the day someone wrote it. A layer that grows keeps its own index, in a
`README.md` beside its files. The map points at that index, and it lists none of the layer's
files. A list of files in the map goes out of date when someone adds a file, and nothing reports
the gap.

**A code comment is the last home.** A sentence goes into a comment only where no other home
fits it. A comment is for code that a reader would change wrongly, where no test warns them.
Where a test can fail on the wrong change, write the test instead. Example:

```ruby
# Lock the order row before the stock row. Do not reverse the order,
# because two checkouts then deadlock under load.
```

## The map

`CLAUDE.md` holds five things:

1. A description of the project, in a few sentences.
2. The table of homes. It has a row for each of the nine homes in "The homes", and a row for each
   evidence layer that the project declares. Each row says what the home answers. The row for an
   empty home says that the home is empty.
3. The priority notes.
4. The working rules.
5. The version line. It names the version of this guide that the project follows, with the URL
   under this guide's title. Example: "This project follows the standing-documents guide
   <version>, at <URL>."

Keep the map short, because the agent loads it whole for every task.

**The priority notes settle the cases where two homes both seem to fit.** Start from these notes,
and add the project's own:

- Where a test can hold a rule, the test holds it, and no file repeats it. Until a test holds it,
  the rule enters its rule file, and its entry says that a test can hold it.
- A rule about the product goes to `UNTESTABLE-RULES.md`. A rule about how we write the code goes
  to `UNTESTABLE-CONVENTIONS.md`.
- A decision that every later change must keep needs a rule or a test, and not only an ADR.
  Where the decision passes the ADR bar in "The homes", an ADR also holds why it won, and the
  rule cites the ADR.
- A word is defined in `GLOSSARY.md` only. A rule that uses the word does not define it again.
- Content that fits no home is deleted. Git keeps it.

The agent sorts content in the unit that fits: a sentence, a paragraph, or a section. One
paragraph can hold a rule, a definition, and a reason, and each part then goes to its own home.

**The working rules are the project's development practices that every task needs before it
starts.** Examples are the commands that check the work, "Do not push to `main`", and which agent
does which work. The agent loads the map before every task, and it cannot know in advance which
other file a task needs. So the working rules live in the map. A practice for one area of the
code is a convention, and it goes to `UNTESTABLE-CONVENTIONS.md`. Example: "Write each migration
so that it can be reversed."

**The documentation duties are the working rules about the standing documents.** This guide gives
no text to copy. Each project writes its working rules in its own words, for its own workflow.
The documentation duties must cover these points:

- Before the work starts, read the standing documents that the work touches. A subagent starts
  with the map and its brief only. So the map or the brief names the documents that the
  subagent reads.
- Put each new piece of content in its home, by the table of homes and the priority notes.
- Update a standing document in the same change that makes it false.
- Before the work finishes, move each decision and reason that a later reader needs out of the
  tracked work, and into its standing home.
- Check for drift before the change merges, by the means that the project chose under "Drift".

Example, one documentation duty in one project's words: "Before you change checkout, read
`UNTESTABLE-RULES.md` and each ADR that the index lists under payments."

## Rules

**A rule says what every later change must keep.** Put it into an automated test where a test
can hold it.

**Otherwise, a rule enters a rule file only where the writer can name a real mistake that it
prevents.** The entry gives its reason in one sentence. The agent judges whether the mistake is
real. A rule such as "Keep methods short" can enter, and the agent applies it with judgment. A
rule such as "Write good code" names no mistake, so it stays out.

**Where a test can later hold a rule, write the test, and delete the entry.** The rule then has
one home, and it is the home that fails on the wrong change. Until a test holds it, a rule that a
test can hold enters its rule file, and its entry says that a test can hold it.

**Each rule has an id**, such as `R-014` in `UNTESTABLE-RULES.md` and `C-007` in
`UNTESTABLE-CONVENTIONS.md`. A citation of a rule names its id. The project chooses the form of a
citation. Where a writer cuts a rule, search the project for its id. Fix each citation that the
search finds. Do not give a cut rule's id to a new rule, because an old citation then points
at the wrong rule.

## Drift

**Drift is a gap between the standing documents and the project.** It comes in four kinds:

1. **A citation points at nothing.** The reader cannot find the rule or the reason, so the agent
   acts without it, or guesses. A script finds this kind well, once the project has citations.
2. **Content sits in the wrong home, or two homes say the same thing.** A reader who looks in the
   right home misses the content. Where two homes hold copies, the copies change apart and then
   disagree.
3. **A change goes against a rule or an ADR, or it makes a decision that passes the ADR bar, and
   records no ADR.**
   The product goes wrong with no warning. Or the next person argues the decision again, with no
   way to learn that the alternative was tried.
4. **A change makes a standing document false, and the change does not update that document.**
   The next task reads the false text as fact, and acts on it. The automated tests are a home
   too, so a test whose description claims more than the test checks is drift of this kind.

Kinds 2 to 4 need judgment, so they do not suit a script.

**The project chooses how it checks for each kind of drift.** The means can be a script, an
agent's review, or a person. The timing can be each step, each commit, or each pull request.
This guide specifies no script and no reviewer. The one limit is that the checks run before a
change merges. After the merge, the next task reads the drift as fact.

Example: CI runs a script for kind 1 on each pull request. An agent reads each pull request for
kinds 2 to 4, and a person rules on its findings before the merge.

**A check does not hold a plan or an issue to the standing documents.** The plan or the issue
ends with its work. A check reports a plan or an issue only where it states a false fact about
the project.

## Adoption

**A first adoption has four steps.** Your agent can do steps 1 to 3, and it prepares the
questions in step 4. A person on the project approves the list of moves in step 2. In step 4,
that person answers the questions and reads back the result.

1. **Write the map.** Write the five things that "The map" names into `CLAUDE.md`. Revise the map
   after steps 2 and 3.
2. **Move the existing content into its homes.** First, show a person on the project the list
   of moves. Do not cut text, or change what a rule means, before that person approves the list.
   The list marks each rule that a test can hold, but that no test holds yet.
   A read-back of the result cannot see a cut, because the cut text is no longer there. A record
   of finished work in its own file or issue, such as a finished plan or a closed issue, stays as
   it is. A decision that only such a record holds moves to its standing home.
3. **Choose how and when the project checks for drift.** "Drift" names the four kinds, and the
   choices.
4. **Have a person read back the result.** First, the agent lists each open item. An open item
   is a question that the moves left unsettled, such as two sources that disagree. The agent
   keeps an item only where the documents, as they stand, give a reader a wrong answer. It puts
   each kept item to the person as one yes-or-no question, and the question states that wrong
   answer. The read-back covers the documents, and not new work on the product. Then the person
   answers each question, and checks that each entry sits in its home and kept its meaning.

   Example: "R-012 says that a customer can return a book within 30 days, and the old
   `README.md` said 14. Is 30 days correct? If it is not, R-012 gives a reader the wrong limit."

**An upgrade starts from the map's version line.** The changelog, `CHANGELOG.md` beside this
guide, has an entry for each version. Each entry says what changed, and what an adopting project
does about it. Read each entry for a version later than the one in the map. Do their actions in
version order, oldest first. Then change the version line to this guide's version. A map that has
no version line, but names the homes, adopted the guide before 0.1.0, so read every entry.

## Limits

**This guide is an early version, and it changes as its projects find gaps.**

**A rule about code that no change touches can go out of date unseen.** A check on a change reads
only what the change reaches. Only a periodic read of the rules against the code finds such a
rule.
