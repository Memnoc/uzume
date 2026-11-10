#!/usr/bin/env python3
"""Seed an isolated task from saved working state, using a private Git index."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def create(source, target, branch, selection=None):
    source = Path(source).resolve()
    env = dict(os.environ)
    for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR',
                'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES'):
        env.pop(key, None)
    env['GIT_OPTIONAL_LOCKS'] = '0'

    def git(*args, environment=None, data=None):
        result = subprocess.run(['git', '--literal-pathspecs', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null',
                                 '-C', str(source), *args], input=data, capture_output=True,
                                env=environment or env, timeout=45)
        if result.returncode:
            raise ValueError(result.stderr.decode('utf-8', 'replace').strip())
        return result.stdout

    if selection:
        selection = json.loads(selection)
        selected = git('rev-parse', '--verify', 'refs/heads/' + selection['branch'] + '^{commit}').decode().strip()
        if selected != selection['head']:
            raise ValueError('The selected branch moved. Choose it again before launching.')
        if not selection['checkout']:
            git('worktree', 'add', '-b', branch, str(target), selected)
            return {'base': selected, 'source_head': selected, 'source_branch': selection['branch'], 'inherited': False}
        current = git('symbolic-ref', '--short', 'HEAD').decode().strip()
        if current != selection['branch']:
            raise ValueError('The selected checkout switched branches. Choose it again before launching.')
    head = git('rev-parse', '--verify', 'HEAD^{commit}').decode().strip()
    if selection and head != selection['head']:
        raise ValueError('The selected branch moved. Choose it again before launching.')
    if git('ls-files', '--unmerged', '-z'):
        raise ValueError('Resolve merge conflicts before starting a new agent task.')
    for entry in git('ls-files', '--stage', '-z').split(b'\0'):
        if entry.startswith(b'160000 '):
            relative = os.fsdecode(entry.split(b'\t', 1)[1])
            if (source / relative / '.git').exists() and git('-C', relative, 'status', '--porcelain', '-z'):
                raise ValueError('Task inheritance cannot include uncommitted submodule changes yet: ' + relative)
    index = Path(os.fsdecode(git('rev-parse', '--git-path', 'index').rstrip(b'\n')))
    if not index.is_absolute():
        index = source / index
    original_index = index.read_bytes() if index.exists() else None
    with tempfile.TemporaryDirectory(prefix='uzume-inherit-') as temporary:
        private = Path(temporary) / 'index'
        staged = dict(env, GIT_INDEX_FILE=str(private))
        if original_index is not None:
            private.write_bytes(original_index)
            # Expand any shared index in the private copy only.
            git('update-index', '--no-split-index', environment=staged)
        else:
            git('read-tree', head, environment=staged)
        git('add', '--all', '--', '.', environment=staged)
        tree = git('write-tree', environment=staged).decode().strip()
        # A second pass detects ordinary concurrent writes while collecting files.
        git('add', '--all', '--', '.', environment=staged)
        if git('write-tree', environment=staged).decode().strip() != tree:
            raise ValueError('Saved files changed during task creation. Try launching again.')
        if git('rev-parse', 'HEAD').decode().strip() != head or (index.read_bytes() if index.exists() else None) != original_index:
            raise ValueError('The source checkout changed during task creation. Try launching again.')
        inherited = tree != git('rev-parse', head + '^{tree}').decode().strip()
        base = head
        if inherited:
            identity = dict(staged, GIT_AUTHOR_NAME='Uzume', GIT_AUTHOR_EMAIL='uzume@localhost',
                            GIT_COMMITTER_NAME='Uzume', GIT_COMMITTER_EMAIL='uzume@localhost')
            base = git('-c', 'commit.gpgsign=false', 'commit-tree', tree, '-p', head,
                       environment=identity, data=b'Uzume: inherited saved workspace state\n').decode().strip()
    # Only the new task branch is advanced; source HEAD and index are never written.
    git('worktree', 'add', '-b', branch, str(target), base)
    return {'base': base, 'source_head': head, 'source_cwd': str(source), 'inherited': inherited}


if __name__ == '__main__':
    try:
        print(json.dumps(create(*sys.argv[1:])))
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
