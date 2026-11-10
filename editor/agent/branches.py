"""Read local branches, linked checkouts and launch advisories. Never mutate Git."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def catalog(project):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0')
    for name in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR'):
        env.pop(name, None)

    def git(root, *args, optional=False):
        result = subprocess.run(['git', '-c', 'core.fsmonitor=false', '-C', str(root), *args],
                                env=env, capture_output=True, timeout=15)
        if result.returncode and not optional:
            raise ValueError(result.stderr.decode('utf-8', 'replace').strip())
        return result.stdout

    checkouts = {}
    for block in git(project, 'worktree', 'list', '--porcelain', '-z').split(b'\0\0'):
        fields = dict(line.decode('utf-8', 'surrogateescape').partition(' ')[::2]
                      for line in block.split(b'\0') if line)
        if fields.get('branch'):
            checkouts[fields['branch']] = fields
    entries = []
    for line in git(project, 'for-each-ref', '--format=%(refname)%00%(objectname)', 'refs/heads').splitlines():
        ref, head = line.decode().split('\0')
        entries.append({'branch': ref.removeprefix('refs/heads/'), 'head': head,
                        'worktree': checkouts.get(ref)})

    def inspect(entry):
        checkout = entry.pop('worktree')
        entry.update(changes=0, files=[], conflicts=False, operation=False, checkout=bool(checkout))
        if checkout:
            directory = Path(checkout['worktree'])
            entry['cwd'] = str(directory.resolve())
            entry['unavailable'] = not directory.is_dir() or 'prunable' in checkout
            entry['locked'] = 'locked' in checkout
            if entry['unavailable']:
                return entry
            raw = git(directory, 'status', '--porcelain=v1', '-z', '--untracked-files=normal')
            paths, index = raw.split(b'\0'), 0
            while index < len(paths) and paths[index]:
                status = paths[index][:2].decode()
                name = os.fsdecode(paths[index][3:])
                entry['files'].append(status + ' ' + name)
                entry['conflicts'] |= status in ('DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU')
                index += 2 if 'R' in status or 'C' in status else 1
            entry['changes'] = len(entry['files'])
            for marker in ('MERGE_HEAD', 'rebase-merge', 'rebase-apply', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'BISECT_LOG'):
                marker_path = Path(os.fsdecode(git(directory, 'rev-parse', '--git-path', marker).rstrip(b'\n')))
                if not marker_path.is_absolute(): marker_path = directory / marker_path
                if marker_path.exists(): entry['operation'] = marker
            entry['token'] = hashlib.sha256(raw + entry['head'].encode()).hexdigest()
        if entry['branch'].startswith('uzume/'):
            reflog = git(project, 'reflog', 'show', '--format=%H%x00%gs', 'refs/heads/' + entry['branch'], optional=True)
            for line in reversed(reflog.splitlines()):
                commit, _, subject = line.partition(b'\0')
                if subject.startswith(b'branch: Created from '):
                    entry['base'] = commit.decode()
                    break
        return entry

    with ThreadPoolExecutor(max_workers=4) as workers:
        return list(workers.map(inspect, entries))


if __name__ == '__main__':
    try:
        print(json.dumps(catalog(sys.argv[1])))
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
