# Linux installation and platform checks

Linux uses the same Lua editor, Python helpers and source installer as macOS.
There is no platform fork or tmux requirement. Native parsers are compiled for
the host; never copy a macOS release bundle into a Linux data directory.

## Prerequisites and installation

On Ubuntu 24.04, install the host tools:

```sh
sudo apt-get update
sudo apt-get install build-essential python3 git ripgrep fd-find
```

Install Neovim **0.11 or newer** separately and check `nvim --version`. The
distribution package may be older than Uzume's minimum. Python **3.12+** is
required. On other distributions, use the equivalent compiler, Python, Git,
ripgrep and fd packages. Ubuntu's `fdfind` executable is accepted directly;
no global `fd` alias is needed.

```sh
git clone https://github.com/Memnoc/uzume.git ~/Code/uzume
cd ~/Code/uzume
python3 setup-editor --register
~/.local/bin/uzume
```

The standalone launcher works from Bash, zsh or another shell. Add `~/.local/bin`
to PATH to call it as `uzume`; the installer leaves shell startup files alone.
Normal `nvim` stays separate. Standard XDG paths are respected. Existing users
should follow [namespace migration](namespace-migration.md) instead of manually
renaming their saved worktrees.

Use a terminal with a Nerd Font. Install Codex/Claude separately and let the
official CLI handle browser authentication. Language tools have their own host
requirements, including Node/npm for web tooling and Rust for Rust projects;
see [tool installation](tool-installation.md). Clipboard integration depends on
Neovim's available provider; `:checkhealth vim.provider` can diagnose the host.

## What CI exercises

[The Linux workflow](../../.github/workflows/linux.yml) builds from empty caches
on Ubuntu 24.04 x86_64 with Neovim **0.11.0** and **0.12.6**. Neovim release
archives have fixed checksums; action revisions and plugin/parser/query sources
are pinned. Each job runs:

1. Fresh installation, all nine parser/query sets, launcher startup and a repeat
   installation using disposable XDG directories.
2. All 16 regression cases: migration, installation, dashboard, pane motion,
   agent lifetimes, inherited edits, task navigation/launch, review/comments,
   Codex/Claude feedback and normal/diff3 integration.
3. Log retention for diagnosing failures. Bash pipeline failure propagation
   prevents `tee` from hiding a failing Python test.

The editor and Git are real; external agent CLIs are fixtures. No model requests,
user credentials or personal projects enter these runs. Tests verify actual
PTY/process behavior and forced-exit cleanup, not only Python imports.

Neovim 0.11 rejects NUL-containing input to `sha256()`. Review storage retains
its existing binary-key format using a cached Python standard-library fallback
on that version; newer versions use Neovim directly. Changing the hash format
would strand existing comment and feedback histories.

## Limits

Ubuntu x86_64 evidence does not establish Linux ARM64, musl/Alpine, every desktop
or Intel macOS support. Ghostty/WezTerm appearance, mouse handling, clipboard,
live vendor CLI behavior and animation smoothness still need hands-on Linux
trials. The installer currently validates a user-installed Neovim; managed
Neovim releases and an update/rollback UI remain future work.

See the [verification record](../verification-namespace-linux-2026-11-11.md)
for exact results and the [handoff](../HANDOFF.md) for follow-up work.
