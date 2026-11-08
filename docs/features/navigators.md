# Project and window navigators

The native navigator overlays retain the supplied Drudwyn appearance: dark
surface, square border, salmon heading/selection, flat rows, muted secondary
columns and a visible shortcut strip. The hierarchy is now **project → windows
→ panes**. The project navigator selects a complete project; the window navigator
selects a complete pane layout, not one split. No tmux dependency is required.

## Controls

Restart ai-nvim to load the current increment.

| Control | Action |
| --- | --- |
| Space ap / `:AiProjects` | Toggle the project navigator |
| Space aw / `:AiWindows` | Toggle the window navigator |
| Space as / `:AiSessions` | Compatibility alias for the project navigator |
| `:AiWorkspaces` | Compatibility alias for the window navigator |
| n | New shell window in the selected project |
| e | New editor window in the selected project |
| N (Shift-n) | Prompt for an existing project directory |
| j/k or arrows | Move through entries |
| Enter | Switch to the selected project/window |
| / | Type a live, case-insensitive substring filter |
| Ctrl-u | Clear the filter or inline input |
| r | Rename the selected project/window display label |
| x, then y | Confirm closing the selected project/window |
| n or Esc at confirmation | Cancel closing |
| s | Save the file layout locally |
| Esc / q | Close the navigator |
| Mouse click / wheel | Select a row / move selection when mouse support is enabled |

While filtering, Enter or Esc returns to the list with the current filter; a
second Esc closes it. Typed action letters are text. Rename changes a display
label, never a filesystem path. Rows show each window's project and pane count,
including managed hidden panes. The current project/window is selected on entry.
Project switching returns to its last active window. Switching preserves jobs.

The AGENTS section remains reserved for supervised-agent integration. Ordinary
shells are not guessed to be agents by parsing their output, and no example
status is presented as live data.

## Projects and windows

**N** starts with the selected project's directory. Ctrl-u clears, Enter opens
and Esc cancels. Invalid or empty paths create nothing. Reopening the same
canonical directory switches to its existing project. The command equivalent is:

```vim
:AiProject ~/Code/tmux-drudwyn
```

`:AiSession` remains a compatibility alias. No Git worktree or directory is
created. A new project starts with an editor window showing its name, directory
and controls beside the explorer. **n** opens a separate shell window; **e** opens
another editor window. **Space w** exposes window controls; **Space p** exposes pane splitting, positioning, resizing,
floating/fullscreen, hide/restore and close; see [Window management](window-management.md).

The top buffer bar continues to list shared Neovim buffers. The status line names
the active project and window; the navigators switch those groups. For a real new
file, Space fn creates an editable buffer and Ctrl-s asks for its filename on
first save. The project home is not a file that needs saving.

## Local save and restore

`s` saves manually to `stdpath("state")/navigator/snapshot.json` in ai-nvim's
state directory. There is one latest snapshot, written atomically with file
permissions 0600 in a 0700 directory. It holds native file layout/cursor
references and project/window labels, not source contents, terminal transcripts,
agent prompts or credentials. Nothing is sent externally.

Dock floating/fullscreen panes and restore managed hidden panes before saving;
the menu explains this requirement rather than silently losing their state.
In a fresh ai-nvim dashboard or one empty unnamed window, use:

```vim
:AiLayoutRestore
```

`:AiSessionRestore` remains an alias. Restore reopens files and window tabs,
groups them into projects and restores labels. Old snapshots are accepted: their
session names become project names. Saved home-only windows regain the home and
explorer. Existing editing layouts are refused. No terminal or agent restarts.

Neovim's `mksession` supplies the file layout, with terminal, option, global and
hidden-buffer capture excluded. A terminal reference retained in an argument
list causes save to refuse rather than recording a possible process restart.
Snapshots contain locally generated session scripts; do not substitute untrusted
ones. Source files still need Ctrl-s or `:w filename` as appropriate.

This is a persistence probe. Terminal panes and auxiliary plugin panels are
omitted on restore, so sizing can change when they disappear. Multiple views of
the same file share one saved pane label. There is no snapshot history,
automatic save/restore or cross-instance state merge. Delete the snapshot to
forget the saved layout; Neovim undo/recovery is separate.

## Implementation and evidence

[navigator.lua](../../editor/lua/ainvim/navigator.lua) renders native floats and
handles navigation, filtering, inline prompts and confirmation. The project/window
model and operations are described in [Window management](window-management.md).
No extra plugin or multiplexer is involved. Lists refresh without stealing focus;
Smear is disabled in navigator input and list buffers.

The [original navigator record](../prototypes/0007-native-navigators.md) preserves
the earlier session/split prototype and its usability findings. The
[window-management record](../prototypes/0008-window-management.md) covers the
current hierarchy. The previous runtime and snapshot names are compatibility
details, not another user-facing session layer.
