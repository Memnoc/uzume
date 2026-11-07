# Installation, isolation and releases

Run `./setup-editor --register` from the editor-preview checkout. Then use
`nvims` → **ai-nvim**, or `NVIM_APPNAME=ai-nvim nvim`. The existing default
LazyVim configuration remains available through plain `nvim` and the default
picker entry. The [launch guide](../../editor/README.md) lists prerequisites
and removal instructions.

## How it works

[setup-editor](../../setup-editor) links this checkout's `editor/` directory to
`~/.config/ai-nvim`. It adds ai-nvim to the existing zsh `nvims` candidate list,
backs up `.zshrc`, and refuses to replace unrelated configuration. An already
running shell needs `source ~/.zshrc` after first registration.

[plugins.lock.json](../../editor/plugins.lock.json) records exact plugin commits
and syntax-resource hashes. The installer extracts those commits from an existing
local cache when possible, otherwise obtains them from the declared repositories.
It stages a package bundle, verifies captured syntax resources, generates help
tags and marks the bundle complete before making it available.

[packages.lua](../../editor/lua/ainvim/packages.lua) loads the bundle selected by
the lockfile hash, using native Neovim `packadd`. Optional packages load only
when their Extras pack is enabled. There is no LazyVim or lazy.nvim runtime,
no startup download and no automatic update check. Already installed bundles
remain available when a new lockfile is installed.

## Stored state and external tools

| Location under normal XDG defaults | Contents |
| --- | --- |
| `~/.config/ai-nvim` | Symlink to the editor checkout |
| `~/.local/share/ai-nvim/releases/<hash>` | Separate pinned plugin and syntax bundle |
| `~/.local/share/ai-nvim/extras.json` | Versioned boolean pack choices; atomic writes |
| `~/.local/share/ai-nvim/tool-paths.json` | Discovered executable paths |
| ai-nvim's XDG state/cache directories | Neovim recovery, history and cache |

The installer reads existing language tools from the supplied Mason cache or
PATH. [tools.lua](../../editor/lua/ainvim/tools.lua) uses recorded paths when
present, otherwise PATH. These are references to external binaries: ai-nvim
does not copy, install or update them, and does not modify LazyVim's Mason cache.
Updating those tools elsewhere can change this editor's behavior.

Extras saves settings locally and does not transmit them. The editor has no
agent login or credential store. Plugin installation can access upstream Git
repositories; language tooling follows its own/project behavior. The broader
agent authentication and data boundaries remain in the [design](../design.md).

## Current limits and verification

This is a local prototype, not a complete release system. Neovim itself and
language executables are not pinned/installed by the distro yet. Captured parser
binaries target macOS ARM64 and require the matching local source cache;
portable parser builds remain work. Keeping old bundles is a foundation for
rollback, not an implemented release/rollback UI.

The [baseline](../prototypes/0003-editor-baseline.md) and
[Extras](../prototypes/0004-extras-and-languages.md) records document installed
startup, isolated runtime behavior and checks that the daily LazyVim files were
unchanged. Keep the editor worktree while the config symlink points into it.
