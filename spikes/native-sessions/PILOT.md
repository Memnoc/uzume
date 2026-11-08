# Drudwyn pilot

Throwaway branch: `spike/drudwyn-pilot`. Question: does native session switching
and attention handling feel useful when Codex and Claude work on real code?

## Run

```sh
~/Code/ai-nvim/spike --drudwyn
```

Use a wide terminal. The first session shows the session navigator source and a
Codex launch pane; the second shows the workspace navigator and Claude. Neither
agent starts automatically.

1. Press **Space o** to open Codex without submitting work. Complete any normal
   CLI setup. Open `/hooks` and review/enable the ai-nvim hooks if Codex marks them
   as needing review. These hooks only report local lifecycle metadata.
2. In Codex, ask **Read .ai-nvim-task.md and carry out the task.**
3. Press **Esc twice**, then **Space 2** and **Space o** to open Claude. Complete
   its normal setup, then give it the same instruction.
4. Press **Esc twice**, then **Space 1** or **Space 2** to switch, or **Space a**
   to select an agent needing you. Press `i` to type into a focused terminal.
5. Save editor changes with `:w`. **Space q** quits, checking unsaved buffers.
   **Space x** terminates only the current session after confirmation.

After initial CLI setup, **Space t** can launch an idle agent with the task
already supplied. On an already-running agent, it focuses that terminal and
asks you to submit the instruction yourself; it never duplicates the task.
**Space ?** shows all controls. Layout/mouse controls match the fixture spike.
`Space b` and `Space c` cannot send fixture commands to real agents.

## Prepared work

Both worktrees originate from clean `tmux-drudwyn` main at `570a865`. The pilot
uses `~/Code/tmux-drudwyn`, not the older `tmux-agent-watch` clone.

| Session | CLI | Worktree under `~/Code/ai-nvim-worktrees/` | Branch | Assigned file |
| --- | --- | --- | --- | --- |
| sessions | Codex | `drudwyn-sessions` | `ai-nvim/clear-filter-sessions` | `src/session_navigator.rs` |
| workspaces | Claude | `drudwyn-workspaces` | `ai-nvim/clear-filter-workspaces` | `src/navigator.rs` |

The task is Ctrl-u to clear a navigator's search query while staying in filter
mode, preserving other modes and normal text input. Each agent adds its own
regression coverage and footer hint in its assigned file. Task copies are in
[tasks/sessions.md](tasks/sessions.md) and [tasks/workspaces.md](tasks/workspaces.md),
and locally in each worktree's untracked `.ai-nvim-task.md`. Agents are told to
leave changes uncommitted for review. Nothing automatically merges or pushes.
Worktrees isolate files and branches; they are not permission sandboxes.

The launcher validates these prepared worktrees, branches, task files, and CLI
availability. It does not create/delete worktrees or prepare arbitrary projects.
This is deliberately a machine-local pilot, not a portable installer.

## What persists and what stops

Worktree source files and the task files survive exit. Neovim's temporary
configuration and lifecycle records do not. Save source edits explicitly;
autosave, layout recovery, review snapshots, and queued feedback are not built
yet. Use Git locally to inspect the resulting diffs.

The installed official CLIs retain their own authentication, permissions,
history, and normal service connections. The supervisor restores original XDG
paths and preserves agent homes. It does not copy credentials, write a login
configuration, or read transcripts. Normal CLI work sends prompts/context to
the chosen provider; the distro's status collector itself makes no network calls.

Hook settings are supplied for these launches only. Existing CLI policies
remain in force. Codex hook trust is handled through its normal `/hooks` review;
there is no trust or permissions bypass. `TMUX` and `TMUX_PANE` are removed from
the child environment to avoid attributing these agents to an outer tmux pane.

Codex runs with `--no-daemon`. A small Python supervisor tracks descendant PIDs
and process start times, stopping those observed processes on exit. A launcher
fallback runs if Neovim crashes. This is a prototype: a rapidly detached child
that escapes between process snapshots, or killing both launcher and editor
forcibly together, is outside the verified cleanup coverage.

## Reading status

`process` means only that the supervised CLI is running or exited. `hook` means
a lifecycle event was received. Waiting and review signals appear in the
attention selector without switching focus. A stopped turn is a request to
inspect the result, not a claim that the task succeeded. Worker events carrying
an agent identity are ignored so their completion does not finish the parent.

Disabled, untrusted, unsupported, or missing hooks can leave status incomplete.
The pilot does not infer progress from terminal text or claim to detect every
blocked state. Inspect the CLI when evidence is missing.

## Evaluation

The first useful feedback is whether you can read code in one session, notice
the other agent needs you, switch to it, and return without losing your place.
Final shortcuts and styling remain open. See the
[probe record](../../docs/prototypes/0002-drudwyn-pilot.md) for tested boundaries.
