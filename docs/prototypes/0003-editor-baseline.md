# Editor baseline preview

Date: 2026-11-07. Status: installed for hands-on evaluation.
Branch: `spike/editor-baseline`. Checkout: `/Users/matteostara/Code/uzume` (renamed from `ai-nvim-editor` on 2026-11-08).

## Question and scope

After trying the Drudwyn pilot, Memnoc found agents more accessible but the
editor insufficiently familiar or capable. Build the editor foundation first:
Rose Pine, the Snacks sidebar, floating navigation, familiar LazyVim key groups,
and discoverable shortcuts. Memnoc explicitly asked to retain plain `nvim` for
the daily LazyVim configuration and add this preview through the existing zsh
`nvims` function.

This is an independent native Neovim configuration, not a LazyVim import. It
does not load the agent pilot. The worktree keeps the pilot's existing paths
intact so it remains available for comparison.

## Implemented increment

- Rose Pine, icons, relative line numbers, indentation guides, buffer line,
  global status line, and a dashboard using the existing visual reference.
- Snacks explorer with `Space e`/`Space E` and its standard file-operation keys.
  File/text/buffer/help/Git pickers float; WhichKey uses the familiar Helix menu.
- Existing file/search/window groups, buffer cycling/deletion, native splits,
  Flash navigation, paired delimiters, and Git signs/hunk actions.
- Independent right-side and floating shells, toggled with `Ctrl-/` and
  `Space 9`. Single Escape and `jk` leave shell input. These are ordinary shell
  terminals, not the agent supervisor; agent input routing is still separate.
- Mouse toggle, explicit source saves, native recovery/undo, and separate editor
  data/history. The original throwaway fixture's discard-on-exit behavior does
  not apply to this editor.

Nine plugins are loaded using native optional packages. `plugins.lock.json`
records exact commits copied from the inspected local installations; the
installer can fetch the declared repository if a commit is not cached. Archived
plugin contents and help tags live in a bundle identified by the lockfile hash.
There is no runtime package manager, update check, or startup download. Old
bundles are retained, but full Neovim version management and release rollback
remain future work. The installer uses Python 3.12+; the runtime is Lua/Neovim.

## Local integration

`~/.config/ai-nvim` links to this checkout's `editor/`. Plugins live under
`~/.local/share/ai-nvim/releases/ae82b31afe90`; state/cache are also namespaced
by `NVIM_APPNAME=ai-nvim`. The only `.zshrc` change adds `ai-nvim` to the existing
`nvims` candidate list. A pre-change backup was written next to `.zshrc`.
No global `NVIM_APPNAME` or `nvim` alias was added.

Open a new shell, run `nvims`, and choose **ai-nvim**. Direct launch:

```sh
NVIM_APPNAME=ai-nvim nvim /Users/matteostara/Code/tmux-drudwyn/src/session_navigator.rs
```

## Verification

Development probes used an isolated configuration/data/state/cache and disposable
Git project. No permanent test suite was added for this Northstar spike.

- Startup loads Rose Pine with no initialization errors and no LazyVim runtime.
- In a real PTY on the installed Neovim 0.12 development build, keyboard actions
  opened/closed the explorer, created a file/directory, renamed a file through
  the Snacks dialog, and opened a file while keeping the sidebar visible.
- File and text pickers returned results in floating windows. Dismissing them
  preserved the sidebar. Pausing after Space opened WhichKey's menu.
- Side and floating shell shortcuts opened distinct terminal buffers; a single
  Escape returned to terminal Normal mode, and each shortcut hid its terminal.
- Installed plugin help resolves, including `:help snacks-explorer`.
- Installation/registration is idempotent in an isolated home. The existing
  `nvims` function was exercised with a fake picker/executable: default unsets
  an inherited app name; selecting ai-nvim sets it; path arguments survive.
- Actual registration preserved hashes of all 19 inspected default LazyVim
  config files. `.zshrc` differed only by the added candidate and passed zsh
  syntax validation. Plain Neovim's default config path remains `~/.config/nvim`.
- The installed ai-nvim configuration starts without errors. The already
  installed Neovim 0.11.6 binary also passed an isolated startup check; full UI
  behavior on 0.11 was not exercised.
- Lua formatting and whitespace checks passed.

Some early probe failures were harness assumptions: headless mode does not fire
the UI startup event, the rename field is cwd-relative, WhichKey's filetype is
`wk`, and picker objects cannot be converted directly through remote-expr. The
final interaction probe used a real attached terminal UI and explicit checks.

## Limits and next evaluation

Native syntax highlighting is enabled. Language servers, automatic completion,
formatting, advanced Treesitter features, debugging/testing, language previews,
and the remaining custom extras are not configured yet. Diagnostic UI is ready
for later providers; it is not proof of working language support. Root detection
uses `.git`/`lua`/cwd; LSP-root precedence remains pending. The floating terminal
uses Snacks instead of ToggleTerm; only the intended toggle/layout behavior has
been checked so far.

Full menu/binding parity, all explorer operations, Linux, Ghostty/WezTerm mouse
behavior, and startup/performance under load are not yet established. There are
no new agent/session menus in this preview. Review snapshots and agent feedback
delivery remain separate increments.

Ask Memnoc to use a real project for reading: sidebar, search, buffers, windows,
and shell access. First settle whether this restores the familiar editor feel;
then add and verify language tooling before bringing agent navigation back.

## Further notes

Main keeps this record and the design references. Source, the lockfile,
`setup-editor`, and the detailed `editor/README.md` stay on the spike branch.
Keep the editor checkout while its configuration symlink is installed.
