# Project, window and pane management spike

Date: 2026-11-08. Branch: `spike/editor-baseline`. Status: implemented and
probed; awaiting Memnoc's hands-on evaluation.

Question: does a project grouping native Neovim tab pages, each representing a
window with its own editor/terminal panes, give Memnoc an understandable native
multiplexer? Test creation, switching, splits, moving/swapping/resizing, floating
and fullscreen with restoration, hide/restore, and scoped close using ordinary
files and shells before integrating agents.

The project directory identifies the project in this increment. Native tab
pages preserve window layouts when switching; native windows represent panes.
Existing navigator styling is retained. This is an interaction/state-model
probe in the real editor, not a new terminal renderer or a production spec.
Runtime changes stay on the spike branch; main retains validated findings.

## Implemented model and controls

`projects.lua` groups native tab pages by canonical directory. A tab is a product
window; native editor/terminal windows are panes. Each window retains its own
layout through native tab switching. Project and window display names are
independent, and the status line identifies both. The top buffer bar remains
shared, rather than masquerading as project/window navigation.

Space ap opens projects; Space aw opens windows. Space as and the old commands
remain compatibility aliases. Both navigators retain the Drudwyn visual
reference and expose n (shell window), e (editor window), N (project directory),
rename, confirmed close, filter and manual layout save. Space w is the discoverable
window/pane action menu. It includes horizontal/vertical editor or shell splits,
directional movement, swapping, transfer to another window in the same project,
resizing/equalizing, float/dock, fullscreen/restore, hide/restore, pane selection,
and scoped closing. `docs/features/window-management.md` on the editor branch
is the full user guide.

Floating/fullscreen uses native floats with a labelled placeholder in the original
tile. Docking restores that tile without recreating the process. Hidden panes
retain their buffers/jobs and can be selected in Space wp; restoration reuses a
placeholder or adds a right-hand split. It does not reconstruct an arbitrary
old split tree after other panes have moved. Float borders accept mouse movement
and resizing; native separators handle tiled resizing. Mouse support can be
turned off. No external multiplexer, plugin or Rust subsystem was added.

Window/project close preflights visible and managed hidden files and shared
terminal views before mutating the target. Closing stops owned native terminal
jobs while other windows/projects continue; files remain. Closing the final
active project/window leaves a neutral dashboard. Closing the last pane returns
to the project home. This is native shell lifecycle handling, not yet complete
Codex/Claude child-process supervision.

Manual snapshot metadata now records project names as well as window names.
Old snapshots remain readable: their former session labels become project names.
Native file layouts restore into their grouped projects without starting shells.
Save refuses outstanding managed floats/fullscreen/hidden panes so that their
state is not silently omitted. Full layout autosave remains deferred.

## Disposable probes and results

The scripts under ignored `.probe/windows/` drive the actual editor through a
PTY and RPC with disposable files and `/bin/sh` terminals. They add no permanent
test suite and submit no model tasks.

`workflow.py` passed on the current nightly and on Neovim 0.11.6:

- Splitting panes increases the pane count without creating another window.
  Creating a shell window adds a second tab inside the same project.
- Switching windows restores the prior focused pane and leaves both shells alive.
- Float, move, resize, fullscreen/unfullscreen and dock preserve the terminal
  job, original tiled tree and original tile dimensions.
- Hide/restore retains jobs; confirmed pane close stops only its shell.
- Tiled movement, buffer/view swapping and transfer to another window work.
- Project/window menus show their distinct entities. Dirty managed hidden files
  block a whole-project close before any window or job is removed.
- Closing one project stops its hidden/visible jobs while another project and
  all source files remain. Closing the final project leaves a neutral dashboard;
  opening a project from that dashboard does not retain a phantom project.

`edges.py` passed on the nightly:

- Injected mouse events move a managed float by its top border and resize its
  bottom/right corner; disabling mouse prevents those mutations. The probe found
  that disabled-mouse events must be consumed rather than returned through the
  expression mapping; that fix is included.
- The pane picker restores a hidden last pane. Project/window renames remain
  distinct and survive a saved file-layout round trip, grouped into one project.
- Save with a managed float or hidden pane refuses and leaves the previous
  snapshot unchanged. Restore does not start terminal jobs.
- The project navigator retains its creation/navigation/footer controls at 80×24.

`last-pane.py` passed on the nightly: hide/restore works with the explorer still
open, closing the final content pane returns home with the explorer, and closing
a window stops its hidden shell while another window's shell stays alive.

`legacy.py` passed against an actual snapshot produced by the earlier navigator
probe: session labels migrate to project names and file layouts reopen. It also
verified canonical-directory reuse and distinct automatic window names after
deleting a middle window and creating another. Lua formatting and whitespace
checks passed.

## Verdict and next evaluation

The native mapping supports the complete first interaction loop without a new
renderer or dependency. This is ready for Memnoc to try against Drudwyn with
ordinary files and shells before the agent workflow returns. Confirm the new
window/pane distinction, Space w controls, placement after hide/restore, and
mouse feel in the actual terminal. The mouse probes validate Neovim event
handling, not every Ghostty/WezTerm/Kitty protocol or GPU rendering path.

Remaining limits: shared buffer lists, in-memory floating/hidden arrangements,
no automatic project persistence, no cross-project pane transfer, and no
task-worktree grouping within a project. Heavy-output responsiveness, animation,
agent attention and process-tree supervision remain separate increments.

## Follow-up: separate window and pane menus

Memnoc found the combined menu too long and requested clear directional names
and distinct window/pane prefixes. Space w now contains six window actions:
pick (ww), new editor (wn), new shell (wN), next/previous (w]/w[), and close (wd).
Pane actions moved to Space p. Focus (pg), Move (pM), and Resize (pR) are short
submenus; h/j/k/l entries are labelled Left, Down, Up and Right. Split labels use
Down and Right; resize labels are Wider, Narrower, Taller, Shorter and Equalize.

Float/dock is pf, fullscreen/restore pm, hide pz, restore hidden pr, pane picker
pp, swap px, transfer po and close pane pd. Existing Ctrl-h/j/k/l focus and
Space - / Space | split aliases remain. Old pane mappings are not duplicated in
the window menu. In particular, pd closes a pane and wd closes the whole window,
both still confirmed; the previous wD binding is removed. Project navigation is
unchanged. Home/placeholder hints and current feature guides use the new keys.

The disposable `.probe/windows/menus.py` inspected the actual rendered WhichKey
menus (including virtual text), then drove the new split, direction, resize,
float/fullscreen, hide/restore, pane/window close and window-picker shortcuts.
All passed. Runtime window/pane behavior is unchanged; this increment reorganizes
bindings and descriptions. Formatting and whitespace checks passed.
