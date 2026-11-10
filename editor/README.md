# Uzume editor preview

The editor preview provides native project, window, and pane management alongside
code navigation, language tools, and discoverable keyboard controls.

This first increment supplies Rose Pine, a Snacks sidebar and floating pickers,
WhichKey's Helix leader menus, buffer/status lines, Git signs and hunk actions,
Flash navigation, paired delimiters, and the familiar shell terminal shortcuts.
The base and optional plugins are pinned to exact commits and loaded with
Neovim's native package support. Packages load without a plugin-manager runtime.
**Space l** (or `:Extras`) manages the language packs and
Smear Cursor; see [Extras](EXTRAS.md) for controls and tool requirements.
The [feature guide](../docs/features/README.md) explains every current feature
group, its implementation, shortcuts, stored state and known limits.

## Launch

Uzume currently uses the original `ai-nvim` installation name to preserve the preview's existing settings and state.

After registration, open a new terminal and run `uzume`. It forwards all arguments to Neovim, so `uzume .` and `uzume path/to/file` work too. In an existing shell, run `source ~/.zshrc` once to load the command. You can also run `nvims`, then choose **ai-nvim**.
The **default** entry and plain `nvim` retain the default Neovim configuration.
To launch directly:

```sh
uzume path/to/project/src/main.rs
```

Configuration lives in this checkout's `editor/` directory, linked as
`~/.config/ai-nvim`.
Neovim uses its own `ai-nvim` data, cache, and state directories. It never loads
your default Neovim configuration or shares its plugin installation. The initial
setup copies committed plugin contents from the local cache when available;
otherwise it downloads the declared repository and extracts the pinned commit.

## First walkthrough

1. Open a project file, then press **Space e** to show/hide the left explorer.
   **Space E** uses the current directory. The explorer retains Snacks' standard
   keys: `a`, `r`, `d`, `c`, `m`, `y`, `p`, `Tab`, `h`, `l`, `H`, `I`, and so on.
   Use a disposable directory when trying file operations.
2. **Space Space** finds files; **Space /** searches project text. **Space ,**
   selects buffers. These are floating pickers; opening a file keeps the explorer.
3. Press **Space** and pause for the leader menu. **Space f**, **Space s**,
   **Space w** (windows), and **Space p** (panes) expose their control groups.
   **Space ?** shows buffer-local help.
4. **Shift h/l** cycles buffers; **Space bd** closes a buffer while retaining the
   window layout. **Space |** and **Space -** create splits; **Ctrl-h/j/k/l** moves
   between them. Native **Ctrl-w** resizing remains available without arrow keys.
5. **Ctrl-/** toggles the right-side shell; **Space 9** toggles a floating shell.
   **Esc** or `jk` leaves terminal input, matching your current shell-terminal
   maps. These are ordinary shells, not supervised agent sessions.
6. **Space gs** opens Git status, **Space gd** shows hunks, and **]h/[h** moves
   through changes. **Space uM** toggles the mouse. **Space qq** quits with normal
   unsaved-buffer confirmation. Save files with `:w` or **Ctrl-s**.
7. **Space aw** opens windows; **Space ap** opens projects (**Space as** is an
   alias). In either menu, **n** creates a shell window, **e** an editor window,
   and **N** prompts for a project directory. Each window keeps its own panes.
   A new editor window shows its project/name/path and the explorer, not an unnamed file.
   **Space fn** starts a real new file; **Ctrl-s** asks for its name on first save.
   The menus show rename, confirmed close, local
   layout save and filter controls. See [Native navigators](../docs/features/navigators.md)
   for the full workflow and restore limits.
8. Try **Space pv** for a right-hand editor split, **Space pt** for a shell below,
   **Space pf** to float/dock a pane, and **Space pm** to fullscreen/restore it.
   **Space pM** opens Move (Left/Down/Up/Right); **Space pR** opens Resize. **Space pz**
   hides, **Space pr** restores, and **Space pp** picks a pane. **Space pd** closes
   a pane; **Space wd** closes its whole window, with confirmation and job cleanup.
   Press **Space w** for windows or **Space p** for panes and pause for the menu. See [Window management](../docs/features/window-management.md).

Rust, Lua, C/C++, and TypeScript/React/HTML/CSS packs now supply language servers,
completion, diagnostics and formatting. Native Treesitter handles the captured
language parsers, including TSX; CSS retains native Vim syntax highlighting.
Smear Cursor is enabled and can be toggled with **Space ua**. Debugging/test
adapters and remaining language previews/custom extras
are still separate work.

**Space ac / aC** first offers a branch picker for Codex / Claude, with saved
changes shown before launch. Choose **Continue this task branch** for its existing
checkout and edits, or **New isolated task** for a separate branch from that starting
point. The current file's counterpart is marked as context. **Space ae / aE** uses
the same picker for an empty new workspace. Write your
instructions directly in the terminal. **Space af** marks a saved file,
**Space aF** marks several, and **Space am** manages the context list. Marked
paths are supplied by the hook on your next prompt; Codex may require `/hooks`
trust. **Space ad** inserts them into the draft manually if needed. Normal CLI
exit collapses the agent pane. See [AI tasks](../docs/features/agents.md).

New tasks inherit saved changes from the selected branch's checkout, including
non-ignored new files, while leaving the original files and staging untouched.
Save before launching. An inherited-state commit on the new task branch provides
the review baseline; review then shows changes made after launch.

**Space vr** (or **Space av**) opens task changes against the starting commit,
including committed and uncommitted edits. Enter opens a stable side-by-side
diff. Inside review, **u** toggles unified, **f** returns to files, **R** captures
newer changes and **q** closes it. The agent keeps running. See
[Task review](../docs/features/review.md).

In review, select lines and press **c** to write a multiline comment. **Ctrl-s**
saves it locally; **C** lists comments, with Enter to inspect and **e/d** to
edit/delete. Saved comments retain their original excerpts across refresh and
restart. Nothing is sent to the agent by these controls.

Press **s** in review or **Space vs** to preview unsent comments, then **a** to
send and focus the agent. Ready agents receive an automatically submitted prompt;
busy agents receive queued feedback at an eligible turn end. **Ctrl-s** queues
without leaving review; **x** cancels pending delivery and **r** checks status.
Restarting an agent requires explicitly queuing again. See
[sending review feedback](../docs/features/review.md#sending-review-feedback).

Unlike the original fixture spike, edits to opened files and normal editor
recovery/history persist. Source-file saving remains explicit. Root detection
uses the attached LSP root, then `.git` (including worktrees), `lua`, and cwd.
Formatting runs on explicit saves by default; **Space uf** toggles it globally,
**Space uF** per buffer, and **Space cf** formats explicitly.

## Installation and pins

```sh
./setup-editor --register
```

Requires Neovim 0.11+, Python 3.12+, Git, `rg`, and `fd`. A Nerd Font provides the
icons throughout the interface. The shell picker also needs `fzf`.
This local preview's captured parser binaries are for macOS ARM64. Installation
also requires the exact parser/query cache identified in the lockfile; portable
parser builds are not implemented yet. The setup script discovers existing tools
without modifying them. At runtime,
Mason installs missing tools for supported files into ai-nvim’s own directory;
see [Tool installation](../docs/features/tool-installation.md).

The installer adds the `ai-nvim` entry to the existing `nvims` list and a
`uzume` shell function that launches the same configuration. It backs up `.zshrc`
and refuses to replace an unrelated config. Registration is idempotent.
No global `NVIM_APPNAME` is exported and the `nvim` command/aliases are unchanged.

`plugins.lock.json` determines a separate immutable package bundle. Plugin
startup does not download or update packages. Opening a supported file
can trigger background language-tool installation; **Space uI** toggles that
behavior. Changing plugin pins requires an explicit installer run; old bundles
remain available. This is not yet the distribution’s Neovim installer, upgrade UI, or complete release/rollback mechanism.

Keep this worktree while its configuration link is installed. To remove the
preview, remove only that link, the `uzume` function, and the `ai-nvim` candidate in `nvims`; remove its
separate data/state/cache only if the local history is no longer wanted.
