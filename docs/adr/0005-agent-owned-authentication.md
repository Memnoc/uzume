---
status: accepted
date: 2026-11-06
proposed-by: project maintainers
approved-by: project maintainer
---

# ADR-0005: Keep authentication in official agent CLIs and autosave locally

## Context

Users may authenticate through browser-based organizational SSO, including Okta. Workspace recovery should not create a second credential store or silently transmit code and drafts.

## Decision

Use existing official Codex and Claude Code installations and their authentication flows; ai-nvim neither collects credentials nor implements login. Autosave session and review state locally, exclude credentials and agent transcripts from session snapshots, and require explicit user handoff for context and feedback delivery. Users retain familiar account access without granting autosave permission to upload their work.

## Considered options

- **CLI-owned authentication and local persistence** — chosen to preserve established login and organizational controls.
- **Distro-managed API keys or authentication** — rejected because it adds credential handling and duplicates official tools.
- **Automatic draft or context upload through autosave** — rejected because persistence is not consent to transmit data.

## Consequences

Local snapshots and review comments may contain source code and need defined storage and retention behavior. Agents retain their own permissions and data handling after explicit launch; this is an application behavior boundary, not network sandboxing. Browser login may still involve credential storage by the CLI.
