# Session and workspace navigators

The editor preview now has native **Session Navigator** and **Workspace
Navigator** overlays, following Memnoc's Drudwyn screenshots. They use the same
dark surface, square border, salmon heading/selection, flat rows, muted secondary
columns, generous space, and bottom shortcut strip. The workspace panel separates
WORKSPACES and AGENTS. The terminal supplies the font and glyph rendering.

There is no tmux dependency. A session is currently a native Neovim tab with a
project/worktree directory; a workspace row selects an editor or terminal window
inside one of those tabs. These are windows within this Neovim instance, not
other terminal tabs or separate Neovim processes. Existing splits remain the
layout mechanism. Buffers remain shared across Neovim tabs; this increment
organizes windows and directories rather than providing separate buffer lists.
The session panel says **current** or **hidden**, because tmux
client attachment is not part of this model.

## Controls

Restart ai-nvim to load this increment, then use:

| Control | Action |
| --- | --- |
| Space aw / `:AiWorkspaces` | Toggle the workspace/window navigator |
| Space as / `:AiSessions` | Toggle the session navigator |
| j/k or arrows | Move through entries; wraps at the ends |
| Enter | Jump to the window, or switch to the session's last editor/terminal window |
| / | Type a live, case-insensitive substring filter |
| Ctrl-u | Clear the filter; while typing, clear the input |
| r | Edit the selected session/window's display name; Enter applies, Esc cancels |
| x, then y | Confirm closing the selected window/session |
| n or Esc at confirmation | Cancel closing |
| s | Save the editor layout locally |
| Esc / q | Close the navigator and return focus |
| Mouse click / wheel | Select a row / move selection, when editor mouse support is enabled |

While typing a filter, Enter or Esc returns to the list with the current filter.
A second Esc closes the panel. Letter keys typed in the filter are text, so
typing `x` cannot close a session. Filtering includes names, project paths and
agent kind/state when supplied. Renaming changes a display label, never a file
or directory. Long lists scroll to retain the selected row; narrow panels wrap
the shortcut strip. The preview was checked at 150×45 and 80×24 cells.

The Space a group keeps the existing Space w window commands and Space s search
commands available. These are provisional shortcuts for the usability trial.

Create another session with an existing local project/worktree path:

```vim
:AiSession /Users/matteostara/Code/tmux-drudwyn
```

`:AiSession` without a path creates a tab at the current directory. Opening the
navigator adopts an ordinary tab as a session; existing native tabs appear too.
The tab's working directory provides a root for an empty editor and the explorer;
the existing file/LSP root detection continues to work for opened code. The
command does not create a Git worktree. Use distinct existing worktrees for
independent tasks; this increment does not yet enforce branch isolation.

## Closing and terminal lifetime

Switching sessions or closing the navigator leaves terminal jobs running.
Confirmed navigator close stops the affected native terminal job; closing a
session also stops its hidden owned terminals. Closing a native tab directly
likewise cleans up terminals owned by that tab. Closing a file window retains
its file on disk, and modified displayed files block navigator close. Closing
the final window/session leaves a usable empty editor.

A terminal displayed in another session/window blocks navigator close, avoiding
accidental termination of the other view. Ordinary terminal toggles still hide
their window. Use the navigator's confirmed close when termination is intended.
Neovim's native job cleanup is used here; complete Codex/Claude descendant-process
supervision remains part of the agent integration increment.

## Local save and restore

`s` saves **manually** to
`stdpath("state")/navigator/snapshot.json` in ai-nvim's state directory. There is
one latest snapshot, written atomically with file permissions 0600 in a 0700
directory. Save contains native file layout/cursor references and session/window
labels. It does not save file contents, terminal transcripts, agent prompts,
credentials, or terminal launch commands, and sends nothing externally.

In a fresh ai-nvim dashboard or one empty unnamed window, run:

```vim
:AiSessionRestore
```

Restore reopens saved files/tabs and does **not** start terminals or agents.
Existing editing layouts are refused. Neovim's `mksession` supplies the layout,
with terminal, option, global-variable and hidden-buffer capture excluded. If
an argument list contains a terminal reference, save refuses it instead of
recording a script that might restart a process. Snapshots are locally generated
session scripts inside JSON; do not substitute downloaded/untrusted snapshots.
Source files still require `:w` or Ctrl-s.

This is a persistence probe, not the planned full autosave system. Terminal
panes and auxiliary plugin panels are omitted on restore; native layout sizing
can change when those panes disappear. Labels for multiple views of the same
file share one saved label. There is no snapshot history, cross-instance merge,
automatic restore, or session autosave yet. Delete the snapshot to forget the
saved layout. Existing Neovim undo/recovery remains separate.

## Implementation and remaining work

[navigator.lua](../../editor/lua/ainvim/navigator.lua) renders native floating
windows and handles navigation, input, filtering, confirmations and resize.
[sessions.lua](../../editor/lua/ainvim/sessions.lua) owns tab/window discovery,
names, switching, terminal cleanup and local snapshots. No plugin or external
multiplexer was added. A one-second refresh keeps an open list current without
changing focus; Smear is disabled inside the overlay.

The AGENTS section is reserved for managed agent terminals. Ordinary shells are
not guessed to be Codex/Claude by reading their output, and no example statuses
are presented as live data. Until the earlier agent pilot is integrated, the
normal editor shows **No managed agents**. Attention events, feedback delivery,
worktree creation and the review suite remain separate work.

See the [navigator probe record](../prototypes/0007-native-navigators.md) for
verified behavior and the remaining usability evaluation.
