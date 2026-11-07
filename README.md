# ai-nvim

Working name for an independent Neovim distribution for reading code, reviewing agent changes, and programming by hand. Preserve the capabilities and keybindings of Memnoc's My-LazyVim configuration, with MNvim's preference for understandable, minimal configuration.

The design combines native Neovim editing with our own pane and session management, Codex and Claude Code terminals, and a substantial local diff and review experience. Plugins remain appropriate when they offer meaningful value at a reasonable maintenance cost.

## Project status

Design and prototype stage. This branch, `spike/editor-baseline`, provides the first independent editor preview. There is no production distribution yet; the full specification remains open.

Run `nvims` and choose **ai-nvim**, or use `NVIM_APPNAME=ai-nvim nvim`. See the [editor guide](editor/README.md) for setup, familiar controls, and the current boundaries. Plain `nvim` keeps the existing LazyVim configuration.

**Space l** opens [Extras](editor/EXTRAS.md): Rust, Lua, C/C++, TypeScript/React/HTML/CSS, and Smear Cursor. Save choices with Ctrl-s and restart to apply them.

The earlier agent pilot remains available in `/Users/matteostara/Code/ai-nvim` on `spike/drudwyn-pilot`. It is separate from this editor preview while we evaluate the editor first.

- [Design record](docs/design.md): agreed behavior, deferred features, and open questions.
- [Feature guide](docs/features/README.md): available features, shortcuts, implementation and limits.
- [Domain glossary](CONTEXT.md): the meaning of sessions, panes, tasks, and reviews.
- [Architecture decisions](docs/adr/README.md): choices and their tradeoffs.
- [First prototype](docs/prototypes/0001-native-sessions.md): scope, technical findings, and pending hands-on evaluation.

## Development approach

Every feature change includes an updated feature write-up: behavior, controls,
implementation, dependencies and stored state, verification, and known limits.
Keep the feature index current and distinguish implemented features from plans.

Use Northstar and ask one design question at a time. Record decisions during the interview; use throwaway spikes to resolve interaction and technical uncertainty. Before the production specification, complete Northstar's compliance triage, then create the spec and incremental tickets. Implement with appropriate TDD and crosscheck, and use harden to verify the assembled workflows. Test small increments with Memnoc rather than building the whole distribution before feedback.

The initial reference terminals are Ghostty and WezTerm on macOS and Linux. Kitty is an additional compatibility target. Animation polish follows a usable core.

## References

- [My-LazyVim](https://github.com/Memnoc/My-LazyVim): functionality and muscle-memory baseline.
- [MNvim](https://github.com/Memnoc/MNvim): design spirit, not a source tree to copy wholesale.
- [Drudwyn](https://github.com/Memnoc/tmux-drudwyn): session navigation, agent attention, worktrees, and TUI inspiration.
- [TUIOS](https://github.com/Gaurav-Gosain/tuios): flexible terminal window management inspiration.

Branding, Rust component boundaries, plugin selection, and exact version pins are not settled.
