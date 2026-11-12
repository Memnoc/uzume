---
status: accepted
date: 2026-11-12
proposed-by: Codex
approved-by: project maintainer (guided recovery scope)
---

# ADR-0013: Recover archives into a new branch and checkout after preview

## Context

ADR-0012 preserves removed task data, but copying Git commands makes recovery
harder to use than removal. A recovery must preserve separate HEAD, index and
working states without overwriting another checkout or restarting an agent.

## Decision

Add Restore to the recovery snapshot screen reached through Space aT. Ask for
a new branch and new directory, show the concrete plan, and require Enter to
restore and open its files. Cancellation before confirmation performs no mutation.
Keep manual commands available.

Resolve and validate the archive from local receipts and repository-owned refs.
Pin its object IDs in the preview and revalidate before mutation. Refuse occupied
branches/directories, destinations inside existing repository checkouts or Git
storage, submodules and custom content filters/encodings. Reserve the destination
with exclusive directory creation and let Git refuse branch-name races.

Create the linked worktree without an initial checkout, restore the working
snapshot, then restore the saved index. HEAD stays at the archived original commit;
staged, unstaged and untracked distinctions are preserved. The original archive,
source checkout and existing branches remain intact.

Record restore attempts separately from cleanup receipts. On a partial failure,
retain what was created and report its location rather than automatically deleting
it. Closing a confirmed operation's progress view only dismisses the UI; completion
still reports through a notification and does not take focus back.

Lua owns the guided screens and new editor window. Python owns validation and Git
operations behind restore-plan/restore. No new runtime dependency is introduced.

## Alternatives

- Overwrite the original branch/path: risks unrelated work since task removal.
- Make one new commit from the working snapshot: loses staged versus unstaged state.
- Automatically roll back failed attempts: can delete data written concurrently.
- Only expose shell commands: retains flexibility but leaves the common recovery
  workflow harder to discover and validate.

## Consequences

Recovery is repeatable into different new destinations; archives do not expire.
Recovered files open in an ordinary project-owned editor window. Agent processes,
conversation state and old review UI are not restored. This remains Git content
recovery, not a complete filesystem backup. External writers and process crashes
can still require manual inspection of partial results. See the feature guide
and real-Git/editor tests for behavior and verification.
