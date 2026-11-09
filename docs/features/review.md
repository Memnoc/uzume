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
commit. An agent committing its work therefore does not hide changes from review.
Capture does not stage files, create commits, invoke external diff drivers or
text converters, modify Git's index, or send source to an agent or service.

Snapshots are private to this editor process and are not written to snapshot
files, swap, undo history or layout metadata. No new plugin is required: Python's
standard library and Git capture the data, Snacks provides the picker, and
Neovim provides native diff views.

## Limits and verification

This increment covers reading changes. Review comments, reviewed markers,
feedback delivery, integration/merging and PR review remain future work.

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
