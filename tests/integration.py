#!/usr/bin/env python3
"""Local feature integration via real editor controls and disposable Git worktrees."""
from agent_harness import *


def body():
    return '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))


def open_review():
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('z-extra'); keys('<CR>'); wait(lambda: js('vim.wo.diff'))

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    git('config','user.name','Fixture'); git('config','user.email','fixture@example.test')
    if os.environ.get('UZUME_TEST_CONFLICT_STYLE'):
        git('config','merge.conflictStyle',os.environ['UZUME_TEST_CONFLICT_STYLE'])
    middle = ''.join('unchanged line ' + str(n) + '\n' for n in range(16))
    (project/'multi.txt').write_text('base alpha\n' + middle + 'base omega\n')
    git('add','multi.txt'); git('commit','-qm','two-conflict fixture')
    original_tab = js('vim.api.nvim_get_current_tabpage()')
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt(); require("uzume.agents").start("codex")')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    checkout = Path(agent['task']['cwd'])
    (checkout/'z-extra.txt').write_text('task feature\n')
    (checkout/'multi.txt').write_text('destination alpha\n' + middle + 'destination omega\n')
    emit(agent, 'Stop')
    wait(lambda: item(1)['status']['state'] == 'review')
    original_head = git('rev-parse','HEAD')
    source_index = (project/'.git/index').read_bytes()
    task_index = Path(subprocess.check_output(['git','-C',str(checkout),'rev-parse','--git-path','index'],text=True).strip())
    task_index_before = task_index.read_bytes()
    open_review()
    assert lua('vim.fn.maparg(" vi", "n")') != '', 'Review has no integrate action'
    keys(' vi')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('New feature'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_input')
    keys('feature/combined'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    assert 'feature/combined' in body() and '+task feature' in body()
    assert 'uncommitted source' not in body(), 'Inherited edits leaked into integration preview'
    assert 'feature/combined' not in git('branch','--format=%(refname:short)').splitlines(), 'Preview created a branch'
    keys('a')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration' and 'INTEGRATED' in body())
    plan = js('require("uzume.integration").current')
    target = Path(plan['cwd'])
    assert git('show','feature/combined:z-extra.txt') == 'task feature'
    assert git('show','feature/combined:example.txt') == 'base', 'Source inherited edits were merged'
    assert git('rev-list','--count',original_head+'..feature/combined') == '1'
    assert git('rev-parse','HEAD') == original_head and (project/'.git/index').read_bytes() == source_index
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    assert task_index.read_bytes() == task_index_before
    assert (checkout/'z-extra.txt').read_text() == 'task feature\n'
    assert (target/'z-extra.txt').read_text() == 'task feature\n'
    print('PASS: preview before mutation; one local feature commit; inherited edits and both source indexes preserved')
    # An independent task changes the same line. Integrate into the existing feature.
    keys('q')
    do('require("uzume.review").close(); vim.api.nvim_set_current_tabpage(' + str(original_tab) + '); require("uzume.agents").start("claude")')
    wait(lambda: js('#require("uzume.agents").list()') == 2)
    second = item(2)
    second_root = Path(second['task']['cwd'])
    (second_root/'z-extra.txt').write_text('second task version\n')
    (second_root/'multi.txt').write_text('task alpha\n' + middle + 'task omega\n')
    emit(second,'Stop'); wait(lambda: item(2)['status']['state'] == 'review')
    open_review()
    (target/'unrelated.txt').write_text('keep this\n')
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('feature/combined'); keys('<CR>')
    wait(lambda: 'Destination has local changes' in lua('vim.inspect(Snacks.notifier.get_history())'))
    assert (target/'unrelated.txt').read_text() == 'keep this\n'
    (target/'unrelated.txt').unlink()
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('feature/combined'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    keys('a'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('z-extra'); keys('<CR>')
    wait(lambda: js('vim.bo.buftype') == '' and js('vim.wo.diff'))
    assert '<<<<<<<' in body() and 'second task version' in body()
    assert len(js('vim.tbl_filter(function(w) return vim.wo[w].diff end,vim.api.nvim_tabpage_list_wins(0))')) == 3
    assert 'EDIT RESULT' in js('vim.wo.winbar'), 'The editable pane is not labelled clearly'
    assert lua('vim.fn.maparg(" vt", "n")') != '', 'Missing choose-task conflict command'
    conflict_plan = js('require("uzume.integration").current')
    assert conflict_plan['state'] == 'conflicts'
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    keys('c')
    wait(lambda: 'Resolve and save conflict markers' in lua('vim.inspect(Snacks.notifier.get_history())'))
    keys('q')
    keys(' vt')
    assert body() == 'second task version', 'Choose task must remove the current conflict markers'
    keys('u')
    assert '<<<<<<<' in body(), 'Conflict choice must be undoable'
    keys(' vb')
    assert body() == 'task feature\nsecond task version', 'Both must keep destination then task'
    keys('u'); keys(' vo')
    assert body() == 'task feature'
    keys('u'); keys(' vt')
    do('vim.cmd.write()')
    keys(' vf'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('multi'); keys('<CR>')
    wait(lambda: js('vim.bo.buftype') == '' and body().count('<<<<<<<') == 2)
    keys(' vo')
    assert body().count('<<<<<<<') == 1 and body().startswith('destination alpha\n')
    assert middle.rstrip() in body() and 'task omega' in body(), 'Choice replaced unrelated content or another conflict'
    keys('u'); keys(']x'); keys(' vt')
    assert body().count('<<<<<<<') == 1 and body().endswith('task omega')
    keys('[x'); keys(' vm')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('Use DESTINATION'); keys('<CR>')
    wait(lambda: js('vim.bo.buftype') == '')
    assert body() == 'destination alpha\n' + middle + 'task omega'
    result_buf = js('vim.api.nvim_get_current_buf()')
    keys(' vS'); wait(lambda: lua('vim.bo.filetype') == 'uzume_integration' and 'INTEGRATED' in body())
    assert not js('vim.api.nvim_buf_call(' + str(result_buf) + ',function() return vim.fn.maparg(" vt","n") ~= "" end)'), 'Resolver mappings leaked after completion'
    assert not js('vim.tbl_contains(vim.tbl_map(function(w) return vim.wo[w].diff end,vim.api.nvim_tabpage_list_wins(0)),true)'), 'Resolver diff panes remained after completion'
    assert git('show','feature/combined:z-extra.txt') == 'second task version'
    assert git('show','feature/combined:multi.txt') == 'destination alpha\n' + middle + 'task omega'
    assert git('rev-list','--count',original_head+'..feature/combined') == '2'
    assert git('show','feature/combined:example.txt') == 'base'
    assert (second_root/'z-extra.txt').read_text() == 'second task version\n'
    assert git('rev-parse','HEAD') == original_head
    print('PASS: dirty destination refused; second task pauses on a real conflict; editable resolution commits to the same feature')
    integrated_head = git('rev-parse','feature/combined')
    keys('q')
    do('vim.api.nvim_set_current_tabpage(' + str(second['tab']) + ')')
    (second_root/'z-extra.txt').write_text('another task revision\n')
    open_review()
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('feature/combined'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    (second_root/'z-extra.txt').write_text('changed after preview\n')
    keys('a')
    wait(lambda: 'Task changed since preview' in lua('vim.inspect(Snacks.notifier.get_history())'))
    assert git('rev-parse','feature/combined') == integrated_head
    keys('q'); keys('R')
    wait(lambda: 'changed after preview' in body())
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('feature/combined'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    keys('a'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('z-extra'); keys('<CR>'); wait(lambda: js('vim.bo.buftype') == '' and js('vim.wo.diff'))
    record = js('require("uzume.integration").current.record')
    do('require("uzume.integration").current=nil')
    keys(' vi'); wait(lambda: lua('vim.bo.filetype') == 'uzume_integration')
    assert 'CONFLICTS' in body(), 'Cannot resume a conflict from its saved record'
    keys('x'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('Abort'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_integration' and 'ABORTED' in body())
    assert git('rev-parse','feature/combined') == integrated_head
    assert (target/'z-extra.txt').read_text() == 'second task version\n'
    assert (second_root/'z-extra.txt').read_text() == 'changed after preview\n'
    assert json.loads(Path(record).read_text())['state'] == 'aborted'
    print('PASS: stale preview refused; conflict state survives reload; explicit abort restores destination and keeps task edits')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:',root)
