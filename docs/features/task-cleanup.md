# Retained tasks and cleanup

**Space at** lists retained tasks for the current Git repository, including closed
agent windows. Select a branch and press Enter to inspect it. This manages Uzume
checkouts under its own `data/worktrees` directory; ordinary branches and your
primary checkout are not cleanup targets.

The picker loads task names without scanning every checkout's contents. Rows say
**Not inspected** until you select one; **Open in editor** is a local window/buffer
hint. Press Enter to calculate the selected task's current changes, integration
evidence and removal guards. The list itself never authorizes removal.

| Control | Action |
| --- | --- |
| Space at | List retained tasks; Enter opens their details |
| Esc / b in details | Back to the task list, preserving search, selection and scroll position |
| q in details | Close the browser and keep the task |
| Esc in the list | Close the browser |
| v | Review the retained task without starting an agent; use i in review to integrate |
| x | Remove the selected task after typing its exact branch name |
| r | Refresh the preview and guards |
| h / Space aT | View local recovery history |
| ? | Show the complete key guide |

## Browsing without losing your place

Type in the list to filter, move to a task and press **Enter**. The list footer
shows these controls. Details show **Esc / b Back to tasks** separately from
**q Close**, both in the action text and the bottom border. Returning with Esc/b
restores your filter, highlighted row and scroll position. Closing with q (or Esc
from the list) ends that visit; a new **Space at** starts a fresh list.

While inspection runs, **Checking task…** identifies the branch and project and
explains what is being checked. Esc/b returns to the same list, and q closes.
Leaving dismisses the result; the read-only helper may finish in the background,
but it cannot reopen details or steal focus. A failed request shows its error
with **r Retry**, **Esc/b Back** and **q Close**. Retrying inspects current state.

Returning reuses the discovered list for that visit; reopening Space at refreshes
the inventory if another tool created or removed tasks. Every selection still
inspects live state, and removal keeps its separate fresh validation. Search and
selection are transient UI state, not a cached removal decision. Review and
recovery remain separate views with their own existing controls.

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

The completion screen and **Space aT** offer guided recovery as well as manual
Git commands. Select a snapshot in history, then:

1. Press **r Restore to a new branch**.
2. Enter a new branch name, then an absolute path for a new directory. Defaults
   use the snapshot ID; the directory's parent must already exist.
3. Read the preview, which shows the original snapshot, new branch and directory.
   **e** edits the choices; **Esc/b** returns to the snapshot; **q** closes.
   Nothing is created before confirmation.
4. Press **Enter Restore & open**. After completion, choose a recovered file in
   a new editor window under the same project. The window is named
   **Recovered · branch** and uses the recovered checkout as its working directory.

| Recovery screen | Controls |
| --- | --- |
| Snapshot / history entry | r restore; q/Esc close; manual commands remain visible |
| Branch and directory prompts | Ctrl-u clears the field; Enter next; Esc back |
| Preview | Enter restore & open; e edit; Esc/b back; q close |
| Destination or restore error | e edit choices; Esc/b back; q close |
| Restore in progress | q/Esc closes the view; the confirmed operation continues |

Recovery restores the original HEAD, working files, and index separately. This
preserves staged versus unstaged edits, deletions and untracked files rather than
committing everything together. Existing branches/directories (even empty ones
or dangling symlinks), paths inside this repository's other checkouts/Git storage,
submodules, and clean/smudge filters or working-tree encodings are refused. The
preview pins archive object IDs; confirmation rechecks the plan and destinations.

The archive stays available, so another recovery can use different new names.
An agent is not restarted and an old CLI conversation or review session is not
reattached. The recovered window is an ordinary editor checkout. Closing the
progress view does not cancel a confirmed Git operation: completion is reported
by notification and does not reopen the view. Open the reported directory with
the project picker if you chose to close the progress view.

If a restore fails after starting, any created branch/directory is kept for
inspection. The error reports the path and attempt record; the original archive
is unchanged. Inspect the partial result before choosing another destination.
Attempt records live in `stdpath("state")/task-restores/<id>.json` with states
**restoring**, **restored**, or **partial**. A process crash can leave **restoring**;
it is not proof of success. No automatic rollback deletes a partial checkout.

Manual commands remain available for explicit execution. They recreate a separate
checkout from the original HEAD, restore working files, then restore the index.

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
It also dispatches `restore-plan` and `restore` to `agent/recovery.py`.
`uzume/agents/recovery.lua` owns snapshot display, branch/directory prompts,
preview, progress/errors and reopening files. Recovery uses an atomic directory
reservation and Git's new-branch creation; it never force-replaces a destination.
Archived attributes are checked with a temporary index before checkout, and
hooks are disabled for helper Git commands. See [ADR-0013](../adr/0013-guided-task-recovery.md).
New tasks always save metadata under `data/task-branches`; legacy linked checkouts
in managed storage are discovered conservatively. Inspection uses a temporary
index and object directory, so it does not alter the repository's index or objects.
Discovery reads metadata and one Git worktree listing, reusing repository identity
lookups within that request. Only the selected checkout gets full inspection;
removal repeats its fresh checks under the existing lock. There is no persistent
status cache that could authorize removal using stale results.

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
by these tests. Bulk removal and archive expiry remain deferred.

`tests/task_restore.py` exercises the public JSON interface with real Git:
preview without mutation; original HEAD/index/working recovery; unchanged source
checkout; invalid/occupied destinations; stale snapshots; filter refusal; and
an injected restore failure that retains a partial checkout and receipt.
The cleanup UI test covers Space aT, branch/directory prompts, destination errors,
preview cancellation and reopening a restored file without launching an agent.

`tests/task_inventory.py` covers a dozen metadata-backed and legacy checkouts
through the JSON command interface. It traces real Git subprocesses to enforce a
small discovery budget and verifies that inspection only scans the selected
checkout. This prevents the previous eager scan (404 Git processes / about 4 s
for 16 local tasks). The same local inventory measured about 0.06 s after the fix;
timings depend on storage and repository size, and detailed inspection can take
longer for a large selected checkout.

The latency fix passed the inventory and cleanup backend regressions, plus the
real-editor cleanup flow on the local development Neovim and minimum 0.11.0.
The full unrelated editor suite was not repeated for this backend-only change.

`tests/task_browser.py` covers filtered return navigation, selection restoration,
explicit close, slow inspection, ignored late results and retry after an external
task change. It drives real editor keys and Git in disposable state, delaying Git
at the subprocess boundary to make the progress behavior reproducible. The test
is included in the consolidated runner.

The navigation polish passed that browser test on the local development Neovim
and minimum 0.11.0, the existing cleanup UI regression on the development build,
the inventory work-budget regression, and Lua formatting/whitespace checks.
Unrelated editor tests were not rerun for this UI-only change.

Guided recovery verification: the consolidated suite passed **28/28** cases on
the local macOS development setup. The strengthened recovery UI test then passed
on both development Neovim and 0.11.0, including exact branch-name entry after
Ctrl-u clear and completion without focus theft after dismissing progress.
The expanded backend test also passed destination-race and foreign-repository
checks. Python syntax, Lua formatting and whitespace checks passed. Linux remains
covered by the CI matrix; these local results are not a Linux execution claim.
