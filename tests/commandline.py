#!/usr/bin/env python3
"""Floating command line preserves native command execution, editing and completion."""
from agent_harness import *

def floats():
    return js('(function() local r={} for _,w in ipairs(vim.api.nvim_list_wins()) do local b=vim.api.nvim_win_get_buf(w); if vim.bo[b].filetype=="noice" then r[#r+1]={win=w,config=vim.api.nvim_win_get_config(w)} end end; return r end)()')
try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    original = js('vim.api.nvim_get_current_win()')
    keys(':')
    wait(lambda: len(floats()) > 0)
    assert lua('vim.fn.getcmdtype()') == ':'
    keys('let g:uzume_cmdline_test = 4x<BS>2<CR>')
    wait(lambda: lua('vim.g.uzume_cmdline_test') == '42')
    assert js('vim.api.nvim_get_current_win()') == original
    keys(':<Up>')
    assert 'uzume_cmdline_test' in lua('vim.fn.getcmdline()')
    keys('<Esc>')
    keys(':let g:uzume_cancelled = 1<Esc>')
    assert js('vim.g.uzume_cancelled == nil')
    do('vim.api.nvim_create_user_command("UzumeCmdlineFixture",function() end,{})')
    keys(':UzumeCmdlineF<Tab>')
    wait(lambda: lua('vim.fn.getcmdline()') == 'UzumeCmdlineFixture')
    keys('<Esc>')
    for columns in (80, 50, 150):
        do(f'vim.o.columns={columns}')
        keys(':')
        wait(lambda: len(floats()) > 0)
        for entry in floats():
            conf = entry['config']
            assert conf['width'] <= columns - 2, conf
        keys('<Esc>')
    print('PASS: floating command line, native editing/execution/history/completion, cancellation and narrow sizes')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
