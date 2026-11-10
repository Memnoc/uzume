---
status: accepted
date: 2026-11-06
proposed-by: project maintainers
approved-by: project maintainer
---

# ADR-0002: Isolate independent tasks and terminate agents with their session

Terminology refinement, 2026-11-08: the current model uses **Project → Windows →
Panes**, with no separate user-facing session entity. See the [design update](../design.md#projects-windows-panes-and-concurrent-work).
The isolation and stop-on-close requirements below remain. The accepted mapping
is one independent AI task per window, with its own branch and worktree and an
editor pane beside its agent. Windows retain their parent project identity even
when their checkouts differ. Switching preserves processes; closing stops them
and retains checkout files. The text below preserves the original decision
context.

Starting-state refinement, 2026-11-10: after saved edits appeared to disappear
when switching into a task's committed-only copy, the maintainer approved
inheriting saved checkout state. Current-file launches inherit the checkout
containing that file; empty launches inherit the active task or project checkout.
Saved tracked edits and non-ignored new files are captured with a private index,
leaving the source files, index and HEAD unchanged. When needed, a snapshot commit
on the new task branch becomes its review baseline, so inherited edits are not
presented as agent work. Clean sources reuse HEAD. Unsaved buffers are excluded.
This replaces the original committed-HEAD-only starting policy; independent
working directories and stop-on-close behavior remain unchanged.

## Context

Agents must work concurrently without independent features overwriting one shared checkout. Persistent background processes are undesirable when a user intentionally ends a session, but switching projects must preserve concurrent work.

## Decision

Bind each session to one project checkout or worktree; independent features use separate worktrees, branches, and sessions. Switching preserves running agents, while terminating a session stops its owned agents and spawned processes. Locally autosaved layout and review state, along with worktree files, survive termination so users can return without leaving agents running.

## Considered options

- **Session-owned agents and task worktrees** — chosen to combine concurrency with clear termination and filesystem isolation.
- **Background persistence by default** — rejected because terminating a session should terminate its agents; explicit keep-running behavior can be considered later.
- **Separate branches sharing one checkout** — rejected because concurrent edits would still affect the same files.

## Consequences

Deliberate collaboration may share a checkout. Session termination and worktree deletion remain distinct actions. Process ownership, crash cleanup, and restart behavior require verification before claiming lifecycle guarantees.
