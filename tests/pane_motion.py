#!/usr/bin/env python3
"""Pane motion through real editor controls, disposable files and terminal UI."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    assert lua('vim.fn.exists(":UzumeMotion")') == '2', 'Pane motion must be available in regular Uzume'
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt()')
    # Observe actual pane geometry while a user invokes the split binding.
    do('''
      _G.motion_frames = {}
      local source = vim.api.nvim_get_current_win()
      vim.api.nvim_input(" pv")
      for i=1,30 do vim.defer_fn(function()
        local w=vim.api.nvim_get_current_win()
        if w~=source and vim.api.nvim_win_get_config(w).relative=="" then
          local p=vim.api.nvim_win_get_position(w)
          table.insert(_G.motion_frames,{col=p[2],width=vim.api.nvim_win_get_width(w)})
        end
      end,i*10) end
    ''')
    time.sleep(.5)
    frames = js('_G.motion_frames')
    assert frames and min(f['width'] for f in frames) < frames[-1]['width'], 'Slide must animate by default'
    assert len({f['col'] + f['width'] for f in frames}) == 1, 'Right reveal must keep its outer edge fixed'
    assert all(a['width'] <= b['width'] for a,b in zip(frames,frames[1:])), 'Default slide must not bounce'
    print('PASS: regular editor defaults to a directional Slide without overshoot')
    for binding, axis, size in [(' pV', 'col', 'width'), (' pS', 'row', 'height')]:
        source = js('vim.api.nvim_get_current_win()')
        source_buffer = js('vim.api.nvim_get_current_buf()')
        do('_G.reverse_frames={}; local source=vim.api.nvim_get_current_win(); '
           'vim.api.nvim_input(' + json.dumps(binding) + '); '
           'for i=1,30 do vim.defer_fn(function() local w=vim.api.nvim_get_current_win(); '
           'if w~=source and vim.api.nvim_win_get_config(w).relative=="" then '
           'local p=vim.api.nvim_win_get_position(w); '
           'table.insert(_G.reverse_frames,{row=p[1],col=p[2],width=vim.api.nvim_win_get_width(w),height=vim.api.nvim_win_get_height(w)}) '
           'end end,i*10) end')
        time.sleep(.5)
        frames = js('_G.reverse_frames')
        assert frames, (binding, 'Split did not open')
        assert min(f[size] for f in frames) < frames[-1][size], (binding, 'No reveal animation')
        assert len({f[axis] for f in frames}) == 1, (binding, 'Outer edge moved')
        assert all(a[size] <= b[size] for a,b in zip(frames,frames[1:])), (binding, 'Slide bounced')
        position = js('vim.api.nvim_win_get_position(' + str(source) + ')')
        assert frames[-1][axis] < position[0 if axis == 'row' else 1], (binding, 'Wrong split direction')
        assert js('vim.api.nvim_get_current_buf()') == source_buffer, 'Editor split must preserve the file'
        do('vim.api.nvim_win_close(0,true); vim.api.nvim_set_current_win(' + str(source) + ')')
    print('PASS: split Left and Up preserve the file and animate inward from a fixed outer edge')
    source = js('vim.api.nvim_get_current_win()')
    keys(' k')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('split left')
    wait(lambda: js('Snacks.picker.get()[1]:items()[1].item.lhs') == ' pV')
    keys('<CR>')
    wait(lambda: js('vim.api.nvim_get_current_win()') != source and js('vim.api.nvim_win_get_config(0).relative') == '')
    time.sleep(.3)
    assert js('vim.api.nvim_win_get_position(0)[2]') < js('vim.api.nvim_win_get_position(' + str(source) + ')[2]')
    do('vim.api.nvim_win_close(0,true); vim.api.nvim_set_current_win(' + str(source) + ')')
    print('PASS: Space k finds Split Editor Left and Enter opens it on the left')


    assert lua('vim.fn.maparg(" uA", "n") ~= ""') == 'true', 'Mode chooser needs the established shortcut'
    keys(' uA')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_list')
    menu = lua('table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),"\\n")')
    assert 'Slide' in menu and 'Instant' in menu and 'Ease' not in menu
    keys('j<CR>')
    assert 'instant' in lua('vim.api.nvim_exec2("UzumeMotion", {output=true}).output')
    # Preference survives a separate editor startup using the same isolated data.
    restart = subprocess.run([NVIM, '--headless', '-i', 'NONE', '+UzumeMotion', '+qa!'],
                             env=env, cwd=project, capture_output=True, text=True, timeout=20)
    assert restart.returncode == 0 and 'instant' in restart.stdout + restart.stderr, restart.stderr
    print('PASS: discoverable modes exclude Ease and preserve Instant across startup')
    do('vim.cmd("UzumeMotion slide"); _G.resize_frames={}; local w=vim.api.nvim_get_current_win(); vim.api.nvim_input(" pR>"); for i=1,30 do vim.defer_fn(function() table.insert(_G.resize_frames,vim.api.nvim_win_get_width(w)) end,i*10) end')
    time.sleep(.5)
    widths = js('_G.resize_frames')
    assert min(widths) < max(widths) and widths[-1] == max(widths), 'Resize must ease to its target'
    keys(' pf')
    time.sleep(.1)
    floating = js('vim.api.nvim_win_get_config(0)')
    keys(' pm'); time.sleep(.1)
    keys(' pm'); time.sleep(.1)
    restored = js('vim.api.nvim_win_get_config(0)')
    assert all(floating[k] == restored[k] for k in ('width','height','row','col')), 'Fullscreen must restore settled geometry'
    keys(' pf')
    assert js('vim.api.nvim_win_get_config(0).relative') == ''
    print('PASS: resize animates and floating/fullscreen/docking preserve geometry')
    before = js('vim.api.nvim_win_get_width(0)')
    do('vim.cmd("UzumeMotion spring"); require("uzume.editor.panes").resize(8,0); vim.cmd("UzumeMotion instant")')
    time.sleep(.5)
    assert js('vim.api.nvim_win_get_width(0)') == before + 8, 'Instant must settle the requested target'
    do('vim.cmd("UzumeMotion slide"); require("uzume.editor.panes").resize(-10,0); vim.api.nvim_win_set_width(0,25)')
    time.sleep(.4)
    assert js('vim.api.nvim_win_get_width(0)') == 25, 'A later native resize must win'
    do('require("uzume.editor.panes").resize(10,0); vim.api.nvim_input("ihello<Esc>")')
    time.sleep(.4)
    assert 'hello' in lua('vim.api.nvim_get_current_line()'), 'Motion must not consume typing'
    assert js('vim.api.nvim_win_get_width(0)') == 35
    do('vim.cmd("undo")')
    # Mode switching and colorscheme changes must restore window-local tint.
    original_highlight = lua('vim.wo.winhighlight')
    do('vim.cmd("UzumeMotion pulse"); require("uzume.editor.panes").resize(1,0)')
    assert 'UzumePanePulse' in lua('vim.wo.winhighlight')
    do('vim.cmd("UzumeMotion instant")')
    assert lua('vim.wo.winhighlight') == original_highlight
    do('vim.cmd("UzumeMotion pulse"); require("uzume.editor.panes").resize(-1,0); vim.cmd.colorscheme("habamax")')
    assert lua('vim.wo.winhighlight') == original_highlight
    do('vim.cmd("UzumeMotion spring"); require("uzume.editor.panes").resize(5,0); vim.cmd("tabnew")')
    other_tab = js('vim.api.nvim_get_current_tabpage()')
    time.sleep(.5)
    assert js('vim.api.nvim_get_current_tabpage()') == other_tab, 'Motion must not steal focus'
    do('vim.cmd("tabclose"); vim.cmd("UzumeMotion slide"); require("uzume.editor.panes").split("below",false); vim.api.nvim_win_close(0,true)')
    remaining = js('vim.api.nvim_list_wins()')
    time.sleep(.4)
    assert js('vim.api.nvim_list_wins()') == remaining, 'Closing an animating pane must not resurrect windows'
    assert lua('vim.v.errmsg') == '', lua('vim.v.errmsg')
    print('PASS: Instant, native resize, typing, theme changes, tab switches and close safely interrupt motion')
    do('vim.cmd("UzumeMotion instant"); vim.o.shell="/bin/sh"')
    for key, axis, before in [('h', 1, True), ('j', 0, False), ('k', 0, True), ('l', 1, False)]:
        source = js('vim.api.nvim_get_current_win()')
        keys(' pN' + key)
        wait(lambda: lua('vim.bo.buftype') == 'terminal')
        job = js('vim.b.terminal_job_id')
        position = js('vim.api.nvim_win_get_position(0)')
        origin = js('vim.api.nvim_win_get_position(' + str(source) + ')')
        assert (position[axis] < origin[axis]) if before else (position[axis] > origin[axis]), (key, position, origin)
        do('vim.cmd.stopinsert(); require("uzume.editor.panes").close()')
        wait(lambda: js('vim.fn.jobwait({' + str(job) + '},0)[1]') != -1)
        do('vim.api.nvim_set_current_win(' + str(source) + ')')
    print('PASS: shell pane shortcuts open left/down/up/right and closing each stops its job')

finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
