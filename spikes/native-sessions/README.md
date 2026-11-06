# Native sessions spike

Throwaway experiment: can native Neovim windows and terminal jobs provide comfortable pane management and concurrent sessions with predictable termination?

This is an interaction and lifecycle probe, not an MVP or a replacement for your daily editor. The UI is deliberately small. No real agents, accounts, plugins, or downloads are involved.

## Run

From the repository root on branch `spike/native-sessions`:

```sh
./spike
```

Or from any directory:

```sh
/Users/matteostara/Code/ai-nvim/spike
```

Requires Neovim 0.11+ and Python 3 on PATH. The tested executable is this machine's Neovim 0.12 development build; the production distro's pinned Neovim installer is not part of the spike. Start with a reasonably wide terminal, around 120 columns by 36 rows, so the editor and two terminals are readable.

The launcher creates fresh temporary config/data/state/cache paths and two disposable sample project directories. It loads only this configuration, starts four Python fixtures plus one child worker each, and removes the scratch directory after exit. Nothing is installed into your normal Neovim configuration. Edits to the sample files are also discarded.

## Try this first

1. Read the sample code in **atlas**. The two right-hand panes represent Codex and Claude, each with a real heartbeat counter and worker process.
2. Press **F7** (`Space b` in Normal mode). An agent in **harbor** requests input; your reading position stays put.
3. Press **F5** (`Space a`), select the request with `j`/`k`, and press Enter. The relevant session and agent pane open. Press `Space c` to let it continue.
4. Press **F3** (`Space f`) to float that pane. Move it by dragging the top border or using `Space w h/j/k/l`. Resize with the bottom/right border, Ctrl-arrows, or `Space r h/j/k/l`.
5. Press **F4** (`Space z`) to zoom, then again to restore. Press F3 to retile. This spike retiles to the right of an available tiled pane; it does not remember the previous tile slot.
6. Press **F6** (`Space s`) to switch sessions. Hidden agents continue running. Press **F9** (`Space x`) to explicitly terminate a session, then confirm; the other session continues.
7. Press `Space q` from Normal mode to quit. All fixtures and workers are stopped and scratch files removed.

On keyboards that reserve function keys for system controls, hold Fn or use the Space mappings. These are prototype controls, not a finalized replacement for the existing LazyVim bindings.

## Controls

Space mappings apply in Normal mode. Function keys and Ctrl-direction/resize keys also work while typing into an agent terminal.

| Action | Key |
| --- | --- |
| Help | F1 / `Space ?` |
| Cycle panes, including floats | F2 / `Space p` |
| Tile / float focused pane | F3 / `Space f` |
| Zoom / restore layout | F4 / `Space z` |
| Attention selector | F5 / `Space a` |
| Next session | F6 / `Space s` |
| Select atlas / harbor | `Space 1` / `Space 2` |
| Simulate a background need | F7 / `Space b` |
| Toggle mouse | F8 / `Space m` |
| Terminate current session | F9 / `Space x` |
| Move tiled pane to an edge / move float | `Space w h/j/k/l` |
| Resize pane | Ctrl-arrows / `Space r h/j/k/l` |
| Focus adjacent native window | Ctrl-h/j/k/l |
| Balance tiled panes | `Space =` |
| Continue focused simulated agent | `Space c` |
| Quit and discard this experiment's scratch files | `Space q` |

Mouse support uses native separator dragging for tiles, top-border dragging for floats, and bottom/right-border dragging for floating resize. Shift-drag one tiled pane onto another to swap positions. A terminal's own Shift-mouse selection binding can intercept that gesture; keyboard pane movement is always available. Session tabs are clickable. Disabling the mouse disables the prototype's pointer interaction.

Focus an agent and press `i` to enter terminal input. Type `w` (input needed), `b` (blocked), `r` (ready for review), `c` (continue), `x` (failed), or `q` (stop that fixture), followed by Enter. Use Neovim's standard **Ctrl-\ then Ctrl-n** to return to Normal mode. F2 also leaves terminal input while moving to another pane.

## Implementation boundary

- `init.lua`: native tabs, splits, floats, terminal jobs, key/mouse handling, and local fixture-state polling.
- `model.lua`: pure attention ordering and next-session queries.
- `fixture.py`: simulated agents with actual child processes and local JSON evidence. It does not modify sample source files or invoke Codex/Claude.
- `../../spike`: isolated launcher with normal-exit cleanup and an ownership-checked fixture cleanup fallback if Neovim exits unexpectedly.

The small JSON files are disposable probe instrumentation, not session persistence. The fixture emits exact lifecycle states; this does not establish how reliably real agents will expose those states. Cleanup is verified for these fixtures, not arbitrary daemonized descendants of real CLIs. Killing both the launcher and Neovim forcibly at once is outside this experiment's recovery guarantee.

No saved layouts, worktree operations, real feedback delivery, review engine, animation, automatic focus, plugin baseline, or installer are implemented here. Code reading/review remains a separate prototype.

## Verdict and feedback

Technical smoke checks show native Neovim can support the proposed basic interaction and fixture lifecycle. Human evaluation in Ghostty and WezTerm, Linux validation, performance measurement, and real-agent behavior remain pending. See the [recorded findings](../../docs/prototypes/0001-native-sessions.md#initial-findings).

Try the workflow before judging the styling. The useful feedback is where focus feels wrong, pane movement is awkward, or an attention signal fails to help you return to the task.
