# Native Drudwyn-style navigators

Date: 2026-11-08. Status: implemented on `spike/editor-baseline`; awaiting
Memnoc's visual/usability feedback in the real editor.

## Question and reference

Can native Neovim surfaces reproduce the Drudwyn session/window picker flow
without requiring tmux, while retaining the established editor controls?

Memnoc identified prefix-w and prefix-s as the most-used Drudwyn features and
provided the 08.51.19 workspace and 08.51.32 session screenshots. These settle
the presentation: floating flat lists, dark background, thin square frame,
salmon heading/selection, muted secondary information, workspace/agent sections,
and the visible j/k, Enter, rename, kill, save, filter, close strip. The screenshots
take precedence over the newer, richer UI in the local Drudwyn source. No browser
mockup or competing visual variant is useful for this already-selected design.

Continue the Northstar spike workflow on the existing throwaway editor branch;
main retains findings rather than implementation. Space aw/as are provisional,
preserving the current Space w and Space s groups. No tmux dependency was added.

## Implementation being evaluated

Sessions use native tabs with directory/name metadata. Workspace rows expose
native editor/terminal windows across those tabs. Native float overlays implement
the screenshot layout, with keyboard filtering and confirmation inside the same
surface. Session labels say current/hidden rather than attached: this model has
no tmux client attachment. This terminology and the mapping of a workspace row
to a Neovim window still need real-project usability feedback.

Switching preserves jobs and window focus. Confirmed close refuses modified
displayed files and shared terminal views, then closes the target and stops
its terminal jobs. Tab ownership includes hidden terminals. The last target
leaves an empty editor. Agent discovery is not inferred from terminal text;
the AGENTS section remains empty until the supervised pilot is integrated.

Manual save probes native mksession plus local display-name metadata. The single
JSON snapshot is atomic/private; restore is explicit from a fresh editor and
omits terminals, options, globals and hidden buffers. It is not full session
autosave, source autosave, or an agent restart facility. Full behavior and limits
are in `docs/features/navigators.md` on the editor branch.

## Disposable verification

The isolated PTY/RPC probes under `.probe/navigation/` open the actual editor
configuration and drive real key input. Their state and fixtures are separate
from the user's working sessions. No permanent test suite was added.

Verified:

- Space aw/as open the intended surface; j/k and Enter switch real windows/tabs.
- Live filtering narrows entries, treats action letters as text, and clears with
  Ctrl-u. Rename applies a label; Esc cancels. Close confirmation can be cancelled.
- Modified files block close. Separate sleep jobs stay alive across tab switches;
  closing one session stops its hidden job and leaves the other job running.
- Save succeeds with the navigator focused. The snapshot is 0600 and contains
  file references, not terminal commands. Restore from the dashboard reopens the
  file tabs and renamed session without starting any terminal.
- Compact 80×24 rendering keeps the controls available; 150×45 on-screen text,
  float geometry and Rose Pine foreground/background values were inspected.
- A shared terminal blocks close. Closing the last terminal leaves an editor.
  Explorer roots follow the newly created session directory.
- Neovim 0.11.6 passed startup and navigator open/close. Lua formatting and
  whitespace checks passed.

Two integration details emerged. Smear owns a hidden float even on a fresh
dashboard, so checking for exactly one API window incorrectly rejects restore;
the guard now counts tiled windows. Also, mksession can retain a terminal through
an argument-list reference even when terminal capture is disabled; save now
rejects such a snapshot. The persistence probe does not capture fold options,
which can contain executable expressions.

## Verdict and next evaluation

Native tabs/windows are sufficient for this first navigator increment. We can
keep the independent, no-tmux first version and evaluate the supplied design in
the actual editor. Rendering checks establish layout/text/colors, not a claim
of pixel-identical output across terminal fonts or GPU renderers.

Next, use both menus against Drudwyn and another local worktree: assess whether
row identity, switching, filtering and closing match the user's expected flow.
Then connect the existing agent pilot, checking genuine attention signals and
process-tree cleanup before claiming managed multi-agent sessions. Autosave,
floating/tiling layout management, and full restoration remain later increments.

## Follow-up: creation from the navigators

Memnoc requested a way to spawn windows and sessions from these menus. Both now
show **n window** and **N session** in the footer. `n` creates a right-hand native
shell split in the selected entry's session, including hidden sessions, and
focuses terminal input. With no filtered selection it uses the current session.
During a close confirmation `n` remains cancel. `N` opens an inline directory
prompt, prefilled from the selected project; Ctrl-u clears, Enter creates a new
empty editor tab, and Esc cancels. It accepts existing directories only and
does not create worktrees.

The disposable `.probe/navigation/create.py` drives both menus with real keyboard
input and a real `/bin/sh` process. It verified prompt cancellation, invalid and
empty paths, correct directory and ownership when creating in a hidden session,
terminal input, close/termination, the no-selection fallback, and all footer
controls at 80×24. Shell startup failure removes the split and leaves the
navigator usable. Launch uses an argument list derived from Neovim's shell
option, avoiding an extra shell-command wrapper. Existing source files remain
unchanged. No new plugin, external multiplexer or persisted preference was added.
