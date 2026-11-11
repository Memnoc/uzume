# Agents and file context

Name a new branch, open the official Codex or Claude terminal on it, then write
your instructions there. New tasks use isolated worktrees; retained task branches
can be continued in their existing checkouts. The branch name is not an agent
prompt. tmux is not required.

## Controls

| Shortcut | Action |
| --- | --- |
| Space ac / Space aC | Codex / Claude with the current file |
| Space ae / Space aE | Empty Codex / Claude workspace |
| Space ab / Space aB | Choose an existing starting branch or continue a Codex / Claude task |
| Space af | Mark the current saved file for an agent |
| Space aF | Mark multiple files: Tab selects, Enter adds |
| Space am | Inspect context and delivery status; Enter removes a file |
| Space ad | Manually insert marked paths into the CLI's draft, without Enter |
| Space aa | Agents and attention |
| Space ar | Restart a stopped CLI with a fresh conversation |
| Space av / Space vr | Review this task's changes against its starting commit |
| Space vs / s in review | Preview and queue review comments for this task's agent |
| Space ww / Space ap | Windows / projects |
| Esc Esc in an agent | Editor controls; `i` returns to terminal input |
| Space pd / Space wd | Close pane / whole window |

`:UzumeAgent codex` and `:UzumeAgent claude` use the current file. Append `empty`
for an empty workspace. Instructions belong in the terminal, not this command.

## Branch selection and preflight

**Space ac / aC** asks for a new branch name, for example `fix/readme`. Press
**Enter** to start the agent on that exact branch, ready for your prompts, or
**Esc** to cancel. The current file's checkout supplies the starting state.
**Space ae / aE** and `:UzumeAgent` also ask for a branch name; empty launch uses
the active task's checkout or the original project. A notification identifies the
source branch and how many changed files will be inherited before you submit.
Invalid or existing names refuse launch; no existing branch is reset or replaced.

For a different starting point or a retained task, use **Space ab / aB**.
Rows show saved-change counts; the wrapped preview shows checkout paths and
changed files. Highlight a branch and press **Ctrl-s** to name a new task from
it, or **Enter** to open the new/continue action menu. Shortcut hints sit at the
bottom of the branch list, not in the preview or search bar. The menu offers:

- **New isolated task from this branch**: name a separate branch and create its
  worktree. Inherit saved changes when the selected branch has a checkout;
  otherwise use its committed files, without unrelated original-project edits.
- **Continue this task branch**: reuse its checkout, edits and review baseline.
  A running agent is focused, not duplicated. A stopped task starts the selected
  CLI with a fresh conversation. Current-file launch opens and marks that file's
  counterpart in the retained checkout. Known task windows and retained Uzume
  branches with recoverable branch-creation reflogs support continuation. Named
  tasks save their checkout and review baseline in a private local record under
  the distribution's data directory so closing a window does not lose that link.

Saved edits are disclosed rather than discarded. Unsaved buffers in the selected
checkout must be saved before launch. Conflicts, unfinished Git operations
(merge, rebase, cherry-pick, revert or bisect), and unavailable checkouts block
launch with an explanation. Branch HEAD and checkout status are checked again
after selection. These checks do not fetch remotes, predict merge conflicts with
`main`, or lock files against other running agents. Browsing never modifies Git.

`editor/agent/branches.py` reads Git metadata; `uzume.branch_launch` owns the
picker and advisories. Programmatic `uzume.agents.start()` remains available to
callers that explicitly choose a source. Continuation does not merge or delete
branches; integration and cleanup controls remain a separate increment.

**Current-file launch:** opens the file's counterpart from the new worktree on
the left, marks it as working context, and focuses the agent. The current file
must be saved. The new worktree inherits the source branch: its HEAD,
saved tracked edits, staged changes as they currently appear on disk, deletions,
and non-ignored new files. Related changes across that checkout travel together.
Unsaved editor buffers are not included. The source files, index/staging choices
and branch stay unchanged. The two working directories are independent afterward.

Launching selects the new task window and its branch/worktree. Root-based file
search, explorer, grep and Git tools remain anchored to that task checkout even
when an original-project or reference file is open beside the agent. Original
project windows retain their own checkout. Explicitly opening a reference file
still opens that exact path; it does not silently substitute another copy.

If inherited changes exist, Uzume records them in a local snapshot commit on the
**new task branch only**, with the source HEAD as parent. This becomes the review
baseline, so inherited user edits are not labelled as new agent work. Clean
checkouts reuse HEAD directly. Snapshot commits use a local Uzume identity and
do not run commit hooks or sign commits; worktree creation also skips repository
hooks. Nothing is pushed. Git's normal clean/checkout filters still apply.

The selected file may come from the original project checkout or any of its
open task worktrees, even when displayed inside another task window. Uzume maps
its relative path into the new checkout. Marking the original copy for an
existing agent does not prevent launching another agent with that file.
Files outside those checkouts remain references: start an empty workspace and
mark them with Space af, or open their own project. The warning explains these
options in a titled, wrapped Snacks notification; Space n reopens its history.

**Empty launch:** starts without marked files and opens a searchable chooser in
the left pane. Choosing a file opens it but does not mark it automatically. Use
Space af or Space aF when ready. Cancel the chooser to leave the left pane empty.
The checkout inherits the selected branch's saved state. "Empty" refers to
marked context for a new task; continuing a task retains its existing context.

Current-file launch starts from the checkout containing that file, even
when it is displayed in another task's window. A new file need not be committed
first. Ignored, untracked files are excluded; if the selected file is excluded,
Uzume explains why and opens the file chooser. Existing task worktrees are never
retroactively updated by this behavior.

Creation uses a temporary private Git index; it never stashes, resets or stages
the source checkout. It checks the captured tree twice and checks source HEAD and
index stability, rejecting detected concurrent changes rather than starting with
an uncertain capture. This is not an atomic filesystem transaction. Unresolved
merge conflicts and dirty submodule working trees refuse launch. Clean submodule
references are retained, but submodule working directories are not initialized.

Buffer tabs show files visited in the active workspace and its owned terminals.
Agent tabs replace the generic file icon with a compact terminal-friendly mark:
`✳` for Claude and `>_` for Codex. Icon colors use the theme's MiniIcons orange
and azure highlights; ordinary file and shell icons retain their normal provider.
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
Space af adds to an existing agent; it does not stage marks for a future launch.
Space ac / aC start a new agent with the current file already marked.

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

Review feedback uses the same prompt hook, or a turn-end continuation hook when
the agent is working. Explicitly queue a batch from **Space vs**; saved comments
alone remain local. See [sending review feedback](review.md#sending-review-feedback)
for cancellation, delivery status and restarting a stopped agent.

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
- `uzume.worktrees` launches the asynchronous `editor/agent/create_worktree.py`
  helper, which captures saved state with Git argument arrays and a private index.
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
agents, launching from a marked original-checkout file inside a task window,
readable rejection of unrelated files, empty launch from that same state,
pane cleanup, restart and layout restore. `--inputs-only` runs the input
regression; `--crash` tests forced editor exit.

`python3 tests/inheritance.py` checks inherited saved/staged/new/deleted/binary
files, executable modes, ignored-file exclusion, hook isolation, unchanged source
index/HEAD, the initial review baseline, and independent nested tasks.

`python3 tests/task_navigation.py` verifies automatic task checkout selection,
file search and explorer scope after reading an original file, and preservation
of the original project's branch and file content.

`python3 tests/named_launch.py` drives Space ac / aC through exact branch naming,
saved-state inheritance, idle CLI startup, invalid/existing names, unsaved-buffer
refusal and cancellation. `python3 tests/branch_launch.py` checks selection before launch, saved-change
disclosure, running/closed task continuation, current-file context, review baseline
retention, branches without checkouts and conflict refusal without index changes.

Authenticated hook delivery needs hands-on verification with the installed CLI
trust settings. Process ownership uses PID/start-time checks, not OS containment;
very quickly detached children and a killed supervisor can escape cleanup.
[Task review and queued feedback](review.md) are available. Linux, terminal
performance and authenticated feedback delivery remain hands-on validation work.
