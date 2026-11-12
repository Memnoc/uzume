#!/usr/bin/env python3
"""Task cleanup through its JSON command interface and disposable real Git repos."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='uzume-cleanup-'))
project, data, state = root/'project', root/'data', root/'state'
project.mkdir(); data.mkdir(); state.mkdir()
def git(cwd, *args):
    return subprocess.check_output(['git','-C',str(cwd),*args],text=True).strip()
git(project,'init','-q','-b','main')
git(project,'config','user.name','Fixture'); git(project,'config','user.email','fixture@example.test')
(project/'file.txt').write_text('base\n')
git(project,'add','.'); git(project,'commit','-qm','base')
base = git(project,'rev-parse','HEAD')
checkout = data/'worktrees/repo/task-one'
checkout.parent.mkdir(parents=True)
git(project,'worktree','add','-qb','task/one',str(checkout))
task = dict(id='task-one', label='One', project=str(project), cwd=str(checkout), branch='task/one', base=base)
records = data/'task-branches'; records.mkdir()
record = records/(hashlib.sha256((str(project)+'\n'+task['branch']).encode()).hexdigest()+'.json')
record.write_text(json.dumps(task))
def call(action, fail=None, **kwargs):
    request = dict(action=action, project=str(project), data=str(data), state=str(state), **kwargs)
    result = subprocess.run(['python3',str(REPO/'editor/agent/cleanup.py')],input=json.dumps(request),text=True,capture_output=True)
    if fail:
        assert result.returncode != 0 and fail in result.stderr, result.stdout+result.stderr
        return
    assert result.returncode == 0, result.stdout+result.stderr
    return json.loads(result.stdout)
items = call('list')['tasks']
assert len(items)==1 and items[0]['task']['branch']=='task/one', items
assert items[0]['status']=='No task changes' and items[0]['blockers']==[], items
assert git(project,'rev-parse','HEAD')==base and checkout.exists()
print('PASS: retained task inventory does not include or modify the primary checkout')
print('Artifacts:',root)
(checkout/'file.txt').write_text('staged version\n'); git(checkout,'add','file.txt')
(checkout/'file.txt').write_text('working version\n')
(checkout/'new.txt').write_text('untracked version\n')
original_index=(project/'.git/index').read_bytes()
preview=call('inspect',branch='task/one')
assert preview['status']=='Needs review'
call('remove',fail='Type the exact branch',branch='task/one',token=preview['token'],confirmation='wrong')
assert checkout.exists()
removed=call('remove',branch='task/one',token=preview['token'],confirmation='task/one')
assert removed['state']=='removed' and not checkout.exists()
assert 'task/one' not in git(project,'branch','--format=%(refname:short)').splitlines()
assert git(project,'show',removed['refs']['working']+':file.txt')=='working version'
assert git(project,'show',removed['refs']['index']+':file.txt')=='staged version'
assert git(project,'show',removed['refs']['working']+':new.txt')=='untracked version'
assert (project/'.git/index').read_bytes()==original_index and git(project,'rev-parse','HEAD')==base
assert record.exists(), 'Keep historical task metadata for recovery'
print('PASS: explicit removal archives staged, working and untracked contents before pruning, source unchanged')
# Recreate an independent task; its branch may be committed or still dirty.
checkout=data/'worktrees/repo/task-two'
git(project,'worktree','add','-qb','task/two',str(checkout))
task=dict(task,id='task-two',branch='task/two',cwd=str(checkout))
record=records/'two.json';record.write_text(json.dumps(task))
(checkout/'file.txt').write_text('integrated content\n')
def integration(request):
    result=subprocess.run(['python3',str(REPO/'editor/review/integration.py')],input=json.dumps(request),text=True,capture_output=True)
    assert result.returncode==0,result.stderr
    return json.loads(result.stdout)
snapshot=json.loads(subprocess.check_output(['python3',str(REPO/'editor/review/snapshot.py'),str(checkout),base],text=True))
plan=integration(dict(action='prepare',task=task,branch='feature/combined',new=True,
                      fingerprint=snapshot['fingerprint'],storage=str(state/'integrations'),worktrees=str(data/'integrations')))
plan=integration(dict(action='apply',record=plan['record']))
assert call('inspect',branch='task/two')['status']=='Integration recorded'
(checkout/'file.txt').touch()
assert call('inspect',branch='task/two')['status']=='Integration recorded', 'Content proof must survive timestamp changes'
git(Path(plan['cwd']),'switch','--detach','-q');git(project,'branch','-D','feature/combined')
assert call('inspect',branch='task/two')['status']=='Needs review', 'Deleted destination must not count as integrated'
print('PASS: integration evidence compares captured contents and requires a surviving destination branch')
preview=call('inspect',branch='task/two')
(checkout/'file.txt').write_text('new changes after preview\n')
call('remove',fail='changed after preview',branch='task/two',token=preview['token'],confirmation='task/two')
assert checkout.exists()
(checkout/'.gitignore').write_text('private.txt\n');(checkout/'private.txt').write_text('keep ignored\n')
assert 'Ignored files' in ' '.join(call('inspect',branch='task/two')['blockers'])
(checkout/'private.txt').unlink();(checkout/'.gitignore').unlink()
git(project,'worktree','lock',str(checkout))
assert 'locked' in ' '.join(call('inspect',branch='task/two')['blockers'])
git(project,'worktree','unlock',str(checkout))
launch=state/'agents/live';launch.mkdir(parents=True)
(launch/'launch.json').write_text(json.dumps(dict(cwd=str(checkout))))
(launch/'state.json').write_text(json.dumps(dict(state='review',child=os.getpid())))
assert 'Stop the agent' in ' '.join(call('inspect',branch='task/two')['blockers'])
(launch/'state.json').write_text(json.dumps(dict(state='stopped')))
# A shared ownership lease prevents cleanup racing a launch/integration.
import sys
sys.path.insert(0,str(REPO/'editor/agent'))
from task_lock import lease
preview=call('inspect',branch='task/two')
with lease(checkout):
    call('remove',fail='Task is busy',branch='task/two',token=preview['token'],confirmation='task/two')
assert checkout.exists()
assert (project/'.git/index').read_bytes()==original_index
print('PASS: changed previews, ignored files, locked worktrees, active processes and shared leases prevent removal')
# Legacy managed checkouts remain removable without inventing a review baseline.
legacy=data/'worktrees/repo/legacy';git(project,'worktree','add','-qb','old-experiment',str(legacy))
legacy_row=call('inspect',branch='old-experiment')
assert legacy_row['status']=='Review status unknown'
removed_legacy=call('remove',branch='old-experiment',token=legacy_row['token'],confirmation='old-experiment')
assert removed_legacy['state']=='removed' and not legacy.exists()
# Refuse external clean filters: inspecting/removing must not invoke arbitrary tools.
(checkout/'.gitattributes').write_text('file.txt filter=never-run\n')
git(project,'config','filter.never-run.clean','false')
assert 'Clean filters' in ' '.join(call('inspect',branch='task/two')['blockers'])
(checkout/'.gitattributes').unlink()
# Metadata cannot authorize deleting the current source checkout.
forged=dict(task,id=project.name,branch='main',cwd=str(project))
(records/'forged.json').write_text(json.dumps(forged))
assert 'Not a verified' in ' '.join(call('inspect',branch='main')['blockers'])
# Recover all three Git states through the exact documented commands.
restored=root/'recovered'
git(project,'worktree','add','-qb','recovered/task-one',str(restored),removed['refs']['head'])
git(restored,'restore','--source='+removed['refs']['working'],'--worktree','--','.')
git(restored,'read-tree',removed['refs']['index'])
assert (restored/'file.txt').read_text()=='working version\n'
assert (restored/'new.txt').read_text()=='untracked version\n'
assert git(restored,'show',':file.txt')=='staged version'
assert git(restored,'rev-parse','HEAD')==base
assert len(call('history'))==2
print('PASS: legacy cleanup, primary-checkout/filter guards, and recovery of original HEAD, index and working files')
