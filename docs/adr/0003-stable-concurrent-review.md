---
status: accepted
date: 2026-11-06
proposed-by: Codex
approved-by: Memnoc
---

# ADR-0003: Review stable snapshots while agents keep working

## Context

Code reading is a primary use case, and moving diffs interrupt comprehension. Pausing every agent during review would undermine concurrency across tasks.

## Decision

Review a stable local snapshot while agents continue editing, and expose newer changes through an explicit refresh. Keep comments attached to their original snapshot and require affected changes to be reviewed again after refresh. Users can read at their own pace and send a collected review, queued by default with an explicit interrupt option.

## Considered options

- **Stable snapshot with explicit refresh** — chosen to protect reading flow while keeping work concurrent.
- **Continuously replace the visible diff** — rejected because code and comment targets could move while being reviewed.
- **Pause agents whenever review opens** — rejected as the normal behavior because it unnecessarily serializes work.

## Consequences

Snapshot identity, baseline selection, stale-comment handling, and delivery acknowledgments need explicit design. The default diff is side-by-side with an explicit unified toggle. PR review is a later extension; no automatic merge is implied by review completion.
