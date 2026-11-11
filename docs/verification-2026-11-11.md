# Consolidated prototype verification — 2026-11-11

Scope: merge preparation for the current editor/agent/review/integration baseline,
responsive dashboard fix, and maintainer handoff. This is prototype verification,
not a production release certification.

## Results

`python3 tests/run.py`: **13/13 cases passed** on macOS ARM64 with Neovim
`v0.12.0-dev-2155+g1e6c4ea896` and plugin bundle `2cbf0de8a3b5`.

| Case | Boundary exercised |
| --- | --- |
| Dashboard | Real terminal resize through 100×34, 80×24, 150×55, 100×40, 80×18, 100×34; populated history, margins, no stale scrolling, new-file key |
| Agents | Four isolated task checkouts, attention without focus theft, metadata privacy, pane routing, close/restart/restore, normal shutdown |
| Agents crash | Forced editor exit cleans up owned CLI and worker processes |
| Inheritance | Saved/staged/new/deleted/binary source state captured with source checkout/index preserved |
| Task navigation | Active checkout, file counterpart, navigation/root behavior |
| Named launch | Codex/Claude exact branch naming, idle launch, invalid/existing names, unsaved refusal, cancellation |
| Branch launch | Preflight, dirty-state disclosure, continuation and baseline retention, conflicts refuse launch |
| Review | Stable capture, refresh, unified/side-by-side layouts, deletions, binary and symlink handling |
| Review comments | Range anchors, old/new sides, stale status, local persistence across restart |
| Feedback Codex | Explicit preview, queue, cancel, at-most-once handoff, automatic idle submission, draft/permission boundaries |
| Feedback Claude | Same boundary through the Claude hook adapter |
| Integration | Preview, two tasks into one feature, source preservation, dirty/stale refusal, labeled conflict choices/undo, continue/abort/recovery |
| Integration diff3 | Same flow with Git's base-section conflict markers |

The new dashboard regression failed before the fix at 100×34: the artwork began
on row zero with populated history. Height budgeting fixed overflow; a second
failure exposed retained `topline=6` after resizing, which was corrected by
restoring the dashboard viewport when its content fits. Ordinary editor scrolling
is unchanged. The dashboard's scrolloff is local to its own window style.

Fresh installation used temporary XDG config/data/state/cache roots, pinned
commits from local read-only plugin caches, and matching syntax resources.
All 19 packages installed, a second installation was idempotent, headless startup
exposed UzumeAgent/UzumeReview without initialization errors, and the dashboard
resize case passed using the freshly installed bundle. Default editor config
files and `.zshrc` hashes were unchanged. Registration and network downloads were
not exercised in this check.

Changed Lua files passed StyLua; the patch passed `git diff --check`.
No real agent requests, remote pushes, or task/worktree removals were performed.

## Limits and follow-up

- Mock CLI fixtures exercise Uzume's integration contract, not compatibility with
  every new Codex/Claude release or authentication environment.
- This run does not establish Linux/Kitty support or a stable Neovim version
  matrix. It does not measure perceived animation smoothness or GPU frame rate.
- Native pane operations and language packs have earlier manual/disposable
  probes; their permanent coverage is less complete than task/review workflows.
- Crash recovery during every Git mutation boundary, external-process races,
  submodule integration and safe cleanup eligibility remain follow-up work.
- Cached install passing does not establish a fully self-contained fresh-machine
  release installer; syntax artifact distribution is still unfinished.

Raw artifacts remain in the printed temporary directories on the test machine.
The consolidated console log for this run is `/tmp/uzume-main-regressions.log`.
The tests and this record are the durable reproduction path; temporary logs are
not committed source or a substitute for rerunning after behavior changes.

## Final polish: pane motion and Lua organization

Implementation commit: `6d41634`, compared with the pre-polish main baseline
`cb8909f`. The regular editor now defaults to Slide; Ease is removed, with Instant,
Pulse and Spring available. Feature modules are grouped under `agents/`, `review/`,
`integration/`, `layout/`, `ui/` and `core/`; principal require names and storage
paths remain stable. Python resources resolve independently of module depth.

`python3 tests/run.py`: **14/14 cases passed**, with the same Neovim and pinned
bundle as above. The additional `pane_motion.py` case exercises real editor
controls, anchored monotonic split reveal, persistent mode selection, resize,
float/fullscreen/dock restoration, input, external geometry changes, theme changes,
tab switching and close during motion. Agent, review, feedback and integration
cases all passed against the reorganized module paths.

A second isolated cached-install check installed all 19 packages, repeated the
installation, verified startup and Python resource resolution, then passed both
dashboard and pane-motion cases using the fresh bundle. Default `nvim` config and
`.zshrc` hashes remained unchanged. No live model requests were made. New motion,
settings and resource-path Lua plus modified pane operations passed StyLua;
`git diff --check` passed.

Local evidence: `/tmp/uzume-final-regressions.log` and
`/tmp/uzume-polish-install.log`; fresh-install artifacts:
`/var/folders/w1/59nwl5mx3q95qfv8nm8p1vg00000gn/T/uzume-polish-install-15oysdcm`.
These temporary artifacts are not part of the distribution. Previous limitations
remain, especially busy real-agent performance and a supported Neovim/platform
matrix. The separate animation experiment and retained user task branches are
not deletion candidates merely because the accepted behavior ships on main.
