---
status: accepted
date: 2026-11-11
proposed-by: project maintainer and Codex
approved-by: project maintainer
---

# ADR-0007: Integrate reviewed task deltas into explicit local destinations

## Context

Isolated tasks leave their edits in separate worktrees, so reopening the original
project does not show the agent's changes. Users need to combine several tasks
into a feature branch for a later PR, without accidentally importing inherited
edits or deleting experiments before deciding what to keep.

## Decision

Integration previews a task's delta since its recorded baseline and applies it
as one commit to an explicitly chosen local destination, preserving the source
task. Conflicts pause in that destination with read-only destination/task panes
and an editable result, explicit side choices, continue and abort. Integration
makes reviewed work available locally; it does not push, create a PR, merge
upstream, or delete branches/worktrees.

## Considered options

- **One reviewed delta commit per task** — supports combining independent tasks
  and excludes the synthetic inherited-state baseline.
- **Merge the entire task branch** — can import unrelated starting edits and
  makes the promised review scope misleading.
- **Copy changed files over the destination** — loses Git's three-way conflict
  handling and could overwrite concurrent destination work.
- **Automatically publish and prune after integration** — couples local review
  to remote policy and irreversible cleanup; these need separate user actions.

## Consequences

Task commit history is not replayed. Destination checkout identity, HEAD,
cleanliness, task fingerprint and live-agent state must be rechecked before
mutation. Operation records retain local patches and status for recovery;
external Git edits and crashes still require careful inspection. Task removal
must later establish integration equivalence explicitly: ancestry alone is
insufficient for a squashed delta. Submodule changes currently require manual
integration. A task delta is not a substitute for merging the distribution's
own diverged development history into main.

See [integration behavior and recovery](../features/integration.md) and
[ADR-0006](0006-named-tasks-and-inherited-state.md).
