"""SPIKE: describe the explicitly prepared Drudwyn worktrees, never delete them."""
from pathlib import Path
import shutil
import subprocess


def sessions():
    code = Path(__file__).resolve().parents[3]
    repo = code / "tmux-drudwyn"
    common = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True).strip()
    result = []
    for suffix, kind, file in (("sessions", "codex", "session_navigator.rs"), ("workspaces", "claude", "navigator.rs")):
        cwd = code / "uzume-worktrees" / ("drudwyn-" + suffix)
        actual = subprocess.check_output(["git", "-C", str(cwd), "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True).strip()
        branch = subprocess.check_output(["git", "-C", str(cwd), "branch", "--show-current"], text=True).strip()
        if Path(actual).resolve() != Path(common).resolve() or branch != "uzume/clear-filter-" + suffix:
            raise RuntimeError("Pilot worktree identity changed: " + str(cwd))
        if not (cwd / ".uzume-task.md").exists():
            raise RuntimeError("Pilot task is missing: " + str(cwd))
        executable = shutil.which(kind)
        if not executable:
            raise RuntimeError(kind + " is not on PATH; install/login through its official CLI")
        result.append({"id": suffix, "name": suffix, "cwd": str(cwd), "agent": kind,
                       "executable": executable, "file": "src/" + file, "branch": branch})
    return result
