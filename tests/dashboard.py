#!/usr/bin/env python3
"""Responsive home screen and searchable live mappings in the real editor."""
import json
import signal
from agent_harness import *

try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    files = []
    for i in range(6):
        directory = root / f'recent-project-{i}'
        directory.mkdir()
        subprocess.run(['git', 'init', '-q', str(directory)], check=True)
        path = directory / f'recent-{i}.txt'
        path.write_text('recent file\n')
        files.append(str(path))
    do('vim.v.oldfiles = vim.json.decode(' + json.dumps(json.dumps(files)) + ')')
    do('Snacks.dashboard.open()')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_dashboard')
    keys(' ?')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert js('vim.api.nvim_win_get_config(0).relative') != '', 'Keymap search must float'
    keys('Inlay Hints')
    wait(lambda: js('Snacks.picker.get()[1]:items()[1].item.lhs') == ' uh')
    assert js('Snacks.picker.get()[1]:items()[1].item.lhs') == ' uh'
    keys('<C-u>x<BS>')
    wait(lambda: lua('vim.api.nvim_get_current_line()') == '')
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_dashboard')
    print('PASS: Space ? opens floating keymap search; description filtering, complete deletion and Escape work')
    for rows, cols in [(34, 100), (24, 80), (55, 150), (40, 100), (18, 80), (34, 100)]:
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
        os.kill(proc.pid, signal.SIGWINCH)
        wait(lambda: js('vim.o.lines') == rows)
        time.sleep(.5)
        view = js('(function() return {height=vim.api.nvim_win_get_height(0), '
                  'lines=vim.api.nvim_buf_get_lines(0,0,-1,false), '
                  'top=vim.fn.line("w0")} end)()')
        nonempty = [i for i, line in enumerate(view['lines']) if line.strip()]
        assert nonempty[0] >= 2, (rows, 'artwork touches top', nonempty[0])
        assert nonempty[-1] < view['height'] - 1, (rows, 'content clipped', nonempty[-1], view['height'])
        assert view['top'] == 1, (rows, 'dashboard scrolled', view)
        text = '\n'.join(view['lines'])
        for label in ('Find File', 'Explorer', 'New File', 'Find Text', 'Recent Files', 'Search Keymaps', 'Quit'):
            assert label in text, (rows, label)
        if rows >= 24:
            assert 'Projects' in text and 'recent-0.txt' in text and 'recent-project-0' in text, (rows, text)
        print(f'PASS: populated dashboard fits {cols}x{rows} with top/bottom margins', flush=True)
    keys('k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_dashboard' and lua('vim.bo.buftype') == '')
    source_buffer = js('vim.api.nvim_get_current_buf()')
    do('vim.g.keymap_fixture_ran=false; vim.keymap.set({"n","i"}, "<leader>zt", '
       'function() vim.g.keymap_fixture_ran=true end, {buffer=0,desc="Local shortcut fixture"})')
    keys(' ?')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('Local shortcut fixture')
    def fixture_modes():
        return set(js('(function() local r={} for _,v in ipairs(Snacks.picker.get()[1]:items()) do '
                      'if v.item.desc == "Local shortcut fixture" then r[#r+1]=v.item.mode end '
                      'end return r end)()'))
    wait(lambda: fixture_modes() == {'n', 'i'})
    keys('<C-g>')
    wait(lambda: lua('Snacks.picker.get()[1].title') == 'Search Keymaps · Buffer')
    wait(lambda: fixture_modes() == {'n', 'i'})
    keys('<C-b>')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 0)
    keys('<C-g>')
    wait(lambda: lua('Snacks.picker.get()[1].title') == 'Search Keymaps · Global')
    assert not fixture_modes()
    keys('<C-b>')
    wait(lambda: fixture_modes() == {'n', 'i'})
    keys('<CR>')
    wait(lambda: js('vim.api.nvim_get_current_buf()') == source_buffer)
    assert not js('vim.g.keymap_fixture_ran'), 'Reading the guide must not execute the selected mapping'
    keys(' sk')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<Esc>')
    wait(lambda: js('vim.api.nvim_get_current_buf()') == source_buffer)
    do('Snacks.dashboard.open()')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_dashboard')
    print('PASS: dashboard and legacy search entries, mode/scope filtering, return without executing a mapping')
    keys('n')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_dashboard')
    assert lua('vim.api.nvim_get_mode().mode') == 'i'
    print('PASS: dashboard keyboard action after repeated resize')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
