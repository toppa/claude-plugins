# Triage playbook

An agent in a terminal cannot reproduce a browser error, so it proposes an action from
the evidence.

The goal is a `for_review` queue that tends to zero. Every issue leaves the queue with a
decision recorded on it.

Apply rules 1 to 5 in that order, to reach one class and one archive mode. Rules 6 to
10 apply to every issue.

**This file holds no platform fact.** The application note at
`~/.claude/data/dev-workflow/triage-sentry/apps/<project-slug>.md` holds them: the noise
classes of that platform, its job conventions, and the way to read a `culprit` there.

## 1. Repeat-archive escalation

Read the activity feed of the issue. Read the feed of every sibling that the recurrence
search returns. Count the previous archives across both feeds.

Where the count reaches three, do not archive again. Recommend archive forever for noise
that keeps returning. Recommend a task where the recurrence proves that the code needs a
fix. State the count in the report, as "archived 3 times before".

**Count a noise archive only, because an archive that a task applied does not show that
the issue is unowned.** A tracker already owns that one, so rule 1 would recommend a
task that exists. Where a task owns the issue and the rate grows again, recommend that
the user raises the priority of that task.

**A regrouped issue carries no history of its own, so a count of zero is not proof of a
first offence.** Sentry groups on the stacktrace. A new frame in a reporting path makes a
fresh group for an old defect. The sibling search is the guard, and it is imperfect.

## 2. The five classes

| Class | When |
|---|---|
| Archive with a condition | The issue is real. It does not earn a task today. A condition brings it back. |
| Archive forever | The issue is noise, and no code change removes it. |
| Resolve | The defect is fixed. A regression reopens the issue. |
| Task | The code is wrong, and the defect meets Low or higher by rule 7. A person must change it. |
| Quarantine | The issue holds a credential, or it is an artifact rather than an error. |

Where no class fits, report the issue with the evidence and propose no action.

Archive forever is the end point for noise. Sentry's "Delete and Discard Forever" stops
collection, and no tool in the catalog performs it. Recommend it in prose where the
volume justifies it.

**Prefer an archive to a delete, because an archived issue keeps its events and its whole
comment thread.** A deleted issue returns as a new issue, with a new short id and no
history, so the next triager repeats the work. Delete answers a data-hygiene question,
and never a severity question.

## 3. The archive modes

`update_issue` sets the status to `ignored`, and it takes the mode in the same call.

| Situation | Sentry archive |
|---|---|
| Transient job retry that later succeeded | `untilOccurrenceCount`, count 1 |
| Low value, kick the can a week | `forDuration`, 10080 minutes |
| Persistent low impact | `untilOccurrenceCount`, count 25 |
| Downstream outage, wait a day | `forDuration`, 1440 minutes |
| Kick the can, still catch a spike | `untilOccurrenceCount` 50, window 60 |
| Filed as a task | `untilEscalating` |
| Rate is acceptable, growth is not | `untilEscalating` |
| Suspected regression of a closed fix | `untilOccurrenceCount`, count 1 |

Reserve a count of 1 for the transient case: the work failed once, and then it succeeded.
**Do not use a count of 1 for a watch item, because one occurrence puts it straight back
into the queue.** A watch item returns at a slow trickle. Use a count of 25, or 10080
minutes.

**A suspected regression inverts that rule.** Where a closed tracker issue already covers
the error, and one event is too little to prove the fix failed, a count of 1 asks the
only question that matters. The next occurrence is the proof, so bring it back at once.

`untilUserCount` suits an issue that one customer hits today.

**A task archives the issue at `untilEscalating`.** The tracker owns the fix from that
moment, so the issue has no further use in the queue. `untilEscalating` returns it where
the rate grows, which is the one thing that would change the priority of the task.

## 4. The quarantine trigger

Quarantine fires on two things only:

1. A credential-shaped value reached the event payload unmasked.
2. The issue is an artifact rather than an error, such as a migration check or a test
   probe.

A masked value is evidence that the scrubbers worked. It is not a finding.

The remedy runs in this order:

1. Revoke the credential.
2. Stop the source that sends it.
3. Delete the record.

**Do not present the deletion on its own, because a deleted issue returns tomorrow while
the source still sends.** The skill recommends a deletion. It never performs one.

## 5. The archive-versus-task check

A justification that holds "should handle", "should add", "should not retry", or "could
improve" describes a task where the defect meets Low or higher by rule 7. Where the
defect is below Low, the justification describes the class "Archive with a condition".
An archive says that the current behaviour is acceptable for now. A task says that the
code is wrong.

## 6. Security-researcher traffic

Scanner-shaped traffic on a valid authenticated session is the case that gets
misclassified most, and it goes wrong in both directions. Check the user email domain on
the event. Treat the domain as a lead, and not as a verdict.

A relay domain, such as `wearehackerone.com` or `bugcrowdninja.com`, belongs to a
bug-bounty researcher. It makes researcher activity the likely explanation, rather than a
hijacked session. It does not establish that the activity was authorized, because an
email address is self-asserted at signup.

The typical fingerprint is an injection payload with a collision canary, a cloud-hosted
IP address, a bare `Mozilla/5.0` user agent, and a valid CSRF token. That combination
reads as session hijacking until you check who the user is.

Keep four questions apart in the report:

- **Is the address genuine?** Mailbox control proves that, and it proves nothing about
  who drove the session.
- **Does the bug-bounty policy authorize this?** That is a policy question for the user.
- **Which organization owns the account?** A researcher's own sandbox organization is low
  risk. An account inside a live customer organization needs follow-up.
- **Did the probe expose a real defect?** File the fix on its own merits. A failed
  exploit attempt still reveals a defect.

## 7. The priority rubric

This rubric ranks a task. Use the first row that matches.

| Priority | When |
|---|---|
| Urgent | An active security exploit, data loss or corruption, or a broad outage |
| High | The issue is on fire. Real users cannot complete a core flow now, such as auth, billing or payouts |
| Medium | Real users hit it every week in a core flow. They lose money, data or access, and no workaround exists |
| Low | Real users hit it, and the harm is real but minor or rare |

A security exposure that a real attacker can use counts as real harm, even with zero
events. Staff count as real users in every row.

**A defect below Low gets the class "Archive with a condition" from rule 2, and not a
task.** The condition brings the issue back to the queue where the harm grows.

## 8. Two Sentry cautions

**Read a user count against the age of the issue, and against its culprit.** A count on a
minutes-old issue means nothing yet. A zero on a background job is accurate rather than
missing, because a job carries no request context and no user. The application note names
the culprits that report a correct zero.

**A zero on an unauthenticated request is missing rather than accurate.** A real person
is there, and the request never identified them. Measured 2026-09-22: a password-reset
error read 0 users, while the tracker issue for that same error counted 26 distinct
people. **Do not read that zero as low impact, because an auth path reports it for every
error.**

**A negative search result is not evidence of absence.** Confirm a negative with a
positive control: run the same query without the negation, and check that the excluded
term is what disappeared.

## 9. The user-facing manifestation

Every issue in the report carries one sentence that states the customer-visible outcome.
That sentence comes before the recommendation. An example: "The payment does not
process, the customer sees no error, and the customer may retry several times."

Where the outcome is unknown, say that it is unknown. **Do not guess an impact, because
that sentence ranks the issue.**

## 10. The deploy-regression signal

Read the first-seen date of every issue that is not obvious noise. A specific date in the
last few weeks is evidence that a deploy introduced the issue. Weigh a task rather than an
archive in that case.

Check whether other issues in the same project share that date. A cluster inside 48 hours
is a strong signal of one bad deploy, and the cluster deserves one report entry rather
than several.

**This rule does not apply to a years-old issue with thousands of events.** A chronic
issue is a different pattern, and its first-seen date carries no signal.

**Where nearly every issue in a project shares one first-seen date, that date is the day
the project started to report, and not a deploy.** Ignore that one date. Rule 10 stays
live for every other date in the project, so a later deploy still earns its weight.
