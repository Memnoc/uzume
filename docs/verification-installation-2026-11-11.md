# Independent installation verification — 2026-11-11

Scope: replace machine-specific syntax resources and shell registration with
pinned-source builds and a standalone launcher. Base: `12872c2`.

## Results

- The registration regression first failed because the old installer had no
  generic executable-registration interface. It now passes: temporary XDG roots,
  a bin directory containing spaces, real launcher startup, repeat registration,
  unchanged `.zshrc`, and refusal to replace unrelated files or configurations.
- Foreign-platform and incomplete bundles are refused without deleting them.
  A missing compiler produces a prerequisite error before source installation.
- The cache-free test first failed because clean-source installation was not
  supported. It now fetches all 19 pinned plugin commits, the pinned query source
  and eight grammar repositories (nine parsers), with no personal caches.
- All nine locally built parsers load and parse representative source snippets.
  Their highlights, injections, folds, indents and locals queries load, including
  inherited C, ECMAScript, JSX and HTML query sets. Repeat installation reuses
  the completed bundle.
- All 14 existing real-editor regression cases passed against this new bundle.
  The additional installer case passed separately and is included in the suite,
  bringing it to 15 cases. External agent CLIs are fixtures, not live model calls.
- Python compilation, changed Lua formatting and `git diff --check` passed.

Host: macOS ARM64; initial Neovim: `v0.12.0-dev-2155+g1e6c4ea896`.
Bundle: `507f1acdc638`. Logs: `/tmp/uzume-source-install.log`,
`/tmp/uzume-install-regressions.log`. Initial clean-install artifacts:
`/var/folders/w1/59nwl5mx3q95qfv8nm8p1vg00000gn/T/uzume-clean-install-kfn9lccd`.
Temporary logs are evidence on the test host, not distribution assets.

## Reproduce

```sh
python3 tests/install_clean.py
# Use the XDG_DATA_HOME printed by that run:
XDG_DATA_HOME=/path/printed/by/test/data python3 tests/run.py
```

The first command deliberately downloads from upstream. The ordinary suite needs
an installed bundle but does not make model requests or push repositories. Neither
test registers the real shell/config/bin paths. No HOME override is used.

## Limits

A clean XDG environment with caches disabled establishes independence from the
maintainer's Neovim files; it is not a separate physical machine or a pristine OS.
System compiler, Python, Git and Neovim remain prerequisites. No Linux/Intel Mac
execution, distro-managed Neovim, fully pinned host toolchain, or packaged release
update/rollback has been verified in this increment.
