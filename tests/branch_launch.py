#!/usr/bin/env python3
"""Choose a task's starting branch through the real launch UI before any CLI starts."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt()')
    initial = git('branch','--show-current')
    original_tab = js('vim.api.nvim_get_current_tabpage()')
    # Another local branch with content different from the original checkout.
    git('branch','selected-feature')
    other = root/'selected checkout'
    git('worktree','add',str(other),'selected-feature')
    (other/'example.txt').write_text('saved edits on selected branch\n')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert js('#require("uzume.agents").list()') == 0, 'CLI started before branch selection'
    keys('selected-feature'); keys('<CR>')
    wait(lambda: 'saved changes' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)'))
    assert js('#require("uzume.agents").list()') == 0
    keys('<CR>')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    assert Path(agent['task']['cwd']) != other
    assert (Path(agent['task']['cwd'])/'example.txt').read_text() == 'saved edits on selected branch\n'
    assert js('vim.fn.getcwd()') == agent['task']['cwd']
    assert git('branch','--show-current') == initial
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    print('PASS: branch chosen and saved changes disclosed before agent launch; selected content inherited')
    task_root = Path(agent['task']['cwd'])
    (task_root/'example.txt').write_text('latest edits in the retained task\n')
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + ')')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys(agent['task']['branch']); keys('<CR>')
    wait(lambda: 'saved changes' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)'))
    keys('Continue'); keys('<CR>')
    wait(lambda: js('vim.api.nvim_get_current_tabpage()') == agent['tab'])
    assert js('#require("uzume.agents").list()') == 1
    assert item(1)['job'] == agent['job'] and js('vim.fn.getcwd()') == str(task_root)
    editor = next(p for p in js('require("ainvim.sessions").windows(0)') if not p['terminal'])
    assert js('vim.api.nvim_buf_get_lines(' + str(editor['buf']) + ',0,-1,false)') == ['latest edits in the retained task']
    print('PASS: continuing a task reuses its exact checkout, edits and running CLI')
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + '); vim.cmd.edit(' + json.dumps(str(project/'z-extra.txt')) + ')')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys(agent['task']['branch']); keys('<CR>')
    wait(lambda: 'saved changes' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)'))
    keys('Continue'); keys('<CR>')
    wait(lambda: js('vim.api.nvim_get_current_tabpage()') == agent['tab'])
    editor = next(p for p in js('require("ainvim.sessions").windows(0)') if not p['terminal'])
    assert js('vim.api.nvim_buf_get_name(' + str(editor['buf']) + ')') == str(task_root/'z-extra.txt')
    assert any(file['path'] == str(task_root/'z-extra.txt') for file in item(1)['task']['context']['files'])
    wait(lambda: (Path(agent['directory'])/'fixture.json').exists())
    (Path(agent['directory'])/'exit').write_text('0')
    wait(lambda: item(1).get('exited'))
    do('vim.cmd.stopinsert(); vim.cmd.tabclose()')
    keys(' aC')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys(agent['task']['branch']); keys('<CR>')
    wait(lambda: 'saved changes' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)'))
    keys('Continue'); keys('<CR>')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    resumed = item(1)
    assert resumed['kind'] == 'claude' and resumed['task']['cwd'] == str(task_root)
    assert resumed['task']['base'] == agent['task']['base']
    assert (task_root/'example.txt').read_text() == 'latest edits in the retained task\n'
    print('PASS: closed task is reopened on the same branch with its original review baseline')
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + ')')
    git('branch','committed-only')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('committed-only'); keys('<CR>')
    wait(lambda: 'saved changes' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)'))
    keys('<CR>')
    wait(lambda: js('#require("uzume.agents").list()') == 2)
    current = js('vim.t.uzume_task')
    assert (Path(current['cwd'])/'example.txt').read_text() == 'base\n', 'Unrelated working edits leaked into a branch without a checkout'
    print('PASS: selecting a branch without a checkout uses only that branch committed state')
    # A genuine unmerged index must stop launch without touching the index.
    base = git('rev-parse','HEAD:example.txt')
    unmerged = ('0 ' + '0'*40 + '\texample.txt\n' + ''.join('100644 ' + base + ' ' + str(stage) + '\texample.txt\n' for stage in (1,2,3)))
    subprocess.run(['git','-C',str(other),'update-index','--index-info'],input=unmerged,text=True,check=True)
    other_index = Path(subprocess.check_output(['git','-C',str(other),'rev-parse','--git-path','index'],text=True).strip())
    before_index = other_index.read_bytes()
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + ')')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('selected-feature'); keys('<CR>')
    wait(lambda: 'Resolve conflicts' in lua('vim.inspect(Snacks.notifier.get_history())'))
    assert js('#require("uzume.agents").list()') == 2 and other_index.read_bytes() == before_index
    print('PASS: conflicts refuse launch and leave the selected checkout untouched')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
