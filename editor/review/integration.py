#!/usr/bin/env python3
"""Explicit local integration. Source indexes and checkouts are never modified."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

from snapshot import capture

for key in list(os.environ):
    if key.startswith('GIT_'):
        os.environ.pop(key)
os.environ.update(GIT_TERMINAL_PROMPT='0', GIT_EDITOR='true', GIT_SEQUENCE_EDITOR='true')


def git(root, *args, data=None, env=None, check=True):
    result = subprocess.run(['git', '--literal-pathspecs', '-c', 'core.fsmonitor=false',
                             '-C', str(root), *args], input=data, capture_output=True,
                            env=env, timeout=60)
    if check and result.returncode:
        raise ValueError(result.stderr.decode('utf-8', 'replace').strip() or result.stdout.decode('utf-8', 'replace').strip())
    return result.stdout if check else result


def oid(root, ref='HEAD'):
    return git(root, 'rev-parse', '--verify', ref + '^{commit}').decode().strip()


def checkout(root, branch):
    for block in git(root, 'worktree', 'list', '--porcelain', '-z').split(b'\0\0'):
        fields = dict(line.decode().partition(' ')[::2] for line in block.split(b'\0') if line)
        if fields.get('branch') == 'refs/heads/' + branch:
            return str(Path(fields['worktree']).resolve())


def same_checkout(first, second):
    return bool(first and second and Path(first).resolve() == Path(second).resolve())


def operation(root):
    for marker in ('CHERRY_PICK_HEAD', 'MERGE_HEAD', 'rebase-merge', 'rebase-apply', 'REVERT_HEAD', 'BISECT_LOG'):
        path = Path(git(root, 'rev-parse', '--git-path', marker).decode().strip())
        if not path.is_absolute():
            path = Path(root) / path
        if path.exists():
            return marker


def clean(root):
    if operation(root):
        raise ValueError('Finish the existing Git operation in the destination first.')
    if git(root, 'status', '--porcelain', '-z', '--untracked-files=all'):
        raise ValueError('Destination has local changes. Save/commit them before integrating; nothing was overwritten.')


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    temporary = path.with_suffix('.tmp-' + uuid.uuid4().hex)
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(value, stream)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def prepare(request):
    task, branch = request['task'], request['branch']
    project = str(Path(task['project']).resolve())
    if branch.startswith('-') or branch == 'HEAD' or git(project, 'check-ref-format', 'refs/heads/' + branch, check=False).returncode:
        raise ValueError('Invalid destination branch name: ' + branch)
    if branch == task['branch']:
        raise ValueError('Choose a destination different from the task branch.')
    snapshot = capture(task['cwd'], task['base'])
    if snapshot['fingerprint'] != request['fingerprint']:
        raise ValueError('Task changed since review. Refresh with Space vR before integrating.')
    if not snapshot['files']:
        raise ValueError('This task has no changes to integrate.')
    if operation(task['cwd']) or git(task['cwd'], 'ls-files', '--unmerged', '-z'):
        raise ValueError('Resolve the task checkout Git operation first.')
    # Submodule working state cannot be represented by a normal file snapshot.
    if any('Submodule/directory' in file.get('note', '') for file in snapshot['files']):
        raise ValueError('Submodule changes require manual integration in this version.')
    exists = git(project, 'show-ref', '--verify', '--quiet', 'refs/heads/' + branch, check=False).returncode == 0
    if request['new'] == exists:
        raise ValueError('Destination branch already exists.' if exists else 'Destination branch no longer exists.')
    start = oid(project, 'HEAD' if request['new'] else 'refs/heads/' + branch)
    cwd = None if request['new'] else checkout(project, branch)
    if cwd:
        clean(cwd)
    key = uuid.uuid4().hex
    path = str(Path(request['storage']) / (key + '.json'))
    plan = dict(id=key, record=path, task=task, project=project, branch=branch, new=request['new'],
                head=start, cwd=cwd, state='preview', fingerprint=snapshot['fingerprint'],
                files=snapshot['files'], paths=[file['path'] for file in snapshot['files']],
                source_branch=git(project, 'symbolic-ref', '--short', 'HEAD').decode().strip() if request['new'] else branch,
                worktree=str(Path(request['worktrees']) / key))
    for record in Path(request['storage']).glob('*.json'):
        old = json.loads(record.read_text())
        if (old.get('state') == 'integrated' and old['project'] == project and old['branch'] == branch
                and old['task']['id'] == task['id'] and old['fingerprint'] == plan['fingerprint']
                and git(project, 'merge-base', '--is-ancestor', old['commit'], start, check=False).returncode == 0):
            raise ValueError('This reviewed task snapshot is already integrated into ' + branch)
    save(path, plan)
    return plan


def task_commit(plan):
    task = plan['task']
    root = task['cwd']
    if capture(root, task['base'], check=True) != plan['fingerprint'] or operation(root):
        raise ValueError('Task changed since preview. Refresh review and prepare integration again.')
    source_head = oid(root)
    if git(root, 'ls-files', '--unmerged', '-z'):
        raise ValueError('Task has unresolved conflicts.')
    with tempfile.TemporaryDirectory(prefix='uzume-integrate-') as temporary:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(temporary) / 'index'))
        git(root, 'read-tree', source_head, env=env)
        git(root, 'add', '--all', '--', '.', env=env)
        tree = git(root, 'write-tree', env=env).decode().strip()
        git(root, 'add', '--all', '--', '.', env=env)
        if git(root, 'write-tree', env=env).decode().strip() != tree or oid(root) != source_head or capture(root, task['base'], check=True) != plan['fingerprint']:
            raise ValueError('Task changed during capture. Refresh review and try again.')
        message = ('Integrate ' + task['label'] + '\n\nUzume task: ' + task['branch']
                   + '\nReview baseline: ' + task['base'] + '\n').encode()
        return git(root, '-c', 'commit.gpgsign=false', 'commit-tree', tree, '-p', task['base'], data=message).decode().strip()


def conflicts(plan):
    return [os.fsdecode(path) for path in git(plan['cwd'], 'diff', '--name-only', '--diff-filter=U', '-z').split(b'\0') if path]


def result(plan, outcome):
    plan['conflicts'] = conflicts(plan)
    if outcome.returncode == 0:
        plan.update(state='integrated', commit=oid(plan['cwd']), error='')
    else:
        plan.update(state='conflicts' if plan['conflicts'] else 'paused',
                    error=(outcome.stderr + outcome.stdout).decode('utf-8', 'replace').strip())
    save(plan['record'], plan)
    return plan


def apply(plan):
    if plan['state'] != 'preview':
        raise ValueError('This integration has already started. Open its status instead.')
    project = plan['project']
    if plan['new']:
        if git(project, 'show-ref', '--verify', '--quiet', 'refs/heads/' + plan['branch'], check=False).returncode == 0:
            raise ValueError('The destination branch was created after preview. Prepare again.')
        if oid(project) != plan['head']:
            raise ValueError('The starting branch moved after preview. Prepare again.')
    elif oid(project, 'refs/heads/' + plan['branch']) != plan['head'] or not same_checkout(checkout(project, plan['branch']), plan['cwd']):
        raise ValueError('The destination moved or changed checkouts. Prepare again.')
    if plan['cwd']:
        clean(plan['cwd'])
        ignored = [os.fsdecode(path) for path in git(plan['cwd'], 'ls-files', '--others', '--ignored', '--exclude-standard', '-z').split(b'\0') if path]
        if any(a == b or a.startswith(b + '/') or b.startswith(a + '/') for a in ignored for b in plan['paths']):
            raise ValueError('Ignored destination files overlap this integration. Move or preserve them before applying.')
    plan['picked'] = task_commit(plan)
    if not plan['cwd']:
        Path(plan['worktree']).parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        args = ['worktree', 'add']
        if plan['new']:
            args += ['-b', plan['branch'], plan['worktree'], plan['head']]
        else:
            args += [plan['worktree'], plan['branch']]
        git(project, *args)
        plan['cwd'] = plan['worktree']
    clean(plan['cwd'])
    plan['state'] = 'applying'
    save(plan['record'], plan)
    return result(plan, git(plan['cwd'], '-c', 'merge.renames=false', 'cherry-pick', plan['picked'], check=False))


def resume(plan, abort=False):
    if plan['state'] not in ('conflicts', 'paused', 'applying'):
        raise ValueError('There is no paused integration to continue.')
    cwd = plan['cwd']
    if git(cwd, 'symbolic-ref', '--short', 'HEAD').decode().strip() != plan['branch'] or oid(cwd) != plan['head']:
        raise ValueError('Destination HEAD changed. Inspect this checkout manually before continuing.')
    if oid(cwd, 'CHERRY_PICK_HEAD') != plan['picked']:
        raise ValueError('The expected cherry-pick is no longer active. Inspect this checkout manually.')
    changed = set(os.fsdecode(path) for path in git(cwd, 'diff', '--name-only', '-z', plan['head'], '--').split(b'\0') if path)
    extra = git(cwd, 'ls-files', '--others', '--exclude-standard', '-z')
    if changed - set(plan['paths']) or extra:
        raise ValueError('Destination contains changes outside this integration. Preserve them before continuing or aborting.')
    if abort:
        git(cwd, 'cherry-pick', '--abort')
        plan.update(state='aborted', conflicts=[], error='')
        save(plan['record'], plan)
        return plan
    for path in plan['paths']:
        file = Path(cwd) / path
        if not file.parent.resolve().is_relative_to(Path(cwd).resolve()):
            raise ValueError('Resolution path traverses a symlink outside the destination: ' + path)
        if file.is_file() and not file.is_symlink():
            with file.open('rb') as stream:
                if any(line.startswith((b'<<<<<<< ', b'=======', b'>>>>>>> ')) for line in stream):
                    raise ValueError('Resolve and save conflict markers first: ' + path)
    git(cwd, 'add', '--all', '--', *plan['paths'])
    return result(plan, git(cwd, 'cherry-pick', '--continue', check=False))


def main(request):
    action = request['action']
    if action == 'prepare':
        return prepare(request)
    path = Path(request['record'])
    plan = json.loads(path.read_text())
    if path.resolve() != Path(plan['record']).resolve():
        raise ValueError('Integration record path does not match.')
    if action == 'status':
        if plan.get('cwd') and plan['state'] in ('conflicts', 'paused', 'applying'):
            plan['conflicts'] = conflicts(plan)
        return plan
    if action == 'sides':
        if request['path'] not in conflicts(plan):
            raise ValueError('This file no longer has unresolved index entries.')
        return {name: git(plan['cwd'], 'show', ':' + str(stage) + ':' + request['path'], check=False).stdout.decode('utf-8', 'replace')
                for name, stage in (('ours', 2), ('theirs', 3))}
    common = Path(git(plan['project'], 'rev-parse', '--git-common-dir').decode().strip())
    if not common.is_absolute():
        common = Path(plan['project']) / common
    lock = common / ('uzume-integration-' + hashlib.sha256(plan['branch'].encode()).hexdigest() + '.lock')
    try:
        fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError('Another integration is operating on this destination. Try again after it finishes.') from None
    os.close(fd)
    try:
        if action == 'apply':
            return apply(plan)
        if action in ('finish', 'abort'):
            return resume(plan, abort=action == 'abort')
        raise ValueError('Unknown integration action')
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        print(json.dumps(main(json.load(sys.stdin))))
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
