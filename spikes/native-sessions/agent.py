"""SPIKE terminal supervisor. The CLI owns authentication and all permissions."""
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time

from processes import atomic, descendants, snapshot, stop


def hooks(agent):
    events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "Stop", "SessionEnd"]
    events += ["Interrupt"] if agent == "codex" else ["Notification", "StopFailure"]
    command = shlex.join([sys.executable, str(Path(__file__).with_name("hook.py"))])
    return {event: [{"hooks": [{"type": "command", "command": command + " " + event, "timeout": 3}]}] for event in events}


def toml(value):
    if isinstance(value, dict):
        return "{" + ", ".join(json.dumps(k) + " = " + toml(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "[" + ", ".join(toml(v) for v in value) + "]"
    return json.dumps(value)


def command_for(config, root, start_task):
    kind = config["agent"]
    if kind == "codex":
        command = [config["executable"], "--no-daemon"]
        for event, groups in hooks(kind).items():
            command.extend(["-c", "hooks." + event + "=" + toml(groups)])
    else:
        settings = root / ("claude-settings-" + config["id"] + ".json")
        atomic(settings, {"hooks": hooks(kind)})
        command = [config["executable"], "--settings", str(settings)]
    if start_task:
        command.append("Read .uzume-task.md in this worktree and carry out that task. Keep all work on this branch.")
    return command


def main():
    config_path, agent_id, action = sys.argv[1:4]
    configuration = json.loads(Path(config_path).read_text())
    config = next(s for s in configuration["sessions"] if s["id"] == agent_id)
    root = Path(os.environ["UZUME_SPIKE_ROOT"])
    state_path = root / ("agent-" + agent_id + ".json")
    events = root / ("events-" + agent_id)
    events.mkdir(exist_ok=True)
    for old in events.glob("*.json"):
        old.unlink()
    env = dict(os.environ)
    for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "NVIM_APPNAME"):
        original = env.pop("UZUME_ORIGINAL_" + key, None)
        if original is None:
            env.pop(key, None)
        else:
            env[key] = original
    # A terminal inside Neovim is not the outer tmux pane. Do not attribute its
    # hooks to another running Drudwyn session. HOME and agent auth homes stay put.
    for key in ("TMUX", "TMUX_PANE", "NVIM", "NVIM_LISTEN_ADDRESS", "CODEX_THREAD_ID", "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT"):
        env.pop(key, None)
    env["UZUME_EVENTS"] = str(events)
    env["UZUME_AGENT_OWNER"] = str(os.getpid())
    running = True

    def interrupted(_sig, _frame):
        nonlocal running
        running = False

    for sig in (signal.SIGHUP, signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, interrupted)
    record = {"pid": os.getpid(), "child": None, "state": "running", "evidence": "process",
              "reason": "CLI started; finish any login or trust prompts", "since": time.time()}
    atomic(state_path, record)
    rows = snapshot()
    owned = {os.getpid(): rows[os.getpid()]["started"]}
    owned_path = root / ("owned-" + agent_id + ".json")
    atomic(owned_path, owned)
    print(f"uzume pilot · {config['agent']} · {config['cwd']}", flush=True)
    print("Esc Esc, then Space ? for workspace controls. Worktree files persist.", flush=True)
    if config["agent"] == "codex":
        print("Use /hooks to review the session's uzume status hooks if Codex requests it.", flush=True)
    child = None
    known = {}
    try:
        command = command_for(config, root, action == "task")
        child = subprocess.Popen(command, cwd=config["cwd"], env=env)
        record["child"] = child.pid
        while running and child.poll() is None:
            rows = snapshot()
            descendants(rows, os.getpid(), known)
            owned.update(known)
            atomic(owned_path, owned)
            for path in sorted(events.glob("*.json")):
                try:
                    event = json.loads(path.read_text())
                    if event["since"] >= record["since"]:
                        record.update(event, evidence="hook")
                    path.unlink()
                except (OSError, ValueError, KeyError):
                    continue
            atomic(state_path, record)
            time.sleep(0.25)
    finally:
        descendants(snapshot(), os.getpid(), known)
        stop(known)
        if child:
            child.wait(timeout=3)
        record.update(state="stopped" if not running or (child and child.returncode == 0) else "failed",
                      reason="Agent process exited; worktree is preserved", since=time.time(), evidence="process")
        atomic(state_path, record)
    return child.returncode if running and child else 0


if __name__ == "__main__":
    raise SystemExit(main())
