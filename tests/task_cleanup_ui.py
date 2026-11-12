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
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:',root)
