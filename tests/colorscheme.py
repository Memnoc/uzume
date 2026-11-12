#!/usr/bin/env python3
"""Named theme isolation, live switching and readable foreground/background pairs."""
from agent_harness import *


def highlights(names):
    return js('(function() local r={} for _,n in ipairs(' +
              json.dumps(names).replace('[', '{').replace(']', '}') +
              ') do r[n]=vim.api.nvim_get_hl(0,{name=n,link=false}) end return r end)()')


def contrast(a, b):
    def light(rgb):
        channels = [(rgb >> shift & 255) / 255 for shift in (16, 8, 0)]
        linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
        return sum(c * weight for c, weight in zip(linear, (.2126, .7152, .0722)))
    lighter, darker = sorted((light(a), light(b)), reverse=True)
    return (lighter + .05) / (darker + .05)


try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    assert lua('vim.g.colors_name') == 'uzume'
    assert 'uzume' in js('vim.fn.getcompletion("", "color")')
    names = ['Normal', 'NormalFloat', 'CursorLine', 'Visual', 'Comment', 'LspInlayHint',
             'Function', 'Keyword', 'String', 'Type', 'Constant', 'Operator',
             'markdownH2', 'markdownUrl', 'SnacksPickerPrompt', 'FloatTitle',
             'DiagnosticError', 'DiagnosticWarn', 'DiagnosticInfo', 'DiagnosticHint',
             'DiagnosticVirtualTextError', 'DiagnosticVirtualTextWarn',
             'DiagnosticVirtualTextInfo', 'DiagnosticVirtualTextHint',
             'DiffAdd', 'DiffDelete', 'DiffText', 'GitSignsNoEOLPreview']
    accepted = highlights(names)
    assert accepted['Function']['fg'] == 0xf6ad75
    assert accepted['Keyword']['fg'] == 0xc4a7e7
    assert accepted['markdownUrl']['fg'] == 0xf6ad75
    for name in ['Function', 'Keyword', 'String', 'Type', 'Constant', 'Operator']:
        ratios = [contrast(accepted[name]['fg'], accepted[bg]['bg'])
                  for bg in ['Normal', 'CursorLine', 'Visual']]
        assert min(ratios) >= 4.5, (name, ratios)
        print(f'{name}: base/cursor/selection ' + ' / '.join(f'{r:.2f}:1' for r in ratios))
    for name in ['Comment', 'LspInlayHint', 'FloatTitle', 'SnacksPickerPrompt',
                 'DiagnosticVirtualTextError', 'DiagnosticVirtualTextWarn',
                 'DiagnosticVirtualTextInfo', 'DiagnosticVirtualTextHint']:
        value = accepted[name]
        background = value.get('bg', accepted['NormalFloat' if name in ['FloatTitle', 'SnacksPickerPrompt'] else 'Normal']['bg'])
        ratio = contrast(value['fg'], background)
        assert ratio >= 4.5, (name, ratio, value)
        print(f'{name}: {ratio:.2f}:1')

    # Preview cancellation must return to Uzume, not to its underlying renderer.
    keys(' uC')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('rose-pine-main')
    wait(lambda: lua('vim.g.colors_name') == 'rose-pine')
    keys('<Esc>')  # Leave Insert mode, then cancel the native picker.
    keys('<Esc>')
    wait(lambda: lua('vim.g.colors_name') == 'uzume')
    assert highlights(names) == accepted
    keys(' uC')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('rose-pine-main')
    wait(lambda: lua('Snacks.picker.get()[1]:current().text') == 'rose-pine-main')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') != 'snacks_picker_input')
    assert lua('vim.g.colors_name') == 'rose-pine'
    do('vim.cmd.colorscheme("uzume")')

    # The dependency must retain its own palette, settings and theme identity.
    do('vim.cmd.colorscheme("rose-pine-main")')
    stock = highlights(names)
    assert stock['Normal']['fg'] == 0xe0def4
    assert stock['Keyword']['fg'] == 0x31748f
    assert stock['markdownH2']['fg'] == 0x9ccfd8
    for name in ['DiagnosticError', 'DiagnosticWarn', 'DiagnosticInfo', 'DiagnosticHint',
                 'DiffAdd', 'DiffDelete', 'DiffText', 'GitSignsNoEOLPreview']:
        assert stock[name] == accepted[name], (name, stock[name], accepted[name])
    for theme in ['rose-pine-moon', 'rose-pine-dawn', 'habamax', 'default', 'rose-pine-main']:
        do('vim.cmd.colorscheme(' + json.dumps(theme) + ')')
        other = highlights(['Normal', 'Function'])
        assert other['Function']['fg'] != 0xf6ad75, theme
        do('vim.cmd.colorscheme("uzume")')
        assert lua('vim.g.colors_name') == 'uzume'
        assert lua('vim.o.background') == 'dark'
        assert highlights(names) == accepted, theme

    do('require("rose-pine").setup({styles={italic=false},palette={main={text="#abcdef"}}}); '
       '_G.theme_saved_options=require("rose-pine.config").options; '
       'vim.cmd.colorscheme("uzume"); '
       'assert(rawequal(_G.theme_saved_options,require("rose-pine.config").options)); '
       'vim.cmd.colorscheme("rose-pine-main")')
    assert highlights(['Normal'])['Normal']['fg'] == 0xabcdef
    do('vim.cmd.colorscheme("uzume")')
    assert highlights(['Normal'])['Normal']['fg'] == 0xe0d4eb
    assert js('vim.fn.exists(":UzumePalette")') == 0
    print('PASS: default/discovery, contrast, semantic colors, light/dark switching, dependency option isolation')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
