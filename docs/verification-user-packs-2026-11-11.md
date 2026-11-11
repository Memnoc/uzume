# User language packs, command line and Linux restore verification

Date: 2026-11-11. Implementation commits: `e023e81` (restore fix) and `bf9832c`
(user packs and command line). Subsequent changes to this record and navigation
links are documentation only.

## Scope

- Extras supports local JSON language packs outside the installed configuration.
- Guided creation uses pinned LSP/formatter definitions and a verified Mason
  registry; enable/save installs missing declared tools, restart activates wiring.
- Required-tool installation, retry and file triggers reuse the existing installer.
- Noice/Nui render the floating command line and completion; notifications remain
  with Snacks. New bundle identity: `de1d6a26c1a6`.
- Restore suppresses routine file-position messages while retaining errors.

## Red/green evidence

The real language-pack startup test initially failed with “User pack was not
loaded.” It now detects a custom filetype, attaches a fixture LSP through native
Neovim, formats through Conform and works with all curated packs disabled.
Malformed JSON, wrong server configuration types, filetype ownership conflicts
and incompatible package pins are isolated. Disabled packs stay inactive after
restart. Only external executables are fixtures; application modules are real.

The real command-line test initially failed because no floating command box
appeared. It now checks native execution, Backspace editing, cancellation, history,
completion and 50/80/150-column surfaces. Completion uses an unambiguous test command
because the installed editor legitimately contains multiple `edi` matches.

The Add Language test drives Space l/Ctrl-a, picks Go/gopls, skips a formatter,
creates a disabled pack, checks version/prerequisite capture, enables/saves it,
opens its external definition with Ctrl-e and checks overwrite refusal. It also
checks wrapped details at 80 and 150 columns. A local registry fixture replaces
only the external registry, avoiding downloads and real model requests.

GitHub runs `43114332438`, `43115001299` and `43116599904` failed on the 0.11
restore path. Captured terminal output ended at “Press ENTER or type command to
continue,” with no underlying file error. Locally:

```sh
UZUME_TEST_NVIM=/tmp/uzume-neovim-minimum/nvim-macos-arm64/bin/nvim python3 tests/agents.py --crash
```

reproduced the RPC timeout inside `sessions.restore()`. Changing only the source
command to `silent source` made the same original regression pass. `silent!` was
not used: genuine errors still propagate. The failure was version-dependent, not
specific to Linux hardware, and was not repaired by extending test timeouts.

## Completed local checks

- Full real-editor/Git/agent/migration/install suite: **21/21 passed**, macOS ARM64,
  installed Neovim `v0.12.0-dev-2155+g1e6c4ea896`.
- New command-line, language-pack and guided-creation cases: passed on Neovim
  **0.11.0**, including a user-only language configuration.
- Focused tests rerun after final validation/width refinements: passed.
- StyLua checks, Python syntax checks and `git diff --check`: passed.
- Updated pinned bundle installed locally without launcher/config registration;
  all 13 existing tool references remain usable, default Neovim unchanged.

## Linux CI

The feature-branch matrix is recorded at
[GitHub Actions run 43120214243](https://github.com/Memnoc/uzume/actions/runs/43120214243).
**Both Ubuntu 24.04 x86_64 jobs passed:** Neovim 0.11.0 and 0.12.6, each with
a cache-free source installation, syntax validation and all **21/21 regression
cases**. This verifies the previously failing restore workflow on Linux.

## Limits / next owner

These tests establish wiring and workflow behavior, not correctness of every
possible third-party language server or user pack. Project setup, server-specific
callbacks, parser installation and external runtimes remain documented boundaries.
The guided path excludes dynamic command definitions; manually maintained packs
can supply explicit commands/settings. User-selected tool versions do not lock
all transitive dependencies or force upgrades of existing usable executables.

Real terminal visual preference still needs the user's trial. No new feature
expansion is planned for the next iteration; focus on polishing and reported bugs.
See ADR-0010 and the user-pack guide before extending the schema or installer.
