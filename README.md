<p align="center">
  <img src="docs/assets/uzume-logo.svg" width="160" alt="Uzume logo: the sun rising inside a cave arch">
</p>

<h1 align="center">Uzume</h1>

<p align="center">
  <strong>An independent, understandable and opinionated Neovim distribution</strong><br>
  for reading code, reviewing agent changes, and programming by hand.
</p>

<p align="center">
  <a href="#project-status"><img src="https://img.shields.io/badge/status-prototype-eb6f92" alt="Status: prototype"></a>
  <a href="editor/README.md#installation-and-pins"><img src="https://img.shields.io/badge/Neovim-0.11%2B-c4a7e7" alt="Requires Neovim 0.11 or newer"></a>
  <a href="docs/features/installation.md#current-limits-and-verification"><img src="https://img.shields.io/badge/preview-macOS_ARM64-9ccfd8" alt="Current preview: macOS ARM64"></a>
</p>

<p align="center">
  <a href="editor/README.md#installation-and-pins"><strong>Install</strong></a> ·
  <a href="docs/features/README.md">Features</a> ·
  <a href="editor/README.md#first-walkthrough">Shortcuts</a> ·
  <a href="editor/EXTRAS.md">Extras</a> ·
  <a href="docs/design.md">Design</a>
</p>

---

The design combines native Neovim editing with built-in project, window, and pane management, first-class support for Codex and Claude Code, and a substantial local diff and review experience.
Plugins are used when they offer meaningful value at a reasonable maintenance cost.

## Install

With Neovim 0.11+, Python 3.12+, Git, ripgrep, fd and a C compiler installed:

```sh
git clone https://github.com/Memnoc/uzume.git ~/Code/uzume
cd ~/Code/uzume
python3 setup-editor --register
~/.local/bin/uzume
```

No existing Neovim config or caches are needed. See the
[installation guide](docs/features/installation.md) for platform status, language
tools and adding the launcher to PATH.

## Why Uzume?

Uzume takes its name from **Ame-no-Uzume**, the Japanese goddess whose dance helped draw the sun goddess Amaterasu out of her cave. Her story connects creativity, laughter, and the return of light—an inspiration for a personal editor that helps bring clarity to complex work. See [Kokugakuin University's Encyclopedia of Shinto](https://d-museum.kokugakuin.ac.jp/eos/detail/?id=9422) for the myth behind the name.

## Project status

The main development baseline contains the independent editor, project/window/pane management, isolated agent tasks, stable review and feedback, and local task integration. This is a working prototype, not a production release; the full production specification remains open.

Run `uzume`, or `uzume path/to/file` to open a file directly. The existing `nvims` → **uzume** entry also works. See the [editor guide](editor/README.md) for setup, familiar controls, and the current boundaries. Plain `nvim` keeps your default configuration.

The code, launcher and config/data directories use **Uzume** consistently. Existing
preview installations can migrate safely with `python3 setup-editor --migrate --register`;
see the [migration guide](docs/features/namespace-migration.md).

**Space l** opens [Extras](editor/EXTRAS.md): Rust, Lua, C/C++, TypeScript/React/HTML/CSS, and Smear Cursor. Save choices with Ctrl-s and restart to apply pack-loading changes. Missing
language tools now install automatically through isolated, pinned Mason when you
open supported files. The [tool workflow](docs/features/tool-installation.md)
covers catalog views, manual installation, disabling automation and retries.

**Space ac** starts a Codex task; **Space aC** starts Claude Code. Each task opens
in its own branch/worktree window under the current project. **Space aa** shows
agent attention. See the [AI task guide](docs/features/agents.md).

**Space uA** selects [pane animation](docs/features/pane-animations.md): Slide is
enabled by default, with Instant available for immediate layout changes.

- [Lua module map](editor/lua/README.md): code grouped by editor feature.
- [Maintainer handoff](docs/HANDOFF.md): architecture, verification, decisions, and prioritized next work.
- [Design record](docs/design.md): agreed behavior, deferred features, and open questions.
- [Feature guide](docs/features/README.md): available features, shortcuts, implementation and limits.
- [Domain glossary](CONTEXT.md): the meaning of projects, windows, panes, tasks, and reviews.
- [Architecture decisions](docs/adr/README.md): choices and their tradeoffs.
- [First prototype](docs/prototypes/0001-native-sessions.md): scope, technical findings, and pending hands-on evaluation.

## Development approach

Every feature change includes an updated feature write-up: behavior, controls,
implementation, dependencies and stored state, verification, and known limits.
Keep the feature index current and distinguish implemented features from plans.

Development proceeds in small, testable increments. Record design decisions, use focused prototypes to resolve uncertainty, and validate real editing workflows before expanding the feature set.

The initial reference terminals are Ghostty and WezTerm on macOS and Linux. Kitty is an additional compatibility target. Pane motion uses native terminal cells; visual performance still needs evaluation under busy agent output.

The Uzume name and cave-and-sun logo are established. Rust component boundaries and the production dependency set remain open.

## Repository layout

- `editor/`: the active distribution, including Lua UI and Python process/Git helpers.
- `installer/` and `setup-editor`: source installation and launcher registration.
- `tests/`: regression tests; `docs/`: features, architecture decisions and handoff.
- `spikes/` and `spike`: historical experiments, never loaded by the installed editor.

`editor/lua/uzume/editor/` contains the editor's core modules. Agent, review,
integration and layout modules live beside it under `uzume/`. See the
[Lua map](editor/lua/README.md). Compatibility links may remain at old storage
paths after migration so existing worktrees and saved records keep working.
