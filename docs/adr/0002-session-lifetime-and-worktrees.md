---
status: accepted
date: 2026-11-06
proposed-by: Memnoc and Codex
approved-by: Memnoc
---

# ADR-0002: Isolate independent tasks and terminate agents with their session

Terminology refinement, 2026-11-08: the current model uses **Project → Windows →
Panes**, with no separate user-facing session entity. See the [design update](../design.md#projects-windows-panes-and-concurrent-work).
The isolation and stop-on-close requirements below remain; the earlier
one-session-per-worktree mapping is under revision. Worktree ownership within
project windows must be settled before concurrent agent integration. The text
below preserves the original decision context.

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
