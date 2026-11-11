# Feature guide

This is the current feature inventory for the **editor prototype** on `main`.
Each write-up explains the behavior, controls,
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
| Codex/Claude workspaces, marked files/reference context, attention and cleanup | [AI tasks](agents.md) |
| Task changes picker, stable diffs, line comments, queued feedback and explicit refresh | [Task review](review.md) |
| Combine tasks into a local feature branch, resolve conflicts and resume/abort | [Task integration](integration.md) |
| Local layout persistence and recovery | [Native navigators](navigators.md) |
| Full project autosave and release management: planned behavior | [Design record](../design.md) |

Start with the [launch guide](../../editor/README.md). Press **Space** and pause
for WhichKey, **Space sk** to search mappings, or **Space ?** for buffer mappings.
The Extras menu also carries its own control hints and icon legend.

The editor preview includes supervised Codex/Claude terminals in task worktrees.
Stable task review, queued feedback, local layout persistence and integration
are available; complete project restoration and managed releases remain planned.
The earlier standalone agent pilot is retained
for comparison.

For every feature change, update its write-up with what changed, how to use it,
how it works, dependencies and stored state, what was verified, and known limits.
Add the feature here if it is new. Keep planned behavior separate from available
behavior; implementation detail belongs in these guides, not in everyday menus.
