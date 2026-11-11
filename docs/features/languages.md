# Languages and cursor animation

Use **Space l** to enable or disable packs. All five requested packs start
enabled; changes apply after saving and restarting. See [Extras](../../editor/EXTRAS.md)
for menu controls and tool discovery details.

## Install language support

For a bundled language:

1. Open **Space l**, search for its pack, and check the enabled indicator. If it
   is disabled, press **Enter** to enable it; **Ctrl-s** saves the choice and
   requests its missing required tools. Do not toggle an already enabled pack off.
2. Wait for installation to finish. Restart Uzume if the pack was newly enabled,
   then open a file in the project. For an already active pack, opening a named
   file automatically installs missing required tools when **Space uI** is on.
3. Use **Ctrl-r** in Extras to install/retry the selected pack's required tools.
   **Space cm**, or **Ctrl-g** inside Extras, opens Mason for optional tools and
   installation output. Restart is not needed just for newly installed tools in
   a pack that is already active.

This covers editor dependencies: configured language servers, formatters,
completion and syntax support. Install the language toolchain/runtime and project
dependencies separately. For example, web tools need Node/npm, Rust projects
need their Rust toolchain and rustfmt, and C/C++ projects need their compiler and
build configuration. Mason does not install those project/runtime dependencies.
See [tool installation](tool-installation.md) for prerequisites and error recovery.

For a language outside the catalog, use **Space l → Ctrl-a** to create a user
language pack. Choose its server and formatter, inspect prerequisites, then enable,
save and restart. **Ctrl-e** edits its definition outside the distribution checkout.
See [User language packs](user-language-packs.md) for the walkthrough, schema,
manual definitions and boundaries. Mason installation alone still does not configure
a language; the pack supplies that wiring.

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

[languages.lua](../../editor/lua/uzume/editor/languages.lua) is the integration point:
Neovim's native LSP configuration and activation use pinned nvim-lspconfig
server definitions. nvim-cmp adds the completion UI and sources, using native
Neovim snippets. Completion is restricted to ordinary file buffers. Conform
coordinates formatting; Neovim handles LSP requests and diagnostics.

| Control | Action |
| --- | --- |
| gd / gr / gI / gy | Definition / references / implementation / type definition |
| K / gK | Hover / signature information |
| Space uh | Toggle native inlay hints for the current buffer (enabled by default) |
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
installed in the background for supported files when automatic installation is
enabled; successful installs refresh language availability. Failures appear in
Extras and require explicit retry. Existing executable presence does not prove
project health. See [Tool installation](tool-installation.md).
External tool paths and version boundaries are covered in
[Installation and releases](installation.md).

## Cursor animation

The **Smear Cursor** pack loads the pinned `smear-cursor.nvim` plugin, configured
in [init.lua](../../editor/init.lua). It uses
`hide_target_hack` and automatic cursor color. Terminal input, Snacks
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
