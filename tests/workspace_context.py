#!/usr/bin/env python3
"""Real checkout identity, reference-file warnings and readable navigator surfaces."""
import signal
from agent_harness import *


def location():
    return js('require("uzume.ui.location").get()')


def resize(rows, columns):
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', rows, columns, 0, 0))
    os.kill(proc.pid, signal.SIGWINCH)
    wait(lambda: js('vim.o.columns') == columns and js('vim.o.lines') == rows)


try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    # A directly opened file must expose context before any project menu is used.
    keys(' wi')
    assert lua('vim.bo.filetype') == 'uzume_location', 'Space wi did not open context for a directly opened file'
    assert str(project/'example.txt') in '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    keys('<Esc>')
    assert location()['root'] == str(project)
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt()')
    source_tab = js('vim.api.nvim_get_current_tabpage()')
    branch = git('branch', '--show-current')
    wait(lambda: location().get('branch') == branch)
    assert location()['kind'] == 'Project'
    checkout = root / 'task checkout'
    git('worktree', 'add', '-qb', 'task/context', str(checkout))
    task = dict(id='context-fixture', cwd=str(checkout), branch='task/context', label='Long task label', project=str(project))
    do('require("uzume.editor.sessions").create(' + json.dumps(str(checkout)) + ', {name="Task window", '
       'project_name="Project % 日本語",project_root=' + json.dumps(str(project)) + ',empty=true,task=vim.json.decode(' +
       json.dumps(json.dumps(task)) + ')})')
    task_tab = js('vim.api.nvim_get_current_tabpage()')
    do('vim.cmd.edit(' + json.dumps(str(checkout/'example.txt')) + ')')
    wait(lambda: location().get('branch') == 'task/context')
    assert location()['kind'] == 'Task' and not location()['outside']
    assert 'task/context' in lua('require("uzume.ui.location").statusline()')
    do('vim.cmd.edit(' + json.dumps(str(project/'example.txt')) + ')')
    assert location()['outside'] and location()['branch'] == 'task/context'
    assert 'Outside checkout' in lua('require("uzume.ui.location").warning()')
    keys(' wi')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_location')
    context_text = '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    for expected in ('task/context', str(checkout), str(project/'example.txt'), 'OUTSIDE'):
        assert expected in context_text, (expected, context_text)
    keys('<Esc>')
    wait(lambda: lua('vim.bo.buftype') == '')
    subprocess.run(['git','-C',str(checkout),'switch','-qc','task/renamed-externally'],check=True)
    wait(lambda: location().get('branch') == 'task/renamed-externally')
    assert task['branch'] == 'task/context', 'Fixture metadata should remain stale to test actual Git identity'
    subprocess.run(['git','-C',str(checkout),'switch','--detach','-q'],check=True)
    wait(lambda: location().get('branch','').startswith('Detached '))
    do('vim.api.nvim_set_current_tabpage(' + str(source_tab) + ')')
    wait(lambda: location().get('branch') == branch)
    assert location()['kind'] == 'Project'
    do('vim.api.nvim_set_current_tabpage(' + str(task_tab) + ')')
    for theme in ('uzume', 'rose-pine-dawn', 'habamax', 'uzume'):
        do('vim.cmd.colorscheme(' + json.dumps(theme) + '); require("uzume.editor.navigator").open("windows")')
        assert js('vim.api.nvim_get_hl(0,{name="UzumeNavNormal",link=false})') == js('vim.api.nvim_get_hl(0,{name="NormalFloat",link=false})')
        assert js('vim.api.nvim_get_hl(0,{name="UzumeNavSelected",link=false})') == js('vim.api.nvim_get_hl(0,{name="PmenuSel",link=false})')
        keys('<Esc>')
    for rows, columns in ((45,150),(24,80),(20,60),(16,45)):
        resize(rows, columns)
        for kind in ('projects','windows'):
            do('require("uzume.editor.navigator").open(' + json.dumps(kind) + ')')
            view = js('(function() local s=require("uzume.editor.navigator").current; return {config=vim.api.nvim_win_get_config(s.win), lines=vim.api.nvim_buf_get_lines(s.buf,0,-1,false)} end)()')
            assert view['config']['width'] <= columns-2
            assert view['config']['height'] <= rows-2
            assert all(js('vim.fn.strdisplaywidth(' + json.dumps(line, ensure_ascii=False) + ')') <= view['config']['width'] for line in view['lines']), view
            assert any('? keys' in line for line in view['lines']), view
            keys('?')
            wait(lambda: lua('vim.bo.filetype') == 'uzume_help')
            help_text='\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
            assert 's save layout' in help_text and 'x close item' in help_text
            keys('<Esc>'); keys('<Esc>')
    assert git('branch','--show-current') == branch
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    print('PASS: actual checkout branch, external-file warning, context dialog, detached/external branch changes, themed/narrow navigators')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
