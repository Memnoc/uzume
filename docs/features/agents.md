# AI tasks and agent terminals

Start a task inside an open Git project. Uzume creates a new branch and worktree,
then opens a dedicated window with a searchable file chooser on the left and
the selected official CLI on the right. Choose a file and press Enter to open it
in the left editor pane; the agent stays visible and running. The chooser is
rooted in the new worktree, so you inspect the same files the agent edits.
Escape dismisses the chooser; Space Space or Space e lets you choose later. Task windows remain grouped under the same
project. Codex and Claude Code are the initial adapters; tmux is not required.

## Controls

| Shortcut | Action |
| --- | --- |
| Space ac | Describe and start a Codex task |
| Space aC | Describe and start a Claude Code task |
| Space aa | Pick an agent; actionable states appear first |
| Space af (from a file) | Add its worktree-relative path to this task’s agent prompt |
| Space ar | Start a fresh CLI in the selected stopped task's existing worktree |
| Space ww / Space aw | Window navigator, including agent states |
| Space ap | Project navigator |
| Space e / Space Space | Explorer / file search in the task checkout |
| Esc Esc in an agent | Return to editor controls; `i` resumes terminal input |
| Ctrl-C in an agent | Deliver the CLI's interrupt key |
| Space pd / Space wd | Close pane / whole task window, with confirmation |

`:UzumeAgent codex <instruction>` and `:UzumeAgent claude <instruction>` also
create tasks. The task field is the **initial instruction**: pressing Enter
creates the worktree and passes the full text as the CLI's initial prompt.
Authentication and trust prompts may still need your response before work begins.
Window and branch labels use a shortened version for readability; shortening does
not change the instruction. Arguments are passed directly, not through a shell.
The file chooser remains available beside the running agent; selecting a file
alone does not add context to that initial instruction. Single Escape, `jk`, and Ctrl-w pass through
in agent buffers. Ordinary shell mappings remain separate. Pane movement,
resizing, floating, fullscreen and hide/restore use the existing Space p controls.
An agent pane stays in its task window; transferring it into another checkout's
window is currently refused.

## File context and terminal labels

Opening a file does not tell the CLI which file you chose. From the editor pane,
press **Space af** to add an exact, quoted path relative to this task's worktree
and focus its agent. It inserts a draft reference at the CLI input cursor using
bracketed paste; **it does not press Enter**. Add your question and submit when
ready. Existing prompt text is retained. Use this at the CLI's message prompt;
known working, permission/input-waiting and starting states refuse the handoff.
If hook status is unknown, inspect the terminal before using the action.

The file must be saved and inside the task's checkout. Unsaved changes are not
silently written or sent, and source text is not copied into the prompt. The CLI
reads the referenced file after you submit. This is a file-reference handoff,
not automatic context synchronization or queued review delivery.

Agent buffer tabs and the filename section of the statusline show **Codex · task**
or **Claude · task**. The earlier `python3` label was the terminal supervisor's
process name; that buffer is the agent terminal, not an extra editor file.

## Checkouts and lifetime

New tasks start at the parent project's **committed HEAD**, captured before
worktree creation. Uncommitted and untracked files in the original checkout are
not copied. Concurrent launches, including identical task names, get distinct
`uzume/<name>-<id>` branches and checkout directories. Repositories without a
commit cannot create tasks. Dependency installation in a new checkout remains
manual; Uzume does not run project setup scripts.

Switching windows or hiding panes keeps agents running. Closing a managed pane,
window or project stops its CLI and observed descendants. Project close checks
for modified visible/managed hidden source buffers before stopping anything.
When the CLI exits normally, its terminal pane and buffer tab disappear and the
remaining editor pane expands. Floating/hidden agent panes and their placeholders
are removed too. Background exits do not switch focus. If the terminal was the
last tiled pane, Neovim retains an empty editor pane. A failed launch/exit keeps
its terminal output visible for diagnosis. A turn ending while the CLI remains
running does not close its pane.

Normal editor exit also stops supervised agents. Closing never deletes the
worktree or branch. Task restart starts a **fresh conversation**, not an automatic
resume, and does not replay the original instruction; saved CLI conversations
remain under the CLI's own control.

A saved layout retains project identity, task name, branch and checkout path.
Restoring it launches no agents. Select a restored task window and press Space ar
when ready to start its CLI. Layout saving still requires docking floats and
restoring hidden panes; full project autosave is separate work.

## Attention

The window navigator refreshes agent states; Space aa opens a focused picker
with project, task, state, waiting age and reason. The statusline retains an
attention count across projects. A transition to waiting, review or failed shows
a notification without moving focus. Ordinary progress stays quiet.

Status comes from lifecycle hooks, not terminal text or inactivity. `unknown`
means the CLI is running without a usable hook signal, including login/trust
screens. `review` means a turn ended or the CLI is awaiting another instruction;
it does not certify that the requested task is complete. Worker events do not
mark the parent task finished. Comprehensive worker needs and semantic blockers
are not inferred in this increment.

## Implementation and data

- [worktrees.lua](../../editor/lua/uzume/worktrees.lua) creates worktrees through
  asynchronous argument-array Git calls. It never runs task names as shell code.
- [task_editor.lua](../../editor/lua/uzume/task_editor.lua) opens the file chooser
  within the left pane and restores normal editor options when a file opens.
- [agents.lua](../../editor/lua/uzume/agents.lua) owns terminal buffers, task
  metadata, status polling, attention and launch/restart controls.
- [supervisor.py](../../editor/agent/supervisor.py) runs the official CLI in the
  terminal, supervises its process tree, and consumes local hook events.
- [hook.py](../../editor/agent/hook.py) reads only selected lifecycle fields.
  It returns no permission decision and retains no prompt, tool arguments or
  transcript content. Malformed/oversized payloads are ignored.

Dependencies are Git, Python 3, `ps`, and the chosen installed CLI. No additional
Neovim plugins are needed. The current CLI baseline is Codex 0.167.0 and Claude
Code 2.1.319. The CLIs remain separately installed; this preview does not update
them. Unsupported flags/hooks after an external upgrade may require adapter
changes.

Worktrees live under `stdpath('data')/worktrees/<project-id>/`; per-launch metadata
and hook settings live under `stdpath('state')/agents/<run-id>/`. These currently
resolve inside the preview's existing `ai-nvim` data/state directories. Runtime
directories are private and metadata files are owner-readable/writable. Records
contain paths, process identity, lifecycle state and fixed explanations. They
are retained locally; a retention/cleanup interface is not yet implemented.
The full initial instruction is placed in the private launch file for handoff;
the supervisor removes it from that file after reading it. Only the shortened
task label remains in workspace metadata. Normal CLI prompt history remains
under the CLI's control. Restart and layout restore do not resend the instruction.

The CLI owns browser/SSO authentication, permissions and its own data handling.
Uzume preserves the user's authentication homes, adds hooks only for the launch,
and does not write global CLI settings or store credentials. Codex runs with
`--no-daemon` to keep the launched process lifecycle local. Review Uzume's status
hooks through `/hooks` if Codex requests trust; Uzume does not bypass that review.
Hook availability remains subject to enterprise policy. See the official
[Codex hook reference](https://developers.openai.com/codex/hooks) and
[Claude hook reference](https://code.claude.com/docs/en/hooks).

## Verification and limits

`python3 tests/agents.py` exercises the actual Neovim UI through a PTY using four
local mock CLIs and disposable Git repositories. It covers independent checkouts,
project grouping, unchanged dirty source checkout, attention without focus changes,
worker event filtering, metadata privacy, hide/float/restore, scoped cleanup,
modified-file close guards, initial instruction delivery (including long text
and option-like text), collapse on CLI exit, restart without prompt replay, and
snapshot restore without starting agents.
Run with `--crash` to exercise forced editor termination instead of normal exit.
The test uses installed pinned packages but isolates writable data, state and
cache. It makes no model requests.

Process tracking records PID and start time, and stops only matching observed
processes. Very short-lived parents that detach children between samples can
escape observation. Forced termination of the supervisor itself can also prevent
cleanup; this is not an OS containment boundary. The suite passed on the installed nightly and Neovim 0.11.6, including normal
and forced editor exit. Both installed CLIs also reached initial interactive
setup under empty authentication homes. Linux, terminal performance, and
authenticated real task/hook flows still need hands-on validation.

Selection/content sending, queued review feedback, a dedicated interrupt-and-send action,
resume selection, worktree deletion and the full diff/review suite remain future
increments. Use the CLI's own input/interrupt controls for this trial.
