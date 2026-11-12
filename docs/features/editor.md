# Editor and navigation

The editor restores the familiar reading and editing workflow before agent
sessions return. It is an independent Lua configuration using selected plugins;
it owns its configuration directly. [ui.lua](../../editor/lua/uzume/editor/ui.lua) configures
Rose Pine, the dashboard, Snacks, WhichKey, bufferline, lualine, Git signs,
Flash and paired delimiters. [keymaps.lua](../../editor/lua/uzume/editor/keymaps.lua)
is the complete mapping reference.

## Appearance and discovery

Rose Pine supplies the theme. The dashboard provides entry points when starting
without a file; bufferline shows open buffers and diagnostics, while lualine
shows mode, branch, file, diagnostics and position. Snacks supplies file icons,
indent guides, status-column UI, input prompts and warning/error notifications.
Indent-guide animation is disabled. WhichKey's Helix-style menu appears after
pressing Space and pausing; no function-row key is required.
The dashboard budgets its full content height on every resize. It reserves top
and bottom breathing room, keeps all seven navigation shortcuts, and shows up to
five recent files and projects only when they fit. At 40 rows it uses the full
wordmark; at 30–39 rows it uses the emblem and compact name; below 30 it keeps
the compact name. Short windows omit history before sacrificing navigation.
Resizing resets a stale scrolled viewport when all content fits.

Notifications use Snacks' compact style with a rounded border, a visible title,
opaque background and wrapped text. They stay for seven seconds without taking
focus. **Space n** opens notification history to reread longer messages. Agent
shortcut failures identify the attempted action in the title and omit Lua source
locations; invalid file selections include the next available actions.

Uzume gives Rose Pine's main variant a gentle mauve text palette: ordinary text
uses `#e0d4eb`, comments and secondary text `#a99ab8`, and muted text `#8b7c98`.
The dashboard's logo, headings, and navigation icons use iris (`#c4a7e7`), labels
and filenames use the pale mauve text color, and shortcut letters use rose
(`#ebbcba`). Mauve/iris is also the interface accent: floating borders and titles,
command/search prompt icons, input dialogs, picker prompts and shortcut keys,
and WhichKey group headings use `#c4a7e7`. Noice's format-specific border/title
links inherit the scoped accent, including `:lua`, help and search prompts.
Filetype icons retain their own recognizable colors. The base,
surface, and overlay backgrounds and the syntax/diagnostic accent palette remain
upstream defaults. These settings live in [ui.lua](../../editor/lua/uzume/editor/ui.lua)
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
The 2026-11-12 accent check inspected the live command popup's format-specific
border/title/icon groups, picker/input groups, semantic syntax/diagnostic/diff
colors and switching through Moon, Dawn, Habamax and back. The existing command-line
smoke test also passed after the accent update.

The home screen centers a two-color cave-and-sun emblem above the Uzume
wordmark, closely following the repository SVG. The shared artwork lives in
[branding.lua](../../editor/lua/uzume/editor/branding.lua) and also appears after the
last project is closed. Unicode half-block characters reproduce the solid arch,
rounded sun, and baseline using normal text rendering, with no image renderer,
conversion utility, or graphics-protocol dependency. The arch follows
`SnacksDashboardHeader`; the sun follows `DiagnosticError` (Rose Pine's love
color). Both adapt to the active colorscheme. The icon occupies 11 columns and
6 rows (about 45% smaller than the initial rendering). Shorter windows use
the compact layouts described above. File, search, explorer, and quit shortcuts remain
below the startup artwork.
`python3 tests/dashboard.py` resizes a populated dashboard through 100×34,
80×24, 150×55, 100×40, 80×18 and back to 100×34, checking visible margins,
shortcuts, history, keymap search and the new-file action. The seven-action home
screen needs roughly 15 rows; extremely short terminals cannot display the complete menu.

**Space k**, **Space ?**, **Space sk**, or **k · Search Keymaps** on the home screen opens a
floating, searchable shortcut guide. Type a description such as `review`,
`split` or `inlay`, or a key such as `Space ac`. The compact rounded window shows readable shortcuts and action descriptions,
with a muted mode label. Callback code, icons and source paths are omitted;
search matches the displayed keys, descriptions and modes only. Each search term
must occur as consecutive characters; terms can appear in any order. This avoids
fuzzy matches such as `swap` finding “Toggle Wrap”. For example, `move pane left`
or `left move pane` finds **Space pMh**, while `Space pMh` searches the keys.
Directional actions include the verb and object in their mapping descriptions
(e.g. “Move Pane Left” and “Focus Pane Left”). Mappings without
a description remain listed as “Custom mapping (no description)”. Use Ctrl-n/p
or arrow keys to browse; Ctrl-u clears the query and
Backspace deletes it completely. Esc returns without running anything. Enter
closes the picker and runs the selected Normal-mode shortcut in the original
pane and buffer. The original mapping handles its normal confirmations and
prompts. Other-mode shortcuts remain searchable; Enter explains which mode is
needed without switching modes or inventing a selection.

Execution uses native key dispatch, supporting Lua callbacks, command strings
and expression mappings. Before dispatch, the original pane/buffer must still
exist and the mapping must still be active there. Changed or locally overridden
mappings are not replayed; reopen the menu to refresh them. The footer shows
Enter/Esc and the buffer/global scope toggles.

The guide reads live global and current-buffer mappings, including plugin and
LSP mappings that are currently registered. Ctrl-b toggles buffer mappings and
Ctrl-g toggles global mappings. Mode labels spell out Normal, Insert, Visual,
Select, Operator, Command and Terminal (`v` displays Visual/Sel; `x` displays Visual
only). Unmapped built-in Vim commands are not a keymap catalog;
**Space sh** opens their help. Internal `<Plug>` entries are hidden.

[keymaps.lua](../../editor/lua/uzume/ui/keymaps.lua) configures the already-pinned
Snacks picker; there is no separate mapping registry or new dependency. Opening
it from a buffer includes that buffer's local shortcuts; filtering stays anchored
to that original buffer after the search field takes focus. **Space s?** retains
the previous WhichKey buffer-only help. Scope toggles reset each time; queries
use Snacks' existing local picker history. The dashboard regression drives the
actual search UI, checks buffer mappings in Normal/Insert modes, toggles scopes,
and confirms Escape does not execute the selected mapping.
`python3 tests/keymaps.py` covers search relevance, word order, exact shortcut
lookup, no-result searches, and rendered rows at 60, 80 and 100 columns. It checks
that Enter dispatches into the originating pane, buffer-local command mappings
work, and wrong-mode/changed mappings are not replayed. It also checks
that the mode label fits and inline highlights do not paint background blocks
across the floating surface or selected row. The action column inherits the
picker background, and its width accounts for Snacks' leading selection cell.
These checks pass on Neovim 0.11.0 and the installed 0.12 development build on macOS.

| Control | Action |
| --- | --- |
| Space k / Space ? / Space sk | Search live mappings; Enter runs a Normal-mode action |
| Space s? | Show buffer-only shortcut help |
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
when learning them. **Space s?** reveals the current buffer's mappings.

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

[project.lua](../../editor/lua/uzume/editor/project.lua) uses a focused picker's cwd,
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
The first-save behavior is implemented in [save.lua](../../editor/lua/uzume/editor/save.lua).

The shells use Snacks terminals and Neovim terminal buffers. Separate terminal
identities prevent the right and floating shortcuts from opening the same pane.
Hiding a terminal preserves its job; confirmed navigator close terminates the
affected terminal. Managed [agent terminals](agents.md) use double Escape for
editor controls and pass single Escape, jk and Ctrl-w through to the CLI.

Terminal input uses a steady block cursor, configured through Neovim's native
`guicursor` option in [options.lua](../../editor/lua/uzume/editor/options.lua).
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

[options.lua](../../editor/lua/uzume/editor/options.lua) and
[autocmds.lua](../../editor/lua/uzume/editor/autocmds.lua) enable local undo/recovery,
restore file position, highlight yanks and check external file changes on focus,
buffer entry and terminal exit. File saving remains explicit: recovery is not
source autosave. State stays in uzume's own Neovim directories.

## Verification and limits

The [baseline record](../prototypes/0003-editor-baseline.md) documents real PTY
checks of explorer toggle/create/rename/mkdir, search, WhichKey and distinct
shells. The [language record](../prototypes/0004-extras-and-languages.md) covers
code features. Not every inherited plugin action has been exercised; broader
editing coverage and Linux/terminal coverage remain future work. Integrated
agent tasks are described in the [agent workflow](agents.md).

### Search and naming input compatibility

The installed Neovim nightly prevents native empty-prompt buffers from deleting
their first character. This reproduces without plugins; stable Neovim 0.11.6
with the same editor configuration deletes it normally. The compatibility layer
in [input.lua](../../editor/lua/uzume/ui/input.lua) handles Backspace/Ctrl-h at that
boundary for Snacks search and naming fields, including multibyte characters.
Other positions use native Backspace, and ordinary source buffers keep their
existing mappings. Remove this workaround when the supported Neovim baseline
passes the regression without it.

`python3 tests/agents.py --inputs-only` checks complete deletion in both search
and naming fields. The full suite also checks explicit file-reference delivery
and user-facing agent labels.

## Floating command line

Press `:` for a compact, rounded command box near the top, centered horizontally.
It scales with terminal width, capped at 100 columns; narrow terminals remain
usable. Native command editing, Enter execution, Escape cancellation, history
and Tab completion remain intact. Search/input prompts use the same Noice
command-line plumbing. This does not replace Snacks input/pickers.

Pinned Noice and Nui render command input and completion only. Messages and
notifications remain with the existing editor/Snacks paths; LSP hover/signature
handling remains native. `uzume/ui/commandline.lua` owns the scope and appearance,
using theme highlight links. No new persisted preference is introduced. Rebuild
packages with `./setup-editor` when updating to this dependency bundle, then restart.

`tests/commandline.py` exercises execution, editing, cancellation, native history,
completion and 50/80/150-column layouts through a real terminal editor.
