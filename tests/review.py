#!/usr/bin/env python3
"""Review through the real editor, with an isolated worktree and mock agent."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt(); require("uzume.agents").start("codex")')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    checkout = Path(agent['task']['cwd'])
    (checkout/'z-extra.txt').write_text('committed change\n')
    subprocess.run(['git','-C',str(checkout),'add','z-extra.txt'],check=True)
    subprocess.run(['git','-C',str(checkout),'-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','agent change'],check=True)
    (checkout/'example.txt').write_text('working change\n')
    (checkout/'new file.txt').write_text('new content\n')
    editor_view = next(p for p in js('require("uzume.editor.sessions").windows(0)') if not p['terminal'])['win']
    do('vim.api.nvim_win_call(' + str(editor_view) + ',function() vim.cmd.diffthis() end)')
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 3)
    rows = js('(function() local r={} for _,i in ipairs(Snacks.picker.get()[1]:items()) do r[i.path]=i.status end return r end)()')
    assert rows == {'example.txt':'M','z-extra.txt':'M','new file.txt':'A'}, rows
    keys('example'); keys('<CR>')
    wait(lambda: js('#vim.tbl_filter(function(w) return vim.wo[w].diff end,vim.api.nvim_list_wins())') == 2)
    texts = js(r'(function() local r={} for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.wo[w].diff then r[#r+1]=table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),"\n") end end return r end)()')
    assert sorted(texts) == ['uncommitted source','working change'], texts
    keys('?')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_help')
    assert 'R refresh the snapshot' in '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    keys('<Esc>')
    wait(lambda: js('vim.wo.diff'))
    print('PASS: task baseline includes committed, working and untracked changes; contextual key guide')
    missing_desc = js('(function() local r={} for _,m in ipairs(vim.api.nvim_buf_get_keymap(0,"n")) do '
                      'if not m.desc or m.desc=="" then r[#r+1]=m.lhs end end return r end)()')
    assert not missing_desc, ('Menu actions need searchable descriptions', missing_desc)
    keys('u')
    assert lua('vim.bo.filetype') == 'diff'
    patch = js('vim.api.nvim_buf_get_lines(0,0,-1,false)')
    assert '-uncommitted source' in patch and '+working change' in patch, patch
    assert lua('vim.api.nvim_get_current_line()') == '+working change', 'Toggle lost the source reading position'
    (checkout/'example.txt').write_text('newer agent edit\n')
    wait(lambda: 'New changes' in lua('vim.inspect(vim.api.nvim_win_get_config(0).footer)'))
    assert js('vim.api.nvim_buf_get_lines(0,0,-1,false)') == patch, 'Live edits replaced the review'
    keys('R')
    wait(lambda: '+newer agent edit' in js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    keys('u')
    assert js('vim.wo.diff')
    assert js('vim.api.nvim_buf_get_lines(0,0,-1,false)') == ['newer agent edit']
    keys('q')
    assert js('vim.fn.jobwait({' + str(agent['job']) + '},0)[1]') == -1
    assert len(js('require("uzume.editor.sessions").windows(0)')) == 2
    assert js('vim.wo[' + str(editor_view) + '].diff'), 'Existing editor diff was not restored'
    do('vim.api.nvim_win_call(' + str(editor_view) + ',function() vim.cmd.diffoff() end)')
    print('PASS: stable review, explicit refresh, unified toggle and layout restoration')
    # Deleted files, staged changes and unavailable previews remain visible.
    (checkout/'example.txt').unlink()
    (checkout/'binary.dat').write_bytes(b'\x00binary')
    (checkout/'empty.txt').write_text('')
    (checkout/'staged.txt').write_text('staged content\n')
    subprocess.run(['git','-C',str(checkout),'add','staged.txt'],check=True)
    (checkout/'link.txt').symlink_to(root)
    index_path = Path(subprocess.check_output(['git','-C',str(checkout),'rev-parse','--git-path','index'],text=True).strip())
    index_before = index_path.read_bytes()
    keys(' av')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 7)
    rows = js('(function() local r={} for _,i in ipairs(Snacks.picker.get()[1]:items()) do r[i.path]=i.status end return r end)()')
    assert rows['example.txt'] == 'D' and rows['staged.txt'] == 'A'
    keys('link.txt'); keys('<CR>')
    assert js('vim.api.nvim_buf_get_lines(0,0,-1,false)') == [str(root)], 'Symlink preview must show the link, not target data'
    assert not js('vim.bo.modifiable') and js('vim.bo.buftype') == 'nofile'
    keys('f')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('binary.dat')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    keys('<CR>')
    assert 'Binary' in lua('vim.api.nvim_get_current_line()'), js('{ft=vim.bo.filetype,lines=vim.api.nvim_buf_get_lines(0,0,-1,false),error=vim.v.errmsg,messages=vim.api.nvim_exec2("messages",{output=true}).output,notifications=vim.tbl_map(function(n) return n.msg end,Snacks.notifier.get_history())}')
    keys('q')
    assert index_path.read_bytes() == index_before, 'Review modified the Git index'
    assert (checkout/'staged.txt').read_text() == 'staged content\n'
    print('PASS: deletion, staged changes, safe symlink preview, binary notice and read-only capture')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
