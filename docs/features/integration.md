# Integrating tasks locally

Collect reviewed work from independent task branches into one local feature
branch, ready for combined testing and a later PR. Integration does not push,
open a PR, merge upstream, or delete task branches/worktrees.

## Workflow

1. Open task review with **Space vr** and inspect the changes. Refresh with
   **Space vR** if the agent has made newer edits. The agent must be idle or stopped.
2. Press **i** in a review pane or **Space vi**. Choose an existing destination,
   or **New feature branch…** and enter its exact name.
3. Read the integration preview. It names the source task, destination, starting
   commit and checkout, and shows the reviewed delta. A new feature starts from
   the original project's current committed HEAD, which is shown in the preview.
   Saved uncommitted original-project edits are not added to that feature.
4. Press **a** to apply. Uzume creates one local commit for this task's changes
   since its review baseline. Both committed and saved uncommitted task edits
   count; unrelated state inherited at task creation does not. Source branches,
   checkouts and indexes stay untouched.
5. Use **f** in the result to open feature files and run your project checks.
   Repeat from another task's review and choose the same feature branch.

A destination already checked out elsewhere uses that existing checkout if it is
clean and not owned by a running Uzume agent. Otherwise, Uzume creates a linked
worktree under its data directory. Integration never checks the original project
out onto another branch. Choosing the original branch explicitly is allowed only
when its checkout passes the same checks; it is not the automatic destination.

## Conflicts and recovery

Conflicts pause the operation and open a file picker. Select a conflicted file:
**Destination** and **Task** are read-only comparison panes; the editable result
contains Git's conflict markers. Edit the result, remove markers and save it.
Do not edit the comparison panes. For deletion conflicts, remove the result file
if deletion is the intended resolution. Binary conflicts need Git/manual tooling;
the text comparison cannot resolve binary contents.

Press **Space vi** from the integration checkout to reopen its status, then:

| Key | Action |
| --- | --- |
| f | Choose a conflict/result file |
| c | Stage the integration's resolved paths and continue the commit |
| x | Offer explicit abort, discarding resolution edits and restoring the starting destination state |
| r | Refresh Git conflict status |
| q / Esc | Close the panel without aborting |

Unresolved markers, unsaved buffers and unrelated destination changes block
continuation. Abort is explicit; it retains the destination branch/worktree and
all task files. Closing a window or editor does not abort Git's operation.
**Space vI** lists saved local integrations, including paused operations, so they
can be reopened after restarting. If Git was committed/aborted separately, or
HEAD moved outside Uzume, inspect it manually rather than forcing continuation.

## Boundaries and verification

The preview is matched to the review snapshot. Source changes after review or
preview require a fresh review. Existing destination HEAD/checkouts are rechecked
before application. Dirty destinations, unfinished Git operations, unsaved editor
buffers and active task agents refuse integration. Ignored destination files
that overlap the task's paths also block application. This protects observed
state; it is not an exclusive lock against arbitrary external editors or Git
processes. A per-destination lock serializes Uzume's own operations.

Integration uses Git's three-way cherry-pick of a temporary commit whose parent
is the task's review baseline. A private index captures task state without
staging it in the source checkout. The temporary commit is not placed on the
task branch; the destination receives a single integration commit. Destination
commit hooks/signing use normal local Git configuration. Failures retain the
checkout and saved operation record for inspection. Local Git author identity
must be configured. Submodule changes need manual integration in this version.

Private JSON records in `stdpath('state')/integrations/` store task identity,
destination, operation status and the reviewed patch, with owner-only file
permissions. They may contain source excerpts. They are local and retained;
expiry, task removal and bulk cleanup are separate follow-up work. A process
crash during Git execution can leave a lock or partially completed operation;
inspect Git status before removing a stale lock or using manual recovery.

`python3 tests/integration.py` drives the real editor with mock agents and real
throwaway repositories. It verifies preview-before-mutation, a combined feature
with two task commits, source preservation, exclusion of inherited edits, dirty
destination refusal, three-pane conflict editing, stale-preview refusal, saved
conflict recovery and explicit abort. No model requests or remote pushes run.
