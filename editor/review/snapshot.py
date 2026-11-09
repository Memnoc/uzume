#!/usr/bin/env python3
"""Read-only, in-memory task review capture. No index, object or worktree writes."""
import difflib
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

FILE_LIMIT = 1024 * 1024
TOTAL_LIMIT = 16 * FILE_LIMIT
FILE_COUNT_LIMIT = 500


def capture(directory, base, check=False):
    root = Path(directory).resolve()

    def git(*args):
        result = subprocess.run(['git', '--no-optional-locks', '--literal-pathspecs', '-c', 'core.fsmonitor=false', '-C', str(root), *args],
                                capture_output=True, timeout=20)
        if result.returncode:
            raise ValueError(result.stderr.decode('utf-8', 'replace').strip())
        return result.stdout

    if not base or any(c not in '0123456789abcdef' for c in base) or len(base) not in (40, 64):
        raise ValueError('The task has no valid starting commit.')
    git('cat-file', '-e', base + '^{commit}')
    def inventory():
        changes = git('diff', '--no-ext-diff', '--no-textconv', '--no-renames', '--name-status', '-z', base, '--').split(b'\0')
        files = {changes[i + 1].decode('utf-8'): changes[i].decode('ascii')
                 for i in range(0, len(changes) - 1, 2)}
        for path in git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0'):
            if path:
                files[path.decode('utf-8')] = 'A'
        stamps = []
        for path, status in sorted(files.items()):
            try:
                info = (root / path).lstat()
                stamp = (info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns, info.st_mode)
            except FileNotFoundError:
                stamp = None
            stamps.append((path, status, stamp))
        return files, hashlib.sha256(json.dumps(stamps).encode()).hexdigest()

    files, fingerprint = inventory()
    if check:
        return fingerprint
    if len(files) > FILE_COUNT_LIMIT:
        raise ValueError('Review exceeds 500 changed files. Split the task into smaller changes.')
    entries, total = [], 0
    for path, status in sorted(files.items()):
        entry = {'path': path, 'display': json.dumps(path, ensure_ascii=False)[1:-1], 'status': status}
        tree = git('ls-tree', '-z', base, '--', path)
        mode = tree.split(b' ', 1)[0] if tree else b''
        current = root / path
        note = None
        before = after = b''
        if mode in (b'160000', b'040000') or (current.is_dir() and not current.is_symlink()):
            note = 'Submodule/directory change: text preview unavailable.'
        elif not current.parent.resolve().is_relative_to(root):
            note = 'Path traverses a symlink outside this checkout; preview omitted.'
        else:
            if tree:
                size = int(git('cat-file', '-s', base + ':' + path))
                if size > FILE_LIMIT:
                    note = 'File exceeds the 1 MiB preview limit.'
                else:
                    before = git('cat-file', 'blob', base + ':' + path)
            try:
                info = current.lstat()
            except FileNotFoundError:
                if status != 'D':
                    raise ValueError('Files changed during capture. Refresh to try again.')
            else:
                if stat.S_ISLNK(info.st_mode):
                    after = os.fsencode(os.readlink(current))
                elif not stat.S_ISREG(info.st_mode):
                    note = 'Special file: text preview unavailable.'
                elif info.st_size > FILE_LIMIT:
                    note = 'File exceeds the 1 MiB preview limit.'
                elif not note:
                    # O_NOFOLLOW prevents a concurrent replacement with an external symlink.
                    fd = os.open(current, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
                    with os.fdopen(fd, 'rb') as stream:
                        opened = os.fstat(stream.fileno())
                        if not stat.S_ISREG(opened.st_mode):
                            raise ValueError('File type changed during capture. Refresh to try again.')
                        after = stream.read(FILE_LIMIT + 1)
                    latest = current.lstat()
                    if (info.st_ino, info.st_size, info.st_mtime_ns) != (latest.st_ino, latest.st_size, latest.st_mtime_ns):
                        raise ValueError('Files changed during capture. Refresh to try again.')
                    if len(after) > FILE_LIMIT:
                        note = 'File exceeds the 1 MiB preview limit.'
        if not note:
            try:
                left, right = before.decode('utf-8'), after.decode('utf-8')
                if '\0' in left or '\0' in right:
                    note = 'Binary file: text preview unavailable.'
            except UnicodeDecodeError:
                note = 'Binary or non-UTF-8 file: text preview unavailable.'
        if note:
            entry.update(note=note, before='', after='', patch=note + '\n')
        else:
            total += len(before) + len(after)
            if total > TOTAL_LIMIT:
                raise ValueError('Review exceeds the 16 MiB capture limit. Split the task into smaller changes.')
            patch = []
            for line in difflib.unified_diff(left.splitlines(keepends=True), right.splitlines(keepends=True),
                                             fromfile='base/' + entry['display'], tofile='task/' + entry['display']):
                patch.append(line if line.endswith('\n') else line + '\n\\ No newline at end of file\n')
            empty = {'A': 'Empty file added.\n', 'D': 'Empty file deleted.\n'}
            entry.update(before=left, after=right, patch=''.join(patch) or empty.get(status, 'File mode/type changed; text is unchanged.\n'))
        entries.append(entry)
    if inventory()[1] != fingerprint:
        raise ValueError('Files changed during capture. Refresh to try again.')
    return {'base': base, 'files': entries, 'fingerprint': fingerprint}


if __name__ == '__main__':
    try:
        print(json.dumps(capture(sys.argv[1], sys.argv[2], '--check' in sys.argv[3:]), ensure_ascii=False))
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
