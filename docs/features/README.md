# Feature guide

This is the current feature inventory for the **editor preview** on
`spike/editor-baseline`. Each write-up explains the behavior, controls,
implementation, and limits. It is updated with feature changes; prototype
records preserve what was actually checked at each increment.

| Feature | What to read |
| --- | --- |
| Appearance, dashboard, explorer, search, buffers, windows, mouse, shells | [Editor and navigation](editor.md) |
| Project/window menus, switching, naming, closing, local layout save | [Native navigators](navigators.md) |
| Splits, moving, resizing, floating/fullscreen, hide/restore and mouse controls | [Window management](window-management.md) |
| Git changes, diagnostics, undo and recovery | [Editor and navigation](editor.md#reading-changes-and-recovery) |
| Optional packs, menu icons, saving choices | [Extras](../../editor/EXTRAS.md) |
| Available/installed catalog, Mason, file-triggered tools, retry controls | [Tool installation](tool-installation.md) |
| Rust, Lua, C/C++, TypeScript/React, HTML/CSS, completion and formatting | [Languages](languages.md) |
| Cursor animation and its controls | [Cursor animation](languages.md#cursor-animation) |
| Separate config, nvims, dependencies, pins and upgrades | [Installation and releases](installation.md) |
| Agent sessions and worktrees: separate experimental pilot | [Pilot findings](../prototypes/0002-drudwyn-pilot.md) |
| Agent attention, review suite, autosave, release management: planned behavior | [Design record](../design.md) |

Start with the [launch guide](../../editor/README.md). Press **Space** and pause
for WhichKey, **Space sk** to search mappings, or **Space ?** for buffer mappings.
The Extras menu also carries its own control hints and icon legend.

The editor preview does not yet integrate supervised Codex/Claude sessions,
the custom diff/review suite, source autosave, or complete managed releases.
Ordinary shell terminals and Git hunk tools are available now. The earlier agent
pilot runs separately from `~/Code/ai-nvim` using
`./spike --drudwyn`; keep its checkout and worktrees intact.

For every feature change, update its write-up with what changed, how to use it,
how it works, dependencies and stored state, what was verified, and known limits.
Add the feature here if it is new. Keep planned behavior separate from available
behavior; implementation detail belongs in these guides, not in everyday menus.
