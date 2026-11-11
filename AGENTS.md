# Working on Uzume

Read [docs/HANDOFF.md](docs/HANDOFF.md) first for the architecture, state paths,
verification, known limits and next work. [CONTEXT.md](CONTEXT.md) defines domain
language; [docs/adr/](docs/adr/README.md) records accepted tradeoffs.

## Work safely in the shared checkout

- Inspect Git status, branch and worktree list before changes. Several historical
  and user-created task worktrees may coexist. Isolate concurrent implementation
  work instead of switching branches underneath another running editor/agent.
- Preserve source files, staged state, user task branches and retained worktrees.
  Product integration is a local delta operation; publishing and cleanup are
  separate actions. Do not assume a squashed task is safe to delete by ancestry.
- Plain `nvim` and its configuration belong to the user. The `uzume` launcher uses
  the compatibility `ai-nvim` app namespace. Do not rename storage paths without
  migration design, or modify the shell/default editor as a side effect of tests.

## Implementation and verification

- Lua owns editor interaction; Python owns the current process/Git helpers. Use
  native APIs and pinned plugins before adding a dependency or rewriting a layer.
- Product hierarchy is Project → Windows → Panes. A native Neovim tabpage is a
  product Window; a native window is a Pane. Independent tasks have separate
  worktrees beneath their project.
- Use the relevant real-editor/Git regression case in `tests/`; external CLI
  fixtures are mocked, application modules are real. `python3 tests/run.py` is
  the consolidated suite for changes spanning the workflow.
- Tests require Neovim and the installed pinned bundle, use disposable XDG roots,
  and must not make real model requests or remote pushes. Installation smoke
  checks should omit `--register` and preserve real shell/default config files.
- Update the relevant feature guide with behavior, controls, implementation,
  state, verification and limits. Record durable architectural decisions in ADRs;
  avoid treating every UI tweak as architecture.
- Keep throwaway experiments on their named branches. The animation spike is an
  evaluation tool, not a production module to merge wholesale.

## Collaboration

Iterate in small increments, preserve the familiar Space-leader controls, and
show useful shortcuts in menus. Ask one design question at a time. Keep progress
updates concise and report verification limits honestly. User instructions take
precedence over this guidance.
