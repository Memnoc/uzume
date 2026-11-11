#!/usr/bin/env python3
"""Name a branch through the launch shortcut; the CLI opens there without a prompt."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt()')
    original_tab = js('vim.api.nvim_get_current_tabpage()')
    initial = git('branch', '--show-current')
    keys(' ac')
    wait(lambda: lua('vim.bo.filetype') in ('snacks_input', 'snacks_picker_input'))
    assert lua('vim.bo.filetype') == 'snacks_input', 'Space ac must ask for a new branch name, not select an existing branch'
    assert js('#require("uzume.agents").list()') == 0
    assert 'Enter start' in lua('vim.inspect(vim.api.nvim_win_get_config(0).footer)')
    keys('fix/my-task'); keys('<CR>')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    task_root = Path(agent['task']['cwd'])
    assert agent['task']['branch'] == 'fix/my-task'
    assert subprocess.check_output(['git','-C',str(task_root),'branch','--show-current'],text=True).strip() == 'fix/my-task'
    assert js('vim.fn.getcwd()') == str(task_root)
    assert (task_root/'example.txt').read_text() == 'uncommitted source\n'
    assert git('branch','--show-current') == initial
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    wait(lambda: (Path(agent['directory'])/'fixture.json').exists())
    fixture = json.loads((Path(agent['directory'])/'fixture.json').read_text())
    assert 'fix/my-task' not in fixture['args'], 'Branch name must not be passed as an instruction'
    assert not (Path(agent['directory'])/'input.bin').exists(), 'Task name must not be submitted as a prompt'
    print('PASS: Space ac names the exact branch, inherits saved edits, and starts the CLI ready for prompts')
    for name in ('fix/my-task', 'bad name'):
        do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + ')')
        keys(' ac'); wait(lambda: lua('vim.bo.filetype') == 'snacks_input')
        keys(name); keys('<CR>')
        wait(lambda: ('already exists' if name == 'fix/my-task' else 'Invalid branch name') in lua('vim.inspect(Snacks.notifier.get_history())'))
        assert js('#require("uzume.agents").list()') == 1
    keys(' ac'); wait(lambda: lua('vim.bo.filetype') == 'snacks_input'); keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_input')
    assert js('#require("uzume.agents").list()') == 1
    print('PASS: duplicate and invalid names refuse launch; Escape cancels')
    do('vim.api.nvim_buf_set_lines(0,0,-1,false,{"unsaved editor change"})')
    keys(' ac')
    wait(lambda: 'Save the file before marking' in lua('vim.inspect(Snacks.notifier.get_history())'))
    assert js('#require("uzume.agents").list()') == 1
    do('vim.cmd("edit!")')
    keys(' aC'); wait(lambda: lua('vim.bo.filetype') == 'snacks_input')
    keys('feature/claude-task'); keys('<CR>')
    wait(lambda: js('#require("uzume.agents").list()') == 2)
    claude = item(2)
    assert claude['kind'] == 'claude' and claude['task']['branch'] == 'feature/claude-task'
    print('PASS: unsaved edits block launch; Claude uses the same branch-naming flow')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
