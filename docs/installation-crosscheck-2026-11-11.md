# Installation crosscheck — 2026-11-11

Base: `12872c2`. Review command: `git diff 12872c2...74b0267`.
Independent read-only Northstar crosscheck against `AGENTS.md`,
`docs/HANDOFF.md` and the standard smell baseline.

## Standards

No additional blocking findings beyond the tool-reference preservation issue
identified during implementation. Registration preserves unrelated configurations
and launchers, uses shell quoting and atomically replaces generated executables.
Source downloads use full commit IDs; query hashes are checked; parser/query
validation precedes activation. Incomplete and foreign-platform bundles are
refused without deletion. Public CLI cases exercise real processes and temporary
registration paths rather than modifying the real shell or config.

No actionable design-smell finding. Source export, syntax build and registration
have distinct responsibilities. Compatibility identifiers and historical spikes
are explicitly documented.

Follow-up requested: verify the advertised Neovim 0.11 floor or narrow the claim.
Resolved after review: the full clean-install/startup/syntax test passed with the
official 0.11.0 archive. The 0.12.6 stable archive passed too. The tool-reference
issue was reproduced with a failing CLI test, fixed, and verified on development
and stable Neovim. See the installation verification record for exact scope.

## Spec

No formal production spec is available; this axis was skipped. ADR-0008 records
the independent-installation decision and the remaining ADR-0004 release work.

Findings: Standards — 1 tool-preservation issue fixed, 1 compatibility evidence
gap addressed; Spec — not assessed (no formal spec).
