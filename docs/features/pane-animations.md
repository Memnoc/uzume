# Pane animations

**Slide is enabled by default.** Right splits reveal inward from their right
edge; bottom splits reveal upward from below. Floating panes rise gently at
their final size. Managed resize and fullscreen transitions settle without
overshoot. Ordinary focus changes, docking, tile rearrangement and closing stay
instant in Slide mode.

## Controls

| Control | Action |
| --- | --- |
| Space uA | Choose a mode with j/k, then Enter to save; Esc cancels |
| `:UzumeMotion` | Show the current mode |
| `:UzumeMotion slide` | Enable the default directional animation |
| `:UzumeMotion instant` | Disable motion and settle the active transition |
| Space pv / ps | Split right / below |
| Space pT / pt | Create a shell pane right / below |
| Space pf / pm | Float/dock / fullscreen/restore |
| Space pR | Discover pane resize controls |

The chooser offers four modes, with the active one marked:

- **Slide:** a restrained 200 ms ease-out; the normal default.
- **Instant:** no geometry animation or tint.
- **Pulse:** final geometry immediately, followed by a brief pane highlight.
- **Spring:** roughly 420 ms with overshoot and a damped settle.

Ease was removed because its behavior overlapped with Slide. Smear Cursor remains
independent and keeps its own **Space ua** toggle. Pane animation uses uppercase
**A**. Choosing Instant does not disable unrelated plugin effects.

## Behavior and storage

The preference is saved locally in `stdpath('data')/pane-motion.json`, with a
version field and mode name. It survives restarts. A fresh installation defaults
to Slide; an unreadable/invalid preference warns and falls back to Slide. Choosing
a valid mode writes a fresh preference atomically. There is no network activity,
new dependency, shell change or source-file mutation associated with this setting.

Motion does not own buffers, terminal processes or focus. Native pane operations
establish the real destination first; the renderer interpolates geometry while
preserving the pane's identity. Directional reveals resize the source side of
the divider, keeping the new pane's outer edge anchored instead of borrowing
space from an unrelated neighbor.

A subsequent managed operation settles the previous transition first. Typing,
focus/tab changes and shutdown end active motion; closed panes are not recreated.
If a native command or mouse action has already changed the geometry, its result
takes precedence. Fullscreen restoration captures settled geometry. Pulse restores
the prior window highlight on completion, interruption or colorscheme change.

## Implementation and verification

[`layout/motion.lua`](../../editor/lua/uzume/layout/motion.lua) contains geometry
animation and interruption handling; [`layout/settings.lua`](../../editor/lua/uzume/layout/settings.lua)
owns validated local preferences. [`ainvim/panes.lua`](../../editor/lua/ainvim/panes.lua)
calls the module directly at pane operations. The experimental monkeypatch,
demo launcher, generated files and sample processes are not loaded by the editor.

`python3 tests/pane_motion.py` drives the regular editor through real controls
in isolated XDG directories. It checks the default reveal and absence of bounce,
mode discovery, removal of Ease, persisted Instant across startup, resize,
float/fullscreen/dock restoration, typing, external resize precedence, mode and
colorscheme changes, tab switching and closing an animating pane. The consolidated
suite also exercises task/review/integration behavior with the new module paths.

Terminal geometry is measured in whole cells, so visible movement is limited by
cell size. Native split minimums and screen bounds can constrain motion. This
does not promise pixel-level compositor effects or 60 FPS. Arbitrary native
`Ctrl-w` operations, mouse dragging, external plugin windows, tab switching and
agent-created layouts are not animated by this module. Managed repeated resize
commands currently settle before the next operation rather than preserving
spring velocity. Performance under several busy real agent TUIs remains a manual
evaluation item; Instant is always available.
