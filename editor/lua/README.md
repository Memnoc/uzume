# Lua module map

Neovim loads `require("uzume.agents")` from `uzume/agents/init.lua`; nested helpers
use names such as `uzume.agents.context`. This is ordinary Lua module resolution,
not a custom loader. Restart the editor after updating across this reorganization;
live `package.loaded` entries are not migrated in place.

| Directory | Responsibility |
| --- | --- |
| `uzume/agents/` | Task launch/continuation, worktrees, context, terminal input, views and scoped buffers |
| `uzume/review/` | Stable review UI, snapshot-anchored comments and feedback delivery |
| `uzume/integration/` | Local task integration and conflict-resolution controls |
| `uzume/layout/` | Pane animation and saved mode preference |
| `uzume/ui/` | Shared UI input behavior |
| `uzume/core/` | Shared resource location, independent of module nesting |
| `uzume/editor/` | Existing editor configuration, tools/languages, projects, navigation and native pane operations |

The principal entry points `uzume.agents`, `uzume.review` and `uzume.integration`
are unchanged. Internal helpers have moved beneath their owning feature. Imports,
tests and documentation links are updated together. Python helpers remain in
`editor/agent/` and `editor/review/`; `uzume.core.paths` resolves them from the
editor's `plugins.lock.json` marker rather than counting parent directories.

Core modules formerly in the old namespace now live under `uzume/editor/`, with
all imports, events, buffer types and internal variables renamed consistently.
Persistent app directories use `uzume`. Existing installations use the explicit
[migration](../../docs/features/namespace-migration.md), preserving files and old
absolute paths through compatibility links; new installations have no legacy dirs.

See [the handoff](../../docs/HANDOFF.md) for architecture and next work, and
[feature guides](../../docs/features/README.md) for behavior and controls.
