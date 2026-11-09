# Agents and file context

Open an agent workspace directly and write your instructions in the official
Codex or Claude terminal. There is no separate task-name or task-instruction
dialog. Both entry points retain an isolated Git branch/worktree under the
current project; tmux is not required.

## Controls

| Shortcut | Action |
| --- | --- |
| Space ac / Space aC | Codex / Claude with the current file |
| Space ae / Space aE | Empty Codex / Claude workspace |
| Space af | Mark the current saved file for an agent |
| Space aF | Mark multiple files: Tab selects, Enter adds |
| Space am | Inspect context and delivery status; Enter removes a file |
| Space ad | Manually insert marked paths into the CLI's draft, without Enter |
| Space aa | Agents and attention |
| Space ar | Restart a stopped CLI with a fresh conversation |
| Space ww / Space ap | Windows / projects |
| Esc Esc in an agent | Editor controls; `i` returns to terminal input |
| Space pd / Space wd | Close pane / whole window |

`:UzumeAgent codex` and `:UzumeAgent claude` use the current file. Append `empty`
for an empty workspace. Instructions belong in the terminal, not this command.

**Current-file launch:** opens the file's counterpart from the new worktree on
the left, marks it as working context, and focuses the agent. The current file
must be saved. The worktree still starts at the parent project's committed HEAD;
unsaved/uncommitted edits are not copied. If the file is absent from HEAD, Uzume
explains that and opens the file chooser instead.

**Empty launch:** starts without marked files and opens a searchable chooser in
the left pane. Choosing a file opens it but does not mark it automatically. Use
Space af or Space aF when ready. Cancel the chooser to leave the left pane empty.

Buffer tabs show files visited in the active workspace and its owned terminals.
The original checkout's buffer remains available in its original workspace; it
is hidden from the task's tab strip rather than closed or unloaded. A reference
file explicitly opened in the task workspace remains visible there.

Selecting an already visible agent buffer—by cycling buffers, clicking its tab,
using the buffer picker or `:buffer`—focuses its existing pane and keeps the
editor's file in place. It does not display the same terminal in both panes.
Floating, docking and swapping panes still move that single terminal normally.

## Marking, references and delivery

Marks form a per-agent list, not another session. Marking is idempotent and works
while an agent is busy. From outside a task window, Space af asks which agent
should receive the file. Space aF allows several files to be selected at once.
Space am shows the list, its working/reference roles, and the delivery state.

Files within the task's checkout are working files. Other local files—including
files from another project—are labelled **reference** and accompanied by an
instruction to use them as guidance without modifying them. This label is not an
OS write restriction. No extra writable directory or permission bypass is added;
the CLI's existing sandbox and permission prompts still apply. Paths, not file
contents, are supplied; unsaved changes must be saved before marking.

On your next submitted prompt, the configured `UserPromptSubmit` hook supplies
the current marked-file list as additional context. Browsing and marking alone
do not submit a model request. The statusline displays `Files N pending` until
the hook reports supplying that revision, then `Files N supplied`. This reports
hook delivery, not proof that the model read every file. Removing a mark affects
future prompts; it cannot erase context already in a conversation.

**Codex may require `/hooks` review and trust before context can be supplied.**
Enterprise policy may disable these hooks. Pending status remains visible when
no delivery signal arrives. Space ad is a manual fallback: at the CLI's message
prompt, paste the marked paths into the draft and press Enter yourself. Known
working or permission-waiting states refuse terminal insertion with a readable
message. Unknown state requires you to inspect the terminal first.

The adapters use the documented additive context output; they do not replace
existing developer/system instructions. See the official
[Codex hooks](https://developers.openai.com/codex/hooks) and
[Claude hooks](https://code.claude.com/docs/en/hooks) references.

## Lifetime and recovery

Switching windows and hiding panes preserves running agents. Closing a pane,
window or project stops its CLI and observed descendants. Normal CLI exit
collapses its terminal pane and removes its buffer tab, expanding the editor.
Floating/hidden placeholders are also removed, without switching to a background
workspace. If the agent was the last tiled pane, an empty editor remains. Failed
exits keep their output visible for diagnosis. A completed turn does not close a
still-running CLI. Worktree files and branches are never deleted on close.

Layout snapshots retain project/task identity and marked paths. Restoring starts
no agents. Space ar starts a fresh CLI with the retained context list available
for its next submitted prompt; it neither resumes a conversation nor replays an
instruction. Full autosave, conversation-resume selection and worktree cleanup
remain separate work.

## Implementation and verification

- `uzume.agents` owns launch, terminal lifetime, attention and shortcuts.
- `uzume.context` owns marks, role classification, atomic context manifests and
  context controls. Errors shown by agent actions omit internal Lua locations.
- `uzume.workspace_buffers` scopes the tab strip without deleting buffers.
- `uzume.agent_views` routes duplicate terminal selections to their existing
  pane after layout operations settle, restoring the displaced editor buffer.
- `uzume.worktrees` uses asynchronous argument-array Git calls.
- `editor/agent/supervisor.py` supervises the official CLI and observed children.
  `hook.py` supplies marked paths and lifecycle metadata, never logs incoming
  prompts/tool arguments/transcripts and never makes a permission decision.

Git, Python 3, `ps` and the chosen CLI are required. The current tested adapter
baseline is Codex 0.167.0 and Claude Code 2.1.319. CLIs own authentication and
credentials; Uzume does not change global CLI settings. Hooks and context
manifests live in private local `stdpath('state')/agents/<run-id>` directories;
worktrees live in `stdpath('data')/worktrees`. Metadata is retained locally;
a retention interface is still pending.

`python3 tests/agents.py` runs the actual editor with mock CLIs and disposable
repositories. It covers both launch modes without submitted prompts, workspace
buffer filtering, agent selection through keyboard/mouse/picker without mirrored
terminals, pane swapping/docking, file marking/deduplication, multi-select/removal, external
reference roles, hook output and metadata privacy, input deletion, concurrent
agents, pane cleanup, restart and layout restore. `--inputs-only` runs the input
regression; `--crash` tests forced editor exit.

Authenticated hook delivery needs hands-on verification with the installed CLI
trust settings. Process ownership uses PID/start-time checks, not OS containment;
very quickly detached children and a killed supervisor can escape cleanup.
Linux, terminal performance, the review suite and queued review feedback remain
future validation/work.
