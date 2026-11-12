---
status: accepted
date: 2026-11-12
proposed-by: Codex
approved-by: project maintainer (task cleanup scope)
---

# ADR-0012: Archive Git state before explicitly removing a retained task

## Context

Closing agent windows intentionally retains branches and worktrees. Testing many
tasks therefore creates clutter. Reviewed changes may be squash-integrated, so
branch ancestry cannot prove that removing a task is safe. Tasks often also hold
uncommitted working files, distinct staging and inherited source edits.

## Decision

Expose a per-project retained-task view with Keep, Review/Integrate and Remove.
Removal is one task at a time, with a preview, fresh validation and exact branch
confirmation. Never prune merely because an agent finished or integration passed.
Before deletion, preserve the original HEAD, baseline, index and working tree in
local recovery refs and write a private operation receipt. Preserve existing
review and integration records. Show recovery commands and history in the editor.

Integration status requires content equality with the captured integration tree
and reachability of the recorded integration commit on its named destination.
It does not promise that subsequent edits/reverts or conflict resolutions retained
all task content. Every removal gets recovery snapshots regardless of this label.

Keep Git/process rules in the Python helper behind list/inspect/remove/history.
Lua owns discovery and current-editor guards. Shared process locks coordinate
supervisors and integration with cleanup's exclusive lease. Refuse ignored files,
unknown active operations and unsupported Git working states instead of guessing.

## Alternatives

- Ancestry-based automatic pruning: cannot account for squash integration,
  uncommitted edits or inherited baselines.
- Force-delete after a confirmation alone: simple, but makes a mistaken selection
  costly to recover and can lose unique staging/untracked files.
- Keep every worktree indefinitely: preserves data but leaves the user to manage
  growing clutter outside the editor.
- Bulk deletion/automatic archive expiry: deferred until single-task use provides
  evidence that the labels, guards and recovery workflow are understandable.

## Consequences

Branches and checkout directories can be removed while their Git content remains
recoverable locally. This is not a disk-space reclamation guarantee or a complete
filesystem backup. Archives need an eventual explicit retention policy. External
writers and other editors' unsaved buffers remain outside the lock protocol;
users must close them before removing a checkout. Linux and macOS use POSIX locks.
See [task cleanup](../features/task-cleanup.md) for behavior and verification.
