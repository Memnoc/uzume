#!/usr/bin/env python3
"""Populated home screen stays visible when the real terminal is resized."""
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
        for label in ('Find File', 'Explorer', 'New File', 'Find Text', 'Recent Files', 'Quit'):
            assert label in text, (rows, label)
        if rows >= 24:
            assert 'Projects' in text and 'recent-0.txt' in text and 'recent-project-0' in text, (rows, text)
        print(f'PASS: populated dashboard fits {cols}x{rows} with top/bottom margins', flush=True)
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
