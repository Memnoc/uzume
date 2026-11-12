#!/usr/bin/env python3
"""Picker discovery stays cheap; only the selected checkout is inspected."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='uzume-task-inventory-') as directory:
    root = Path(directory)
    project, data, state = root/'project', root/'data', root/'state'
    project.mkdir(); (data/'task-branches').mkdir(parents=True); state.mkdir()
    def git(*args):
        return subprocess.check_output(['git', '-C', str(project), *args], text=True).strip()
    git('init', '-q', '-b', 'main')
    git('config', 'user.name', 'Fixture'); git('config', 'user.email', 'fixture@example.test')
    (project/'file.txt').write_text('baseline\n')
    git('add', '.'); git('commit', '-qm', 'baseline')
    base = git('rev-parse', 'HEAD')
    tasks = []
    for number in range(12):
        cwd = data/'worktrees/repo'/f'task-{number}'
        branch = f'task/{number}'
        git('worktree', 'add', '-qb', branch, str(cwd))
        task = dict(id=cwd.name, label=branch, project=str(project), cwd=str(cwd), branch=branch, base=base)
        tasks.append(task)
        # Exercise discovery of older worktrees without metadata too.
        if number % 2 == 0:
            (data/'task-branches'/f'{number}.json').write_text(json.dumps(task))
    # Trace actual Git calls at the public subprocess seam, forwarding unchanged.
    real_git = shutil.which('git')
    commands = root/'commands.jsonl'
    bin_dir = root/'bin'; bin_dir.mkdir()
    wrapper = bin_dir/'git'
    wrapper.write_text('#!' + sys.executable + '\nimport json, os, sys\n'
                       + f'with open({str(commands)!r}, "a") as stream: stream.write(json.dumps(sys.argv[1:]) + "\\n")\n'
                       + f'os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n')
    wrapper.chmod(0o755)
    env = dict(os.environ, PATH=str(bin_dir)+os.pathsep+os.environ['PATH'])
    def call(action, **values):
        commands.write_text('')
        start = time.perf_counter()
        result = subprocess.run([sys.executable, str(REPO/'editor/agent/cleanup.py')],
                                input=json.dumps(dict(action=action, project=str(project), data=str(data),
                                                      state=str(state), **values)),
                                text=True, capture_output=True, env=env, check=True)
        calls = [json.loads(line) for line in commands.read_text().splitlines()]
        print(f'{action}: {time.perf_counter()-start:.2f}s, {len(calls)} Git processes', flush=True)
        return json.loads(result.stdout), calls
    rows, calls = call('list')
    assert len(rows['tasks']) == len(tasks)
    # A deterministic work budget, independent of CI machine speed: discovery
    # must not read/hash each checkout or launch Git once per task record.
    assert len(calls) <= 3, f'Opening the task list launched {len(calls)} Git processes'
    assert all('token' not in row for row in rows['tasks']), 'Inventory is not a removal preview'
    assert all(row['status'] == 'Not inspected' for row in rows['tasks'])
    preview, calls = call('inspect', branch='task/0')
    assert preview['status'] == 'No task changes' and preview['token']
    roots = {str(Path(args[args.index('-C')+1]).resolve()) for args in calls}
    assert roots <= {str(project.resolve()), str(Path(tasks[0]['cwd']).resolve())}, roots
    assert sum('write-tree' in args for args in calls) == 2, 'Only the selected task needs tree snapshots'
    broken_project = root/'not-a-repository'; broken_project.mkdir()
    record = data/'task-branches/0.json'
    record.write_text(json.dumps(dict(tasks[0], project=str(broken_project))))
    preview, calls = call('inspect', branch='task/0')
    assert preview['status'] == 'Unavailable' and preview['blockers'] and 'token' not in preview
    print('PASS: inventory has constant Git cost; detailed validation only touches the selected task')
