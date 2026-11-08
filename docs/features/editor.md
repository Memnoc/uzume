# Editor and navigation

The editor restores the familiar reading and editing workflow before agent
sessions return. It is an independent Lua configuration using selected plugins;
it owns its configuration directly. [ui.lua](../../editor/lua/ainvim/ui.lua) configures
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

Uzume gives Rose Pine's main variant a gentle mauve text palette: ordinary text
uses `#e0d4eb`, comments and secondary text `#a99ab8`, and muted text `#8b7c98`.
The dashboard's logo, headings, and navigation icons use iris (`#c4a7e7`), labels
and filenames use the pale mauve text color, and shortcut letters use rose
(`#ebbcba`). Filetype icons retain their own recognizable colors. The base,
surface, and overlay backgrounds and the syntax/diagnostic accent palette remain
upstream defaults. These settings live in [ui.lua](../../editor/lua/ainvim/ui.lua)
and use Rose Pine's palette and `before_highlight` callback, scoped to its main
variant. No global `ColorScheme` hook forces these colors onto other themes.
**Space uC** can switch to another installed colorscheme;
its own colors take over. Rose Pine Moon and Dawn keep their original palettes.
Switching back to Rose Pine main restores the mauve tint. To use its unmodified
palette and dashboard colors, remove the `palette.main` overrides and the
`before_highlight` callback from the setup table.
Startup checks compared the main editor backgrounds and syntax, diagnostic, and
diff highlights against stock Rose Pine, then verified switching to Habamax,
Moon, and Dawn and back without the mauve settings leaking into those themes.
The first palette-only change left the dashboard cyan because Snacks links its
header and labels to accent groups. A subsequent PTY check inspects the actual
dashboard extmarks and resolved highlight colors, covering the logo, headings,
navigation icons, labels, and shortcut keys.

The home screen centers a small ASCII cave-and-sun emblem above the Uzume
wordmark, matching the repository logo. The shared artwork lives in
[branding.lua](../../editor/lua/ainvim/branding.lua) and also appears after the
last project is closed. It uses ordinary ASCII characters and the dashboard's
theme highlight, with no image renderer or extra plugin. File, search, explorer,
and quit shortcuts remain below the startup artwork.
Disposable PTY checks verified the rendered header and shortcuts at 120×36 and
80×24, the new-file action, and the dashboard shown after closing the last project.

| Control | Action |
| --- | --- |
| Space sk / Space ? | Search all mappings / show buffer mappings |
| Space n | Notification history |
| Space uC | Select a colorscheme for this run |
| Space uw / us | Toggle wrapping / spelling |
| Space ul / uL | Toggle line numbers / relative numbers |
| Space ug / ud | Toggle indent guides / diagnostics |
| Space uM | Toggle mouse support |
| Space uz / pm | Zen mode / maximize the current window |

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
| Ctrl-h/j/k/l | Move between panes |
| Ctrl-w + / - / > / < | Native tiled pane resizing |
| Space pd / wd | Confirm close pane / whole window |
| Space aw / Space ap | Window navigator / project navigator (Space as is an alias) |
| Ctrl-/ | Toggle right-side shell |
| Space 9 | Toggle floating shell |
| Space ft / fT | Floating shell at project root / cwd |
| Esc or jk in terminal input | Return to terminal Normal mode |
| Ctrl-s / :w | Save source file; Ctrl-s prompts for a filename on first save |
| Space qq | Quit, confirming unsaved changes |

The [native navigators](navigators.md) provide Drudwyn-style project/window
selection, creation, naming, confirmed closing and manual local layout save.
Inside either menu, **n** opens a shell window, **e** an editor window, and
**N** prompts for an existing project directory. Projects group native tabs;
each tab is a window with its own pane layout. `:AiProject /existing/directory`
is also available. **Space w** exposes window controls and **Space p** the [pane controls](window-management.md),
including split, move, resize, float/fullscreen and hide/restore.
New editor windows show a labelled, non-editable home view and the project explorer.
They do not create a source file to save. To write a new file, use **Space fn**
and **Ctrl-s**: the filename prompt supports completion, cancellation preserves
the draft, and existing files are not silently overwritten. Named files save
normally. Native `:w filename` also works; `:w` alone still needs a named buffer.
The first-save behavior is implemented in [save.lua](../../editor/lua/ainvim/save.lua).

The shells use Snacks terminals and Neovim terminal buffers. Separate terminal
identities prevent the right and floating shortcuts from opening the same pane.
Hiding a terminal preserves its job; confirmed navigator close terminates the
affected terminal. Supervised agent input routing still belongs to the separate
pilot.

Terminal input uses a steady block cursor, configured through Neovim's native
`guicursor` option in [options.lua](../../editor/lua/ainvim/options.lua).
Normal editing cursor shapes and Smear Cursor settings are unchanged. This
applies to Uzume's terminal buffers; the host terminal controls its own shell
cursor. Ghostty's `cursor-style-blink = false` sets its default, while WezTerm's
`default_cursor_style = "SteadyBlock"` and `cursor_blink_rate = 0` disable blinking.
Uzume's installer does not change either terminal application's configuration.
Verified in a real Neovim 0.11.6 PTY session: terminal input was active and output
requested the steady block cursor (`DECSCUSR 2`), with no blinking cursor request.

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
icons in the gutter. This uses Neovim's native diagnostics with four spaces
before the message, a dot prefix, and source labels when multiple diagnostic sources are present. Updates wait until you
leave Insert mode. Long inline text may be clipped by the window width; use
**Space cd** for the full diagnostic float, **]d / [d** to navigate, or
**Space sD** for the buffer's diagnostic picker. **Space ud** toggles diagnostics.
Gray inferred types, such as `Args` and `Option<String>`, are inlay hints rather
than error messages. Native LSP inlay hints are enabled by default when language
packs are loaded; **Space uh** toggles them for the current buffer. The toggle
lasts for that buffer in the current editor session; other buffers keep their
own setting and new buffers start enabled. A server must provide hints for them
to appear. This uses Neovim plus the existing Snacks toggle, with no new plugin.

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
code features. Not every inherited plugin action has been exercised; broader
editing coverage, Linux/terminal coverage and integrated agents remain future work.
