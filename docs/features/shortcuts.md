# Shortcut coverage and discovery

**Space k** opens searchable shortcuts. **Space ?** and **Space sk** are aliases.
Type action words in any order; Enter runs a Normal-mode mapping in its original
pane, and Esc closes. Ctrl-b/Ctrl-g include or exclude buffer/global mappings.
**Space s?** shows buffer-local WhichKey help. Press Space and pause for groups.

This guide covers implemented Uzume actions. It is not a replacement for Vim's
built-in command reference: **Space sh** opens that help. Language-server actions
appear after an LSP attaches; review, conflict, navigator and tool-menu actions
appear in their own buffers. Optional plugins and executables can add mappings.

## Editor, files and code

| Controls | Actions |
| --- | --- |
| Space e / E, fe / fE | Explorer at project root / current directory |
| Space Space / ff; fF; fg | Find project files; current-directory files; Git files |
| Space fr / fR; fp; fc; fn | Recent files / current-directory recent files; projects; config files; new file |
| Space , / fb; bb / backtick | Pick buffers; switch to the other buffer |
| Shift-h/l or [b / ]b; [B / ]B | Previous/next buffer; move buffer left/right |
| Space bp / bj; bd / bo / bD | Pin/pick buffer; delete current/others/current with window |
| Space / / sg; sG; sw; sb / sB | Search project/current-directory text; word or selection; current/open buffer lines |
| Space : / sc; sC; sh; s"; sj; sm; sR; su; n | Command history; commands; help; registers; jumps; marks; resume picker; undo; notifications |
| Ctrl-s; Space cf; uf / uF | Save; format file/selection; toggle format-on-save globally/locally |
| Space l; cm; uI | Extras; Mason tools; toggle automatic tool installation |
| gd / gr / gI / gy; K / gK | Definition/references/implementation/type definition; hover/signature (LSP) |
| Space ca / cr; cs / ss / sS | Code action/rename; document/workspace symbols (LSP) |
| Ctrl-Space; Ctrl-n/p; Enter / Ctrl-y; Ctrl-e | Request completion; select; accept; dismiss (Insert mode) |
| Tab / Shift-Tab; Ctrl-b/f | Snippet fields; completion documentation scroll (Insert mode) |
| Space cd; [d / ]d; sd / sD | Line diagnostics; previous/next; project/buffer diagnostic picker |
| Space xq / xl; [q / ]q | Toggle quickfix/location list; previous/next quickfix entry |
| Space gs / gd / gl / gf; gg | Git status/diff/log/file history; Lazygit when installed |
| Space ghs / ghr / ghp / ghb; [h / ]h | Stage/reset/preview/blame hunk; previous/next hunk |
| Space uw / us / uL / ul / ud / uh / ug | Wrap/spelling/relative numbers/numbers/diagnostics/inlay hints/indent guides |
| Space uM / uC / uz / uZ / uA / ua | Mouse/theme/Zen/fullscreen/pane animation/Smear (if enabled) |
| Space qq | Quit, with unsaved-file confirmation |

## Projects, windows and panes

| Controls | Actions |
| --- | --- |
| Space ap / as; ww / aw | Project navigator; window navigator |
| Space wn / wN; w[ / w]; wd | New editor/shell window; previous/next project window; confirm close |
| Space wi | Inspect window project, branch, checkout and file |
| Space ws / wR | Save local file layout / restore it from a fresh empty editor |
| Space ps / pS; pv / pV | Split editor down/up; right/left |
| Space - / Space pipe | Existing down/right split aliases |
| Space pN then h/j/k/l | New shell pane left/down/up/right |
| Space pt / pT | Existing shell-down/right aliases |
| Ctrl-h/j/k/l or Space pg then h/j/k/l | Focus pane left/down/up/right |
| Space pM then h/j/k/l | Move pane left/down/up/right |
| Space pR then > / < / + / - / = | Resize wider/narrower/taller/shorter/equalize |
| Ctrl-arrows | Native pane resizing; horizontal controls also work in shell input |
| Space pp / px / po | Pick pane; swap with next; transfer to another project window |
| Space pf / pm / pz / pr / pd | Float/dock; fullscreen/restore; hide; restore hidden; confirm close |
| Ctrl-/ (Ctrl-_ alias); Space 9 / ft / fT | Toggle right terminal; floating terminal/current project/current directory |
| Space Tab then Tab / d / ] / [ | Native tab new/close/next/previous compatibility controls |

In an ordinary shell, Esc or jk enters editor controls; Ctrl-w enters native
window commands. Managed agents preserve CLI input and use **Esc Esc** for
editor controls. Source-file saving and layout saving are separate operations.
Layout restore retains its existing guard against replacing an active editor.

Inside the project/window navigator: **n/e/N** creates a shell window/editor
window/opens a project directory; **r** renames; **x then y** confirms close;
**s** saves layout; **/** filters; **Ctrl-u** clears; **j/k or arrows** move;
**Enter** opens; **?** shows all controls; **q/Esc** closes. These actions have searchable descriptions.

## Agents, review and integration

| Controls | Actions |
| --- | --- |
| Space ac / aC | Named Codex/Claude task with the current file |
| Space ae / aE; ab / aB | Empty Codex/Claude task; choose an existing branch |
| Space aa / ar | Agent attention; restart the task CLI |
| Space at / aT | Retained tasks and explicit cleanup; recovery history |
| Space af / aF / am / ad | Mark current/multiple files; manage marks; add marked context to prompt |
| Space vr / av; vf; vu; vR; vq | Open review; changed files; unified toggle; refresh; close |
| Space vc / vC / vs | Comment on review lines; inspect comments; preview feedback to send |
| Space vi / vI | Local integration/continue; integration history |

Review buffers expose **?** for the full guide and **f/u/R/q/C/s/i/c/Tab** for files, diff layout, refresh,
close, comments, feedback, integration, comment and switch side. Feedback uses
**a** to send/focus, **Ctrl-s** to queue, **x** to cancel queued feedback and **r**
to refresh status. Integration exposes **?** for its guide and uses **a** to apply a preview, **f** for files,
**c** to continue and **x** for confirmed abort when applicable. Conflict actions
are available through **Space vm** in conflict buffers. Actions appear only when
valid for that surface/state; adding descriptions does not bypass confirmations.

## Audit and verification

The November 2026 audit found missing shell-left/up controls, resize labels that
omitted their action context, command-only Mason/layout entry points, and unnamed
navigator/integration/feedback controls. These are now covered. Existing bindings
were retained; **Space pN** groups shell directions to avoid a long flat menu.

`tests/shortcut_audit.py` verifies 147 core leader bindings, descriptions,
action-prefix collisions, navigator search and guarded layout persistence.
A temporary startup observer recorded 241 mapping registrations with no
replacement collisions, rather than relying only on the final keymap table.
This count is from the installed plugin bundle and can vary with enabled packs. `tests/keymaps.py` checks search and
execution; `tests/pane_motion.py` checks four-direction shell creation and process
cleanup. Existing review, feedback and integration tests check their local action
descriptions while exercising the actual workflows. Run `python3 tests/run.py`
for the consolidated suite; external agent CLIs are fixtures.

Verification on 2026-11-11: **18/18** consolidated cases passed on macOS with the
installed Neovim 0.12 development build; the core shortcut audit also passed on
Neovim 0.11.0. Formatting and whitespace checks passed.

The audit does not turn unimplemented features into bindings. Debugger/test-runner
integration, automatic project autosave, remote project support and generic
third-party language packs remain separate work. LSP attachment and optional
plugin availability affect the live menu; a missing inactive-provider action is
not a shortcut collision.

Retained-task details offer **Esc/b** to return to the filtered list with its
selection preserved, **q** to close and keep, **v** to review, **x** for removal
with exact branch confirmation, **r** to refresh and **h** for recovery history.
During inspection Esc/b goes back and q closes; a failed check also offers r to retry.
In **Space aT** recovery snapshots, **r** starts guided restore. The preview offers
**Enter** to restore and open, **e** to edit choices, **Esc/b** to go back and **q**
to close. Closing a confirmed restore's progress view does not cancel the operation.
See [task cleanup](task-cleanup.md) for its guards and archive limits.
