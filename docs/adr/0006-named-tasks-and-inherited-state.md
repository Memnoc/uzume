---
status: accepted
date: 2026-11-11
proposed-by: project maintainer and Codex
approved-by: project maintainer
---

# ADR-0006: Name isolated task branches and inherit saved checkout state

## Context

Opening an agent from an edited file originally showed a committed-only copy,
which looked like lost work. Repeated branch pickers also obscured the simple
intent to name a task and start working. This records the accepted refinements
to [ADR-0002](0002-session-lifetime-and-worktrees.md), whose isolation and lifetime
decisions remain in force.

## Decision

New-task actions ask for an exact branch name, create a separate worktree, and
open an idle official CLI beside its editor; existing-branch continuation is a
separate action. Saved tracked changes and non-ignored new files are inherited
using a private index and, when necessary, a task-local baseline commit, without
changing the source checkout's files, index or HEAD. Users see the saved code
they started from, while review identifies only subsequent task changes.

## Considered options

- **Named isolated task with inherited saved state** — makes ownership explicit
  and preserves visible starting code without sharing a writable directory.
- **Always branch from committed HEAD** — simple but made local edits appear to
  disappear when the editor moved into the task.
- **Switch the original checkout to the task branch** — would entangle other
  agents and user edits; a branch name alone does not isolate writes.
- **Always pick an existing base before naming** — remains useful as a separate
  action, but was confusing as the default new-task flow.

## Consequences

The task baseline may be a synthetic commit that must not be merged wholesale
to import the agent's delta. Unsaved buffers require resolution before launch;
inheritance is a point-in-time copy, not ongoing synchronization. Existing
tasks retain their checkout and baseline metadata for continuation. Foreign
files explicitly marked as context remain references, not automatic copies or
permission to edit another checkout.

See [task launch](../features/agents.md), [the glossary](../../CONTEXT.md), and
[local integration](0007-local-reviewed-delta-integration.md).
