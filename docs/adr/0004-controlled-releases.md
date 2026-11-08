---
status: accepted
date: 2026-11-06
proposed-by: Codex
approved-by: project maintainer
---

# ADR-0004: Manage Neovim and ship user-controlled tested releases

## Context

A plugin lockfile does not fix the editor executable or other runtime components. The existing configuration and active installation also demonstrate how resolved versions can diverge over time.

## Decision

Install and launch a distro-managed pinned Neovim version alongside existing installations, and define tested releases covering the distro and selected dependencies. Users explicitly choose upgrades and can roll back to a previous working release.

## Considered options

- **Distro-managed executable and tested dependency set** — chosen to make releases reproducible and recovery deliberate.
- **Use any system Neovim with plugin pins** — rejected as the primary path because core API compatibility remains uncontrolled.
- **Continuously update dependencies independently** — rejected as the default because it expands untested combinations.

## Consequences

Release packaging and rollback require platform-specific validation on macOS and Linux. Exact versions, language-tool management, and compatibility checks for user-installed agent CLIs remain open; this decision does not promise immunity to every external change.
