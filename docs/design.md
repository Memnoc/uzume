# Design record

Date: 2026-11-06. Project: Uzume (name selected 2026-11-08; formerly ai-nvim).

This records the design interview, not a completed implementation specification. Agreed product behavior is separated from proposed experiments and unresolved mechanisms.

## Purpose and design principles

- Code reading and review are primary product capabilities; manual programming remains fully supported.
- Maintain a documented inventory of editing capabilities and stable keybindings. Fewer dependencies are useful only when they reduce total maintenance work.
- Build an independent distribution from scratch. Use native Neovim facilities where appropriate and selected pinned plugins where they add substantial value.
- Build our own multiplexing inside Neovim. External multiplexer integration is a possible later addition.
- Rust is welcome when it serves a clear architectural need and maintainability; portfolio value alone does not determine language choice.
- Interview one question at a time, and test incremental prototypes with the maintainer.

## Projects, windows, panes, and concurrent work

Updated on 2026-11-08: the product hierarchy is **Project → Windows → Panes**. A project is rooted in a chosen local directory and owns its dedicated windows. A window is a switchable group of editor/terminal panes with its own retained layout. A pane is one editor or terminal surface. There is no separate user-facing session entity; the need for any additional grouping can be revisited after hands-on window-management use.

The workflow is to create/open a project at a directory, create the windows and panes needed there, switch among them, and close the whole project workspace when finished. Switching projects or windows preserves their background processes. Closing a project ends its windows, panes, agents and owned spawned processes by default. Optional keep-running behavior remains deferred.

Independent features still require separate worktrees and branches; branches alone do not isolate simultaneous edits in one directory. Joining a task's checkout represents deliberate collaboration. **Accepted, 2026-11-08:** starting an AI task creates a dedicated window, branch, and worktree beneath its existing project, with editor and agent panes side by side. Project identity is separate from window checkout. The original committed-HEAD-only policy was replaced by saved-state inheritance; see [ADR-0006](adr/0006-named-tasks-and-inherited-state.md). Worktree creation, switching, and cleanup should be easy to discover.

Closing/removing the project workspace is distinct from deleting its directory or worktrees. Checkout files and locally saved layout/review state are retained. Worktree cleanup is a separate, explicit action. Drudwyn's refusal to remove primary, dirty, or unintegrated worktrees is a useful reference to refine before implementation; exact cleanup and integration rules remain open.

The earlier preview labelled native tab pages as sessions and individual splits as windows, causing confusion alongside the shared buffer bar. The current window-management spike groups native tabs by project directory: each tab is a product window, and its native editor/terminal windows are panes. This is a structural prototype with independent layouts, not just renamed menus. Native buffers remain shared. See the [window-management findings](prototypes/0008-window-management.md); hands-on evaluation remains pending.

Four directly launched agents are the initial everyday performance workload, not a product limit. Spawned workers also contribute to load. Higher stress workloads will be chosen from observed usage.

## Pane interaction and visual direction

- Tiling is the default, inspired by Pop!_OS, with floating panes and fullscreen/zoom that returns to the previous arrangement.
- Moving, resizing, tiling, floating, zooming, and switching panes must be keyboard accessible.
- Mouse dragging and resizing are supported; mouse support can be disabled. Keyboard use remains central.
- Drudwyn's compact navigation, visible shortcuts, restrained borders, and agent-state cues are references. Preserve the current configuration's visual preferences unless a change is deliberately agreed.
- Most navigation menus, including project/window quick switching, should float; selected persistent tools should be anchored. Menus expand/collapse through keyboard shortcuts. The file explorer is an essential anchored sidebar with the standard Snacks shortcuts, including `<leader>e` and explorer-local `a`. The hierarchy is project → windows → panes; exact menus and bindings remain to be designed. See the [editor baseline](editor-baseline.md).
- Ghostty and WezTerm are primary reference terminals on macOS and Linux. Kitty is an additional compatibility target.
- Smooth input and resizing matter in the first usable version. Animation polish follows the working product and remains configurable/off-switchable.
- GPU-accelerated terminals are the intended environment. Hardware thresholds, terminal version requirements, and any hard compatibility gate require measurements before adoption.

The initial animation discussion suggested 60 updates per second as an experiment, not a guaranteed frame rate or a release requirement. Neovim's built-in floating-window placement rounds fractional coordinates to character cells, so terminal pane motion is not desktop pixel motion. Measure actual redraw behavior, input latency, and resource use under agent output rather than treating a timer frequency as delivered FPS. [Neovim window API](https://neovim.io/doc/user/api/#nvim_open_win())

## Agents and attention

Interaction refinement, 2026-11-09: launch either with the current file's
worktree counterpart marked or as an empty workspace. Both skip a separate task
dialog; instructions are entered directly in the CLI. Each agent owns a visible
file-context list, including explicit external references. Buffer tabs are scoped
to the active workspace without deleting the original checkout's buffers.

Codex and Claude Code are the first-release agents. Use their existing interactive terminal UIs, with editor actions for sending selected code, file references, diagnostics, and review feedback. A custom chat interface is deferred unless actual usage demonstrates friction.

The attention interface answers who needs the user, why, and where to go. Show project/task context, the actionable need, and waiting time; provide direct navigation to the relevant agent. Ordinary background activity should remain quiet. A process tree or agent count is secondary to actionable information. Worker needs should surface when the user can act on them, without duplicating a need already being handled by a parent.

Focus is manual by default, with persistent attention indicators and restrained notifications. Optional automatic focus follows agent attention after an idle delay, respecting active prompts and dialogs. Focus-follows-mouse is a separate optional behavior. The precise signals for idle, protected interaction, and agent attention require prototyping; terminal output must not be treated as infallible evidence of task completion.

## Code reading and review

Local worktree review comes first. GitHub/GitLab PR review remains a possible later extension using the same review concepts.

- Side-by-side diff is the default. Unified diff is an explicit toggle, preserving reading position. Narrow panes should not silently override the chosen mode.
- Review the complete task change, including uncommitted changes, against its starting point. Exact baseline and snapshot mechanics remain open.
- Keep a stable snapshot while agents continue editing. Indicate newer changes and refresh only when the user chooses.
- Refreshing invalidates reviewed markers for affected changes. Comments retain their original context and indicate when newer edits make them outdated.
- Let the user select hunks or lines, add comments, collect feedback, and explicitly send a review to the responsible agent.
- Queue feedback by default while the agent is working, showing it as pending. Provide an immediately accessible interrupt-and-send action for urgent corrections.
- Interrupting current work differs from terminating an agent or session. Preserve the conversation where the CLI supports this; verify both agents' actual behavior.
- Provide explicit paths to inspect changes, run relevant checks, integrate work, and clean up. Merging remains the user's decision.

Usability evaluation should cover the whole cycle: read, navigate surrounding code, comment, send, and inspect a revision. File navigation, hunks, reviewed markers, contextual code navigation, and test results should support comprehension. Exact search, history, conflict-resolution, and editing features still need prioritization rather than being silently promised by the phrase “feature-rich diff suite.”

## Local persistence and authentication

Project window/pane layouts, open-file references, review progress, and unsent comments autosave locally during use; clean exit or a manual save shortcut is not required. Reopening restores that workspace state. Restarting agents is explicit.

Source-file saves remain explicit as the initial design direction, with local recovery for unsaved edits. Source autosave, if added, is a separate setting because it can trigger formatters/watchers and alter the files agents read. Autosave never authorizes uploading data or handing drafts to an agent.

Use the installed official Codex/Claude CLIs and their existing authentication. The CLI owns browser login, organizational SSO such as Okta, and any credential persistence. ai-nvim collects no keys, implements no login flow, and copies no credentials or agent transcripts into its session snapshots. An explicitly launched agent's own permissions and data handling remain its responsibility; this is not a promise that the distro provides network isolation.

Review snapshots and draft comments can contain source code, even though stored locally. Storage location, permissions, retention, recovery, and deletion behavior must be defined before production persistence. Snapshot file capture and the boundary between automatic local capture and explicit agent sharing remain part of the pre-spec review.

## Releases and platform scope

First release: local projects on macOS and Linux. SSH is deferred until necessary; Windows is outside the initial target.

The distro manages a pinned Neovim executable alongside existing installations. Releases identify a tested dependency combination; the user decides when to update, and rollback retains a previous working release. Exact plugin/parser pins, language-tool ownership, release artifact formats, compatibility checks for separately installed agent CLIs, and upgrade/rollback mechanics are still to be designed.

## Baseline inspection

The initial prototype was inspected with Neovim `v0.12.0-dev-2155+g1e6c4ea896`. This is a development observation, not a chosen release version.

The baseline includes Snacks navigation, completion, LSP, formatting/linting, debugging, tests, previews, multicursor editing, and terminal controls. Enabled language extras include C/C++, CMake, Rust, TypeScript, Tailwind, JSON, TOML, YAML, and Typst; custom Slint and Markdown/Mermaid functionality also needs accounting for. Notable custom bindings include `<C-/>` for the right-side terminal, `<leader>9` for a floating terminal, terminal `<C-h/j/k/l>` navigation, and horizontal resize bindings.

Verify executable configuration and resolved dependencies against documented pins.

## Next steps and open design work

**2026-11-11 — local integration implemented.** The maintainer approved combining
independent task work into a chosen local feature branch for a later PR, with
explicit conflict resolution. The first implementation applies each reviewed
task delta as one commit, preserves source checkouts, and supports saved conflict
status, continuation and explicit abort. See [task integration](features/integration.md).
Pushing/PR creation and removal/bulk cleanup are not part of this increment.

**2026-11-11 — proposed next increment: task completion and cleanup.** The review
and feedback loop now needs an editor UI for keeping a task, integrating its
reviewed changes into a chosen destination, or removing its worktree and local
branch after an experiment. Show running agents, saved/uncommitted edits, and
integration status before acting. Preserve the primary checkout; require agents
to stop before removal and explicit confirmation before discarding unintegrated
work. Integration should preview the exact changes and check destination edits
and conflicts. Bulk cleanup of completed tasks can follow once these checks are
reliable. The user-facing action should be **Remove task**, covering both branch
and worktree. Integration is now implemented as described above. Removal is not implemented;
cleanup eligibility and discard confirmation still need a focused design pass.

The first Drudwyn pilot feedback changes the order: agents inside Neovim feel
more accessible than a separate terminal, but the editor does not yet meet the
expected appearance or functionality. Establish a solid
editor experience before expanding agent features. The distribution remains independent.

1. Complete the capability, visual, and binding inventory. The acceptance baseline includes: Rose Pine, Snacks pickers/explorer, leader-menu discovery, code navigation, completion, diagnostics, formatting, and terminal behavior. Account for the remaining extras without silently dropping them.
2. Agree and build the first editor-focused increment, choosing native equivalents or pinned plugins where they preserve behavior. Evaluate everyday reading and editing with the maintainer before integrating more AI UI.
3. **Completed trial: native window/pane management.** The prototype now covers project-owned windows, editor/terminal splits, moving/swapping/resizing, floating/fullscreen restoration, hide/restore and scoped close. Space ap selects projects, Space aw windows, Space w exposes window controls, and Space p pane controls (with Focus, Move and Resize submenus); Space as remains a compatibility alias. Evaluate ordinary files and shells in Drudwyn, including mouse behavior and busy output, before proceeding. See [window-management findings](prototypes/0008-window-management.md).
4. **Current milestone: task-owned agents.** Integrate Codex and Claude terminals into dedicated worktree windows under their project. Verify terminal key routing, attention, scoped process cleanup, and concurrency with local fixtures, then try a real task. See [agent workflow](features/agents.md). Existing pilot code remains available for comparison.
5. Prototype local review separately, including stable snapshots and revision feedback; choose storage boundaries and per-agent lifecycle/delivery mechanisms from evidence.
6. Complete Northstar's compliance triage before writing the production spec. Record the relevant source-code persistence and explicit external-handoff boundaries without expanding the product into an authentication or policy platform.
7. Set up canonical repository guidance and the ticket tracker, then produce the spec and incremental implementation tickets.

These steps are proposed sequencing, not an approved implementation ticket list.

## Current continuation point

The [maintainer handoff](HANDOFF.md) records the consolidated prototype baseline,
module map, verification commands, and prioritized remaining work. Historical
trial steps above describe the development sequence, not a fresh implementation
plan. The separate `spike/pane-animations` trial informed the accepted regular
implementation: Slide enabled by default, with Instant, Pulse and Spring available
on Space uA. Ease was removed as redundant. See the [pane animation guide](features/pane-animations.md)
for behavior and limits; the trial's demo and monkeypatch remain on its branch.
