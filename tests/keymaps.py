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
    do('vim.keymap.set("o", "<leader>zq", function() end, '
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
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
