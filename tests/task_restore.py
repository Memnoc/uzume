#!/usr/bin/env python3
"""Guided recovery through the public JSON helper and disposable real Git."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='uzume-restore-') as directory:
    root = Path(directory).resolve()
    project, data, state = root/'project', root/'data', root/'state'
    project.mkdir(); (data/'task-branches').mkdir(parents=True); state.mkdir()
    def git(cwd, *args):
        return subprocess.check_output(['git', '-C', str(cwd), *args], text=True).strip()
    git(project, 'init', '-q', '-b', 'main')
    git(project, 'config', 'user.name', 'Fixture'); git(project, 'config', 'user.email', 'fixture@example.test')
    (project/'file.txt').write_text('base\n')
    (project/'deleted.txt').write_text('delete later\n')
    git(project, 'add', '.'); git(project, 'commit', '-qm', 'base')
    base = git(project, 'rev-parse', 'HEAD')
    cwd = data/'worktrees/repo/task'
    git(project, 'worktree', 'add', '-qb', 'task/original', str(cwd))
    task = dict(id='task', project=str(project), cwd=str(cwd), branch='task/original', base=base)
    (data/'task-branches/task.json').write_text(json.dumps(task))
    (cwd/'file.txt').write_text('staged\n'); git(cwd, 'add', 'file.txt')
    (cwd/'file.txt').write_text('working\n'); (cwd/'new.txt').write_text('untracked\n')
    (cwd/'deleted.txt').unlink()
    def call(action, fail=None, env=None, **values):
        result = subprocess.run([sys.executable, str(REPO/'editor/agent/cleanup.py')],
                                input=json.dumps(dict(action=action, project=str(project), data=str(data), state=str(state), **values)),
                                text=True, capture_output=True, env=env)
        if fail:
            assert result.returncode and fail in result.stderr, result.stdout+result.stderr
            return
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout)
    preview = call('inspect', branch=task['branch'])
    receipt = call('remove', branch=task['branch'], confirmation=task['branch'], token=preview['token'])
    index = (project/'.git/index').read_bytes()
    target = root/'recovered with spaces'
    args = dict(archive=receipt['id'], branch='recovered/demo', target=str(target))
    plan = call('restore-plan', **args)
    assert not target.exists() and 'recovered/demo' not in git(project, 'branch', '--format=%(refname:short)').splitlines()
    result = call('restore', **args, token=plan['token'], confirmation=args['branch'])
    assert result['state'] == 'restored' and result['target'] == str(target)
    assert git(target, 'rev-parse', 'HEAD') == base
    assert git(target, 'show', ':file.txt') == 'staged'
    assert (target/'file.txt').read_text() == 'working\n'
    assert (target/'new.txt').read_text() == 'untracked\n'
    assert not (target/'deleted.txt').exists()
    status = subprocess.check_output(['git', '-C', str(target), 'status', '--porcelain'], text=True)
    assert set(status.splitlines()) == {'MM file.txt', ' D deleted.txt', '?? new.txt'}, status
    assert git(project, 'rev-parse', 'HEAD') == base and (project/'.git/index').read_bytes() == index
    assert (project/'file.txt').read_text() == 'base\n'
    assert git(project, 'rev-parse', receipt['refs']['head']) == base
    assert json.loads((state/'task-restores'/(result['id']+'.json')).read_text())['state'] == 'restored'
    print('PASS: preview is read-only; restore preserves HEAD, staging, working edits, deletions and untracked files')
    fresh = dict(args, branch='recovered/second', target=str(root/'second'))
    call('restore-plan', fail='Branch already exists', **dict(fresh, branch=args['branch']))
    call('restore-plan', fail='Directory already exists', **dict(fresh, target=str(target)))
    call('restore-plan', fail='outside existing checkouts', **dict(fresh, target=str(project/'nested')))
    call('restore-plan', fail='absolute directory', **dict(fresh, target='relative'))
    dangling = root/'dangling'; dangling.symlink_to(root/'missing')
    call('restore-plan', fail='Directory already exists', **dict(fresh, target=str(dangling)))
    next_plan = call('restore-plan', **fresh)
    call('restore', fail='Confirm the new branch', **fresh, token=next_plan['token'])
    old_working = git(project, 'rev-parse', receipt['refs']['working'])
    git(project, 'update-ref', receipt['refs']['working'], receipt['refs']['index'])
    call('restore', fail='plan changed', **fresh, token=next_plan['token'], confirmation=fresh['branch'])
    git(project, 'update-ref', receipt['refs']['working'], old_working)
    assert not Path(fresh['target']).exists()
    (project/'.git/info/attributes').write_text('* filter=fixture\n')
    call('restore-plan', fail='filters', **fresh)
    (project/'.git/info/attributes').unlink()
    call('restore-plan', fail='valid recovery snapshot', **dict(fresh, archive='../bad'))
    # Changes between preview and confirmation must not overwrite new work.
    git(project, 'branch', fresh['branch'])
    call('restore', fail='Branch already exists', **fresh, token=next_plan['token'], confirmation=fresh['branch'])
    git(project, 'branch', '-D', fresh['branch'])
    Path(fresh['target']).mkdir(); (Path(fresh['target'])/'keep.txt').write_text('external work\n')
    call('restore', fail='Directory already exists', **fresh, token=next_plan['token'], confirmation=fresh['branch'])
    assert (Path(fresh['target'])/'keep.txt').read_text()=='external work\n'
    (Path(fresh['target'])/'keep.txt').unlink(); Path(fresh['target']).rmdir()
    other=root/'other'; other.mkdir(); git(other, 'init', '-q')
    archive_file=state/'task-cleanup'/(receipt['id']+'.json')
    archive_file.write_text(json.dumps(dict(receipt, task=dict(receipt['task'], project=str(other)))))
    call('restore-plan', fail='another repository', **fresh)
    archive_file.write_text(json.dumps(receipt))
    print('PASS: occupied branches/paths, nesting, symlinks, stale snapshots, invalid IDs, foreign repositories and filters are refused')
    # A failed checkout must keep its partial result and the original archive.
    bin_dir=root/'bin'; bin_dir.mkdir()
    real_git=shutil.which('git')
    wrapper=bin_dir/'git'
    wrapper.write_text('#!'+sys.executable+'\nimport os, sys\n'
                       + 'if "restore" in sys.argv:\n    print("fixture disk failure", file=sys.stderr)\n    sys.exit(1)\n'
                       + f'os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n')
    wrapper.chmod(0o755)
    next_plan=call('restore-plan', **fresh)
    call('restore', fail='Recovery incomplete', env=dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH']),
         **fresh, token=next_plan['token'], confirmation=fresh['branch'])
    assert Path(fresh['target']).is_dir()
    assert git(Path(fresh['target']), 'rev-parse', 'HEAD') == base
    attempts=[json.loads(p.read_text()) for p in (state/'task-restores').glob('*.json')]
    assert any(p['state']=='partial' and 'fixture disk failure' in p['error'] for p in attempts)
    assert git(project, 'rev-parse', receipt['refs']['working']) == old_working
    assert (project/'.git/index').read_bytes() == index
    print('PASS: failed restore keeps the partial checkout, branch, archive and an actionable attempt record')
