# Historical experiments

These are development probes, not the installed editor. Normal `uzume` startup
and `setup-editor` do not load or install this directory.

`native-sessions/` contains the first native-window and agent-lifetime experiment:
Python fixtures simulate agents and child processes; the later pilot connected
real CLIs in prepared Drudwyn worktrees. The root `spike` launcher runs this old
experiment explicitly. Its controls and session terminology are historical.

The current implementation lives in `editor/`, with its regression suite in
`tests/`. In particular, current Python process/Git helpers in `editor/agent/`
and `editor/review/` are active product code, unlike the old probe scripts here.
See [the maintainer handoff](../docs/HANDOFF.md) for the current architecture.
