#!/usr/bin/env python3
"""Task launch and file navigation keep the editor in the agent's checkout."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt()')
    original_tab = js('vim.api.nvim_get_current_tabpage()')
    original_branch = git('branch', '--show-current')
    keys(' ac')
    choose_new_task()
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    checkout = Path(agent['task']['cwd'])
    assert js('vim.api.nvim_get_current_tabpage()') == agent['tab']
    assert js('vim.fn.getcwd()') == str(checkout)
    assert subprocess.check_output(['git','-C',str(checkout),'branch','--show-current'],text=True).strip() == agent['task']['branch']
    editor = next(p for p in js('require("uzume.editor.sessions").windows(0)') if not p['terminal'])['win']
    # Reading a source/reference file must not silently move task navigation back.
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_win(' + str(editor) + '); vim.cmd.edit(' + json.dumps(str(project/'example.txt')) + ')')
    (checkout/'example.txt').write_text('agent edited this copy\n')
    keys('  ')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert js('Snacks.picker.get()[1]:cwd()') == str(checkout), 'File finder escaped to the original checkout'
    keys('example.txt'); keys('<CR>')
    wait(lambda: lua('vim.bo.buftype') == '')
    do('vim.cmd.checktime()')
    assert js('vim.api.nvim_buf_get_name(0)') == str(checkout/'example.txt')
    assert js('vim.api.nvim_buf_get_lines(0,0,-1,false)') == ['agent edited this copy']
    # Explorer also stays anchored when an original file is explicitly opened.
    do('vim.cmd.edit(' + json.dumps(str(project/'example.txt')) + ')')
    keys(' e')
    wait(lambda: js('#Snacks.picker.get({source="explorer"})') == 1)
    assert js('Snacks.picker.get({source="explorer"})[1]:cwd()') == str(checkout)
    do('for _,p in ipairs(Snacks.picker.get()) do p:close() end; vim.api.nvim_set_current_tabpage(' + str(original_tab) + ')')
    keys('  ')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert js('Snacks.picker.get()[1]:cwd()') == str(project), 'Original window lost its checkout'
    assert git('branch','--show-current') == original_branch
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    print('PASS: task launch selects its branch/worktree; finder and explorer remain task-scoped; original stays unchanged')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
