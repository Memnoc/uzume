# Uzume

An independent Neovim distribution combining familiar editing, project-owned windows and panes, concurrent agents, and code review.

## Language

**Project**:
A local working environment rooted in a directory, usually a Git repository or checkout, owning a dedicated set of **Windows** and associated **Review** state. It is the user-facing grouping for work; there is no additional session layer above or below it.
_Avoid_: session, project session as a separate entity, distro profile

**Task**:
A unit of work within a **Project**. Starting an AI task creates a dedicated **Window**, branch, and worktree, with editor and agent panes side by side. Independent tasks remain isolated; deliberate shared-checkout collaboration is a later extension.
New tasks inherit saved state from the selected checkout. A task-local snapshot
commit records inherited edits as its review baseline; the source branch and
index are unchanged. Subsequent edits remain isolated.

**Window**:
A switchable container belonging to one **Project**, containing one or more **Panes** and retaining their layout. A window is distinct from an individual pane or a file buffer.
_Avoid_: split as a synonym for window, buffer tab

**Pane**:
A visible editor or terminal surface belonging to a **Window**, presented in a tiled, floating, or zoomed arrangement.

**Agent Instance**:
A directly launched Codex or Claude Code CLI running in a **Pane**, associated with a **Project** and a task checkout; it may create its own **Workers**.

**Marked File**:
A saved local file explicitly included in an agent's context list. Files within
the task checkout are working files; external files are reference material.
Marks are local until supplied alongside a user-submitted prompt. Removing a
mark affects future delivery, not previous conversation history.

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
_Avoid_: close project, terminate agent

**Close Project**:
Ending a **Project**'s active workspace, including its **Windows**, **Panes**, agents and owned processes, while retaining source/worktree files and locally saved layout and review state.
_Avoid_: delete project files, switch project, remove worktree, finish review

**Project Autosave**:
Local persistence of a **Project**'s window/pane arrangement, open-file references, review progress, and draft comments. It is not source-file autosave or authorization to transmit context to an agent.

**Distribution Release**:
A tested combination of the distro, a distro-managed Neovim version, and selected dependencies, installed through an explicit user-controlled update with rollback.

## Mappings

### Native Neovim preview

| Theirs | Ours | Notes |
| --- | --- | --- |
| Tabs sharing an explicit project root | Project | Task tabs may use different worktree directories while retaining the same project identity. |
| Tab page | Window | Retains its pane layout while another window is active. |
| Editor/terminal window | Pane | Native UI terminology differs from our product hierarchy; auxiliary picker windows are not managed panes. |

### Drudwyn

| Theirs | Ours | Notes |
| --- | --- | --- |
| tmux session | Project | Our top-level grouping is explicitly rooted in a project directory; no additional generic session entity is required. |
| tmux window / pane | Window / Pane | A window holds a pane layout; a pane is one editor or terminal surface. Native Neovim API terminology is not the product hierarchy. |
| Agent lifecycle state | Attention Item | Only actionable needs belong in the attention queue; ordinary background work stays quiet. |
| Kill session | Close Project | Uzume owns process cleanup and retains local review state; worktree removal is a separate action. Closing a single window has narrower scope. |

### Codex and Claude Code

| Theirs | Ours | Notes |
| --- | --- | --- |
| Interactive CLI process | Agent Instance | Existing terminal interfaces and official authentication flows remain in use. |
| Spawned subagent | Worker | Discovery and actionable state depend on what each CLI reliably exposes; coverage is not assumed. |
| CLI conversation | Agent Instance | A saved Uzume project workspace does not itself restore or authenticate an agent conversation. Resume behavior requires verification. |
