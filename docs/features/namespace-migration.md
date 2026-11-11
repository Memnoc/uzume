# Consistent Uzume naming and migration

Core Lua modules now live in `editor/lua/uzume/editor/`. Other features stay under
`uzume/agents`, `uzume/review`, `uzume/integration`, `uzume/layout`, `uzume/ui` and
`uzume/core`. Imports, events, internal variables and buffer types use Uzume.
The core code is preserved; this is a namespace change, not a replacement editor.

New installations use `NVIM_APPNAME=uzume`, config/data/state/cache directories
named `uzume`, and `pack/uzume` inside newly installed bundles. No legacy directory
is created for a new installation. Historical reports may still describe old names.

## Existing installations

Save your work and close every Uzume instance. From the checkout currently used
by your config link, run:

```sh
python3 setup-editor --migrate --register
```

The installer checks running instances and all destination paths, then moves the
old app directories to `uzume`. It does not merge two existing installations or
replace unrelated files. If you only want to migrate storage, without downloading
packages or registering a launcher, use `python3 setup-editor --migrate-only`.

After migration, under normal XDG defaults:

| Canonical location | Legacy compatibility link |
| --- | --- |
| `~/.config/uzume` | `~/.config/ai-nvim` → `uzume` |
| `~/.local/share/uzume` | `~/.local/share/ai-nvim` → `uzume` |
| `~/.local/state/uzume` | `~/.local/state/ai-nvim` → `uzume` |
| `~/.cache/uzume` | `~/.cache/ai-nvim` → `uzume` |

The old names are links, not duplicate data directories. They preserve absolute
paths in Git's worktree metadata, saved integration records, Mason executable
links, editor history and recovery data. Do not remove them just because the new
editor starts. The migration does not reset source files, modify Git indexes,
rewrite comment text, restart agents or delete old bundles. Renamed directories
retain their contents and permissions.

The new generated executable uses `NVIM_APPNAME=uzume`. If an older shell function
shadows it, change only that function's `NVIM_APPNAME=ai-nvim` to
`NVIM_APPNAME=uzume`. Likewise, replace the old entry with `uzume` in a custom
`nvims` picker. Open a new shell after editing; the current shell keeps its previous
function definition until reloaded. The generic installer never rewrites shell
files. Ordinary `nvim` remains separate.

## Recovery and compatibility

A private journal at `$XDG_STATE_HOME/.uzume-namespace-migration.json` records
planned moves before they happen; an advisory lock prevents concurrent migrations.
If a run stops after a directory move but before its compatibility link is made,
rerun the same command with the same XDG roots. It reconstructs the link without
moving the directory again. Conflicting destinations are refused before any move;
inspect them rather than deleting either tree to silence the error.

Retained task and integration paths compare canonical filesystem locations, so
an old path and its new alias still identify the same checkout/record. Saved
baselines and comments keep their original identity. Source text and history are
not modified by global string replacement. New tasks use the canonical data root.

Restart the editor after updating the code. Live Lua module caches and buffer
variables are not hot-migrated. Historical worktrees outside the app directories
remain where they are; a code namespace rename does not relocate arbitrary Git
repositories or the common Git directory shared by linked worktrees.

## Verification

`tests/migration.py` drives the public installer with disposable XDG roots and
real Git worktrees. It checks staged/unstaged preservation, permissions, legacy
path continuity, integration history, repeat/recovery, live-editor refusal and
all-destination preflight. Branch-launch regression also reopens a retained task
through a compatibility path and checks its original review baseline. The full
suite verifies the renamed Lua modules through actual editor workflows.
