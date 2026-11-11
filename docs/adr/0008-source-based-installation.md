---
status: accepted
date: 2026-11-11
proposed-by: Codex
approved-by: project maintainer (independent-installation request)
---

# ADR-0008: Install from pinned sources without personal caches

## Context

The prototype captured macOS ARM64 parser binaries from the maintainer's machine.
Its shell registration also depended on a specific `nvims` function. A cloned
repository was therefore insufficient to install on a new machine. Plugin pins
alone did not make installation independent.

## Decision

Fetch exact plugin and grammar commits, compile generated grammar C sources with
the host compiler, and install query files from a pinned upstream revision with
SHA-256 verification. Load every parser and query set in the user's Neovim before
publishing a complete bundle. Record the host platform and reject reuse on a
different platform. Keep older completed bundles.

Create an executable `uzume` launcher and isolated config symlink on explicit
`--register`. Do not inspect or edit shell startup files, require `nvims`, or
replace unrelated config/launcher paths. The launcher records installation XDG
roots and forwards editor arguments. Caches are optional read-only accelerators,
never prerequisites. Source installation is for macOS and Linux; verification
status must distinguish tested systems from implementation targets.

**Namespace follow-up:** ADR-0009 supersedes this temporary retention decision.

Keep the `ai-nvim` app/data namespace and current Lua module names for existing
settings, task worktrees and recovery data. The old spike is historical source,
not part of the installed runtime. Namespace migration is separate work.

## Alternatives

- Distribute prebuilt parser artifacts: easier on machines without a compiler,
  but requires a maintained architecture/ABI artifact matrix. Deferred.
- Install parsers dynamically at editor startup: rejected because startup should
  use the tested dependency set without silently updating it.
- Require copied caches or a particular shell function: rejected because this
  prevents independent installation.

## Consequences

First installation requires network access and a C compiler; compiler versions
can produce different binary bytes from identical source pins. Parser/query
validation catches ABI and syntax mismatches before activation. No new runtime
plugin manager or Tree-sitter CLI is required. Runtime query dependencies already
used by the prototype gain explicit source provenance.

This implements independent package installation, not all of ADR-0004. Neovim
is still user-installed; distro-managed executable versions, release distribution,
update/rollback UI and the tested platform matrix remain follow-up work.
