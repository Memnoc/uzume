---
status: accepted
date: 2026-11-11
proposed-by: Codex
approved-by: project maintainer (explicit namespace-renaming request)
---

# ADR-0009: Use the Uzume namespace and retain legacy path aliases

## Context

The product name changed before its Lua and app/storage namespaces. Keeping those
old names initially avoided breaking saved state, but left active core code and
new installs inconsistent. The maintainer explicitly requested consistent naming
without removing or replacing core code. Existing absolute paths cannot simply
be rewritten: worktree metadata, user comment excerpts and recovery records have
different ownership and integrity requirements.

## Decision

Move core Lua modules under `uzume/editor`, rename internal namespaces and use
`NVIM_APPNAME=uzume` for new runtime paths. Give the new package layout a distinct
lockfile identity; retain existing immutable releases.

Offer explicit migration for config, data, state and cache. Move real directories
to their canonical names and retain relative compatibility links at legacy names.
Preflight all destinations and refuse conflicting data or live app instances.
Journal moves outside the app directory and lock migration so a partial move/link
sequence is recoverable. Compare retained filesystem identities canonically.

New installations create only canonical names. Shell files remain outside generic
installer ownership; an existing custom launcher/picker can be updated narrowly
when the user authorizes it. Do not relocate unrelated historical Git worktrees.

## Consequences

Core code remains intact under clearer names. User files, staging, comments,
baselines, settings and tool installations remain reachable. Existing users may
still see old-name compatibility links and old immutable package layouts; those
are intentional, not active competing namespaces. Removing the aliases requires
separate evidence that retained references no longer use them.

This supersedes the temporary namespace-retention portion of ADR-0008. It does
not change the native editor/process boundaries or authorize automatic cleanup.
