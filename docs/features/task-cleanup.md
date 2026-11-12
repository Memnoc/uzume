# Retained tasks and cleanup

**Space at** lists retained tasks for the current Git repository, including closed
agent windows. Select a branch and press Enter to inspect it. This manages Uzume
checkouts under its own `data/worktrees` directory; ordinary branches and your
primary checkout are not cleanup targets.

| Control | Action |
| --- | --- |
| Space at | List retained tasks; Enter opens their details |
| q / Esc | Keep the task and close |
| v | Review the retained task without starting an agent; use i in review to integrate |
| x | Remove the selected task after typing its exact branch name |
| r | Refresh the preview and guards |
| h / Space aT | View local recovery history |
| ? | Show the complete key guide |

Close the task's window with **Space wd** before removing it. This stops its agent
and retains files. Wait for shutdown, then inspect the retained task from another
project window. Unsaved buffers, panes still displaying the checkout and an open
review block removal in the current editor. Running managed agents are also
checked using their process records and shared checkout locks.

## What the status means

- **No task changes:** the working tree equals the recorded starting baseline.
  The baseline may itself contain inherited source edits, so it is still archived.
- **Needs review:** current contents have no matching surviving integration receipt.
- **Integration recorded:** the working tree equals the tree captured for an
  integration, and that integration's commit is still reachable from its named
  local destination branch. This uses Git content identity, not file timestamps
  or ancestry of the task branch. Later destination edits, a revert, or conflict
  resolutions can change the result; this label is evidence of integration, not
  a guarantee that the destination currently contains every line unchanged.
- **Review status unknown:** an older managed checkout lacks a reliable baseline.
  It can be explicitly archived/removed, but the UI does not invent a review diff.
- **Running:** a managed agent process still owns this task; close its window first.
- **Blocked / Unavailable:** read the reasons in the detail view. No removal is
  attempted until they are resolved.

Locked worktrees, active Git operations/integrations, unmerged indexes, ignored
files, sparse/assume-unchanged entries, submodules/nested repositories and custom
clean filters/working-tree encodings block removal. Move or remove ignored build
artifacts yourself; Uzume does not guess that ignored files are disposable.
Custom filters are detected without executing them during inspection.

## Removal and recovery

Removal is always explicit, even for an integrated task. Preview records the
checkout identity, branch HEAD, index tree and working tree. Before mutation,
Uzume rechecks these and the blockers under an exclusive checkout lock. A changed
preview is refused; refresh and inspect it again.

Before deleting anything, Uzume creates four local Git recovery refs under
`refs/uzume/removed/<id>/`: **head**, **baseline**, **index** and **working**. The
last two preserve staged and working contents separately, including non-ignored
untracked files. A private index is used; the task's real index and the original
project's files/index/HEAD are not rewritten. The task's linked checkout is then
removed and its branch ref deleted only if it still points at the inspected HEAD.

The completion screen and **Space aT** show commands to recreate a separate
branch and checkout from the original HEAD, restore working files, then restore
the index. The commands have been exercised against staged/unstaged/untracked
fixtures. They are shown for explicit execution, not run automatically.

These are Git content snapshots, not a filesystem backup: empty directories,
extended attributes, ownership and non-Git permission metadata are not retained.
Archives keep Git objects reachable and consume local storage. This release
clears branch/checkout clutter; it does not automatically expire recovery refs
or reclaim all historical data. Nothing is pushed and no agent is restarted.
Review comments, feedback, task metadata and integration history are retained.

Receipts in `stdpath("state")/task-cleanup` record **archived**, **removed** or
**partial**. If removal fails after archiving, the receipt and recovery refs remain.
A branch moved or checked out elsewhere after checkout removal is retained rather
than force-deleted. Inspect partial operations before retrying. If no receipt was
written, a failure before removal may leave recovery refs without a history entry;
Git still retains those snapshots.

## Implementation and limits

`uzume/agents/cleanup.lua` owns the UI and current-editor buffer/window guards.
`agent/cleanup.py` exposes list, inspect, remove and history JSON commands.
New tasks always save metadata under `data/task-branches`; legacy linked checkouts
in managed storage are discovered conservatively. Inspection uses a temporary
index and object directory, so it does not alter the repository's index or objects.

`agent/task_lock.py` uses POSIX shared/exclusive locks under the repository's
common Git directory. Supervisors hold a shared lock for the CLI lifetime;
integration holds shared source/destination locks during mutation; cleanup holds
an exclusive lock. Locks release when the process exits. Existing agents started
before this update are covered by process-record checks, but restart Uzume before
using cleanup to obtain the new locking behavior.

External tools and other editors can still write files without these locks. Close
other views/editors and stop external writers before removal. The current editor
checks its buffers; it does not inspect another editor's unsaved memory. No claim
of atomic filesystem snapshots or arbitrary external-writer exclusion is made.

`tests/task_cleanup.py` exercises real Git inventory, staged/working/untracked
recovery, integration receipts, stale previews, primary checkout protection,
legacy tasks and refusal conditions. `tests/task_cleanup_ui.py` drives the actual
keys, review without launching, cancellation, removal and recovery UI with mocked
agent CLIs. Both are part of `python3 tests/run.py`; no real user task is deleted
by these tests. Bulk removal, archive expiry and a one-click restore are deferred.
