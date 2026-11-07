# Drudwyn real-project pilot

Date: 2026-11-07. Status: initial hands-on feedback received; not production code.
Throwaway branch: `spike/drudwyn-pilot`.

## Question and authorization

Can Memnoc maintain reading flow while two real CLI agents work in separate
native Neovim sessions? The fixture trial was too artificial to judge shortcuts
and attention. Memnoc chose Drudwyn, approved the clear-filter task, and clarified
that the newly cloned `/Users/matteostara/Code/tmux-drudwyn` should be used.

The new clone and the previously inspected `tmux-agent-watch` checkout both
pointed at `570a865`; the new clone was clean. Two branches/worktrees were created
from that commit under `/Users/matteostara/Code/ai-nvim-worktrees`: Codex handles
the session navigator and Claude handles the workspace navigator. Each task adds
Ctrl-u filter clearing and its own narrow regression coverage. The assignments
do not share implementation files. No Drudwyn feature implementation has been
made by the pilot setup; the user starts the agents during evaluation.

## Implemented experiment

`./spike --drudwyn` opens the prepared source files and idle agent panes. Space o
opens the official CLI; Space t supplies its prepared task on launch. Hidden
sessions continue, attention never steals focus, and the existing tile/float,
zoom, keyboard, and mouse controls remain available. Ordinary terminal input
uses `i`; Esc twice returns to Normal mode for Space shortcuts.

CLI settings inject observational hooks for the process lifetime. The collector
stores only event/state/reason/time metadata, never prompts or transcripts.
Codex retains its normal hook review and trust flow. Original CLI auth homes and
XDG paths are preserved; no login handling or credential copies are introduced.
Outer tmux attribution variables are removed. Hook evidence is distinct from
process liveness. Missing signals remain unknown rather than inferred from
terminal text; a turn ending is not a claim that the task passed review.

A Python supervisor observes descendant process identities and terminates them
when the terminal job stops. Codex launches without its shared daemon. The
launcher supplies fallback cleanup on editor exit. Worktree files persist.
Session termination refuses unsaved buffers; normal quit uses Neovim's save
confirmation. Source autosave and durable layout/review recovery are not part of
this increment. The original `./spike` fixture mode remains available.

The implementation follows the documented [Codex hooks](https://learn.chatgpt.com/docs/hooks)
and [Claude hooks](https://code.claude.com/docs/en/hooks) interfaces. These are
observations, not an authorization mechanism: hooks never grant permissions.

## Development probes

Verified on this macOS machine with Neovim
`v0.12.0-dev-2155+g1e6c4ea896`, Codex `0.167.0`, and Claude Code `2.1.317`:

- Startup opens both real worktrees without launching an agent or sending a task.
- Two local mock CLIs run concurrently in native terminals, each with a child.
  Hook requests in a hidden session update attention without switching focus;
  selecting the attention entry jumps to the correct session. A worker Stop
  carrying an agent identity does not mark the parent turn complete.
- Real-mode floating, zoom/restoration, and retiling retain the terminal job.
- Session close refuses a modified source buffer. After clearing that probe-only
  flag, closing one session removes its supervisor, CLI, and child while the
  other continues. Quitting removes the remaining processes and temporary state.
- Hook payload sentinel content is absent from retained lifecycle state.
- The installed Codex accepts generated hook overrides under strict config
  validation with an empty temporary home.
- The original fixture mode still starts four fixtures and four workers,
  advances their heartbeats, and removes all eight processes on quit.
- Both installed CLIs reach their actual startup UIs inside Neovim with empty
  temporary homes: Codex sign-in and Claude theme setup. No credentials or model
  tasks were submitted. Killing only Neovim removes the recorded CLI descendants
  through launcher cleanup, then removes the runtime directory.

The probe scripts are disposable development tools, not a permanent test suite.
No authenticated turn, browser/Okta login, live provider hook delivery, completed
Drudwyn change, or resulting diff has yet been verified. Worker lifecycle signals
are incomplete; this pilot is not a full subagent monitor. Rapidly detached
processes that escape between snapshots and simultaneous forced termination of
both launcher and editor are outside the verified cleanup coverage. Linux,
minimum Neovim version, terminal-specific mouse behavior, and performance under
heavy output remain unverified.

## Next observation

Memnoc reports that the AI workflow feels more accessible than opening a
separate terminal. However, the editor lacks the feel, visual appeal, and
functionality of the current LazyVim configuration. The next priority is a solid
editor experience, then determining how the AI workflow best fits within it.

For sessions/workspaces, Memnoc prefers Neovim/LazyVim-style floating or anchored
menus that can expand and collapse through keyboard shortcuts. Their default
placement and exact interaction are still open; the pilot's tab presentation
is not a final navigation decision.

This feedback supports keeping agents close to code but does not validate full
editor parity, authenticated lifecycle reliability, or a production keymap.
Complete the editor baseline inventory and evaluate an editor-focused increment
before expanding AI features. Keep the existing pilot as a reference. Code
review snapshots and feedback delivery remain separate work. This pilot is not
approval to ship the prototype as the distro.

## Further notes

Source and the detailed usage guide live on `spike/drudwyn-pilot`, under
`spikes/native-sessions/`, with the root `./spike --drudwyn` launcher. Main keeps
design/findings and this branch pointer only. The two untracked task files in
the prepared Drudwyn worktrees are intentional local pilot inputs.
