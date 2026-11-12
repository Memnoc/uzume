#!/usr/bin/env python3
"""Inspect retained task checkouts; explicitly archive and remove one task at a time."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from task_lock import lease

ENV = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
ENV.update(GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')

def atomic(path, record):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(record, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)

def git(root, *args, env=None, input=None, check=True):
    result = subprocess.run(['git', '--literal-pathspecs', '-c', 'core.fsmonitor=false',
                             '-c', 'core.hooksPath=/dev/null', '-C', str(root), *args],
                            env=env or ENV, input=input, capture_output=True, timeout=60)
    if check and result.returncode:
        raise ValueError(result.stderr.decode(errors='replace').strip())
    return result.stdout if check else result

def value(root, *args):
    return git(root, *args).decode().strip()

def gitpath(root, name):
    path = Path(value(root, 'rev-parse', '--git-path', name))
    return path if path.is_absolute() else Path(root)/path

def common(root):
    path = Path(value(root, 'rev-parse', '--git-common-dir'))
    return (path if path.is_absolute() else Path(root)/path).resolve()

def worktrees(project):
    return [dict(os.fsdecode(line).partition(' ')[::2] for line in block.split(b'\0') if line)
            for block in git(project, 'worktree', 'list', '--porcelain', '-z').split(b'\0\0') if block]

def records(path):
    for file in sorted(path.glob('*.json')):
        try:
            item = json.loads(file.read_text())
            if isinstance(item, dict):
                yield file, item
        except (OSError, ValueError):
            continue

def trees(root, persist=False):
    # Never touch the user's index or populate their object store during inspection.
    with tempfile.TemporaryDirectory(prefix='uzume-task-trees-') as directory:
        temp = Path(directory)
        env = dict(ENV, GIT_INDEX_FILE=str(temp/'index'))
        if not persist:
            (temp/'objects').mkdir()
            env.update(GIT_OBJECT_DIRECTORY=str(temp/'objects'),
                       GIT_ALTERNATE_OBJECT_DIRECTORIES=str(gitpath(root,'objects').resolve()))
        index = gitpath(root,'index')
        if index.exists():
            shutil.copyfile(index, temp/'index')
            git(root, 'update-index', '--no-split-index', env=env)
        else:
            git(root, 'read-tree', 'HEAD', env=env)
        staged = git(root,'write-tree',env=env).decode().strip()
        git(root,'add','--all','--','.',env=env)
        working = git(root,'write-tree',env=env).decode().strip()
        if any(row.startswith(b'160000 ') for row in git(root,'ls-tree','-r',working,env=env).splitlines()):
            raise ValueError('Submodules or nested repositories require manual cleanup.')
        return staged, working

def running(state, cwd):
    for launch in (state/'agents').glob('*/launch.json'):
        try:
            if Path(json.loads(launch.read_text())['cwd']).resolve() != cwd:
                continue
            status = json.loads((launch.parent/'state.json').read_text())
            child = status.get('child')
            if child:
                try:
                    os.kill(int(child),0)
                    return True
                except ProcessLookupError:
                    continue
                except PermissionError:
                    return True
            if status.get('state') not in ('stopped','failed'):
                return True
        except (OSError, ValueError, KeyError, TypeError):
            # An incomplete launch for this checkout is not evidence of shutdown.
            return True
    return False

def inspect(request, task):
    project, data, state = (Path(request[k]).resolve() for k in ('project','data','state'))
    cwd = Path(task['cwd']).resolve()
    result = dict(task=task, status='Needs review', blockers=[], integrated=[], changes='Unknown')
    blocked = result['blockers']
    if not cwd.is_dir():
        blocked.append('Checkout is missing; repair it manually.'); return result
    entries = worktrees(project)
    entry = next((v for v in entries if Path(v['worktree']).resolve()==cwd), None)
    if (not entry or entry.get('branch') != 'refs/heads/'+task['branch']
            or cwd == project or not (cwd/'.git').is_file()
            or cwd.parent.parent != data/'worktrees' or cwd.name != task['id']
            or common(cwd) != common(project)):
        blocked.append('Not a verified Uzume task checkout; manual cleanup required.'); return result
    result['changes'] = len([p for p in git(cwd,'status','--porcelain','-z','--no-renames','--untracked-files=all').split(b'\0') if p])
    if 'locked' in entry:
        blocked.append('Git worktree is locked.')
    for marker in ('MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD','rebase-merge','rebase-apply','BISECT_LOG'):
        if gitpath(cwd,marker).exists():
            blocked.append('Finish the Git operation: '+marker)
    result['agent_running'] = running(state,cwd)
    if result['agent_running']:
        blocked.append('Stop the agent and close its task window first.')
    if not gitpath(cwd,'index').is_file():
        blocked.append('Git index is missing; repair it manually before cleanup.')
    for _, plan in records(state/'integrations'):
        if (cwd in (Path(plan.get('task',{}).get('cwd','/')).resolve(), Path(plan.get('cwd') or '/').resolve())
                and plan.get('state') in ('applying','paused','conflicts')):
            blocked.append('Finish or abort the pending integration first.')
    ignored = git(cwd,'ls-files','--others','--ignored','--exclude-standard','-z').split(b'\0')
    if any(ignored):
        blocked.append('Ignored files are present; move or remove them yourself before cleanup.')
    if any(row[:1] == b'S' or row[:1].islower() for row in git(cwd,'ls-files','-v','-z').split(b'\0') if row):
        blocked.append('Sparse/assume-unchanged index entries require manual cleanup.')
    if git(cwd,'ls-files','--unmerged','-z'):
        blocked.append('Resolve merge conflicts first.')
    candidates = git(cwd,'ls-files','--cached','--others','--exclude-standard','-z')
    attributes = git(cwd,'check-attr','-z','--stdin','filter','working-tree-encoding',input=candidates).split(b'\0')
    if any(attributes[i] not in (b'unspecified', b'unset') for i in range(2,len(attributes)-1,3)):
        blocked.append('Clean filters or working-tree encodings require manual cleanup; no filters were run.')
    if blocked:
        result['status']='Running' if result.get('agent_running') else 'Blocked'; return result
    head = value(cwd,'rev-parse','HEAD')
    staged, working = trees(cwd)
    baseline = value(cwd,'rev-parse','--verify',task['base']+'^{tree}')
    result.update(head=head, staged=staged, working=working)
    if task.get('baseline_known') is False:
        result['status']='Review status unknown'
    elif working == baseline:
        result['status']='No task changes'
    for _, plan in records(state/'integrations'):
        if (plan.get('state')!='integrated' or plan.get('task',{}).get('id')!=task['id']
                or Path(plan.get('task',{}).get('cwd','/')).resolve()!=cwd):
            continue
        branch, commit, picked = plan.get('branch'),plan.get('commit'),plan.get('picked')
        if not all(isinstance(s,str) and s for s in (branch,commit,picked)):
            continue
        tip = git(project,'rev-parse','--verify','refs/heads/'+branch,check=False)
        captured = git(project,'rev-parse','--verify',picked+'^{tree}',check=False)
        if (tip.returncode==0 and captured.returncode==0 and captured.stdout.decode().strip()==working
                and git(project,'merge-base','--is-ancestor',commit,tip.stdout.decode().strip(),check=False).returncode==0):
            result['integrated'].append(branch)
    if result['integrated']:
        result['status']='Integration recorded'
    result['token']=hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()
    return result

def catalog(request):
    project, data = Path(request['project']).resolve(), Path(request['data']).resolve()
    repo = common(project)
    tasks, warnings = [], []
    for path, task in records(data/'task-branches'):
        try:
            if not all(isinstance(task.get(k),str) and task[k] for k in ('id','project','cwd','branch','base')):
                continue
            if not Path(task['project']).exists() or common(task['project'])!=repo:
                continue
            tasks.append(inspect(request,task))
        except (ValueError,OSError,subprocess.TimeoutExpired) as error:
            tasks.append(dict(task=task,status='Unavailable',blockers=[str(error)],integrated=[],changes='Unknown'))
    removed = [v for _,v in records(Path(request['state'])/'task-cleanup') if v.get('state')=='removed']
    tasks = [row for row in tasks if not any(old['task']==row['task'] and not Path(row['task']['cwd']).exists() for old in removed)]
    known={str(Path(row['task']['cwd']).resolve()) for row in tasks}
    for entry in worktrees(project):
        cwd=Path(entry['worktree']).resolve()
        if str(cwd) in known or cwd.parent.parent!=data/'worktrees' or not entry.get('branch'):
            continue
        task=dict(id=cwd.name,label=cwd.name,project=str(project),cwd=str(cwd),
                  branch=entry['branch'].removeprefix('refs/heads/'),base=entry['HEAD'],baseline_known=False)
        try:
            row=inspect(request,task)
            # Legacy checkouts may lack a reliable original review baseline.
            tasks.append(row)
        except (ValueError,OSError,subprocess.TimeoutExpired) as error:
            tasks.append(dict(task=task,status='Unavailable',blockers=[str(error)],integrated=[],changes='Unknown'))
    tasks.sort(key=lambda row:row['task']['branch'])
    return dict(tasks=tasks,warnings=warnings)

def selected(request):
    matches = [row for row in catalog(request)['tasks'] if row['task']['branch']==request['branch']]
    if len(matches)!=1:
        raise ValueError('Task is missing or ambiguous; refresh the list.')
    return matches[0]

def remove(request):
    preview = selected(request)
    task = preview['task']
    if request.get('confirmation')!=task['branch']:
        raise ValueError('Type the exact branch name to confirm removal.')
    with lease(task['cwd'],exclusive=True):
        current = selected(request)
        if current['blockers']:
            raise ValueError('Removal blocked: '+' '.join(current['blockers']))
        if not request.get('token') or current['token']!=request['token']:
            raise ValueError('Task changed after preview; refresh and inspect it again.')
        staged, working = trees(task['cwd'],persist=True)
        if (staged,working)!=(current['staged'],current['working']):
            raise ValueError('Task changed during archive; refresh and try again.')
        key=uuid.uuid4().hex
        prefix='refs/uzume/removed/'+key
        refs={name:prefix+'/'+name for name in ('head','baseline','index','working')}
        identity=dict(ENV,GIT_AUTHOR_NAME='Uzume',GIT_AUTHOR_EMAIL='uzume@localhost',
                      GIT_COMMITTER_NAME='Uzume',GIT_COMMITTER_EMAIL='uzume@localhost')
        commits={'head':current['head'],'baseline':task['base']}
        for name,tree in (('index',staged),('working',working)):
            commits[name]=git(task['cwd'],'-c','commit.gpgsign=false','commit-tree',tree,'-p',current['head'],
                              env=identity,input=('Uzume task recovery: '+name+'\n').encode()).decode().strip()
        commands='start\n'+''.join('create '+refs[name]+' '+commit+'\n' for name,commit in commits.items())+'prepare\ncommit\n'
        git(request['project'],'update-ref','--stdin',input=commands.encode())
        receipt=dict(id=key,task=task,refs=refs,state='archived',created=time.time(),integrated=current['integrated'])
        storage=Path(request['state'])/'task-cleanup'
        storage.mkdir(parents=True,mode=0o700,exist_ok=True)
        path=storage/(key+'.json'); atomic(path,receipt)
        if selected(request).get('token')!=current['token']:
            raise ValueError('Task changed before removal; checkout kept. Recovery: '+refs['working'])
        try:
            git(request['project'],'worktree','remove','--force',task['cwd'])
            if any(entry.get('branch')=='refs/heads/'+task['branch'] for entry in worktrees(request['project'])):
                raise ValueError('Branch was checked out elsewhere; retained it.')
            git(request['project'],'update-ref','-d','refs/heads/'+task['branch'],current['head'])
            receipt['state']='removed'
        except (ValueError,OSError,subprocess.TimeoutExpired) as error:
            receipt.update(state='partial',error=str(error))
            atomic(path,receipt)
            raise ValueError(str(error)+' Recovery snapshot: '+refs['working']) from None
        atomic(path,receipt)
        return receipt

def main(request):
    if request['action']=='list':
        return catalog(request)
    if request['action']=='inspect':
        return selected(request)
    if request['action']=='remove':
        return remove(request)
    if request['action']=='history':
        repo=common(request['project'])
        return sorted([v for _,v in records(Path(request['state'])/'task-cleanup') if common(v['task']['project'])==repo], key=lambda v:v.get('created',0),reverse=True)
    raise ValueError('Unknown cleanup action')

if __name__=='__main__':
    os.umask(0o077)
    try:
        print(json.dumps(main(json.load(sys.stdin))))
    except (ValueError,OSError,KeyError,TypeError,subprocess.TimeoutExpired) as error:
        print(str(error),file=sys.stderr); sys.exit(1)
