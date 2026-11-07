# Editor baseline: navigation and explorer

Status: first navigation/visual increment implemented on `spike/editor-baseline`;
full editor parity remains incomplete. See the [evaluation record](prototypes/0003-editor-baseline.md).
Recorded after initial Drudwyn pilot feedback on 2026-11-07.

## Interaction direction

Most menus float, with anchored views for tools that benefit from staying beside
the code. Session/workspace quick switching follows that model. Opening and
dismissing navigation must preserve the editing position. The file explorer is
an essential left sidebar, toggled by the user's existing shortcuts.

Keep Rose Pine and the existing LazyVim editor behavior as the acceptance
reference. Finish this baseline before expanding the AI workflow. The independent
distribution can use selected plugins directly; it need not inherit LazyVim.

## Verified reference

Inspected My-LazyVim's extras/custom configuration and the installed LazyVim
`snacks_explorer.lua`, plus Snacks' explorer documentation, source configuration,
sidebar layout, and file actions. Also consulted upstream
[explorer documentation](https://github.com/folke/snacks.nvim/blob/main/docs/explorer.md)
and [picker documentation](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md).

The installed LazyVim maps `<leader>e`/`<leader>fe` to the project-root explorer
and `<leader>E`/`<leader>fE` to the current-directory explorer. The inspected
Snacks source uses a left sidebar that remains open when a file is opened,
follows the current file, watches changes, and displays Git/diagnostic indicators.
These are reference behaviors to verify in our editor, not claims about the spike.

Installed reference commits:

- Snacks: `882c996cf28183f4d63640de0b4c02ec886d01f2`.
- LazyVim: `999700997f72227187d49d8b92667183dc7fc809`.

These differ from the repository lockfile. Use the installed behavior as the
muscle-memory reference; select and test an explicit distribution pin rather
than silently following upstream main.

## Explorer shortcuts to preserve

Leader is Space. Single-letter actions below apply inside the explorer.

| Key | Behavior |
| --- | --- |
| `Space e` / `Space fe` | Toggle project-root explorer |
| `Space E` / `Space fE` | Current-directory variant |
| `a` | Create file; trailing `/` creates directory |
| `r`, `d` | Rename, delete |
| `c`, `m` | Copy, move; honor selection |
| `y`, `p` | Yank paths, paste copies |
| `Tab` | Select entries |
| `Enter`, `l`, `h` | Open/expand, collapse |
| `Backspace`, `.` | Parent directory, focus selected directory |
| `H`, `I` | Toggle hidden/ignored entries |
| `Z`, `u`, `P` | Collapse directories, refresh, preview |
| `Space /` | Search within explorer directory |

Retain remaining standard actions and help discovery as supplied by the selected
Snacks version. Do not substitute a reduced homemade tree with similar letters.

## Implementation direction and acceptance

Use a pinned Snacks explorer/picker as the proposed implementation: its existing
behavior supplies meaningful value and matches the user's configuration. Keep
our session/worktree model separate from menu rendering. Existing LazyVim file,
search, window, and buffer bindings take precedence over prototype agent keys.
In particular, `Space f` and `Space s` cannot remain single-action prototype
bindings when they must serve as the familiar file/search prefixes.

For the editor increment, verify the toggle from both code and explorer, folder
expansion, file creation/rename/copy/move/delete in disposable directories,
search, and focus/reading-position restoration. Opening a file should leave the
sidebar available. Verify the selected version's confirmation and deletion
behavior rather than assuming trash support from the shortcut name.

When sessions return, verify that the explorer operates on the active checkout
and never accidentally targets another task's worktree. Session-specific explorer
state and root detection need integration checks; inherited LazyVim root logic
is not automatically available in an independent distribution.

This is the first part of the baseline inventory. Completion, language support,
formatting, diagnostics, Git, debugging/testing, and the remaining custom extras
still need their own mapping. The first runnable editor now supplies the mapped
navigation and visual foundation; it does not yet supply those language tools.

The subsequent [Extras increment](prototypes/0004-extras-and-languages.md) adds
Rust, Lua, C/C++, web language tooling and Smear Cursor, with **Space l** opening
the feature catalog. The remaining baseline extras and full parity are still
open; the linked record distinguishes verified behavior from pending coverage.
