# Architecture Decision Records

| ADR | Decision | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-independent-native-distribution.md) | Build an independent distribution with multiplexing inside Neovim | accepted | 2026-11-06 |
| [0002](0002-session-lifetime-and-worktrees.md) | Isolate independent tasks and terminate agents with their session | accepted | 2026-11-06 |
| [0003](0003-stable-concurrent-review.md) | Review stable snapshots while agents keep working | accepted | 2026-11-06 |
| [0004](0004-controlled-releases.md) | Manage Neovim and ship user-controlled tested releases | accepted | 2026-11-06 |
| [0005](0005-agent-owned-authentication.md) | Keep authentication in official agent CLIs and autosave locally | accepted | 2026-11-06 |
| [0006](0006-named-tasks-and-inherited-state.md) | Name isolated task branches and inherit saved checkout state | accepted | 2026-11-11 |
| [0007](0007-local-reviewed-delta-integration.md) | Integrate reviewed task deltas into explicit local destinations | accepted | 2026-11-11 |

The 2026-11-08 [domain refinement](../design.md#projects-windows-panes-and-concurrent-work)
replaces user-facing sessions with projects containing windows and panes. ADR
0002 carries the terminology/mapping update; historical session wording in these
records does not introduce an additional grouping in the current model.
