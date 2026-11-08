"""Observational hook: retain lifecycle metadata only, never transcripts."""
import json
import os
from pathlib import Path
import sys
import time


def main():
    folder = os.environ.get("UZUME_EVENTS")
    if not folder or not Path(folder).is_dir():
        return
    # Payloads may contain prompts or tool input. Inspect only the fields below;
    # never log the payload, open transcript_path, or return permission decisions.
    raw = sys.stdin.buffer.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024:
        return
    payload = json.loads(raw or b"{}")
    event = payload.get("hook_event_name") or sys.argv[1]
    # Worker stop events must not mark the parent turn complete.
    if payload.get("agent_id") or event.startswith("Subagent"):
        return
    state = None
    if event == "SessionStart":
        state = ("ready", "Agent ready; enter a task")
    elif event in ("UserPromptSubmit", "PreToolUse", "PostToolUse"):
        state = ("working", "Agent is working")
        if event == "PreToolUse" and payload.get("tool_name") in ("AskUserQuestion", "request_user_input"):
            state = ("waiting", "Agent has a question for you")
    elif event == "PermissionRequest":
        state = ("waiting", "Agent needs permission; inspect its terminal")
    elif event == "Stop":
        state = ("review", "Agent turn ended; inspect the result")
    elif event == "StopFailure":
        state = ("failed", "Agent reported a failed turn")
    elif event == "Interrupt":
        state = ("waiting", "Agent interrupted; give it direction")
    elif event == "SessionEnd":
        state = ("stopped", "Agent session ended")
    elif event == "Notification":
        kind = payload.get("notification_type")
        if kind == "permission_prompt":
            state = ("waiting", "Agent needs permission; inspect its terminal")
        elif kind == "idle_prompt":
            state = ("review", "Agent is waiting for your next instruction")
    if state:
        stamp = time.time_ns()
        value = {"event": event, "state": state[0], "reason": state[1], "since": stamp / 1e9}
        path = Path(folder) / f"{stamp}-{os.getpid()}.json"
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(value))
        tmp.replace(path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, IndexError, AttributeError):
        pass  # An observational failure must never decide or block agent work.
    print("{}")
