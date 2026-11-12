#!/usr/bin/env python3
"""Retained-task cleanup through real editor controls; CLIs are fixtures."""
from agent_harness import *

def body():
    return '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
try:
    wait(lambda: lua('vim.v.vim_did_enter')=='1')
    origin=js('vim.api.nvim_get_current_tabpage()')
    do('require("uzume.editor.sessions").adopt(); require("uzume.agents").start("codex")')
    wait(lambda: js('#require("uzume.agents").list()')==1)
    agent=item(1); task=agent['task']; checkout=Path(task['cwd'])
    wait(lambda: (Path(agent['directory'])/'fixture.json').exists())
    (checkout/'z-extra.txt').write_text('keep my task work\n')
    do('vim.cmd.stopinsert()');keys(' at')
    wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('<CR>');wait(lambda: lua('vim.bo.filetype')=='uzume_task_cleanup')
    assert 'Stop' in body() or 'Close' in body(), body()
    keys('x')
    assert lua('vim.bo.filetype')=='uzume_task_cleanup' and checkout.exists()
    keys('q')
    do('require("uzume.editor.projects").close({kind="window",tab=vim.api.nvim_get_current_tabpage()}); vim.api.nvim_set_current_tabpage('+str(origin)+')')
    wait(lambda: not js('#require("uzume.agents").list()'))
    wait(lambda: json.loads((Path(agent['directory'])/'state.json').read_text()).get('state') in ('stopped','failed'))
    keys(' at');wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('<CR>');wait(lambda: lua('vim.bo.filetype')=='uzume_task_cleanup')
    assert 'Needs review' in body() and task['branch'] in body()
    keys('v');wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('z-extra');keys('<CR>');wait(lambda: js('vim.wo.diff'))
    assert js('#require("uzume.agents").list()')==0, 'Review restarted an agent'
    keys('ggc');wait(lambda: lua('vim.bo.filetype')=='uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode')=='i')
    keys('Keep a local review note.');keys('<C-s>');keys('s')
    wait(lambda: lua('vim.bo.filetype')=='uzume_review_feedback')
    assert 'No running agent' in body()
    keys('q');keys('q')
    keys(' at');wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input');keys('<CR>')
    wait(lambda: lua('vim.bo.filetype')=='uzume_task_cleanup')
    keys('x');wait(lambda: lua('vim.bo.filetype')=='snacks_input');keys('<Esc>')
    assert checkout.exists(), 'Cancel removed the task'
    keys('x');wait(lambda: lua('vim.bo.filetype')=='snacks_input')
    keys(task['branch']);keys('<CR>')
    wait(lambda: not checkout.exists())
    wait(lambda: lua('vim.bo.filetype')=='uzume_task_recovery')
    assert 'refs/uzume/removed/' in body() and ' worktree add' in body()
    assert task['branch'] not in git('branch','--format=%(refname:short)').splitlines()
    assert (project/'example.txt').read_text()=='uncommitted source\n'
    print('PASS: running/open task refusal, stopped task review without launch, cancel and confirmed removal with recovery instructions')
    # Guided recovery is also reachable after restarting the history flow.
    keys('q'); keys(' aT'); wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype')=='uzume_task_recovery')
    assert 'r Restore to a new branch' in body(), body()
    target=root/'recovered task'
    def restore_form(destination=target, expected='uzume_restore_preview', branch='recovered/ui-test'):
        keys('r'); wait(lambda: lua('vim.bo.filetype')=='snacks_input')
        keys('<C-u>'+branch); keys('<CR>')
        wait(lambda: lua('vim.bo.filetype')=='snacks_input' and 'directory' in lua('vim.inspect(vim.api.nvim_win_get_config(0).title)'))
        keys('<C-u>'+str(destination)); keys('<CR>')
        wait(lambda: lua('vim.bo.filetype')==expected)
        if expected=='uzume_restore_preview':
            assert 'New branch: '+branch+'\n' in body(), body()
    restore_form(project, 'uzume_restore_error')
    assert 'Directory already exists' in body() and 'e Edit branch / directory' in body(), body()
    keys('<Esc>'); wait(lambda: lua('vim.bo.filetype')=='uzume_task_recovery')
    restore_form()
    assert 'recovered/ui-test' in body() and str(target) in body(), body()
    keys('<Esc>'); wait(lambda: lua('vim.bo.filetype')=='uzume_task_recovery')
    assert not target.exists(), 'Canceling the preview created a checkout'
    restore_form(); keys('<CR>')
    wait(lambda: (target/'z-extra.txt').exists())
    wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('z-extra'); keys('<CR>')
    wait(lambda: js('vim.api.nvim_buf_get_name(0)')==str(target/'z-extra.txt'))
    assert body()=='keep my task work' and js('#require("uzume.agents").list()')==0
    assert js('vim.t.uzume_root')==str(target)
    assert js('vim.t.uzume_project_root')==str(project)
    assert subprocess.check_output(['git','-C',str(target),'branch','--show-current'], text=True).strip()=='recovered/ui-test'
    assert (project/'example.txt').read_text()=='uncommitted source\n'
    print('PASS: history restore preview/cancel, confirmed recovery and file selection without launching an agent')
    # Dismiss a confirmed slow restore: it must finish without reopening its UI.
    gate, started = root/'hold-restore', root/'restore-started'
    real_git=shutil.which('git')
    wrapper=fixtures/'git'
    wrapper.write_text('#!'+sys.executable+'\nimport os, sys, time\nfrom pathlib import Path\n'
                       +f'gate=Path({str(gate)!r})\n'
                       +'if "restore" in sys.argv and gate.exists():\n'
                       +f'    Path({str(started)!r}).touch()\n'
                       +'    deadline=time.monotonic()+10\n'
                       +'    while gate.exists() and time.monotonic()<deadline: time.sleep(0.05)\n'
                       +f'os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n')
    wrapper.chmod(0o755)
    gate.touch()
    keys(' aT'); wait(lambda: lua('vim.bo.filetype')=='snacks_picker_input')
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype')=='uzume_task_recovery')
    background=root/'background recovery'
    restore_form(background, branch='recovered/background')
    keys('<CR>'); wait(started.exists)
    assert 'Closing this view does not cancel' in body(), body()
    keys('q')
    kept_buf=js('vim.api.nvim_buf_get_name(0)'); kept_tab=js('vim.api.nvim_get_current_tabpage()')
    gate.unlink()
    wait(lambda: any(v['state']=='restored' and v['branch']=='recovered/background'
                     for v in (json.loads(p.read_text()) for p in (root/'state/uzume/task-restores').glob('*.json'))))
    time.sleep(.4)
    assert (background/'z-extra.txt').read_text()=='keep my task work\n'
    assert js('vim.api.nvim_get_current_tabpage()')==kept_tab
    assert js('vim.api.nvim_buf_get_name(0)')==kept_buf
    assert lua('vim.bo.filetype')!='snacks_picker_input'
    print('PASS: closing progress keeps the confirmed restore running and does not steal focus on completion')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:',root)
