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
