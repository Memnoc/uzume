# Editor and navigation

The editor restores the familiar reading and editing workflow before agent
sessions return. It is an independent Lua configuration using selected plugins;
it does not import LazyVim. [ui.lua](../../editor/lua/ainvim/ui.lua) configures
Rose Pine, the dashboard, Snacks, WhichKey, bufferline, lualine, Git signs,
Flash and paired delimiters. [keymaps.lua](../../editor/lua/ainvim/keymaps.lua)
is the complete mapping reference.

## Appearance and discovery

Rose Pine supplies the theme. The dashboard provides entry points when starting
without a file; bufferline shows open buffers and diagnostics, while lualine
shows mode, branch, file, diagnostics and position. Snacks supplies file icons,
indent guides, status-column UI, input prompts and warning/error notifications.
Indent-guide animation is disabled. WhichKey's Helix-style menu appears after
pressing Space and pausing; no function-row key is required.

| Control | Action |
| --- | --- |
| Space sk / Space ? | Search all mappings / show buffer mappings |
| Space n | Notification history |
| Space uC | Select a colorscheme for this run |
| Space uw / us | Toggle wrapping / spelling |
| Space ul / uL | Toggle line numbers / relative numbers |
| Space ug / ud | Toggle indent guides / diagnostics |
| Space uM | Toggle mouse support |
| Space uz / wm | Zen mode / maximize the current window |

## Explorer and finding code

The Snacks explorer is anchored left. Search, buffers and other pickers float.
**Space e** toggles the project explorer; **Space E** uses the current directory.
Inside the explorer, `a` adds a file (a trailing slash creates a directory), `r`
renames, `d` deletes, `c` copies, `m` moves, `y` yanks and `p` pastes. `h/l`
collapse/expand, `Tab` selects, `H` toggles hidden files and `I` ignored files.
These are real filesystem operations supplied by Snacks; use disposable files
when learning them. **Space ?** reveals the current buffer's mappings.

| Control | Action |
| --- | --- |
| Space Space / ff | Find project files |
| Space fF | Find files from cwd |
| Space / / sg | Search project text |
| Space sw | Search word or visual selection |
| Space sb / sB | Search current buffer lines / open buffers |
| Space fr / fp | Recent files / projects |
| Space , / fb | Select an open buffer |
| Space sR | Resume the last picker |
| s | Flash jump to a visible target |

[project.lua](../../editor/lua/ainvim/project.lua) uses a focused picker's cwd,
then the file's containing attached LSP root, then `.git` (file or directory),
`lua`, and cwd. This supports worktrees without requiring a repository at the
terminal's original directory. `rg` and `fd` provide external search tools.

## Buffers, panes and shells

| Control | Action |
| --- | --- |
| Shift-h / Shift-l | Previous / next buffer |
| Space bb | Alternate buffer |
| Space bd / bo | Close buffer while keeping layout / close other buffers |
| Space bp / bj | Pin buffer / select buffer by label |
| Space - / Space \| | Split below / right |
| Ctrl-h/j/k/l | Move between windows |
| Ctrl-w + / - / > / < | Native window resizing |
| Space wd | Close window |
| Ctrl-/ | Toggle right-side shell |
| Space 9 | Toggle floating shell |
| Space ft / fT | Floating shell at project root / cwd |
| Esc or jk in terminal input | Return to terminal Normal mode |
| Ctrl-s / :w | Save source file |
| Space qq | Quit, confirming unsaved changes |

The shells use Snacks terminals and Neovim terminal buffers. Separate terminal
identities prevent the right and floating shortcuts from opening the same pane.
Closing a visible pane is not a supervised agent-session operation. Agent input
routing and lifecycle controls belong to the separate pilot.

## Reading changes and recovery

| Control | Action |
| --- | --- |
| Space gs / gd | Git status / diff hunks |
| Space gl / gf | Commit log / current file history |
| ]h / [h | Next / previous changed hunk |
| Space ghp / ghb | Preview hunk / blame line |
| Space ghs / ghr | Stage / reset hunk (these change Git or file state) |
| Space gg | Lazygit, only when its executable is installed |
| ]d / [d / Space cd | Next / previous / current diagnostic |
| Space sd / sD | All / current-buffer diagnostics |
| Space xq / xl | Toggle quickfix / location list |
| Space su | Undo history picker |

Snacks supplies Git pickers; gitsigns supplies gutter markers and hunk actions.
This is not yet the planned side-by-side agent-review suite. Diagnostic data
comes from the language servers described in [Languages](languages.md).

Errors and warnings appear inline beside code, with underlines and severity
icons in the gutter. This uses Neovim's native diagnostics, matching LazyVim's
effective LSP display: four spaces before the message, a dot prefix, and source
labels when multiple diagnostic sources are present. Updates wait until you
leave Insert mode. Long inline text may be clipped by the window width; use
**Space cd** for the full diagnostic float, **]d / [d** to navigate, or
**Space sD** for the buffer's diagnostic picker. **Space ud** toggles diagnostics.
Gray inferred types, such as `Args` and `Option<String>`, are inlay hints rather
than error messages; this display fix does not enable them.

The [diagnostic display investigation](../prototypes/0006-diagnostic-display.md)
records the real Rust reproduction and why the earlier baseline hid messages.

[options.lua](../../editor/lua/ainvim/options.lua) and
[autocmds.lua](../../editor/lua/ainvim/autocmds.lua) enable local undo/recovery,
restore file position, highlight yanks and check external file changes on focus,
buffer entry and terminal exit. File saving remains explicit: recovery is not
source autosave. State stays in ai-nvim's own Neovim directories.

## Verification and limits

The [baseline record](../prototypes/0003-editor-baseline.md) documents real PTY
checks of explorer toggle/create/rename/mkdir, search, WhichKey and distinct
shells. The [language record](../prototypes/0004-extras-and-languages.md) covers
code features. Not every inherited plugin action has been exercised; full
LazyVim parity, Linux/terminal coverage and integrated agents remain future work.
