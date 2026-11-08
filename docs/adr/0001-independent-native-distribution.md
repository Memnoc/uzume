---
status: accepted
date: 2026-11-06
proposed-by: project maintainers
approved-by: project maintainer
---

# ADR-0001: Build an independent distribution with multiplexing inside Neovim

## Context

Uzume needs stable editing defaults, flexible panes, and concurrent agent sessions with a minimal, understandable implementation. Depending on another distribution would couple these workflows to its changing defaults and release schedule.

## Decision

Build an independent distribution using native Neovim windows and terminals for our own session and pane management. Preserve familiar editor capabilities and bindings with native APIs or selected pinned plugins; users get an integrated workspace whose defaults and upgrades are owned by the distribution.

## Considered options

- **Independent configuration and native Neovim multiplexing** — chosen for ownership and native integration without initially building a terminal renderer.
- **Extend an existing distribution** — rejected as the foundation because it retains dependency on another distribution's evolving defaults.
- **Require an external multiplexer** — deferred as an optional integration because the baseline should own multiplexing behavior.
- **Build a surrounding terminal application** — deferred because it introduces rendering and process-management scope before native feasibility has been tested.

## Consequences

The distro must maintain its compatibility inventory, session behavior, and key routing. Pane movement, rendering limits, and process cleanup require a small feasibility prototype. Rust remains available for justified components; no Rust subsystem is selected by this decision.
