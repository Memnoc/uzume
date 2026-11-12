"""Restore a cleanup archive into an exclusively new branch and checkout."""
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import time
import uuid

from cleanup import ENV, atomic, common, git, value, worktrees


def archive(request):
    key = request.get('archive', '')
    if not isinstance(key, str) or not re.fullmatch('[0-9a-f]{32}', key):
        raise ValueError('Choose a valid recovery snapshot from history.')
    receipt = json.loads((Path(request['state'])/'task-cleanup'/(key+'.json')).read_text())
    project = Path(request['project']).resolve()
    if receipt.get('id') != key or common(receipt['task']['project']) != common(project):
        raise ValueError('This recovery snapshot belongs to another repository.')
    if receipt.get('state') not in ('removed', 'archived', 'partial'):
        raise ValueError('This snapshot is not available for recovery.')
    commits = {}
    for name in ('head', 'baseline', 'index', 'working'):
        ref = 'refs/uzume/removed/'+key+'/'+name
        if receipt.get('refs', {}).get(name) != ref:
            raise ValueError('Recovery snapshot references are invalid.')
        commits[name] = value(project, 'rev-parse', '--verify', ref+'^{commit}')
    return receipt, commits


def supported(project, commits):
    # Read attributes from each archived index, not the currently open checkout.
    # Detect smudge/encoding hooks before any checkout can execute them.
    with tempfile.TemporaryDirectory(prefix='uzume-restore-check-') as directory:
        env = dict(ENV, GIT_INDEX_FILE=str(Path(directory)/'index'))
        for commit in set(commits.values()):
            entries = git(project, 'ls-tree', '-r', '-z', commit).split(b'\0')
            if any(row.startswith(b'160000 ') for row in entries):
                raise ValueError('Submodules require manual recovery.')
            git(project, 'read-tree', commit, env=env)
            files = git(project, 'ls-files', '-z', env=env)
            attrs = git(project, 'check-attr', '--cached', '-z', '--stdin',
                        'filter', 'working-tree-encoding', input=files, env=env).split(b'\0')
            if any(attrs[i] not in (b'unspecified', b'unset') for i in range(2, len(attrs)-1, 3)):
                raise ValueError('Clean/smudge filters or working-tree encodings require manual recovery.')


def plan(request):
    receipt, commits = archive(request)
    project = Path(request['project']).resolve()
    branch, raw_target = request.get('branch'), request.get('target')
    if not isinstance(branch, str) or not branch or branch.startswith('-') or any(ord(c) < 32 for c in branch):
        raise ValueError('Enter a valid new branch name.')
    git(project, 'check-ref-format', 'refs/heads/'+branch)
    if git(project, 'show-ref', '--verify', '--quiet', 'refs/heads/'+branch, check=False).returncode == 0:
        raise ValueError('Branch already exists; choose a new branch name.')
    if not isinstance(raw_target, str) or not raw_target or any(ord(c) < 32 for c in raw_target):
        raise ValueError('Choose a new absolute directory path.')
    requested = Path(raw_target).expanduser()
    if not requested.is_absolute():
        raise ValueError('Choose a new absolute directory path.')
    if os.path.lexists(requested):
        raise ValueError('Directory already exists; choose a new directory.')
    target = requested.resolve()
    if not target.parent.is_dir():
        raise ValueError('The parent directory must already exist.')
    occupied = [Path(entry['worktree']).resolve() for entry in worktrees(project)]
    occupied += [common(project)]
    if any(target == path or path in target.parents for path in occupied):
        raise ValueError('Choose a directory outside existing checkouts and Git storage.')
    supported(project, commits)
    result = dict(archive=receipt['id'], original_branch=receipt['task']['branch'],
                  project=str(project), branch=branch, target=str(target), commits=commits)
    result['token'] = hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()
    return result


def restore(request):
    current = plan(request)
    if request.get('confirmation') != current['branch']:
        raise ValueError('Confirm the new branch name before restoring.')
    if request.get('token') != current['token']:
        raise ValueError('Recovery plan changed; preview it again.')
    project, target = current['project'], Path(current['target'])
    commits = current['commits']
    key = uuid.uuid4().hex
    result = dict(current, id=key, state='restoring', created=time.time())
    storage = Path(request['state'])/'task-restores'
    storage.mkdir(mode=0o700, parents=True, exist_ok=True)
    record = storage/(key+'.json')
    atomic(record, result)
    try:
        # mkdir and Git's -b both refuse a target claimed since the preview.
        target.mkdir(mode=0o700)
        git(project, 'worktree', 'add', '--no-checkout', '-b', current['branch'], str(target), commits['head'])
        git(target, 'restore', '--source='+commits['working'], '--worktree', '--', '.')
        git(target, 'read-tree', commits['index'])
        result['state'] = 'restored'
        atomic(record, result)
    except Exception as error:
        result.update(state='partial', error=str(error))
        atomic(record, result)
        raise ValueError(str(error)+'\nRecovery incomplete. Any created branch/directory was kept at '
                         +str(target)+'. The archive is unchanged. Attempt record: '+str(record)) from None
    return result
