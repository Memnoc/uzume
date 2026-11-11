# Extras

Open **Space l** or `:Extras`. Type to filter, press **Enter** to toggle a pack,
then **Ctrl-s** to save. Restart uzume to apply saved changes. Closing with
Escape discards changes that were not saved. The menu marks changes that require
a restart and shows required/optional tool availability in its preview.

The menu border keeps the controls visible: **Ctrl-n/p** moves, **Enter** toggles,
**Ctrl-s** saves, and one **Esc** cancels. **Ctrl-v** cycles catalog views,
**Ctrl-r** installs/retries the selected pack, and **Ctrl-g** opens Mason.
Type to filter; arrow keys also move.
The preview appears beside the list in wide terminals and below it in narrower
ones. The icon legend stays at the top even when details are out of view.

| Indicator | Meaning |
| --- | --- |
| ✓ | Selected to be enabled |
| ○ | Selected to be disabled |
| * unsaved | Different from the last saved choice; Ctrl-s commits it |
| ↻ restart | Different from the currently running configuration |
| available / external | Required tools are missing / usable outside uzume storage |
| installing / installed / failed | Managed installation state; details show versions and errors |

Icons have different shapes as well as colors. The preview spells out both
**Selected** and **Running now** so a draft toggle is not mistaken for an
immediate change. Cancelling does not undo preferences saved earlier or stop an installation
already requested. Pack loading changes need a restart; installing a missing
tool for an active pack does not.

## How it is built

This is our own small manager inspired by LazyExtras, not LazyExtras itself.
[extras.lua](lua/uzume/editor/extras.lua) owns the catalog, preferences and Snacks picker.
It separates the startup state, saved choices for the next launch, and a draft
copy for the open menu. Enter edits only the draft. Ctrl-s validates all catalog
choices and atomically renames a temporary JSON file into place; Esc drops the
draft. [packages.lua](lua/uzume/editor/packages.lua) and
[languages.lua](lua/uzume/editor/languages.lua) use startup choices to load features.
There is no plugin-manager runtime and no general third-party
Extras marketplace or custom-pack editor yet. Mason supplies the tool installation
backend; our catalog and native LSP configuration remain independent.

## Available packs

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
setup and pinned. Saving a newly enabled pack installs its missing required
tools through Mason; toggling the draft alone does not start a download.
Preferences live in `~/.local/share/uzume/extras.json`, outside the source
checkout, and are written atomically. No editor restart is forced.

## Editing

- **gd**, **gr**, **gI**, **gy**: definition, references, implementation, type definition.
- **K**, **gK**: hover and signature information.
- **Space uh**: toggle native inlay hints for this buffer; enabled by default.
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
`~/.local/share/uzume/tool-paths.json`. It checks the supplied Mason cache before
PATH; this machine's rustup rust-analyzer shim is broken, while its Mason binary
works. HTML/CSS servers are present inside the existing eslint-lsp package even
though Mason exposes only some binaries in its top-level bin directory. These
are read-only references: the installer does not update or write into the supplied
Mason installation. PATH is a runtime fallback if a recorded executable vanishes.
Managed binaries in uzume’s own `mason/bin` now take precedence. Opening a
supported file automatically installs missing required tools, then refreshes
LSP/formatter availability. **Space uI** toggles this behavior persistently.
Executable detection is not a guarantee of server/project health.

Plugin commits and copied parser/query hashes are in `plugins.lock.json`. Syntax
resources are copied into uzume's own package bundle and loaded through native
Neovim Treesitter; the nvim-treesitter plugin is not a runtime dependency. This
snapshot is for this macOS ARM64 machine. CSS/SCSS/LESS use native Vim syntax;
their language-server features and Prettier are configured independently.

External language tools remain user-managed; updating them elsewhere may change
their behavior. New managed tools use Mason with the registry and top-level
versions in `tools.lock.json`. Existing installations are not automatically
upgraded. Portable parser builds, transitive dependency locking and complete
release migrations remain work. See [Tool installation](../docs/features/tool-installation.md)
for the complete workflow, prerequisites, catalog views and retry policy.

Smear mirrors the existing color/target settings, excludes picker/input/menu
buffers, and does not animate terminal input. It is independent of other Snacks
animations. No FPS or terminal-specific performance guarantee has been measured.

See the [feature index](../docs/features/README.md) for the rest of the editor,
and the [prototype record](../docs/prototypes/0004-extras-and-languages.md) for
verification and remaining evaluation.
