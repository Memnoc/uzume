"""Own a terminal CLI and its observed descendants; retain lifecycle metadata only."""
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time

from processes import atomic, descendants, snapshot, stop


def hooks(kind):
    events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest",
              "PostToolUse", "Stop", "SessionEnd"]
    events += ["Interrupt"] if kind == "codex" else ["Notification", "StopFailure"]
    command = shlex.join([sys.executable, str(Path(__file__).with_name("hook.py"))])
    return {event: [{"hooks": [{"type": "command", "command": command + " " + event,
                               "timeout": 3}]}] for event in events}


def toml(value):
    if isinstance(value, dict):
        return "{" + ", ".join(json.dumps(k) + " = " + toml(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "[" + ", ".join(toml(v) for v in value) + "]"
    return json.dumps(value)


def command_for(config, root):
    if config["kind"] == "codex":
        command = [config["executable"], "--no-daemon"]
        for event, groups in hooks("codex").items():
            command.extend(["-c", "hooks." + event + "=" + toml(groups)])
    elif config["kind"] == "claude":
        settings = root / "claude-settings.json"
        atomic(settings, {"hooks": hooks("claude")})
        command = [config["executable"], "--settings", str(settings)]
    else:
        raise ValueError("Unsupported agent")
    return command


def main():
    os.umask(0o077)
    root = Path(sys.argv[1])
    config = json.loads((root / "launch.json").read_text())
    events = root / "events"
    events.mkdir(mode=0o700, exist_ok=True)
    env = dict(os.environ)
    # Preserve the user's CLI auth/config homes. Only remove enclosing terminal
    # identities and Uzume's Neovim app selector, never copy credentials.
    for key in ("NVIM_APPNAME", "TMUX", "TMUX_PANE", "NVIM", "NVIM_LISTEN_ADDRESS",
                "CODEX_THREAD_ID", "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT"):
        env.pop(key, None)
    env["UZUME_EVENTS"] = str(events)
    running = True
    parent = os.getppid()

    def interrupted(_sig, _frame):
        nonlocal running
        running = False

    for sig in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(sig, interrupted)
    # Ctrl-C belongs to the CLI's interrupt workflow, not workspace shutdown.
    signal.signal(signal.SIGINT, lambda *_: None)
    record = {"state": "unknown", "evidence": "process", "since": time.time(),
              "reason": "CLI running; inspect login, trust, or hook setup in its terminal"}
    state_path = root / "state.json"
    atomic(state_path, record)
    child, known = None, {}
    print(f"Uzume · {config['kind']} · {config['cwd']}", flush=True)
    print("Esc Esc: editor controls · Space aa: agents · Ctrl-C: CLI interrupt", flush=True)
    if config["kind"] == "codex":
        print("Use /hooks to review Uzume status hooks if Codex requests it.", flush=True)
    try:
        snapshot()  # Fail before launch if process ownership cannot be inspected.
        child = subprocess.Popen(command_for(config, root), cwd=config["cwd"], env=env)
        record["child"] = child.pid
        while running and os.getppid() == parent and child.poll() is None:
            descendants(snapshot(), os.getpid(), known)
            for path in sorted(events.glob("*.json")):
                try:
                    event = json.loads(path.read_text())
                    if event["since"] >= record["since"]:
                        record.update(event, evidence="hook")
                except (OSError, ValueError, KeyError, TypeError):
                    pass
                finally:
                    path.unlink(missing_ok=True)
            atomic(state_path, record)
            time.sleep(0.2)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Could not run agent: {error}", file=sys.stderr, flush=True)
    finally:
        descendants(snapshot(), os.getpid(), known)
        stop(known)
        if child:
            child.wait(timeout=3)
        failed = child is None or (running and os.getppid() == parent and child.returncode != 0)
        record.update(state="failed" if failed else "stopped", evidence="process", since=time.time(),
                      reason="Agent process exited; worktree files retained")
        atomic(state_path, record)
    return child.returncode if running and child else 0


if __name__ == "__main__":
    from task_lock import lease
    try:
        config = json.loads((Path(sys.argv[1]) / "launch.json").read_text())
        with lease(config["cwd"]):
            raise SystemExit(main())
    except (ValueError, OSError) as error:
        atomic(Path(sys.argv[1]) / "state.json", dict(state="failed", evidence="process",
               since=time.time(), reason=str(error)))
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
