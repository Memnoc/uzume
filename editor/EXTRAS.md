# Extras

Open **Space l** or `:Extras`. Type to filter, press **Enter** to toggle a pack,
then **Ctrl-s** to save. Restart ai-nvim to apply saved changes. Closing with
Escape discards changes that were not saved. The menu marks changes that require
a restart and shows required/optional tool availability in its preview.

The requested packs are enabled initially:

| Pack | Provides |
| --- | --- |
| Rust | rust-analyzer, completion, diagnostics, navigation, rustfmt, native Treesitter |
| Lua / Neovim | LuaLS, Neovim-aware lazydev integration, completion, StyLua, native Treesitter |
| C / C++ | clangd, completion, diagnostics, navigation, clangd formatting, native Treesitter |
| TypeScript / React / HTML / CSS | vtsls for JS/TS/JSX/TSX; HTML/CSS/JSON servers; Prettier; JSX/HTML tag closing and rename; optional ESLint, Tailwind, Emmet |
| Smear Cursor | Cursor animation, independently switchable with **Space ua** for the current run |

Disabling a pack stops loading its optional plugins and language servers on the
next launch. The small local catalog's dependencies are installed together at
setup and pinned; toggling a pack does not fetch packages or update the editor.
Preferences live in `~/.local/share/ai-nvim/extras.json`, outside the source
checkout, and are written atomically. No editor restart is forced.

## Editing

- **gd**, **gr**, **gI**, **gy**: definition, references, implementation, type definition.
- **K**, **gK**: hover and signature information.
- **Space ca**, **Space cr**, **Space cs**: code action, rename, document symbols.
- **Ctrl-Space**, **Ctrl-n/p**, **Enter**: request, select, accept completion.
- **Tab / Shift-Tab**: move through an active native snippet.
- **Space cf**: format explicitly, including a visual selection.
- **Space uf / uF**: toggle formatting on save globally / for the buffer.
- Existing diagnostic navigation and floating diagnostic pickers remain available.

Source files are still saved explicitly. Formatting on save uses the project's
formatter configuration. Prettier prefers a project-local executable and then
the discovered fallback. Rust uses the project's edition through Conform's
rustfmt integration. C/C++ formatting uses clangd, so no additional clang-format
installation is required.

The web pack does not create a React application or install its dependencies.
Normal project dependencies and `tsconfig.json`/`jsconfig.json` determine React
types and framework behavior. ESLint attaches when project configuration is
present; Tailwind follows its configured project detection. Build/run commands,
debuggers, test runners, and framework-specific development servers are not
managed by this pack.

## Tools and pins

The installer records usable existing executables in
`~/.local/share/ai-nvim/tool-paths.json`. It checks the supplied Mason cache before
PATH; this machine's rustup rust-analyzer shim is broken, while its Mason binary
works. HTML/CSS servers are present inside the existing eslint-lsp package even
though Mason exposes only some binaries in its top-level bin directory. These
are read-only references: the installer does not update or write into LazyVim's
Mason installation. PATH is a runtime fallback if a recorded executable vanishes.
Missing tools are shown in Extras; servers without a usable executable are not
started. Executable detection is not a guarantee of server/project health.

Plugin commits and copied parser/query hashes are in `plugins.lock.json`. Syntax
resources are copied into ai-nvim's own package bundle and loaded through native
Neovim Treesitter; the nvim-treesitter plugin is not a runtime dependency. This
snapshot is for this macOS ARM64 machine. CSS/SCSS/LESS use native Vim syntax;
their language-server features and Prettier are configured independently.

External language tools remain user-managed and are not release-pinned yet.
Updating their existing installation may change their behavior. Portable parser
builds and independently managed/pinned tool distributions remain release work;
the current mechanism is a local, working editor experiment.

Smear mirrors the existing color/target settings, excludes picker/input/menu
buffers, and does not animate terminal input. It is independent of other Snacks
animations. No FPS or terminal-specific performance guarantee has been measured.
