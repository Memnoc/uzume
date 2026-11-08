# Extras and language packs

Date: 2026-11-07. Status: installed for user evaluation on `spike/editor-baseline`.

## Requested increment

The maintainer reported the editor preview was working, requested
optional features, and selected Rust, Lua, C, TypeScript/React/HTML/CSS, plus
Smear Cursor. The requested menu shortcut is **Space l**.

## Behavior

A Snacks floating catalog is available through Space l and `:Extras`. Enter
toggles a draft choice, Ctrl-s saves, and closing discards unsaved choices.
Saved choices take effect on restart; active versus desired state is visible.
Required and optional executable availability appears in the item preview.
Preferences are written atomically to ai-nvim's data directory, outside the
source checkout. The menu never downloads tools or forces a restart.

The five requested packs default to enabled. Disabling every language pack
avoids loading completion, formatting, LSP configurations, and the syntax package.
Smear is separately optional and has a temporary Space ua toggle. Picker/input
buffers and terminal input are excluded from its animation.

Language integration uses Neovim's native `vim.lsp.config`/`enable`, pinned
nvim-lspconfig definitions, nvim-cmp with native snippets, Conform, lazydev for
Neovim Lua, and HTML/JSX tag closing. Tools include rust-analyzer/rustfmt, LuaLS/
StyLua, clangd (including formatting), vtsls, HTML/CSS/JSON servers, Prettier,
and optional configured-project ESLint/Tailwind plus Emmet. LSP navigation,
hover, symbol rename, code actions, symbols, diagnostics and formatting use the
familiar editor shortcuts. Formatting runs on explicit saves and is toggleable;
source saves remain explicit. Root detection now considers attached LSP roots.

## Dependency boundary

Plugin commits remain pinned; optional dependencies are installed in the bundle
and selectively loaded. The current bundle is `964fa77256e4`. Native parser/query
resources are copied into ai-nvim storage with hashes, including Rust/Lua/C/C++/
JavaScript/TypeScript/TSX/HTML/JSON and inherited queries. Native TSX/JSX aliases
are registered explicitly. CSS retains native Vim syntax, independently of its
language-server and formatter support.

The captured syntax binaries are macOS ARM64 artifacts from this machine's
existing installation. Portable source builds/grammar-version distribution are
not implemented. This must be replaced before a portable distro release.

The installer discovers existing tool executables and records read-only paths
in ai-nvim's data directory. All 13 advertised executables were found. This
machine's rustup rust-analyzer shim cannot run, so the working Mason binary is
chosen. HTML/CSS executables already exist inside the eslint-lsp package. No
tools were downloaded and no default configuration or Mason files were modified.

These executables remain user-managed, not pinned by ai-nvim. Plugin/syntax pins
do not guarantee that external tool behavior cannot change. Tool distribution,
health beyond executable detection, and full controlled upgrades remain work
before production. React/application dependencies remain the project's own.

## Verification

Disposable development probes, not a permanent test suite:

- Real local servers attached to isolated Rust, Lua, C, TSX, HTML and CSS files.
- Rust/Lua/TypeScript produced the intended type diagnostics. A C definition
  request resolved to the function declaration. Native Treesitter highlighting
  was active for tested captured languages, including TSX.
- Explicit formatting was exercised for every language; clangd supplied C
  formatting, and Prettier handled the web files. Lua formatting was invoked on
  an already formatted file. TypeScript completion returned string methods.
- The TSX fixture used a small ambient JSX declaration, without installing a
  React application. Real React dependency/version combinations remain user
  evaluation, not proven by that fixture.
- In a real PTY, Space l opened the searchable menu; toggling, applying,
  discarding, and reopening worked. Restart applied saved choices. With every
  pack disabled, optional modules remained unloaded, no LSP clients started,
  and the base Rose Pine editor remained intact.
- Smear's temporary toggle and HTML tag auto-closing worked through UI input.
- Neovim 0.11.6 also passed startup and TSX highlighter activation with normal
  filesystem-watcher access; the full interaction/server probe used the installed
  Neovim 0.12 development build.
- Installed startup confirms Space l, all five enabled packs, and active Smear.
  Default editor config hashes and `.zshrc` were unchanged by installation.
- Lua formatting, installer syntax, and whitespace checks passed.

Not yet verified: real React application workflows, TSX paired-tag renaming,
ESLint/Tailwind project fixtures, full range-formatting/snippet navigation,
debug/test integration, Linux, or measured animation performance. Current
executable discovery is not a comprehensive tool-health check.

## Next evaluation

Restart ai-nvim through `nvims`. Use Space l to inspect the packs, then read and
edit a real Rust or web project. Evaluate code navigation, completion, diagnostics,
formatting and cursor feel before adding further features. The separate agent
pilot remains available; this increment does not integrate agent sessions.

Main retains this record. Implementation and `editor/EXTRAS.md` stay on the
editor spike branch.

## Follow-up: discoverable controls and feature write-ups

The maintainer requested ongoing write-ups explaining each feature and its implementation,
and controls visible directly in the Extras menu. The editor branch now keeps a
feature index at `docs/features/README.md`, covering editor/navigation, languages,
cursor animation, installation/isolation/pins, and the separate agent pilot.
`editor/EXTRAS.md` explains the custom manager, its state model and shortcuts.
Future feature changes must update these guides with behavior, usage,
implementation, dependencies/state, verification and remaining limits.

The menu now has a persistent icon legend (✓ enabled, ○ disabled) and a border
footer listing Ctrl-n/p movement, Enter toggle, Ctrl-s save and Esc cancel.
Unsaved choices and changes awaiting restart have separate markers. The preview
spells out selected versus running state. One Escape closes from input or list,
discarding the current draft. Previously saved choices remain saved. The details
sit beside the list in wide terminals and below it when opened below 120 columns.

Disposable real-PTY probes passed at 150×45 and 80×24: rendered icon rows,
legend/footer text fitting the frame, draft/restart markers, preview state and
single-Escape cancellation without writing preferences. The existing interaction
probe also passed filtering, save, discard, restart activation, all-disabled
loading, temporary Smear toggle and HTML tag closing. Formatting, whitespace and
local guide links were checked. These probes used isolated ai-nvim data; the
user's pack preferences were not changed. This does not establish behavior at
all terminal sizes or animation performance.
