# User language packs

Uzume's curated packs remain small. A language outside that catalog can be added
without editing the distribution or importing another distribution's runtime.
User packs appear alongside built-ins in **Space l**, labeled **User language**.
They start disabled and remain separate from Uzume updates.

## Guided installation

1. Open **Space l**, then **Ctrl-a** (or choose **Add a language…**).
2. Enter the Neovim filetype, such as `python`, `go`, `yaml`, or `typst`.
3. Select a language server. The list uses compatible definitions from Uzume's
   pinned nvim-lspconfig; **No language server** allows a formatting-only pack.
4. Select a formatter by name or language, or choose **No formatter** to retain
   any formatting supplied by the server. Formatter choices come from pinned
   Conform definitions; check that the selected tool supports your language.
5. Choose **Create disabled pack**. Back in Extras, inspect its prerequisites
   and tool versions. Find the new pack, press **Enter**, then **Ctrl-s**.
6. Install any listed runtime/toolchain requirements, wait for tool installation,
   then restart Uzume and open a real project file. **Ctrl-r** retries failed
   tools; **Ctrl-g** opens Mason logs. **Space cf** formats the current file.

The wizard consults the same checksum-verified Mason registry used by normal
installation. It records versions from that registry, reusing an existing Uzume
pin for shared packages. It never refreshes to an unpinned registry. A missing
registry needs network access; an unavailable registry produces a retry message
without creating a partial pack. Creating or cancelling the wizard installs no
tools. Enabling and saving requests missing tools; Escape cannot cancel a download
that has already started. Existing usable external executables remain usable.

The menu's **Ctrl-v** cycles All, Languages, Features, User, Available, Installed,
and Enabled. **Ctrl-e** opens a selected user's definition. Built-in pack files
are not exposed as editable customizations. Esc discards unsaved toggle choices;
leaving for Add/Edit/Mason also closes that draft, so save wanted toggles first.

## Location and definition

Definitions live in `${XDG_CONFIG_HOME:-~/.config}/uzume-user/languages/*.json`.
This is a sibling of the installed `uzume` configuration, which may itself be a
symlink into the Git checkout. Back up this folder with your other dotfiles.
Enable/disable choices still live in Uzume's data `extras.json`; they use
`user:<filename-without-extension>` IDs. Restart after editing a definition.

Example `python.json`, using externally installed tools:

```json
{
  "version": 1,
  "name": "Python",
  "description": "Python navigation and Black formatting",
  "filetypes": ["python"],
  "servers": [
    {
      "name": "pyright",
      "command": "pyright-langserver",
      "args": ["--stdio"],
      "config": {
        "settings": {
          "python": { "analysis": { "typeCheckingMode": "basic" } }
        }
      }
    }
  ],
  "formatters": [{ "name": "black", "command": "black" }],
  "prerequisites": ["Python project environment", "Node.js for Pyright"]
}
```

To manage a tool with Mason, its entry must also contain `package` and an exact
`version`. The wizard fills these in from the pinned registry. Without them,
install the declared command on PATH yourself; absolute executable paths are
also supported for external tools. Arguments are arrays, not shell expressions.

Supported fields:

| Field | Meaning |
| --- | --- |
| `version` | Definition schema; currently `1` |
| `name`, optional `description` | Display text |
| `filetypes` | Nonempty array of Neovim filetypes |
| `extensions` | Optional suffixes without dots; detected as the first filetype |
| `servers` | Array of `{name, command, args?, package?, version?, config?}` |
| Server `config` | Optional `settings`, `init_options`, `root_markers` (string array), `workspace_required` |
| `formatters` | Ordered array of `{name, command, args?, stdin?, package?, version?}` |
| `syntax` | Optional name of an already installed native Treesitter parser |
| `prerequisites` | Human-readable runtime/project requirements; never executed |

Servers inherit the named nvim-lspconfig definition when one exists; their
runtime registrations are scoped to the pack. For a new server name, supply its
command, arguments and root markers yourself. Formatters inherit a named Conform
definition when available. A custom formatter can supply command/args/stdin;
Conform placeholders such as `$FILENAME` remain available. The formatter chain
runs in listed order. All declared tools apply to every filetype in the pack.

Unknown fields, malformed definitions, duplicate filetype ownership and conflicting
package/executable pins are rejected. Valid packs still load. **Space l** displays
**Repair …** entries; Enter opens the offending file. Fix it and restart. Exclusive
creation refuses to overwrite an existing file. Disabling a pack does not delete
its tools or definition; after disabling/restarting you may remove its JSON file.

## Boundaries and verification

Built-in packs are curated; a user pack is not automatically certified for every
project or platform. An executable being installed does not prove successful
attachment. Check `:checkhealth vim.lsp`, diagnostics and navigation in a real
project; **Space cm** shows tool installation status.

The wizard supports static executable definitions; servers or formatters requiring
special Lua callbacks, additional plugins or complex project setup may need a
maintained integration. JSON packs do not run arbitrary setup hooks or install
plugins. They do not install runtimes, compilers, project libraries or new parsers.
Default Neovim syntax remains available; optional `syntax` requires a parser and
queries already on runtimepath. Built-in parser changes still go through pinned
source builds. Automatic downloading/compiling of arbitrary user parsers is deferred.

Top-level Mason versions are recorded; existing usable installations are not
silently upgraded and transitive dependencies are not fully locked. Use a fresh
project trial when promoting a user pack into the built-in catalog.

Implementation: `uzume/extras/packs.lua` validates/loads local JSON,
`uzume/extras/create.lua` guides creation, `editor/extras.lua` owns choices/UI,
`editor/languages.lua` registers LSP/formatting, and `editor/installer.lua` reuses
Mason installation/retry/file-trigger behavior. Shared package loading works even
when only a user pack is enabled.

`tests/language_packs.py` runs real native LSP and Conform with external fixture
executables, verifies custom filetype detection, malformed/conflicting definitions,
and disabled restart. `tests/extras_ui.py` drives the actual wizard against a local
external registry fixture, verifies captured pins/prerequisites, creation disabled,
enable/save, edit location and overwrite refusal. These tests make no tool downloads.
