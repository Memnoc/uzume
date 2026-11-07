# Editor preview

Northstar editor spike: can a small independent configuration restore Memnoc's
LazyVim navigation and visual feel before adding agent sessions?

This first increment supplies Rose Pine, a Snacks sidebar and floating pickers,
WhichKey's Helix leader menus, buffer/status lines, Git signs and hunk actions,
Flash navigation, paired delimiters, and the familiar shell terminal shortcuts.
Nine plugins are pinned to exact commits and loaded with Neovim's native package
support. There is no dependency on LazyVim or a plugin-manager runtime.

## Launch

After registration, open a new terminal and run `nvims`, then choose **ai-nvim**.
The **default** entry and plain `nvim` retain the existing LazyVim configuration.
To launch directly:

```sh
NVIM_APPNAME=ai-nvim nvim /Users/matteostara/Code/tmux-drudwyn/src/session_navigator.rs
```

Configuration lives in this checkout's `editor/`, linked as `~/.config/ai-nvim`.
Neovim uses its own `ai-nvim` data, cache, and state directories. It never loads
your daily LazyVim configuration or shares its plugin installation. The initial
setup copies committed plugin contents from the local cache when available;
otherwise it downloads the declared repository and extracts the pinned commit.

## First walkthrough

1. Open a project file, then press **Space e** to show/hide the left explorer.
   **Space E** uses the current directory. The explorer retains Snacks' standard
   keys: `a`, `r`, `d`, `c`, `m`, `y`, `p`, `Tab`, `h`, `l`, `H`, `I`, and so on.
   Use a disposable directory when trying file operations.
2. **Space Space** finds files; **Space /** searches project text. **Space ,**
   selects buffers. These are floating pickers; opening a file keeps the explorer.
3. Press **Space** and pause for the leader menu. **Space f**, **Space s**, and
   **Space w** retain their familiar groups. **Space ?** shows buffer-local help.
4. **Shift h/l** cycles buffers; **Space bd** closes a buffer while retaining the
   window layout. **Space |** and **Space -** create splits; **Ctrl-h/j/k/l** moves
   between them. Native **Ctrl-w** resizing remains available without arrow keys.
5. **Ctrl-/** toggles the right-side shell; **Space 9** toggles a floating shell.
   **Esc** or `jk` leaves terminal input, matching your current shell-terminal
   maps. These are ordinary shells, not supervised agent sessions.
6. **Space gs** opens Git status, **Space gd** shows hunks, and **]h/[h** moves
   through changes. **Space uM** toggles the mouse. **Space qq** quits with normal
   unsaved-buffer confirmation. Save files with `:w` or **Ctrl-s**.

This increment uses native syntax highlighting. Language servers, automatic
completion, formatters, advanced Treesitter features, debugging/tests, previews,
and the remaining custom extras are still pending. Diagnostic displays are
ready for later language support; their presence does not mean a server is
installed. Agent sessions and the custom review suite remain in the separate
pilot, not this editor preview.

Unlike the original fixture spike, edits to opened files and normal editor
recovery/history persist. Source-file saving remains explicit. Root detection
currently uses `.git` (including worktrees), `lua`, then cwd; LSP-root precedence
will be evaluated with the language tooling increment.

## Installation and pins

```sh
./setup-editor --register
```

Requires Neovim 0.11+, Python 3.12+, Git, `rg`, and `fd`. A Nerd Font provides the
icons, as in the current LazyVim setup. The shell picker also needs `fzf`.

The installer adds only the `ai-nvim` entry to Memnoc's existing `nvims` list,
backs up `.zshrc`, and refuses to replace an unrelated config. It is idempotent.
No global `NVIM_APPNAME` is exported and the `nvim` command/aliases are unchanged.

`plugins.lock.json` determines a separate immutable package bundle. Startup
does not install, update, or check for updates. Changing pins requires an explicit
installer run; old bundles remain available. This is not yet the distribution's
Neovim installer, upgrade UI, or complete release/rollback mechanism.

Keep this worktree while its configuration link is installed. To remove the
preview, remove only that link and the `ai-nvim` candidate in `nvims`; remove its
separate data/state/cache only if the local history is no longer wanted.
