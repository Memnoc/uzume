# ai-nvim

An independent Neovim distribution combining familiar editing with concurrent agent sessions and code review.

## Language

**Project**:
A local source directory, usually a Git repository, that provides the context for one or more **Sessions**.

**Task**:
A unit of work within a **Project**; independent features use separate branches and worktrees, while deliberate collaboration may share a checkout.

**Session**:
A managed workspace bound to one project checkout or worktree, containing **Panes**, **Agent Instances**, and associated **Review** state. A session is not a switchable Neovim configuration.
_Avoid_: distro profile, tmux session as an implementation assumption

**Pane**:
A visible editor or terminal surface belonging to a **Session**, presented in a tiled, floating, or zoomed arrangement.

**Agent Instance**:
A directly launched Codex or Claude Code CLI associated with a **Session** and its checkout; it may create its own **Workers**.

**Worker**:
A child agent or process spawned by an **Agent Instance**. Its existence alone does not warrant a separate visible pane or attention entry.

**Attention Item**:
An actionable need associated with an agent and task, such as a request for input, a blocker, a failure, or work ready for review.

**Review Snapshot**:
A fixed view of task changes and the code being reviewed at a particular point in time, remaining stable while the live worktree changes.

**Review**:
A reading and feedback workflow over a **Review Snapshot**, including reviewed progress and comments; refreshing moves it to newer changes and invalidates affected reviewed markers.

**Review Comment**:
Feedback tied to code in a **Review Snapshot**, retaining file, location, and snapshot context so later worktree edits do not silently change its meaning.

**Feedback Delivery**:
An explicit handoff of review comments or selected context to an **Agent Instance**, with a pending state when queued.

**Interrupt**:
Stopping an agent's current work to allow correction while retaining its session and conversation where the CLI supports this behavior.
_Avoid_: terminate session

**Terminate Session**:
Ending a session's running agents and owned processes while retaining worktree files and locally saved session and review state.
_Avoid_: switch session, remove worktree, finish review

**Session Autosave**:
Local persistence of session arrangement, open-file references, review progress, and draft comments. It is not source-file autosave or authorization to transmit context to an agent.

**Distribution Release**:
A tested combination of the distro, a distro-managed Neovim version, and selected dependencies, installed through an explicit user-controlled update with rollback.

## Mappings

### Drudwyn

| Theirs | Ours | Notes |
| --- | --- | --- |
| Worktree workspace in a tmux window | Session | ai-nvim binds a session to one checkout/worktree; it does not adopt Drudwyn's exact tmux hierarchy. |
| Agent lifecycle state | Attention Item | Only actionable needs belong in the attention queue; ordinary background work stays quiet. |
| Kill session or window | Terminate Session | ai-nvim owns process cleanup and retains local review state; worktree removal is a separate action. |

### Codex and Claude Code

| Theirs | Ours | Notes |
| --- | --- | --- |
| Interactive CLI process | Agent Instance | Existing terminal interfaces and official authentication flows remain in use. |
| Spawned subagent | Worker | Discovery and actionable state depend on what each CLI reliably exposes; coverage is not assumed. |
| CLI conversation | Agent Instance | A saved ai-nvim session does not itself restore or authenticate an agent conversation. Resume behavior requires verification. |
