# Uzume maintainer handoff

Updated 2026-11-11. Read this first, then [CONTEXT.md](../CONTEXT.md), the
[ADR index](adr/README.md), and the relevant [feature guide](features/README.md).
This is a working prototype baseline. It is not a declaration of production
readiness or completion of every item in the original design interview.

## Product intent and working agreement

Uzume is an independent, minimal Neovim distribution for reading code, ordinary
editing, and supervising concurrent Codex/Claude tasks. Native capabilities are
preferred when they meet the need; pinned plugins are appropriate when they
save substantial maintenance. Rust is welcome for a demonstrated need, not as
a requirement to rewrite the existing Lua/Python implementation.

Keep iteration small and usable. Ask one design question at a time, show controls
on the surface they operate, and update feature documentation with every change.
Use Northstar skills where they fit. Avoid inventing permission steps for routine
local implementation work. Sending source to agents, remote publishing and
destructive cleanup are distinct actions with explicit user intent.

The user values flow: attention should identify agents needing input, review or
help without stealing focus. Reading and side-by-side review matter as much as
launching agents. Mouse support is useful and switchable; Space-leader keyboard
controls remain primary. Preserve plain `nvim` and its existing configuration.

## What exists and why

| Area | Current behavior | Reason / boundary |
| --- | --- | --- |
| Editor | Rose Pine with scoped mauve accents, Snacks explorer/pickers/notifications, completion, Git signs, native LSP/diagnostics/inlay hints, formatting | Familiar, capable editing before bespoke AI UI; other colorschemes retain their palettes |
| Extras | Own feature catalog on Space l; Rust, Lua, C/C++, web tooling, Smear Cursor; pinned Mason packages and opt-out automatic missing-tool install | Discoverable tool bundles without importing another distribution |
| Multiplexing | Project → Windows → Panes; native tabpages, splits and floats; Space w and Space p menus | No tmux requirement, no second renderer, no extra session concept |
| Tasks | Space ac/aC names a Codex/Claude branch and opens its worktree beside an idle CLI; ae/aE starts without a marked file; ab/aB selects/continues a branch | Separate writable directories prevent independent agents colliding; branch names alone do not |
| Starting state | Saved source edits/new files inherited via a private index and task baseline commit; original index/HEAD/files unchanged | Prevent the apparent loss of edits on switching into a task |
| Context | Explicit marked file list, including cross-project references; supplied with a prompt | Opening a file alone is not authorization to send it |
| Lifetime | Switching retains processes; closing the owning workspace stops them; restart/restore does not silently restart agents | Avoid abandoned agent processes while preserving files and layout |
| Review | Stable snapshot, side-by-side default, unified toggle, changed-file picker, reviewed markers, snapshot-anchored comments | Reading remains stable while agents continue writing |
| Feedback | Preview first; a queues, submits to a ready CLI and focuses it; Ctrl-s queues only; busy delivery at eligible hook boundary | No need to manually tell an idle agent to check its queue; no injection into permission prompts |
| Integration | Preview reviewed task delta, select local destination, apply one commit; labeled conflict resolver, continue/abort, saved operation history | Combine several tasks into a feature branch without importing inherited starting edits or publishing remotely |
| Home | Responsive cave/sun artwork and history list budgeting, visible shortcuts | Populated history must fit too; padding alone hid the bottom of the dashboard |

Names in old prototype reports are historical. `ainvim` modules and the
`ai-nvim` app/data namespace remain compatibility identifiers, not alternative
product names. Changing them requires a planned migration for plugins, tools,
worktrees, snapshots and saved records. Do not do a blind string replacement.

## Architecture and code map

| Entry point / module | Responsibility |
| --- | --- |
| `editor/init.lua`, `editor/lua/ainvim/` | Bootstrap, native package load, editor options, Extras/languages/tools, UI/keymaps |
| `setup-editor`, `editor/plugins.lock.json`, `editor/tools.lock.json` | Exact plugin bundle installation, syntax hashes, selected tool versions; optional shell registration |
| `ainvim/projects.lua`, `sessions.lua`, `panes.lua`, `navigator.lua` | Product grouping, layout persistence, pane operations and pickers; native window terminology differs from product Window |
| `ainvim/branding.lua`, `ui.lua` | Logo and whole-dashboard size budget; dashboard-only viewport correction |
| `uzume/agents.lua`, `agent_views.lua`, `agent_input.lua`, `context.lua` | Agent lifecycle/UI, meaningful labels/icons, terminal routing and explicit file context |
| `uzume/branch_launch.lua`, `worktrees.lua`, `task_editor.lua`, `workspace_buffers.lua` | Named or existing task launch, checkout/baseline identity, left editor pane and buffer scoping |
| `editor/agent/branches.py`, `create_worktree.py` | Git preflight, task creation and inherited-state capture using argument arrays/private index |
| `editor/agent/supervisor.py`, `processes.py`, `hook.py`, `feedback.py` | CLI supervision/PTY, process cleanup, hook events, bounded feedback delivery |
| `uzume/review*.lua`, `editor/review/snapshot.py` | Review UI, stable capture, comments and delivery records |
| `uzume/integration.lua`, `conflicts.lua`, `editor/review/integration.py` | Local integration plan/apply/status, editable conflict result, Git capture/cherry-pick and operation persistence |

Lua owns editor interaction. Python handles process supervision and Git-heavy
operations. Keep those boundaries understandable before considering Rust.
The Python process visible in low-level process listings is the supervisor;
buffer tabs should display the agent name/icon instead of `python3`.

## Invariants to preserve

- A Project can own windows rooted in different task worktrees. Do not collapse
  project identity into whichever cwd happens to be focused.
- The left pane edits the task's file; the right pane is a single agent terminal.
  Buffer navigation must not duplicate the agent into the editor pane.
- Task inheritance must preserve source staging, saved files and HEAD exactly.
  Unsaved buffers are not silently captured. Inherited baseline changes are not
  reported as agent work and are not included in task integration.
- Stable review data and comment anchors do not move with the live checkout.
  Refresh is explicit; outdated comments retain their original context.
- A supplied feedback receipt means the hook emitted context, not that the model
  read, accepted, or completed it. A restarted run needs an explicit new handoff.
- No hidden authentication layer: the official CLI owns login/browser/SSO and
  credentials. Uzume does not store API keys on the user's behalf.
- Integration is local. No push, PR creation or deletion is implicit in apply,
  review completion, closing a pane, or closing a project.
- Source buffers are not autosaved by project-layout autosave. Named source
  files retain ordinary explicit save behavior.

## Local state and recovery

Paths are relative to Neovim's `stdpath` for `NVIM_APPNAME=ai-nvim`:

| Location | Contents |
| --- | --- |
| data/releases/<lock hash> | Installed immutable plugin/syntax bundle |
| data/mason | Managed language tools |
| data/worktrees, data/task-branches | Task checkouts and branch/baseline metadata |
| data/integration-worktrees | Separate destination checkouts when needed |
| state/agents/<run> | Private launch/event/state/feedback records |
| state/review-comments, state/review-feedback | Local comment drafts and immutable handoff batches |
| state/integrations | Local integration plans, patches and status |
| state/navigator | Locally saved project/window layout |

Records can contain source excerpts and paths. They are local, private, retained
state; removal/retention policy is not implemented. Closing a workspace preserves
checkouts and branches. Never treat these directories as disposable caches.

For an interrupted integration, inspect the chosen destination's Git status
first, then Space vi (current) or Space vI (history). Resume or explicitly abort
the recorded operation. External Git mutations can invalidate a preview; inspect
and rebuild the plan. A crash can leave a per-destination lock in the common Git
directory; confirm no operation remains live before any manual lock removal.
Do not reset/clean a user's checkout to silence an error.

## Consolidating the development baseline

The older local main contained design records and an obsolete README, while
`spike/editor-baseline` contained the actual editor. Integrating a tiny README
cleanup task onto that old main produced a misleading large conflict: the
destination did not contain the modern document to which the task delta applied.

Consolidation uses a real Git history merge on `stabilize/main-baseline`, starting
at development `cd55b3c` and merging old main `ee94529`. All 14 conflicts were
documentation/metadata; their differences were inspected and current development
records retained, including anonymized descriptions and later accepted behavior.
The editor code had no merge conflicts. The clean committed README already
contained the desired single tagline; the duplicate test paragraph is backed up
before removing it from the user's checkout. No task branches are pruned.

Main advanced locally to consolidation commit `f286734`, and the normal
`/Code/uzume` checkout is now on main. The former main integration checkout is
retained detached; its aborted operation and all task worktrees remain intact.
The duplicate README test edit was backed up outside the repository as
`/Users/matteostara/Code/uzume-readme-before-cleanup-20261111.md`. Do not confuse
this repository-history operation with the product's one-task delta integration.
Check `git status`, `git log --oneline --decorate -6`, and `git worktree list`
on entry to a future session: local worktree placement and remote state can change.
No remote publication is part of this handoff's consolidation task.

## Verification and how to continue safely

Run `python3 tests/run.py` from the repository root. It runs 13 cases sequentially:
dashboard resizing; normal and forced-exit agent cleanup; saved-state inheritance;
task navigation; named and existing-branch launch; review; comments; Codex and
Claude feedback; normal and diff3 conflict integration. Each uses real Neovim/PTY
and real disposable Git repositories, with mock external CLIs and isolated XDG
state. No model requests or remote pushes occur. Failure artifacts are printed
and retained for diagnosis. Installed pinned bundles and Neovim are prerequisites.

Focused commands remain available, e.g. `python3 tests/integration.py` and
`UZUME_TEST_CONFLICT_STYLE=diff3 python3 tests/integration.py`.
Use the actual editor and Git boundary for behavioral regressions, not tests
that simply assert private helper structure. For a throwaway animation probe,
use disposable UI observations before deciding what warrants a permanent test.

Fresh-install smoke: isolate all four XDG roots, provide plugin repositories
containing the pinned commits and the matching syntax cache to `setup-editor`,
then repeat installation and launch Neovim against that isolated config. Do not
use `--register` when testing installation against the real home directory.
On 2026-11-11 this passed from local caches, including startup commands and the
populated resize test; the default config and `.zshrc` hashes were unchanged.
See [verification record](verification-2026-11-11.md) for consolidated results.

The harness verifies the adapters' contract, not every live vendor CLI release.
Manual Codex and Claude trials have informed the workflow, but upgrades still
need live smoke tests. Terminal appearance/frame rate needs real Ghostty/WezTerm
evaluation; a passing PTY test cannot establish perceived smoothness.

## Next work, in order

1. **Task lifecycle and cleanup UI.** Inventory retained tasks, live agents,
   worktree dirtiness, integration receipts and destination state. Offer Keep,
   Review/Integrate and explicit Remove task. Preserve primary checkouts; require
   agents stopped; confirm discarded unintegrated work. Define equivalence for
   squashed integration before claiming a branch is safe to prune. Start with
   one task; bulk cleanup follows proven checks.
2. **Integration recovery hardening.** Exercise process death at mutation
   boundaries, external Git changes, lost records, hooks/signing failures, and
   partial operation receipts. Keep errors actionable and conflicts labeled.
3. **Release/install story.** Select and test a supported Neovim version, define
   OS/terminal matrix, provide syntax artifacts without assuming an existing
   local cache, automate release checks, and build explicit update/rollback.
   Plugins/tools are pinned today; Neovim itself is not distro-managed yet.
4. **Coverage and maintenance.** Add CI on the supported platform, maintain
   vendor CLI compatibility probes, expand meaningful editor/language smoke
   coverage, and measure four-agent output/resizing before performance claims.
   Native pane management has earlier manual probes but less permanent coverage
   than the newer task/review/integration workflows.
5. **Production specification.** Reconcile remaining editor capabilities, storage
   migration/retention, crash recovery and operating limits with the agreed
   design. Complete the planned compliance triage before a production spec or
   release; do not turn this into a new credentials/policy platform.

Optional later work: PR review and remote publishing; external multiplexer
integration; SSH projects if demanded; richer attention/worker discovery; CLI
conversation resume; automatic interrupt-and-send; persisted focus policies;
namespace migration; Rust only where measurements or ownership justify it.

## Animation experiment

Implemented separately on `spike/pane-animations`, based on `f286734`, in
`/Users/matteostara/Code/uzume-pane-animations`. Main retains instant pane behavior.
Run `/Users/matteostara/Code/uzume-pane-animations/spike-animations` to compare
Instant, Ease, Pulse and Spring in a disposable three-pane workspace with local output.
Space uA opens the mode list (j/k, Enter); Space uD demonstrates a resize.
The launcher shares only pinned plugin files read-only, disables automatic tool
installation, and discards its demo state on exit. Ordinary `uzume` is unaffected.

The real-Neovim probe showed native geometry tweening is feasible without an
extra dependency. Eased operations settled in approximately 142–157 ms and pulse
cues around 189–191 ms in that run. Split/resize, floating, fullscreen/restore,
docking, repeated operations, keyboard mode selection and cancellation ran
without editor errors. These are callback timings, not measured GPU frame rates.
Eased mode repeatedly resizes terminals; pulse leaves final geometry immediate.
Native topology movement stays atomic and receives a cue. Arbitrary native
commands, mouse arbitration, CPU/battery cost and four live agents remain
unverified. No motion policy has been accepted for main.

Follow-up `c65ba69` on the experiment branch adds Spring after the maintainer
liked the initial variants and requested a bouncing desktop-style option.
The preview starts in Spring; a damped response overshoots and settles in about
420 ms, with exact final geometry and Instant cancellation. A real editor probe
observed a 69→87-column resize peak at 90, rebound to 86, and settle at 87.
Repeated Spring resize keys retarget from the visible position while accumulating
the intended destination. Velocity continuity and sub-cell rendering are not
implemented; whole-cell rounding remains the fundamental visual limit. The
branch's prototype record contains the details. Main's runtime remains unchanged.

The full usage/observation record is on the experiment branch:
`git show spike/pane-animations:docs/prototypes/0009-pane-animations.md`.
Keep the demo and monkeypatch implementation off main. If a mode is preferred,
rewrite a small opt-in implementation with cancellation/focus/layout coverage
and load measurements rather than promoting the experiment wholesale.
