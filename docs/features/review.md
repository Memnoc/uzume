# Task review

Review a task's complete saved change against the commit it started from. The
picker includes committed edits, staged/unstaged edits, deletions and untracked
files. Ignored files are excluded. Renames appear as deletion plus addition in
this first version.

## Controls

| Shortcut | Action |
| --- | --- |
| Space vr / Space av | Open task changes; choose a task from the project if needed |
| Enter in the picker | Open the selected file |
| Space vf / f in review | Return to the changed-files picker |
| Space vu / u in review | Toggle side-by-side / unified diff |
| ]c / [c | Next / previous hunk |
| Tab in review | Switch between the base and captured sides |
| Space vR / R in review | Capture and display the latest saved changes |
| Space vq / q in review | Close review and return to the previous pane |
| Space vc / c in review | Comment on the current line or visual line range |
| Space vC / C in review | List saved local comments for this task |
| Space vs / s in review | Preview unsent comments or inspect the pending batch |

Side-by-side is the default: the starting commit is on the left, captured task
content on the right. Review opens above the existing workspace without
rearranging its editor and agent panes. Both sides are read-only. Mouse clicks
or Tab select either side. The footer lists local shortcuts. Existing editor diffs
are temporarily excluded from comparison and restored when review closes.
The toggle retains the nearest corresponding source line when that line appears
in the unified patch. It never silently changes mode to fit a narrow terminal.

## Stable snapshots

Opening review captures saved worktree content in memory. The agent continues
working, but the displayed text stays fixed. A periodic local check marks newer
changes in the footer; refresh is explicit. Unsaved editor buffers are not part
of capture. Closing review discards its snapshot; reopening captures again.

The baseline is the task's recorded starting commit, not the agent's latest
commit. New tasks with inherited local edits use their inherited-state snapshot
commit; those edits are already part of the starting point. Review therefore
shows what changed after launch. An agent committing its work does not hide
changes from review. Older tasks retain their original recorded baseline.
Capture does not stage files, create commits, invoke external diff drivers or
text converters, modify Git's index, or send source to an agent or service.

Snapshots are private to this editor process and are not written to snapshot
files, swap, undo history or layout metadata. No new plugin is required: Python's
standard library and Git capture the data, Snacks provides the picker, and
Neovim provides native diff views.

## Local review comments

Press **c** on a line, or select lines with `V` and press **c**, to open a
multiline floating editor. **Ctrl-s** saves the comment locally and returns to
the same diff side. Escape returns to normal mode; **q** in normal mode or
**Ctrl-c** cancels the unsaved edit. The composer does not send anything to the
agent.

**C** opens the comment list. Enter inspects the full comment and its original
excerpt. In that view, **e** edits the text, **d** offers deletion, and **q**
returns to review. **s** opens the send-review preview. The list shows file/line
references, outdated status, and whether that comment version is draft, queued,
supplied, paused, or awaiting an uncertain handoff.

Both side-by-side and unified views support comments. Unified selections may
include removed and added lines in one hunk; the saved comment keeps separate
base and task ranges. Diff headers, unavailable previews and empty file sides
are not comment targets. Character selections are expanded to whole lines;
block selections are not supported in this increment.

Comments retain their original file, line numbers, selected code, baseline and
snapshot identity. Refresh never reanchors them silently. If that file's content
or change status differs in the new snapshot, its comments are labelled outdated.
This deliberately checks the whole file, so an edit elsewhere in it also marks
the comment outdated. Comments on unchanged files stay current. Editing a
comment changes its body, not its anchor. The indicator compares review
snapshots, not the live worktree before refresh.

Saved drafts survive closing review and restarting Uzume. They live in
`stdpath('state')/review-comments/`, in one JSON file per task. The directory is
owner-only (`0700`), records are owner-readable/writable (`0600`), and saves use
atomic replacement. Only selected excerpts and comment text persist; the full
review snapshot remains in memory. Deleting a comment removes it from the saved
record. Closing a task retains its comments along with its checkout. No automatic
expiry or task-wide cleanup interface is included yet. This local state is not
encrypted. Deleting a draft does not remove its copy from an already queued or
supplied feedback batch.

## Sending review feedback

1. Save your comments, then press **s** in review or **Space vs**.
2. Read the floating preview: it names the task and agent and contains all unsent
   comment versions, file paths, original line ranges, and code excerpts.
3. Press **Ctrl-s** to explicitly queue this frozen batch for that task's agent.
   Opening the preview or saving a comment alone never publishes feedback.
4. If the agent is working, its next eligible end-of-turn hook supplies the batch
   and requests a continuation. If it is idle, press **a** to return to its terminal
   and submit a prompt such as `Apply my queued review`. The prompt hook supplies
   the batch alongside marked file context.
5. **r** refreshes delivery status. **x** cancels a pending batch. **q** returns to
   review. These shortcuts also appear in the preview footer.

Delivery does not type into the terminal, submit a draft, or steal focus. Permission
and question prompts are left to the user. For urgent feedback, queue it, press
**a**, interrupt using the CLI's own controls, then submit your correction; the
queued review accompanies that prompt. An automatic interrupt-and-send action
is not implemented in this increment.

Only one batch is queued per running task. Reopening **s** shows that pending
batch. Cancel it before replacing it. Editing or deleting a comment never changes
an already queued batch: cancel and preview again to include the new version.
After delivery, unchanged comment versions are omitted from the next preview;
edited versions are eligible again. Outdated comments remain visibly labelled
and retain their original excerpts; the agent is instructed to check current
code before applying feedback. This is not automatic reanchoring.

**Supplied** means the hook emitted the batch, not that the model read, accepted,
or completed it. If a hook claims a batch but crashes before recording output,
the UI shows **handoff uncertain** and does not automatically replay it. Cancellation
and delivery use an atomic rename: cancellation succeeds only before the hook
claims the pending batch. Hooks disabled by policy or not yet trusted leave the
batch pending. A continued Stop hook does not consume another batch; that batch
waits for a later user prompt or eligible turn end, avoiding continuation loops.

Stopping an agent pauses its pending delivery. Restarting a CLI never republishes
feedback automatically. Open **s** and queue again explicitly; Uzume retires the
previous run's pending copy before publishing to the new run. Original comments
and batch records remain available locally. The first version shows unsent work,
the pending batch, or the latest batch; a full delivery-history browser is deferred.

### Implementation and storage

`uzume.review_feedback` provides the preview; `review_feedback_store` owns frozen
batches and run identity. Batch records live under
`stdpath('state')/review-feedback/<task-hash>/`; run-scoped pending/claimed packets
and receipts live under `stdpath('state')/agents/<run>/feedback/`. Directories use
`0700`, records `0600`, and publication is atomic. The 256 KiB packet limit fails
visibly. Batch records and packets retain the explicitly shared comment text and
selected excerpts, including cancelled batches. There is no automatic expiry or
history-cleanup UI yet. Full snapshots and CLI transcripts are not copied.

The hook uses `UserPromptSubmit` additive context and `Stop` continuation output,
with no permission decisions or subagent delivery. These contracts are documented
by [Codex](https://developers.openai.com/codex/hooks) and
[Claude Code](https://code.claude.com/docs/en/hooks#stop-decision-control).
Hook output is not an acknowledgement from the model; authenticated, policy-enabled
delivery still needs a hands-on check in the user's installed CLIs.

## Limits and verification

This increment covers reading changes, local comments and explicit queued feedback.
Reviewed markers, integration/merging and PR review remain future work.

Binary/non-UTF-8 files, submodules and special files have an explicit unavailable
preview. Symlinks show their target text without reading the target. Text
previews are limited to 1 MiB per side; captures to 500 files and 16 MiB of source
text. Larger captures fail visibly rather than silently omitting files.

Capture reads files in sequence, not as an atomic filesystem transaction. Normal
concurrent writes detected during capture fail with a refresh instruction. Once
capture succeeds, its text is stable. Changes checks use file status and stat
metadata; deliberately preserved timestamps may evade the hint. Refresh always
rereads content. Only one review workspace is open at a time.

`python3 tests/review.py` exercises the real editor with disposable Git worktrees
and a mock agent. It verifies the task baseline, committed/working/untracked
changes, stable snapshots, explicit refresh, diff presentation and preservation
of the running agent and underlying pane layout.

`python3 tests/review_comments.py` exercises comment composition, saved line
ranges and original excerpts, refresh/outdated status, editing and deletion,
local persistence and the absence of terminal input to the agent.

`python3 tests/feedback.py` and `python3 tests/feedback.py claude` exercise actual
Neovim controls with isolated mock CLIs and the real hook entry point. They cover
preview versus publication, single-use delivery, cancellation, outdated excerpts,
additive file context, ignored worker/permission events, edited comment versions,
restart isolation and private batch storage. They make no model requests.
