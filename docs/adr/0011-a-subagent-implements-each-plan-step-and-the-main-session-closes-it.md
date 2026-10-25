# 0011 — A subagent implements each plan step, and the main session closes it

## Context

Before 2026-10-11, the `dev-workflow:implement-plan` skill ran every step of a plan in the main
session, so the main session's context grew with each step. The user checked its size at
each approval stop. Past about 150K tokens, the user ran `/compact` before the next step, because a
model's output gets worse as its context fills. A plan that runs without approvals has no such
stop. A model cannot run `/compact`, and automatic compaction can start in the middle of a
step.

So each step now runs in a subagent with a fresh context, and the main session takes in only
the subagent's report. Some projects route their work to specialist agents. A private Rails
8.1, Inertia, and React application uses `rails-core:rails`, `inertia-react:frontend`, and a
project-specific reviewer agent. Other projects have no specialist agent. The design
must work in both kinds of project.

Three facts of Claude Code 2.1.296 shape the design. The Claude Code documentation on
subagents[^subagents] states each one.

1. Claude Code removes `AskUserQuestion` from every subagent. A subagent cannot ask the user a
   question.
2. Only a subagent's summary reaches the main conversation. Its intermediate output stays out.
3. A subagent can start its own subagents, by default up to three layers below the main
   session. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` turns that off. An agent definition whose
   `tools` list omits `Agent` cannot start a subagent either.

## Decision

**The subagent implements the step, and the main session closes it.** The close runs the
checks and sends the change to the reviewer that the project's CLAUDE.md names. It also updates
the plan and the standing documents, and it commits. The subagent neither edits the plan nor
commits.

**The plan names the agent for each step.** The `write-plan` skill writes an `**Agent:**` line
under each step's heading. It takes the name from the routing in the project's CLAUDE.md, or
writes `general-purpose` where no row of that routing covers the step's work. The
`implement-plan` skill uses that name, and does not choose again. `dev-workflow` names no
specialist agent. A specialist agent ships in another plugin, so a pointer to it dangles in
every project without that plugin. ADR [0008](0008-the-rails-agent-owns-app-controllers.md)
rests on the same fact: `rails` routes nothing to `frontend`, because that pointer dangles
where `inertia-react` is absent.

**A step can name several agents, in order.** The line then reads `**Agents:** <a>, then <b>`.
The main session gives each agent's report to the next agent in its brief. The step closes
once, after the last agent, and the last agent proves the outcome of the whole step. This is
the handoff that ADR [0008](0008-the-rails-agent-owns-app-controllers.md) defines at the
controller: `frontend` reports the props contract, and `rails` builds it. A plan splits such a
job into two steps only where each half passes its checks alone.

**Every step runs in an agent, whatever the plan's approval mode.** The approval mode controls
only the stops. The user can ask for one step to run in the main session. That request is an
instruction in the conversation, and not a setting in the plan.

## The alternatives that lost

**A subagent that implements the step and closes it too.** It cannot hold a stop for the
user, because it cannot ask a question, and the user sees only its summary. A reviewer that it
starts reports to it, and not to the main session, so the main session sees the review only as
that subagent retells it. Its call to the reviewer also fails where nesting is off. Last, the
specialist agents preload neither `implement-plan` nor `commit-messages`.

**A choice of agent at run time.** A step that crosses two agents' scopes then gets its owner
during the run. In a run without approvals, nobody sees that choice before the work is done.

**One agent for each step.** That rule forbids the handoff at the controller, where neither
`rails` nor `frontend` can do the job alone.

**A plan setting that turns the agents off.** No plan wants approvals off and agents off,
because that run fills its own context with no stop to compact it.

[^subagents]: https://code.claude.com/docs/en/sub-agents
