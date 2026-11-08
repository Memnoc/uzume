# Mason-backed Extras workflow

Date: 2026-11-08. Status: installed for evaluation on `spike/editor-baseline`.

## Question and decision

Can the independent Extras menu provide a browsable tool catalog and install
missing language tools when a supported file is opened, without importing
LazyVim or replacing working external tools?

Yes. Use pinned Mason as the installation backend, keep our catalog and native
Neovim language integration, and request explicit tool versions from a pinned
registry snapshot. This avoids maintaining platform-specific package installers.
The user authorized completing the catalog workflow and automatic missing-tool
installation on file open. This remains an incremental Northstar editor spike.

## Implemented behavior

- Space l exposes All, Available, Installed and Enabled views (Ctrl-v), activation
  icons, tool/package versions, external executable paths and install errors.
- Ctrl-r installs/retries a selected pack's required tools into ai-nvim storage.
  Ctrl-g opens Mason for package browsing, optional tools and installation output.
  Border hints remain visible; the details pane includes all controls.
- Enter edits a draft, Ctrl-s saves, Esc discards it. Saving a newly enabled pack
  starts missing required-tool installation. Installation does not enable an
  inactive pack. Pack loading changes still take effect on restart.
- Named local files in enabled supported packs trigger missing-tool installation
  in the background. Successful installation refreshes LSP activation for open
  files and formatter resolution without a restart. Repeated events are deduped.
- Existing managed/external executables satisfy automatic requests; project-local
  Prettier also satisfies formatter availability. Ctrl-r can install a managed
  copy even where an external executable already exists.
- Space uI / ExtrasAutoInstall persists the automatic-install preference. Disabled
  packs, unsupported filetypes, unnamed and special/URI buffers do not trigger
  installs. Failures persist and require an explicit retry rather than looping.
- Mason uses ai-nvim's own data directory, skips PATH modification, limits installs
  to four, and uses its native installation locks. Registry auto-refresh and
  version checks on UI open are disabled. First-run :Mason bootstraps the pinned
  registry through the same path as Ctrl-g.
- Required host runtimes remain external. In particular rustfmt is supplied by
  the Rust toolchain, not this Mason registry; a missing rustfmt produces a clear
  component-install instruction. Optional integrations remain explicit.

## Version and dependency boundary

The plugin bundle is `2cbf0de8a3b5`, adding Mason at
`2a6940af80375532e5e9e7c1f2fc6319a1b7a69d`. `tools.lock.json` records the registry
`2026-11-06-sneaky-satin`, its JSON checksum and exact top-level tool versions,
mostly drawn from the already exercised external installation. Our workflow
checks the registry hash and passes the selected version to Mason's install API.
It does not upgrade an existing binary automatically.

The default LazyVim installation and tool cache are not updated. Its existing
binaries remain usable through earlier read-only references; new installs go
under ai-nvim/mason. The normal nvim and nvims registration are unchanged.

Mason's advanced package commands can select/update versions outside our release
choices. The catalog displays installed versus selected versions. This is not a
complete reproducible release system: transitive npm dependencies, host runtimes,
Neovim itself, portable syntax builds and release migration/rollback remain work.
The custom automatic workflow supports the existing language packs, not every
package visible in Mason.

## Verification

Disposable probes used real Neovim PTYs and isolated ai-nvim data:

- From an empty tool directory and PATH without existing language tools, opening
  Lua downloaded LuaLS 3.19.1 and StyLua v2.5.2. Receipts matched the selected
  versions, lua_ls attached to the existing buffer and formatting changed the
  fixture without restarting. Repeated buffer events did not reinstall.
- The initial probe found a Homebrew LuaLS on PATH, correctly reused it, and
  installed only StyLua. A stricter isolated PATH exercised both downloads.
  A fixture with its tool cache inside the Lua project caused LuaLS's preload
  prompt; separating project and data removed that fixture-specific interference.
- With npm absent, HTML/Prettier installation failed with the missing-executable
  reason visible. Repeated events and a restart did not retry. Restoring npm and
  explicitly retrying downloaded the selected tools, attached the HTML server
  and made Prettier available.
- The automatic-install toggle survived restart. Opening CSS with it disabled
  did not download a server; re-enabling with the web pack explicitly disabled
  still did not download one.
- Ctrl-r on Lua installed managed copies despite existing external tools; the
  open catalog refreshed to installed. Available/Installed/Enabled filters worked.
  Ctrl-g opened Mason, and shortcut footers fit at 150×45 and 80×24.
- Idle startup did not fetch a registry. Existing HTML tooling plus project-local
  Prettier did not trigger a download. First-run :Mason fetched the pinned registry
  and displayed its package catalog.
- Neovim 0.11.6 passed startup with Mason and the automatic-install controls.
  The full interactive installation probes used the installed 0.12 development build.
- Lua formatting, JSON parsing, documentation links and whitespace checks passed.
- Existing Extras save/discard/restart, optional-pack loading, temporary Smear
  toggle and HTML tag-closing probes passed with Mason present.

Remaining checks include Linux, all supported installers, offline registry
bootstrap, simultaneous editor processes, interruption/recovery during downloads,
full tool health checks and transitive reproducibility. Existing executable
presence is not proof that a language server is healthy or can attach to a given
project. This workflow does not reinstall merely because no client is attached.

## Write-up and next evaluation

`docs/features/tool-installation.md` on the editor branch explains the full user
workflow, implementation, persistence, pinning, prerequisite and network behavior.
The feature index and existing guides are updated. Main retains this finding;
runtime code and disposable probes remain outside main.

Restart ai-nvim and open a real project. Use Space l to inspect whether tools are
external or managed, browse the catalog with Ctrl-v, and use Ctrl-r if a managed
copy is wanted. Evaluate the progress notifications and transition from editing
without a tool to editing with an attached server.

Primary reference: [Mason documentation](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/doc/mason.txt).
