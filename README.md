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

## Why Uzume?

Uzume takes its name from **Ame-no-Uzume**, the Japanese goddess whose dance helped draw the sun goddess Amaterasu out of her cave. Her story connects creativity, laughter, and the return of light—an inspiration for a personal editor that helps bring clarity to complex work. See [Kokugakuin University's Encyclopedia of Shinto](https://d-museum.kokugakuin.ac.jp/eos/detail/?id=9422) for the myth behind the name.

## Project status

Design and prototype stage. This branch, `spike/editor-baseline`, provides the first independent editor preview. There is no production distribution yet; the full specification remains open.

Run `uzume`, or `uzume path/to/file` to open a file directly. The existing `nvims` → **ai-nvim** entry also works. See the [editor guide](editor/README.md) for setup, familiar controls, and the current boundaries. Plain `nvim` keeps your default configuration.

The project is now named **Uzume**. The preview retains its original `ai-nvim` installation name and `ainvim` Lua namespace so existing settings, tools, and saved state continue to work. Renaming those identifiers will need a migration.

**Space l** opens [Extras](editor/EXTRAS.md): Rust, Lua, C/C++, TypeScript/React/HTML/CSS, and Smear Cursor. Save choices with Ctrl-s and restart to apply pack-loading changes. Missing
language tools now install automatically through isolated, pinned Mason when you
open supported files. The [tool workflow](docs/features/tool-installation.md)
covers catalog views, manual installation, disabling automation and retries.

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

The initial reference terminals are Ghostty and WezTerm on macOS and Linux. Kitty is an additional compatibility target. Animation polish follows a usable core.

The Uzume name and cave-and-sun logo are established. Rust component boundaries and the production dependency set remain open.
