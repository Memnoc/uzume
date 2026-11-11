# Projects, windows and panes

The editor preview now implements the agreed hierarchy. A **project** owns a
set of **windows**; each window has its own layout of editor and terminal
**panes**. Windows switch as a whole. For example:

```text
Drudwyn project
├── Editor window: source pane | test pane
└── Build window: shell pane / output pane
```

The status line shows **project / window**. The top buffer bar still lists
shared Neovim buffers; it is not a window or project switcher. **Space ap**
opens projects, **Space aw** opens windows, and **Space pp** selects panes in
the current window. **Space as** remains an alias for projects.

## Start a project and its windows

In either navigator, **N** prompts for an existing project directory. Opening
the same canonical directory again switches to that project rather than creating
a duplicate. **n** creates a new shell window in the selected project; **e**
creates an editor window. Both appear as separate navigator entries and retain
their own layouts. An editor window starts with the project home and explorer.

`:AiProject /path/to/project` is the command alternative. Creating directories,
Git repositories and worktrees is not part of this action. Different worktree
directories are separate projects in this increment; grouping task worktrees
under one project remains an agent-integration design question.

## Keyboard controls

Press **Space w** for window controls or **Space p** for pane controls. Pause
for WhichKey. Pane focus, movement and resizing have short submenus to keep the
main menu readable; directions are labelled Left, Down, Up and Right. In a shell,
press **Esc** first to leave terminal input; `i` resumes typing into the shell.

| Control | Action |
| --- | --- |
| Space ww | Pick a window (Space aw remains available) |
| Space wn / wN | New editor window / new shell window in this project |
| Space w] / w[ | Next / previous window in this project |
| Space wd | Confirm closing the whole window and its terminal jobs |
| Space ps / pv | Split editor Down / Right |
| Space - / Space \| | Familiar aliases for editor splits |
| Space pt / pT | Start a new shell pane Down / Right |
| Ctrl-h/j/k/l, or Space pg then h/j/k/l | Focus Left / Down / Up / Right |
| Space pM then h/j/k/l | Move Left / Down / Up / Right (tile edge or floating position) |
| Space px | Swap contents/views with the next visible pane |
| Space po | Move the pane to another window in the same project |
| Space pR then > / < | Increase / decrease width by five cells |
| Space pR then + / - | Increase / decrease height by two cells |
| Space pR then = | Equalize tiled pane sizes |
| Space pf | Float the current pane / dock it back into its original tile |
| Space pm or Space uZ | Fullscreen / restore the pane |
| Space pz | Hide the pane, retaining its buffer and running shell |
| Space pr | Restore the most recently hidden pane in this window |
| Space pp | Pick a visible or hidden pane; Enter focuses/restores it |
| Space pd | Confirm closing the pane and stopping its terminal job |

Editor splits share the current file buffer, as ordinary Neovim splits do.
Splitting from a terminal or home with the editor command creates a new editable
buffer; use the shell commands when another process is wanted. **Ctrl-s** asks
for a filename when saving a genuine unnamed file. A project home itself is not
a source file to save.

Moving a pane between windows preserves its buffer, cursor/view and terminal job;
the terminal's cleanup ownership moves to the destination window. Transfers are
limited to the same project, avoiding an implicit change of project for an
already-running process. Shared terminal views block transfer/close where that
would affect another view.

The old pane bindings under Space w have moved to Space p; they are not duplicate
aliases in the window menu. In particular, **Space pd closes a pane** and
**Space wd closes the whole window**, both with confirmation. The previous
Space wD binding is removed. Ctrl-h/j/k/l and the Space - / Space | split aliases
remain available. Uppercase **M** and **R** select the Move and Resize submenus;
lowercase **m** toggles fullscreen and **r** restores a hidden pane.

## Floating, fullscreen and mouse

Floating a pane leaves a labelled placeholder in its original tile. Docking
returns to that same tile and layout, without restarting the shell. Fullscreen
uses a large native float: invoking it again restores either the original tile
or the previous floating geometry. Other panes keep running. Leave fullscreen
before moving/resizing the pane.

With mouse support enabled, drag native split separators to resize tiled panes.
For managed floats, drag the **top border** to move; drag the **bottom or right
border/corner** to resize. Mouse movement is clamped to the terminal viewport.
**Space uM** disables/enables mouse support. Ordinary editor/picker mouse handling
continues outside managed float borders.

Hiding a pane removes its visible surface without stopping its process. The last
pane leaves a placeholder so the window remains accessible. Restore uses that
placeholder when available; otherwise it opens a right-hand tile. A hidden float
also recovers its floating geometry. Hide/restore does not promise reconstruction
of an entire earlier split tree after the remaining panes have been rearranged.

## Closing, saving and scope

Navigator **x**, then **y**, closes the selected project or window. A project close
checks all its windows, including managed hidden panes, before mutating anything.
Modified files block the operation; terminals displayed outside the target block
it too. Confirmed close stops owned native terminal jobs, including hidden ones.
Other projects/windows continue. Source files and worktree directories remain.
Closing the last active project/window leaves a neutral dashboard, not an
unnamed file. Closing the last pane leaves the project home.

Use these managed close actions for their cleanup semantics. Native `:close`,
buffer deletion and third-party terminal toggles retain their own behavior.
Native tab closure still stops terminal jobs tagged to that tab. Full agent
descendant-process supervision has not yet been integrated.

Navigator **s** manually saves file layouts and project/window labels locally.
Dock floats, leave fullscreen and restore hidden panes first: save refuses to
silently omit those managed panes. `:AiLayoutRestore` restores from a fresh editor
and groups saved windows into their projects. Existing snapshots are accepted;
their old session names become project names. Terminals never restart on restore.
The [navigator guide](navigators.md) describes storage and remaining limitations.
Automatic layout saving remains pending.

## Implementation and validation

[projects.lua](../../editor/lua/uzume/editor/projects.lua) groups native tabs by project
directory and owns window/project navigation, naming and close preflight.
[panes.lua](../../editor/lua/uzume/editor/panes.lua) handles native splits, floating
placeholders, fullscreen, hidden buffers, transfers, close and mouse borders.
The older [sessions.lua](../../editor/lua/uzume/editor/sessions.lua) now supplies
low-level tab/buffer discovery, homes, terminal ownership and snapshot
compatibility; its filename does not introduce another product entity.

No dependency, terminal renderer or external multiplexer was added. The existing
Lua editor is the appropriate place to test these interactions; there is no new
Rust subsystem in this increment. The [probe record](../prototypes/0008-window-management.md)
records actual workflow and compatibility checks. Heavy-output performance,
terminal-specific mouse ergonomics and hands-on layout evaluation remain
open. Agent tasks and review are now implemented; see the feature index.

Managed panes now use Slide animation by default. **Space uA** chooses Slide,
Instant, Pulse or Spring and saves the preference. See [pane animations](pane-animations.md)
for controls, interruption rules and regression coverage.
