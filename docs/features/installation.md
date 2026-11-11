# Installation, isolation and releases

Uzume installs from its repository and pinned upstream sources. No existing
Neovim configuration, plugin cache, Mason cache or parser binaries are required.

## Install on a new machine

Install these prerequisites on PATH:

- Neovim **0.11+**, Python **3.12+**, Git, ripgrep (`rg`), and `fd` or `fdfind`.
- A C compiler: Xcode Command Line Tools on macOS, or a GCC/Clang toolchain on Linux.
- A terminal with a Nerd Font for the interface icons. Ghostty and WezTerm are
  the primary manual evaluation terminals.

Then run:

```sh
git clone https://github.com/Memnoc/uzume.git ~/Code/uzume
cd ~/Code/uzume
python3 setup-editor --register
~/.local/bin/uzume
```

Keep the checkout: the configuration links to its `editor/` directory. Add
`~/.local/bin` to your shell's PATH if you want to type just `uzume`. The installer
prints the exact executable path and does not edit shell startup files. It works
without `nvims`, zsh or a pre-existing `.zshrc`. `--bin-dir PATH` selects another
launcher directory. Plain `nvim` keeps its existing configuration.

Install Codex and/or Claude separately and authenticate using their own login
flows. Node/npm are needed for Mason's web language tools; Rust projects need
their Rust toolchain. See [tool installation](tool-installation.md) for tool-specific
requirements. The editor can start before either agent CLI is installed.

The source-build path supports macOS and Linux. Cache-free installation and the
editor suite have been exercised on macOS ARM64; Linux and Intel Mac validation
remain pending. This does not yet claim a fully tested platform matrix.

## How it works

[setup-editor](../../setup-editor) checks prerequisites and rejects conflicting
registration paths before downloading. It fetches exact plugin and grammar Git
commits from [plugins.lock.json](../../editor/plugins.lock.json). Generated C
grammars are compiled for the local machine, so neither a Tree-sitter CLI nor
copied binaries are needed. Matching query files come from a pinned upstream
revision and are checked against their SHA-256 hashes, including inherited query
sets. Upstream licenses accompany the installed sources' runtime resources.

Before publishing the staged bundle, the installer loads every parser and query
set in the installed Neovim. Incompatible grammar ABI or queries fail the install;
a partial bundle is not activated. Help tags are generated, a platform marker and
completion marker are written, and the completed bundle is moved into place.
Repeated installation reuses a completed bundle for the same lockfile and host.
Interrupted/incomplete or foreign-platform bundles are refused with an explanation;
the installer does not silently delete them. Previous releases remain available.

`--register` creates the isolated config symlink and an executable launcher. It
refuses unrelated configs or launchers. The launcher records the chosen XDG
config/data/state/cache roots, sets `NVIM_APPNAME=ai-nvim` only for its subprocess,
and forwards arguments to `nvim`. It does not install Neovim itself.

`--plugin-cache PATH` optionally reads local Git repositories containing the
pinned commits; otherwise sources are fetched. `--tool-cache PATH` optionally
discovers existing Mason executables as read-only references. Later installs
retain working previously recorded executables when no replacement is supplied. Neither option is
needed. `--no-cache` ignores both options for a clean-source check. `--cc COMMAND`
(or `CC`) chooses the C compiler. The old `--syntax-cache` option has been removed:
syntax is built from sources now.

[packages.lua](../../editor/lua/ainvim/packages.lua) loads the bundle selected by
the lockfile hash using native `packadd`, checking the host marker first. Optional
packages follow Extras choices. Startup never downloads or updates plugins;
opening supported files may install missing language tools through Mason.

## Existing installations and updates

Your existing `uzume` shell function and `nvims` entry still work: the config/data
namespace remains `ai-nvim`. Re-run `python3 setup-editor` after updating the
checkout to a new lockfile, before restarting the editor. Registration is optional
if the existing config link already points to that checkout.

For the first update from the captured-parser preview, the new source pins produce
a new bundle. The old bundle, tools, worktrees, review comments and saved layouts
remain untouched. Do not point the config link at another worktree while an agent
is using it. The installer refuses to replace an unrelated link automatically.

## Stored state

| Location under normal XDG defaults | Contents |
| --- | --- |
| `~/.local/bin/uzume` | Generated launcher (or the chosen `--bin-dir`) |
| `~/.config/ai-nvim` | Symlink to the checkout's editor directory |
| `~/.local/share/ai-nvim/releases/<hash>` | Pinned plugin bundle, locally compiled syntax, platform/completion markers |
| `~/.local/share/ai-nvim/extras.json` | Saved pack choices |
| `~/.local/share/ai-nvim/tool-paths.json` | Executables discovered on PATH or an explicitly supplied cache |
| `~/.local/share/ai-nvim/mason/` | Separately managed language tools |
| ai-nvim's state/cache directories | Recovery, history and cache |

Installation downloads public upstream source code. It does not upload project
files or handle agent credentials. Extras settings remain local; sending context
to an agent is a separate explicit workflow.

To uninstall, remove only the Uzume launcher and its config symlink. Keep data and
state until you have deliberately dealt with retained task worktrees and review
records; those directories are not all disposable caches. Older shell functions
or `nvims` entries, if present, can be removed manually.

## Verification and remaining work

`python3 tests/installation.py` tests registration, repeat registration, argument
forwarding/startup, shell preservation, and refusal of unrelated configs/launchers,
foreign or incomplete bundles and missing prerequisites. It uses an already
installed bundle and isolated XDG paths. It is part of `tests/run.py`.

`python3 tests/install_clean.py` is a separate **network-enabled** test: empty XDG
roots, no supplied caches, fresh downloads/builds, all nine parsers with real
language samples, inherited query loading, launcher startup and repeat install.
It prints its temporary data directory, which can be used as `XDG_DATA_HOME` when
running the regular suite against the newly built bundle. It does not register
anything in your real config or bin directories, and makes no agent requests.

Neovim and host executables remain user-installed; the distro-managed Neovim,
release/update/rollback UI and supported platform matrix from ADR-0004 are still
unfinished. Source pins control inputs; they do not make compiler-dependent output
byte-identical across systems. CLI compatibility and language-tool runtime
requirements need their own validation.

Neovim's [Tree-sitter documentation](https://neovim.io/doc/user/treesitter/)
describes parser loading and ABI compatibility. The pinned query source is
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/tree/915f2bd3d4e2a33704bfc476b5137e9befa82f3d/runtime/queries);
it supplies build-time resources, not an added runtime plugin.
