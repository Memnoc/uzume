# Namespace migration and Linux verification — 2026-11-11

## Scope

Baseline: `8a86dc0`. Implementation branch: `feat/uzume-namespace-linux`.
Commits `e2a300f`, `577ae09`, `7a9b9aa` implement the namespace migration,
retained-path fixes, Linux CI and minimum-Neovim review compatibility. Later
documentation and formatting changes do not alter those behaviors.

Core modules moved from the old namespace into `uzume/editor`; the app name,
package directory and active internal names now use `uzume`. Code was retained.
Historical prototype evidence still contains the names used when it was recorded.
The explicit installer migration moves app directories and leaves compatibility
links, with preflight, locking, a private journal and retry recovery. It does not
rewrite user source, Git indexes, task baselines, comments or integration records.

## Failures found and resolved

- Canonical equality correctly rejects missing paths, but branch preflight also
  needs to consider two absent checkouts equal. An existing no-checkout branch
  regression caught this; literal equality is now checked before canonical paths.
- A retained old-name cwd and canonical file path referred to the same checkout
  but marked its own file as an external reference. The real branch continuation
  test now moves a checkout and retains an alias, asserting working-file roles,
  original baseline and no duplicate marks. Context uses canonical containment.
- Migration's running-editor guard now checks all four XDG roots canonically,
  including a shared state root reached through a symlink. A real headless editor
  fixture verifies refusal before any move.
- Linux's Neovim 0.11 job exposed `E976: Using a Blob as a String` when opening
  review. A minimal SHA-256 probe and the actual comments workflow reproduced it
  on macOS 0.11 too: it was a version boundary, not a Linux-only UI issue. The
  cached Python fallback preserves the old binary digest. A persisted filename
  assertion verifies compatibility with Python's independent SHA-256 result.
- The first CI run used `tee` without pipeline failure propagation. Its green
  badge hid failing cases (15/16 on 0.12.6, 12/16 on 0.11.0). Those results are
  **not** accepted as passing evidence. Explicit Bash now propagates test errors;
  both job status and printed suite totals must be checked.

## Independent crosscheck

Northstar crosscheck reviewed the change against repository invariants and the
user's naming/Linux request. It found the no-checkout and context-role regressions
above; both were reproduced and fixed. Follow-up review found no concrete blocker
in the migration fixes, review-key fallback or CI failure handling. No production
spec is implied; verification and platform limits remain explicit.

## Results

macOS ARM64: clean installation passed with empty XDG roots, all 19 pinned
plugins and nine parser/query sets. The full suite passed **16/16** on
`v0.12.0-dev-2155+g1e6c4ea896`. The focused comments workflow also passed on the
official 0.11.0 binary after first reproducing `E976` there.

Local evidence: `/tmp/uzume-namespace-install.log`,
`/tmp/uzume-namespace-final-macos.log`,
`/tmp/uzume-minimum-comments-red.log` and
`/tmp/uzume-minimum-comments-green.log`.

Ubuntu 24.04 x86_64: both Neovim **0.11.0** and **0.12.6** passed cache-free
installation, all nine parser/query checks, repeat installation and **16/16**
regression cases. Both jobs succeeded in
[Actions run 43104447725](https://github.com/Memnoc/uzume/actions/runs/43104447725)
at `7a9b9aa`. The downloaded log `/tmp/uzume-linux-final.log` independently
confirms both totals; no failing cases or tracebacks remain.

Python compilation (31 modules/entry points), changed review-module formatting
with the repository's two-space style, and `git diff --check` passed. The final
review-key formatting change only wraps the existing method chain.

## Reproduction

```sh
python3 tests/install_clean.py
# Use the temporary XDG_DATA_HOME printed by that command:
XDG_DATA_HOME=/path/from/test python3 tests/run.py
```

Focused regressions: `tests/migration.py`, `tests/branch_launch.py`,
`tests/review_comments.py`. `UZUME_TEST_NVIM=/path/to/nvim` selects another editor
for PTY cases. The actual public installer finds `nvim` on PATH; CI installs the
selected release there. Tests preserve default editor/shell paths and use mock
Codex/Claude executables, with no live model requests.

## Limits and local rollout

Passing fixtures do not establish live vendor CLI compatibility, terminal
smoothness, every Linux distribution, Linux ARM64 or Intel macOS. See
[Linux](features/linux.md) and [the handoff](HANDOFF.md).

The implementation is published on `feat/uzume-namespace-linux`; the normal
`/Code/uzume` checkout remains on `main` at `8a86dc0` pending local rollout. At the
last check, the user's two Neovim processes still used the old namespace. Their
editor must be closed before changing its active checkout and real storage.
No test authorizes closing their editor or pruning retained tasks.
Old-name compatibility links and the common historical Git checkout are deliberate
retentions, not leftover competing implementations.
