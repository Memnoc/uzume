# Uzume maintainer handoff

Updated 2026-11-12. Read this first, then [CONTEXT.md](../CONTEXT.md), the
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
| Editor | Named Uzume colorscheme (mauve/orange), Snacks explorer/pickers/notifications, completion, Git signs, native LSP/diagnostics/inlay hints, formatting | Pinned Rose Pine renderer with isolated options; original Rose Pine and other themes retain their palettes |
| Extras | Own feature catalog on Space l; curated packs plus user JSON packs and Ctrl-a guided creation; pinned Mason packages and opt-out automatic missing-tool install | Discoverable tool bundles without importing another distribution |
| Checkout visibility | Statusline uses the window checkout branch; Space wi shows full paths and warns about an outside file | Async cached read-only Git; opening a reference does not switch checkout or supply agent context |
| Multiplexing | Project → Windows → Panes; native tabpages, splits and floats; Space w and Space p menus; ps/pS split down/up, pv/pV right/left | No tmux requirement, no second renderer, no extra session concept |
| Pane motion | Slide enabled by default; Space uA selects Slide, Instant, Pulse or Spring | Native geometry, interruption handling, no extra renderer or dependency |
| Tasks | Space ac/aC names a Codex/Claude branch and opens its worktree beside an idle CLI; ae/aE starts without a marked file; ab/aB selects/continues a branch | Separate writable directories prevent independent agents colliding; branch names alone do not |
| Starting state | Saved source edits/new files inherited via a private index and task baseline commit; original index/HEAD/files unchanged | Prevent the apparent loss of edits on switching into a task |
| Context | Explicit marked file list, including cross-project references; supplied with a prompt | Opening a file alone is not authorization to send it |
| Task cleanup | Space at inspects retained tasks; explicit removal archives HEAD/baseline/index/working state; Space aT shows recovery | One task at a time, exact branch confirmation, process/Git/editor guards; no automatic archive expiry |
| Lifetime | Switching retains processes; closing the owning workspace stops them; restart/restore does not silently restart agents | Avoid abandoned agent processes while preserving files and layout |
| Review | Stable snapshot, side-by-side default, unified toggle, changed-file picker, reviewed markers, snapshot-anchored comments | Reading remains stable while agents continue writing |
| Feedback | Preview first; a queues, submits to a ready CLI and focuses it; Ctrl-s queues only; busy delivery at eligible hook boundary | No need to manually tell an idle agent to check its queue; no injection into permission prompts |
| Integration | Preview reviewed task delta, select local destination, apply one commit; labeled conflict resolver, continue/abort, saved operation history | Combine several tasks into a feature branch without importing inherited starting edits or publishing remotely |
| Home | Responsive cave/sun artwork and history list budgeting, visible shortcuts | Populated history must fit too; padding alone hid the bottom of the dashboard |
| Shortcut discovery | Space k / Space ? / Space sk or dashboard k searches live mappings; Enter runs Normal-mode actions, Esc closes | Literal multiword search; native dispatch in the original pane; guards wrong-mode, changed or overridden mappings; Space s? retains buffer-only help |

The active code and app namespace are now `uzume`. Existing storage can be renamed
using `setup-editor --migrate --register` after closing Uzume. Legacy absolute
paths remain valid through compatibility symlinks; do not delete them while
saved Git worktrees, Mason references or histories rely on them. New installations
create only `uzume` paths. See [namespace migration](features/namespace-migration.md).
Historical reports retain old names where they describe evidence from earlier runs.

The [shortcut audit and coverage guide](features/shortcuts.md) records the core
bindings, context-dependent menus and regression coverage.

## Architecture and code map

| Entry point / module | Responsibility |
| --- | --- |
| `editor/init.lua`, `editor/lua/uzume/editor/` | Bootstrap, native package load, editor options, Extras/languages/tools, UI/keymaps |
| `setup-editor`, `editor/plugins.lock.json`, `editor/tools.lock.json` | Exact plugin bundle installation, pinned grammar/query sources, selected tool versions; optional standalone launcher registration |
| `uzume/editor/projects.lua`, `sessions.lua`, `panes.lua`, `navigator.lua` | Product grouping, layout persistence, pane operations and pickers; native window terminology differs from product Window |
| `uzume/ui/location.lua`, `text.lua`, `help.lua` | Window checkout identity, terminal-cell label sizing and shared scrollable menu guides |
| `uzume/editor/branding.lua`, `ui.lua` | Logo and whole-dashboard size budget; dashboard-only viewport correction |
| `uzume/agents/init.lua`, `views.lua`, `input.lua`, `context.lua` | Agent lifecycle/UI, meaningful labels/icons, terminal routing and explicit file context |
| `uzume/agents/branches.lua`, `worktrees.lua`, `editor.lua`, `buffers.lua` | Named or existing task launch, checkout/baseline identity, left editor pane and buffer scoping |
| `editor/agent/branches.py`, `create_worktree.py` | Git preflight, task creation and inherited-state capture using argument arrays/private index |
| `editor/agent/supervisor.py`, `processes.py`, `hook.py`, `feedback.py` | CLI supervision/PTY, process cleanup, hook events, bounded feedback delivery |
| `uzume/review/`, `editor/review/snapshot.py` | Review UI, stable capture, comments and delivery records |
| `uzume/integration/init.lua`, `conflicts.lua`, `editor/review/integration.py` | Local integration plan/apply/status, editable conflict result, Git capture/cherry-pick and operation persistence |

`editor/colors/uzume.lua` loads `uzume/ui/theme.lua`: the named default palette.
It temporarily configures the pinned Rose Pine renderer, restores that plugin's
options/palette cache even on failure, and reports `colors_name = "uzume"`.
Do not leave global palette overrides or a ColorScheme hook on other themes.
See [colorscheme](features/colorscheme.md) and ADR 0011. The trial remains on
`spike/uzume-palette`; its launcher and selector are not production features.

See the [Lua directory map](../editor/lua/README.md). Feature helpers now live
under `agents/`, `review/`, `integration/`, `layout/`, `ui/` and `core/`. Public
`require("uzume.agents")`, `require("uzume.review")` and
`require("uzume.integration")` resolve through `init.lua`. Restart after this
update; live module caches are not migrated. Python resource paths are resolved
from the editor root marker, independently of Lua nesting.

Lua owns editor interaction. Python handles process supervision and Git-heavy
operations. Keep those boundaries understandable before considering Rust.
The Python process visible in low-level process listings is the supervisor;
buffer tabs should display the agent name/icon instead of `python3`.

## Invariants to preserve

- Task inventory is discovery only: do not run full cleanup inspection for every
  row. The 2026-11-12 latency fix reduced a 16-task inventory from about 4 s / 404
  Git commands to 0.06 s by deferring checks until selection and caching repository
  identities within the request. `tests/task_inventory.py` enforces the subprocess
  budget and selected-checkout scope. Removal still performs fresh checks; never
  turn inventory rows into removal authorization.

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

Paths are relative to Neovim's `stdpath` for `NVIM_APPNAME=uzume`:

| Location | Contents |
| --- | --- |
| data/releases/<lock hash> | Installed immutable plugin/syntax bundle |
| data/pane-motion.json | Versioned animation preference; fresh installs default to Slide |
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
That consolidation was initially local. The subsequent final-polish request
authorizes merging the accepted animation implementation and publishing main;
inspect the remote and verification record for the completed publication state.

## Verification and how to continue safely

Run `python3 tests/run.py` from the repository root. It runs 21 cases sequentially:
namespace migration; installer registration and conflict refusal; dashboard resizing; shortcut search/audit; floating command line; user language packs and creation UI; pane motion, restoration and interruption; normal and forced-exit agent cleanup; saved-state inheritance;
task navigation; named and existing-branch launch; review; comments; Codex and
Claude feedback; normal and diff3 conflict integration. Each uses real Neovim/PTY
and real disposable Git repositories, with mock external CLIs and isolated XDG
state. No model requests or remote pushes occur. Failure artifacts are printed
and retained for diagnosis. Installed pinned bundles and Neovim are prerequisites.

Focused commands remain available, e.g. `python3 tests/integration.py` and
`UZUME_TEST_CONFLICT_STYLE=diff3 python3 tests/integration.py`.
Use the actual editor and Git boundary for behavioral regressions, not tests
that simply assert private helper structure. The accepted pane-motion behavior now has permanent coverage in
`tests/pane_motion.py`; the throwaway demo remains separate.

Fresh installation no longer needs personal caches. `python3 tests/install_clean.py`
performs an opt-in network test with empty XDG roots: fetch/build the pinned
plugins, nine grammar parsers and matching query files, register a temporary
launcher, exercise real language samples and startup, then repeat installation.
The default shell/config/bin paths are untouched. Use the printed temporary
`XDG_DATA_HOME` to run the editor suite against that bundle. The registration
case is part of the regular suite and does not download anything.

Cache-free installation and all **16 cases** passed on macOS ARM64 and Ubuntu
24.04 x86_64. Linux CI checks Neovim 0.11.0 and 0.12.6; macOS's final full run used
`v0.12.0-dev-2155+g1e6c4ea896`, with a focused 0.11.0 review compatibility test too.
See [Linux](features/linux.md), [installation](features/installation.md),
[ADR-0009](adr/0009-uzume-namespace-migration.md) and
[the current verification record](verification-namespace-linux-2026-11-11.md).
Intel Mac, Linux ARM64 and hands-on Linux terminal trials remain pending.
Earlier cached-install reports are historical evidence, not the new-machine path.

Namespace/Linux implementation was fast-forwarded into the normal `/Code/uzume`
main checkout from `e56b2c0` after the user closed Uzume and no live instances
remained. `setup-editor --migrate --register` completed on 2026-11-11: canonical
config/data/state/cache paths are active, legacy links preserve absolute paths,
and bundle `2b1f2b0916ce` is installed. The pre/post audit matched 1,707 saved
files/links, 23 retained Git worktrees (HEAD, staging, unstaged changes and status),
and all four directory identities. All 13 tool references remain executable.
Both the standalone launcher and updated shell function passed startup checks.

Only the Uzume function, its comment and the `nvims` entry changed in `.zshrc`;
the backup is `~/.zshrc.before-uzume-namespace-20261111-214304`. Existing shells
must reload the file or open a new shell to use the new function. Plain `nvim`
was not changed. Do not remove compatibility links or rename `/Code/ai-nvim`:
that historical checkout owns the common Git directory used by linked worktrees.
See the verification record for rollout evidence; check current Git/remote state
before subsequent work instead of assuming the development branch is still ahead.

The harness verifies the adapters' contract, not every live vendor CLI release.
Manual Codex and Claude trials have informed the workflow, but upgrades still
need live smoke tests. Terminal appearance/frame rate needs real Ghostty/WezTerm
evaluation; a passing PTY test cannot establish perceived smoothness.

## Final feature increment: user packs and command line

See [ADR-0010](adr/0010-user-language-packs.md) and the
[user-pack guide](features/user-language-packs.md). Definitions are in the config
sibling `uzume-user/languages`, never inside the source checkout. Invalid packs
are isolated and shown for repair. No user parser installer or plugin marketplace
was added. New Noice/Nui pins require rebuilding the package bundle before startup.
Noice owns command input/completion only; Snacks still owns notifications.

Linux CI's Neovim 0.11 restore failure was reproduced locally: routine file-position
messages caused a hit-enter prompt while sourcing a saved layout. `silent source`
suppresses normal output while preserving real errors; the existing agent/crash
regressions exercise restoration. Do not replace this with `silent!` or just raise
the RPC timeout. The [verification record](verification-user-packs-2026-11-11.md) records 21/21
local cases and both Linux matrix jobs passing. The new user preference is to freeze feature expansion here and
concentrate on polishing and bug fixes; the broader backlog below is not an
instruction to add more features in the next iteration.

## Next work, in order

1. **Task cleanup follow-up.** Single-task archive/remove and recovery instructions
   are implemented (ADR-0012). Validate the wording on real projects before bulk
   selection or archive expiry. One-click restore and cross-editor unsaved-buffer
   coordination remain separate work; do not overstate the locks' coverage.
2. **Integration recovery hardening.** Exercise process death at mutation
   boundaries, external Git changes, lost records, hooks/signing failures, and
   partial operation receipts. Keep errors actionable and conflicts labeled.
3. **Release/install story.** Select and test a supported Neovim version, define
   OS/terminal matrix, automate source-build release checks, consider prebuilt
   syntax artifacts, and build explicit update/rollback. Independent source
   installation is implemented; personal caches are no longer required.
   Plugins/tools are pinned today; Neovim itself is not distro-managed yet.
4. **Coverage and maintenance.** Extend the existing Ubuntu CI matrix, maintain
   vendor CLI compatibility probes, expand meaningful editor/language smoke
   coverage, and measure four-agent output/resizing before performance claims.
   Pane motion now has automated coverage; heavy-output and terminal-specific
   mouse behavior still need hands-on validation.
5. **Production specification.** Reconcile remaining editor capabilities, storage
   migration/retention, crash recovery and operating limits with the agreed
   design. Complete the planned compliance triage before a production spec or
   release; do not turn this into a new credentials/policy platform.

Optional later work: PR review and remote publishing; external multiplexer
integration; SSH projects if demanded; richer attention/worker discovery; CLI
conversation resume; automatic interrupt-and-send; persisted focus policies;
retirement of legacy path aliases after proving no retained references remain;
Rust only where measurements or ownership justify it.

## Accepted pane motion and experiment history

Slide is enabled by default in the regular editor. Space uA offers Slide, Instant,
Pulse and Spring; Ease was removed because it overlapped with Slide. The choice
persists locally. See [pane animations](features/pane-animations.md) for controls,
implementation, interruption behavior and limits.

The throwaway `spike/pane-animations` branch remains available separately at
`/Users/matteostara/Code/uzume-pane-animations`; its `spike-animations` launcher
uses disposable state. Its demo, generated files and monkeypatch were not merged.
The regular implementation in `uzume/layout/` is called directly by pane
operations, preserves native buffer/process ownership, settles before a new
managed operation, and yields to typing, focus changes and later native geometry.
It deliberately does not preserve spring velocity across repeated actions.

The experiment established that native whole-cell geometry transitions were
usable. Spring was fluid but the bounce was not preferred. Slide was accepted
with a 200 ms ease-out, fixed-size upward float entrance and anchored directional
split reveals; focus changes and topology moves remain instant. These timings
are policy values, not measured GPU frame rates. Four busy agents, CPU/battery
cost and terminal-specific visual performance remain evaluation work.

The historical observation record is available with:
`git show spike/pane-animations:docs/prototypes/0009-pane-animations.md`.
The existing ADRs cover native pane ownership and isolated agent lifetimes;
this reversible motion preference does not change those architectural decisions.

## Checkout and menu polish (2026-11-12)

Project/window navigation follows the selected theme and fits smaller terminals.
Selected checkout details sit below its list; ? shows controls when the compact
footer cannot fit them. Review and integration use concise titles and ? guides.
Feedback retains an always-visible action area, now wrapping on resize. Agent
and changed-file pickers separate their title from Enter/Esc hints.

`tests/workspace_context.py` is included in the consolidated suite, covering
branch changes, detached HEAD, outside-checkout files and light/dark/narrow menus.
Review tests exercise help return; both feedback fixtures exercise action resizing.
This pass adds no cleanup policy, preference persistence or process-performance
claims. Batch cleanup ergonomics, sustained concurrent-agent load testing and
persistent theme selection remain possible follow-up polish.

Verification: all **23/23** consolidated cases passed on macOS with the installed
Neovim 0.12 development build. Checkout/menu tests and Codex feedback also passed
on minimum Neovim 0.11.0. The updated shortcut audit covers 145 core bindings;
StyLua and whitespace checks pass. Linux verification is delegated to CI after
publishing; these local checks are not Linux runtime evidence.

## Retained task cleanup (2026-11-12)

`uzume/agents/cleanup.lua` and `agent/cleanup.py` implement the single-task
inventory/inspect/archive/remove workflow. `agent/task_lock.py` coordinates
supervisors and integration with deletion. Inspection uses temporary Git objects;
removal writes recovery refs before touching checkout/branch. Named and generated
tasks now persist metadata; legacy managed checkouts have unknown review status.
The original user's retained worktrees were not used for destructive testing.
Read [the guide](features/task-cleanup.md) for exact guards, recovery commands,
partial receipts and limits. Tests use real Git/editor workflows in disposable
state; `tests/task_cleanup.py` and `task_cleanup_ui.py` join the consolidated suite.

Verification: the consolidated 25-case run exposed a command-callback regression
and a fixture startup race. The callback now discards Ex-command metadata before
opening review; integration fixtures wait for CLI readiness before emitting hooks.
All 25 cases passed across the suite and targeted reruns of the affected cases.
The new cleanup UI also passed on Neovim 0.11.0. Cleanup and recovery assertions
use disposable worktrees only; no real model calls or user task removals occurred.

## Task browser navigation polish (2026-11-12)

- Completed: details return via Esc/b with filter, selected row and scroll position
  preserved; q explicitly ends the visit. The list and detail footers explain the
  difference. A new Space at refreshes discovery and starts a new visit.
- Completed: a checking screen identifies branch/project and allows back/close;
  failed requests offer retry. Each inspection has an in-memory identity. Closing
  its window or replacing the view invalidates it before late callbacks can show
  results or errors. The read-only helper is allowed to finish; never apply this
  dismissal policy to archive/remove operations.
- Boundary: list items are retained only for that visit, while every selection
  and removal still checks current Git state. No persisted authorization/status
  cache, new dependency or Python protocol change was introduced.
- Coverage: `tests/task_browser.py` uses real keys, pinned Snacks and disposable
  Git checkouts, including a controlled slow Git call and externally removed task.
  Existing cleanup UI coverage continues to exercise review, removal cancellation,
  safeguards and recovery. See the feature guide for controls and limits.
- Verification: browser navigation/progress/retry passed on development Neovim
  and 0.11.0; existing cleanup UI and inventory regressions passed, as did Lua
  formatting and whitespace checks. The unrelated full suite was not repeated.
- Deferred: consistent project/branch labeling across all review/integration
  surfaces and a guided restore-to-new-branch action were suggestions, not part
  of this two-item polish pass. Recovery still presents explicit Git commands.
