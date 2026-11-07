# Languages and cursor animation

Use **Space l** to enable or disable packs. All five requested packs start
enabled; changes apply after saving and restarting. See [Extras](../../editor/EXTRAS.md)
for menu controls and tool discovery details.

## Language packs

| Pack | Implementation and behavior |
| --- | --- |
| Rust | rust-analyzer provides navigation, types, completion and diagnostics; rustfmt formats using the project edition through Conform. Native Treesitter supplies syntax. |
| Lua / Neovim | LuaLS plus lazydev provides Lua and Neovim API completion; StyLua formats. LuaJIT and the `vim` global are configured. Native Treesitter supplies syntax. |
| C / C++ | clangd provides navigation, completion, diagnostics and formatting; background indexing and clang-tidy are enabled. Supply a project `compile_commands.json` for accurate build flags. Native Treesitter supplies syntax. |
| Web | vtsls handles JavaScript, TypeScript and JSX/TSX; HTML, CSS and JSON servers handle their formats. Prettier formats. nvim-ts-autotag closes/renames tags. ESLint, Tailwind and Emmet are optional integrations subject to executable availability and project detection. |

The web pack supports React editing in an existing project; it does not create
applications or install npm dependencies. Project types, configuration and
framework versions still determine the available completion/diagnostics.
Native Treesitter parsers cover JS/TS/JSX/TSX, HTML and JSON; CSS/SCSS/LESS retain
Vim syntax highlighting. TSX and JSX filetype aliases are registered explicitly.

[languages.lua](../../editor/lua/ainvim/languages.lua) is the integration point:
Neovim's native LSP configuration and activation use pinned nvim-lspconfig
server definitions. nvim-cmp adds the completion UI and sources, using native
Neovim snippets. Completion is restricted to ordinary file buffers. Conform
coordinates formatting; Neovim handles LSP requests and diagnostics.

| Control | Action |
| --- | --- |
| gd / gr / gI / gy | Definition / references / implementation / type definition |
| K / gK | Hover / signature information |
| Space ca / cr | Code action / rename |
| Space cs / ss / sS | Document symbols / document symbols / workspace symbols |
| Ctrl-Space | Request completion |
| Ctrl-n/p / Enter | Select / accept completion |
| Tab / Shift-Tab | Move through an active snippet |
| Space cf | Format buffer or visual selection |
| Space uf / uF | Toggle format-on-save globally / for this buffer |

Formatting runs on explicit saves by default. Prettier prefers the project's
local executable, then the discovered fallback. C formatting comes from clangd,
so a separate clang-format executable is not required. Missing servers are
skipped and shown in Extras; executable presence does not prove project health.
External tool paths and version boundaries are covered in
[Installation and releases](installation.md).

## Cursor animation

The **Smear Cursor** pack loads the pinned `smear-cursor.nvim` plugin, configured
in [init.lua](../../editor/init.lua). It follows the existing LazyVim cursor
settings (`hide_target_hack`, automatic cursor color). Terminal input, Snacks
picker/input windows and WhichKey menus are excluded. It does not configure
other plugins' animations.

**Space ua** toggles animation for the current run when the pack is loaded.
To disable loading permanently, switch it off in **Space l**, save with
**Ctrl-s**, then restart. The temporary toggle does not change the saved pack
selection. No frame-rate or Ghostty/WezTerm/Kitty performance claim has been
measured; animation polish follows the usable editor.

## Verification and limits

The [language probe record](../prototypes/0004-extras-and-languages.md) records
real servers attached to Rust, Lua, C, TSX, HTML and CSS; diagnostic, definition,
completion, formatting, syntax and HTML tag-closing checks; plus Smear toggling
and pack activation across restarts. Neovim 0.11.6 startup and TSX highlighting
were also checked; the full probe used the installed 0.12 development build.

The TSX fixture used ambient JSX declarations, not a complete React app.
Real React projects, ESLint/Tailwind fixtures, paired-tag rename, full snippet
and range-formatting behavior still need hands-on evaluation. Debuggers, test
adapters and build/dev-server orchestration are not included yet.
