# ai-nvim pilot: clear the workspace navigator filter

Implement this small real task in the current worktree and branch
`ai-nvim/clear-filter-workspaces`.

Read CONTRIBUTING.md and relevant context first. Your only implementation file
is `src/navigator.rs`; add meaningful regression coverage in its existing test
module. Another agent handles `src/session_navigator.rs` in a separate worktree.
Do not edit that file, shared documentation, dependencies, or other worktrees.

While editing the workspace navigator's search filter, Ctrl-u should clear the
whole query, refresh the visible results, and leave the user in filter input
mode with a valid selection. Preserve the current workspace kind filter. It
must work from a no-match query and be harmless when already empty. Plain `u`
must remain ordinary text. Preserve existing Enter/Esc behavior and the
precedence/behavior of rename, create, details, and kill confirmation modes.
Add a concise Ctrl-u hint to this navigator's filter footer. Handle key modifiers
explicitly; the current event loop passes only `key.code` to the handler.

Run `cargo fmt --check` and relevant Rust tests with `--locked`, then the full
Rust suite if feasible. Do not alter the lockfile or install hooks. Report any
environment limits honestly, and describe a short manual verification path.

Leave your changes uncommitted for local review. Do not push, merge, open a PR,
change global settings, or stage this task file. Stop after reporting changed
behavior and validation. This file is pilot guidance, not part of Drudwyn.
