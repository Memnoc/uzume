# First prototype proposal: native sessions and pane interaction

Status: proposed; scope not yet confirmed. No prototype code exists.

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
