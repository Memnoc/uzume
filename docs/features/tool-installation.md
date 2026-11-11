# Tool catalog and automatic installation

The editor now uses **Mason** to install language servers and formatters into
uzume's own data directory. Our Extras catalog owns pack choices, versions,
filetype triggers and retry policy. Native Neovim still configures and starts
language servers; Mason is the installer. Language integrations are configured
directly, without mason-lspconfig or a separate automatic-tool-installer plugin.

## Everyday workflow

Open a named local file in an enabled, supported language pack. Missing required
tools install in the background, with progress notifications and status in
**Space l**. The newly installed server attaches to open matching files and
formatting becomes available without restarting. Files remain editable during
downloads. Repeated file events share an outstanding install rather than starting
another one.

| Filetype | Automatically requested tools when missing |
| --- | --- |
| Rust | rust-analyzer; checks rustfmt from the Rust toolchain |
| Lua | Lua language server, StyLua |
| C / C++ | clangd, including its formatter |
| JavaScript / TypeScript / JSX / TSX | vtsls, Prettier |
| HTML | HTML language server, Prettier |
| CSS / SCSS / LESS | CSS language server, Prettier |
| JSON / JSONC | JSON language server, Prettier |

An existing usable executable satisfies automatic installation. Managed uzume
binaries take priority, followed by previously discovered external paths and
PATH. Prettier uses the project's local executable first; that also prevents an
unnecessary automatic global download. Existing binaries are not automatically
upgraded or replaced. Availability means executable presence, not a full health
check: an installed but broken server or a project configuration issue is not
fixed by repeatedly reinstalling it.

Automatic installation starts enabled. **Space uI** or `:ExtrasAutoInstall`
toggles it persistently. A disabled pack is respected, including a saved disable
that is awaiting restart. Unnamed buffers, terminal/help/picker buffers, URI
buffers and unsupported filetypes do not trigger downloads. This first catalog
covers the existing packs; installing an arbitrary Mason package does not create
a new language integration.

## Catalog controls

**Space cm** opens Mason directly. For bundled packs, open **Space l**, then:

| Key | Action |
| --- | --- |
| Type / Ctrl-n,p or arrows | Filter / move |
| Ctrl-v | Cycle All → Available → Installed → Enabled |
| Enter | Toggle a draft pack choice |
| Ctrl-s | Save choices; newly enabled packs start installing missing required tools |
| Ctrl-r | Install/retry the selected pack's required tools in uzume storage, even if external copies exist |
| Ctrl-g | Open Mason's package browser, installation output and optional tools |
| Esc | Close and discard unsaved pack choices |

**Available** includes packs whose required tools are not all managed by uzume.
**Installed** means their Mason-managed required tools are present (with rustfmt
allowed from the Rust toolchain); Smear needs no external tools. **Enabled**
shows the current draft selection. Optional integrations do not determine pack
readiness. The detail pane lists each tool's state, pinned version, installed
version when managed, executable path and any installation error, plus the
pack's included plugins and their pins.

Rows distinguish `available`, `external`, `installing`, `installed` and `failed`.
The ✓/○ icon describes activation; installation is a separate state. Installing
an inactive pack does not enable it. Pack loading changes still require restart;
new tools for an already active pack do not. Escape cancels the draft, not an
installation already requested. Mason provides cancellation for an active install.

## Failure and prerequisites

Failures remain visible and are recorded locally. Automatic events and editor
restarts do not repeatedly retry them. Fix the prerequisite or network problem,
then use **Ctrl-r** on the pack to retry, or inspect output through **Ctrl-g** /
`:MasonLog`. A successful manual Mason installation also refreshes language
availability. Mason limits concurrent installers to four and provides package
installation locks; multi-editor contention has not yet been stress-tested.

Mason still needs the appropriate host tools: Node/npm for the web packages,
and platform archive/download utilities. It does not install Node, compilers,
project dependencies, or complete language toolchains for us. `rustfmt` is not
in this pinned Mason registry: if absent, Extras explains
`rustup component add rustfmt`, leaving toolchain selection to the user/project.
Optional ESLint, Tailwind and Emmet can be installed through Mason, and retain
the existing project-detection rules.

## Implementation and version boundary

- [installer.lua](../../editor/lua/uzume/editor/installer.lua) maps filetypes to required
  tools, configures Mason, tracks pending/failure state, schedules installation
  and exposes catalog status. It validates the pinned registry JSON hash before
  managed installation and uses Mason's asynchronous install API with an exact
  package version.
- [tools.lua](../../editor/lua/uzume/editor/tools.lua) resolves managed, external and
  project-local executables. [languages.lua](../../editor/lua/uzume/editor/languages.lua)
  refreshes LSP configuration after installation and resolves formatter paths
  when formatting is requested.
- [extras.lua](../../editor/lua/uzume/editor/extras.lua) renders pack/tool details and
  refreshes the open picker as installation status changes. Its draft choices
  remain independent from installation state.
- [plugins.lock.json](../../editor/plugins.lock.json) pins Mason itself;
  [tools.lock.json](../../editor/tools.lock.json) pins the registry snapshot,
  its JSON checksum and the selected top-level tool versions. No periodic registry
  refresh, automatic upgrade, or version check on opening Mason is enabled.

Files under `~/.local/share/uzume/` (or the equivalent XDG directory):

| Location | Contents |
| --- | --- |
| `mason/` | Registry, packages, executable links and Mason receipts |
| `tool-settings.json` | Persistent automatic-install setting |
| `tool-failures.json` | Failed requests awaiting explicit retry |
| `tool-paths.json` | Earlier read-only external executable references |
| `extras.json` | Enabled-pack choices |

Mason's advanced commands can install other versions or update packages manually;
that bypasses our selected tool-version policy. The catalog shows both installed
and release versions. Changing a release pin does not silently upgrade an
existing binary. Full release migration/rollback and transitive dependency
locking remain future work; npm dependency ranges and host runtimes are not made
immutable merely by pinning the top-level package.

Downloads contact package registries/upstream release hosts. Our installer does
not send source buffers, project contents or credentials. Downloaded tools and
package installation scripts have their own behavior; this is ordinary local
package installation, not a sandbox for those programs. An existing external Mason
installation is only read when resolving previously discovered external tools.
New managed installs use uzume's directory.

## Verification

See the [Mason workflow record](../prototypes/0005-mason-workflow.md) for real
fresh-install, attachment, formatting, retry and menu probes. The implementation
is still an editor spike, not a portable production release; Linux, all package
installers, multiple simultaneous editor instances and every terminal size have
not been verified.

Primary references: [Mason's documentation](https://github.com/mason-org/mason.nvim/blob/main/doc/mason.txt)
and [package API](https://github.com/mason-org/mason.nvim/blob/2a6940af80375532e5e9e7c1f2fc6319a1b7a69d/lua/mason-core/package/init.lua).
