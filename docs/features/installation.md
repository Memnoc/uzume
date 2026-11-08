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
no startup plugin download and no automatic update check. Supported filetypes
can trigger missing-tool downloads through Mason. Already installed bundles
remain available when a new lockfile is installed.

## Stored state and external tools

| Location under normal XDG defaults | Contents |
| --- | --- |
| `~/.config/ai-nvim` | Symlink to the editor checkout |
| `~/.local/share/ai-nvim/releases/<hash>` | Separate pinned plugin and syntax bundle |
| `~/.local/share/ai-nvim/extras.json` | Versioned boolean pack choices; atomic writes |
| `~/.local/share/ai-nvim/tool-paths.json` | Discovered external executable paths |
| `~/.local/share/ai-nvim/mason/` | ai-nvim-managed tools and pinned registry |
| `~/.local/share/ai-nvim/tool-settings.json` / `tool-failures.json` | Automatic-install preference / failures awaiting retry |
| ai-nvim's XDG state/cache directories | Neovim recovery, history and cache |

The installer reads existing language tools from the supplied Mason cache or
PATH. [tools.lua](../../editor/lua/ainvim/tools.lua) prefers ai-nvim-managed
binaries, then recorded external paths, otherwise PATH. External paths remain
read-only references, and ai-nvim does not modify LazyVim’s Mason cache.
Updating those tools elsewhere can change this editor's behavior.

Extras saves settings locally and does not transmit them. The editor has no
agent login or credential store. Plugin installation can access upstream Git
repositories. Mason installs missing supported language tools from upstream
packages/releases; language tooling follows its own/project behavior. The broader
agent authentication and data boundaries remain in the [design](../design.md).

## Current limits and verification

This is a local prototype, not a complete release system. Neovim itself and
external executables are not pinned/installed by the distro. New Mason-managed
installs use a pinned registry and explicit top-level tool versions; see
[Tool installation](tool-installation.md) for activation, retries and limitations.
Captured parser binaries target macOS ARM64 and require the matching local source cache;
portable parser builds remain work. Keeping old bundles is a foundation for
rollback, not an implemented release/rollback UI.

The [baseline](../prototypes/0003-editor-baseline.md),
[Extras](../prototypes/0004-extras-and-languages.md), and
[Mason workflow](../prototypes/0005-mason-workflow.md) records document installed
startup, isolated runtime behavior and checks that the daily LazyVim files were
unchanged. Keep the editor worktree while the config symlink points into it.
