#!/usr/bin/env python3
"""Audit public shortcut coverage and navigator discoverability in real Neovim."""
from agent_harness import *

# Existing editor operations, not every built-in Vim command or optional plugin.
GROUPS = {
    'discovery': ['k', '?', 'sk', 's?', 'l', 'cm'],
    'files': ['e', 'E', 'fe', 'fE', ' ', 'ff', 'fF', 'fg', 'fr', 'fR', 'fp', 'fc', 'fn', ',', 'fb'],
    'search': ['/', 'sg', 'sG', 'sw', 'sb', 'sB', ':', 'sc', 'sC', 'sh', 's"', 'sj', 'sm', 'sR', 'sd', 'sD', 'su', 'n'],
    'buffers': ['bp', 'bj', 'bb', '`', 'bd', 'bo', 'bD'],
    'projects/windows': ['ap', 'as', 'aw', 'ww', 'wn', 'wN', 'w]', 'w[', 'wd', 'wi', 'ws', 'wR'],
    'panes': ['-', '|', 'ps', 'pS', 'pv', 'pV', 'pt', 'pT', 'pNh', 'pNj', 'pNk', 'pNl',
              'pp', 'pf', 'pm', 'pz', 'pr', 'px', 'po', 'pd', 'pgh', 'pgj', 'pgk', 'pgl',
              'pMh', 'pMj', 'pMk', 'pMl', 'pR>', 'pR<', 'pR+', 'pR-', 'pR='],
    'agents': ['ac', 'aC', 'aa', 'ab', 'aB', 'ae', 'aE', 'af', 'aF', 'am', 'ad', 'ar', 'av'],
    'review/integration': ['vr', 'vf', 'vu', 'vR', 'vq', 'vC', 'vs', 'vc', 'vi', 'vI'],
    'git/diagnostics': ['gs', 'gd', 'gl', 'gf', 'ghs', 'ghr', 'ghp', 'ghb', 'cd', 'xq', 'xl'],
    'format/UI': ['cf', 'uf', 'uF', 'uw', 'us', 'uL', 'ul', 'ud', 'uh', 'ug', 'uZ', 'uz', 'uM', 'uC', 'uA', 'uI'],
    'terminal/quit': ['9', 'ft', 'fT', 'qq'],
}
try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    mappings = js('(function() local r={} for _,m in ipairs(vim.api.nvim_get_keymap("n")) do r[(m.lhs:gsub("<lt>","<"))]=m.desc or "" end return r end)()')
    missing = [(group, key) for group, keys_ in GROUPS.items() for key in keys_ if not mappings.get(' ' + key)]
    assert not missing, ('Missing or undescribed shortcuts', missing)
    actions = {key: desc for key, desc in mappings.items() if key.startswith(' ') and desc and 'which-key' not in desc.lower()}
    overlaps = [(a, b) for a in actions for b in actions if a != b and b.startswith(a)]
    assert not overlaps, ('Action prefix conflicts', overlaps)
    do('require("uzume.editor.sessions").adopt()')
    keys(' ap')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_navigator')
    undescribed = js('(function() local r={} for _,m in ipairs(vim.api.nvim_buf_get_keymap(0,"n")) do '
                     'if not m.desc or m.desc=="" then r[#r+1]=m.lhs end end return r end)()')
    assert not undescribed, ('Navigator actions missing descriptions', undescribed)
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('rename')
    wait(lambda: not js('Snacks.picker.get()[1]:is_active()'))
    matches = js('(function() local r={} for _,v in ipairs(Snacks.picker.get()[1]:items()) do '
                 'if v.item.buffer>0 then r[#r+1]=v.item.lhs end end return r end)()')
    assert 'r' in matches, ('Navigator rename is not searchable', matches)
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_navigator')
    keys('q')
    wait(lambda: lua('vim.bo.filetype') != 'uzume_navigator')
    keys(' ws')
    saved = Path(lua('vim.fn.stdpath("state")')) / 'navigator/snapshot.json'
    wait(lambda: saved.exists())
    before = js('vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative=="" end,vim.api.nvim_tabpage_list_wins(0))')
    keys(' wR')
    assert js('vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative=="" end,vim.api.nvim_tabpage_list_wins(0))') == before, 'Restore replaced an active layout'
    print('PASS: %d documented core bindings, no action-prefix conflicts, searchable navigator actions' % sum(map(len,GROUPS.values())))
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
