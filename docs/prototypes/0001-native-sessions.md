# First prototype proposal: native sessions and pane interaction

Status: scope approved by Memnoc on 2026-11-06; throwaway prototype implemented on branch `spike/native-sessions`. Human evaluation is pending.

## Question

Can native Neovim windows and terminal jobs deliver a comfortable session and pane workflow while preserving background work and making explicit termination predictable?

## Proposed experiment

Build a throwaway Lua prototype using a separate launch configuration and isolated state paths. It must not change the user's active Neovim configuration. Provide one command to launch it and concise on-screen keyboard help.

Use two sessions rooted in two disposable project directories. Display an editor and simulated agent terminal in each, then exercise a four-agent workload. Simulated agents print progress and transition to needs-input, blocked, and review-ready states; one fixture spawns a child process so ownership and termination can be observed without using paid agents or real credentials.

Implement only enough behavior to evaluate:

- Session switching while background terminal jobs continue.
- Tiled panes, a movable/resizable floating pane, and zoom with layout restoration.
- Keyboard movement/resizing and mouse interaction with an off switch.
- A compact attention indicator and a selector that jumps to an agent needing input, without stealing focus.
- Explicit session termination, checking that owned fixture processes stop while the other session keeps running.

Show current session, pane mode, fixture state, and process identifiers so behavior is observable. Successful fixture cleanup is not proof that real Codex/Claude workers behave identically; a subsequent integration probe must establish that.

## Boundaries

No production plugin stack, real agent authentication, automatic code transmission, worktree creation/removal, review engine, persistence, animations, release installer, or optional automatic focus in this first experiment. These remain product requirements or later experiments, not silently dropped features.

Keep state in memory and code clearly marked as throwaway. After scope confirmation, follow Northstar's spike workflow on a throwaway branch. The resulting verdict should identify what native APIs can handle comfortably, where interaction feels awkward, and what needs a different design.

## Hands-on evaluation

1. Start simulated work in both sessions; switch repeatedly and verify that hidden work continues.
2. Navigate, resize, float, move, and zoom panes with keyboard and mouse. Disable the mouse and repeat keyboard actions.
3. Trigger attention in a hidden session, continue reading, then choose to jump to the waiting agent.
4. Terminate one session and verify its fixture and child stop; verify the other session is unaffected.
5. Quit the prototype and inspect for leftover fixture processes.
6. Try the same flow in Ghostty and WezTerm, recording available platform coverage and any untested combinations.

The primary verdict is whether the interaction feels worth building upon. Record responsiveness and visible redraw problems under output load; do not claim a measured FPS based on timer settings. Bring the verdict back to the design before writing production tickets.

## Follow-up experiment

Separately prototype the side-by-side review loop: fixed snapshot, navigation, comments, explicit submission, queued/interrupt controls, newer-change indicator, and refresh. Initially use fixtures for agent delivery. Real CLI lifecycle and input behavior must be verified before committing to delivery guarantees.

## Initial findings

The native API experiment supports continuing with hands-on evaluation. On macOS with Neovim `v0.12.0-dev-2155+g1e6c4ea896`, direct RPC exercises and terminal input checks verified:

- Four fixture agents and four spawned workers run across two project tabs, and hidden-session heartbeat counters continue advancing.
- Triggering attention in a hidden session leaves the current session and focus in place; the selector identifies the project, agent, reason, and waiting time.
- A terminal window can become a float, move, resize, zoom, restore, and become a tiled window again without restarting its job.
- Injected mouse events move and resize floating windows and swap tiled panes; native separators retain native mouse resizing.
- Keyboard session selection, terminal input, function-key focus changes from terminal input, and leader-based floating work through a PTY.
- Explicit session termination removes that session's two agent processes and two child workers while the other session continues.
- Normal exit removes the remaining fixture processes and the scratch directory.
- Forced termination of only Neovim also leaves no fixture agents/workers: the launcher's fallback cleanup removes remaining owned processes and scratch state.
- Mouse-off input, help, and pane transitions also work at an 80-by-24 grid; a wider terminal is recommended for reading side-by-side panes.

Retiling currently chooses a right-side position rather than restoring the original tile slot. Zoom preserves the underlying layout. Those are intentionally different operations in the spike and need user feedback.

No persistent test suite was added: these are development probes and manual smoke checks, in keeping with Northstar's throwaway spike workflow. Linux, minimum supported Neovim, terminal-specific behavior in Ghostty/WezTerm, real agent workers, and end-to-end latency/FPS are unverified. Simulated lifecycle evidence is not a substitute for probing Codex and Claude.

## Further notes

Source is kept on the throwaway branch `spike/native-sessions`, under `spikes/native-sessions/`, with the root `./spike` launcher. Main should retain design/findings and this branch pointer, not absorb the prototype as production implementation. Run it from that branch, report interaction friction, and settle the next design changes before production tickets.
