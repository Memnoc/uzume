#!/usr/bin/env python3
"""Shortcut relevance and rendered rows through the real editor UI."""
import signal
from agent_harness import *

failures = []
def check(condition, message):
    if not condition:
        failures.append(message)

def search(query):
    keys('<C-u>' + query)
    wait(lambda: not js('Snacks.picker.get()[1]:is_active()'))
    return js('(function() local r={} for _,v in ipairs(Snacks.picker.get()[1]:items()) do '
              'r[#r+1]={key=v.item.lhs,description=v.item.desc} end return r end)()')

try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    do('vim.g.operator_shortcut_ran=false; vim.keymap.set("o", "<leader>zq", function() vim.g.operator_shortcut_ran=true end, '
       '{buffer=0,desc="Long operator fixture with enough words to exercise truncation at narrow widths"})')
    keys(' ?')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    matches = search('swap')
    check(bool(matches) and all('swap' in m['description'].lower() for m in matches),
          ('Unrelated swap results', matches))
    matches = search('move pane')
    found = {m['key'] for m in matches}
    check({' pMh', ' pMj', ' pMk', ' pMl', ' po'} <= found,
          ('Missing move-pane actions', matches))
    check(all('move pane' in m['description'].lower() for m in matches),
          ('Unrelated move-pane results', matches))
    matches = search('move pane left')
    check([m['key'] for m in matches] == [' pMh'], ('Wrong move-pane-left results', matches))
    matches = search('left move pane')
    check([m['key'] for m in matches] == [' pMh'], ('Word order changed search meaning', matches))
    matches = search('Space pMh')
    check([m['key'] for m in matches] == [' pMh'], ('Key search failed', matches))
    check(not search('qxznotashortcut'), 'Nonsense query returned unrelated actions')
    search('long operator fixture')
    for rows, cols in [(34, 100), (24, 80), (22, 60)]:
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
        os.kill(proc.pid, signal.SIGWINCH)
        wait(lambda: js('vim.o.columns') == cols)
        time.sleep(.3)
        view = js('(function() local w=Snacks.picker.get()[1].list.win; '
                  'local lines=vim.api.nvim_buf_get_lines(w.buf,0,-1,false); '
                  'local widths={} for _,line in ipairs(lines) do widths[#widths+1]=vim.fn.strdisplaywidth(line) end; '
                  'return {width=vim.api.nvim_win_get_width(w.win),lines=lines,widths=widths} end)()')
        check(bool(view['lines']) and 'Operator' in view['lines'][0], ('Missing mode label', cols, view))
        check(all(width <= view['width'] for width in view['widths']), ('Clipped row', cols, view))
        # Inline background overrides break both the floating surface and selection.
        backgrounds = js('(function() local w=Snacks.picker.get()[1].list.win; local r={} '
                         'for _,e in ipairs(vim.api.nvim_buf_get_extmarks(w.buf,-1,0,-1,{details=true})) do '
                         'local group=e[4].hl_group; if type(group)=="string" then '
                         'local hl=vim.api.nvim_get_hl(0,{name=group,link=false}); '
                         'if hl.bg then r[#r+1]=group end end end return r end)()')
        check(not backgrounds, ('Inline background blocks', cols, backgrounds))
    assert not failures, failures
    print('PASS: literal multiword/key search, directional action names, full mode labels and uniform row backgrounds')
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_picker_input')
    source_window = js('vim.api.nvim_get_current_win()')
    do('vim.wo.wrap=false; vim.cmd("vsplit"); vim.wo.wrap=false')
    other_window = js('vim.api.nvim_get_current_win()')
    do('vim.api.nvim_set_current_win(' + str(source_window) + ')')
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    search('Toggle Wrap')
    keys('<CR>')
    wait(lambda: js('vim.wo[' + str(source_window) + '].wrap'))
    assert not js('vim.wo[' + str(other_window) + '].wrap'), 'Action ran in the wrong pane'
    assert js('vim.api.nvim_get_current_win()') == source_window
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    search('Toggle Wrap')
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_picker_input')
    assert js('vim.wo[' + str(source_window) + '].wrap'), 'Escape executed the action'
    print('PASS: Space k opens shortcuts; Enter executes in the original pane; Escape only closes')
    source_buffer = js('vim.api.nvim_get_current_buf()')
    do('vim.keymap.set("n", "<leader>z<", "<Cmd>let g:shortcut_rhs_buffer = bufnr() <CR>", '
       '{buffer=0,desc="RHS execution fixture"})')
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    search('RHS execution fixture')
    keys('<CR>')
    wait(lambda: js('vim.g.shortcut_rhs_buffer') == source_buffer)
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    search('long operator fixture')
    keys('<CR>')
    assert lua('vim.bo.filetype') == 'snacks_picker_input', 'Wrong-mode action closed the guide'
    assert not js('vim.g.operator_shortcut_ran'), 'Operator shortcut ran in Normal mode'
    assert 'Operator mode' in lua('vim.inspect(Snacks.notifier.get_history())')
    search('RHS execution fixture')
    do('vim.g.replacement_shortcut_ran=false; vim.keymap.set("n", "<leader>z<", '
       'function() vim.g.replacement_shortcut_ran=true end, '
       '{buffer=' + str(source_buffer) + ',desc="Changed execution fixture"})')
    keys('<CR>')
    assert lua('vim.bo.filetype') == 'snacks_picker_input'
    assert not js('vim.g.replacement_shortcut_ran'), 'Changed mapping ran without refreshing'
    assert 'changed or is overridden' in lua('vim.inspect(Snacks.notifier.get_history())')
    keys('<Esc>')
    print('PASS: buffer-local RHS with literal < executes; wrong-mode and changed mappings are not replayed')


finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
