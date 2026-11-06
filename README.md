# ai-nvim

Working name for an independent Neovim distribution for reading code, reviewing agent changes, and programming by hand. Preserve the capabilities and keybindings of Memnoc's My-LazyVim configuration, with MNvim's preference for understandable, minimal configuration.

The design combines native Neovim editing with our own pane and session management, Codex and Claude Code terminals, and a substantial local diff and review experience. Plugins remain appropriate when they offer meaningful value at a reasonable maintenance cost.

## Project status

Design and prototype stage. There is no production distribution yet. The first native-session prototype has been approved and implemented on the throwaway branch `spike/native-sessions`; user evaluation and the full specification remain open.

To try it, switch to `spike/native-sessions` and run `./spike`. Its controls and boundaries are in `spikes/native-sessions/README.md` on that branch. Main retains design records and technical findings only; the prototype code is not a production foundation.

- [Design record](docs/design.md): agreed behavior, deferred features, and open questions.
- [Domain glossary](CONTEXT.md): the meaning of sessions, panes, tasks, and reviews.
- [Architecture decisions](docs/adr/README.md): choices and their tradeoffs.
- [First prototype](docs/prototypes/0001-native-sessions.md): scope, technical findings, and pending hands-on evaluation.

## Development approach

Use Northstar and ask one design question at a time. Record decisions during the interview; use throwaway spikes to resolve interaction and technical uncertainty. Before the production specification, complete Northstar's compliance triage, then create the spec and incremental tickets. Implement with appropriate TDD and crosscheck, and use harden to verify the assembled workflows. Test small increments with Memnoc rather than building the whole distribution before feedback.

The initial reference terminals are Ghostty and WezTerm on macOS and Linux. Kitty is an additional compatibility target. Animation polish follows a usable core.

## References

- [My-LazyVim](https://github.com/Memnoc/My-LazyVim): functionality and muscle-memory baseline.
- [MNvim](https://github.com/Memnoc/MNvim): design spirit, not a source tree to copy wholesale.
- [Drudwyn](https://github.com/Memnoc/tmux-drudwyn): session navigation, agent attention, worktrees, and TUI inspiration.
- [TUIOS](https://github.com/Gaurav-Gosain/tuios): flexible terminal window management inspiration.

Branding, Rust component boundaries, plugin selection, and exact version pins are not settled.
