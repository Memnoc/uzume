---
status: accepted
date: 2026-11-11
proposed-by: Codex
approved-by: project maintainer (user-defined packs and final feature scope)
---

# ADR-0010: Extend Extras with declarative user language packs

## Context

Uzume's small catalog cannot cover every language. Requiring core edits for each
new language conflicts with independent installation and updates. LazyExtras
provides broad coverage but depends on LazyVim and lazy.nvim internals, whereas
Uzume loads pinned native packages and owns its language/tool configuration.

## Decision

Keep the curated catalog and support declarative JSON packs outside the installed
configuration, in the sibling `uzume-user/languages` directory. A guided creation
flow reuses pinned nvim-lspconfig and Conform definitions and the checksum-verified
Mason registry. New packs start disabled; explicit enable/save requests required
tools, and restart activates changed language wiring.

Use Mason for installation, native Neovim LSP for attachment, Conform for formatting,
and existing syntax resources. Record user-selected top-level tool versions.
Reject conflicting ownership and pins; surface individual invalid packs for repair
without preventing editor startup. Do not implement a plugin marketplace or run
setup code from project-owned pack files.

## Alternatives

- Adopt LazyVim/LazyExtras: broader maintained coverage, but imports distribution
  assumptions into Uzume's loading/configuration/release lifecycle.
- Copy the whole Extras catalog: creates substantial ongoing synchronization and
  compatibility work without evidence users need every integration.
- Expose only Mason: installs tools but leaves attachment/formatting undiscoverable.
- Arbitrary local Lua hooks: more flexible, but harder to validate and explain in
  the first extension interface. Deferred for demonstrated integration needs.

## Consequences

User customizations survive checkout updates. A narrow schema is understandable
and testable, but cannot express every language-specific callback/plugin. Standard
Neovim syntax is the fallback; new parser builds remain a pinned installation
change. Users own toolchains and project dependencies. Existing external/managed
tools are retained; pins are install requests, not a claim of full hermeticity.
User packs require real-project verification before promotion to curated support.

The separate floating command-line request uses pinned Noice/Nui, scoped to command
input/completion. Snacks retains notifications and native LSP retains hover/signature
handling. This reuses mature UI plumbing instead of a bespoke command-line renderer.
