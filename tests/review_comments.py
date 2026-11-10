#!/usr/bin/env python3
"""Local review comments through actual editor controls; no model calls."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt(); require("uzume.agents").start("codex")')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    checkout = Path(agent['task']['cwd'])
    (checkout/'example.txt').write_text('first changed line\nsecond changed line\n')
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    keys('<CR>')
    wait(lambda: js('vim.wo.diff'))
    keys('ggVjc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Explain this change.\nPlease add a test.')
    keys('<C-s>')
    wait(lambda: js('vim.wo.diff'))
    keys('C')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    assert 'Explain this change.' in js('Snacks.picker.get()[1]:items()[1].text')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    detail = '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    assert 'Task L1–2' in detail and 'first changed line' in detail and 'second changed line' in detail, detail
    assert 'Explain this change.\nPlease add a test.' in detail
    assert not js('vim.bo.modifiable')
    assert not (Path(agent['directory'])/'input.bin').exists(), 'Commenting typed into the CLI'
    print('PASS: multiline comment on a selected range, review list and original excerpt')
    keys('q')
    (checkout/'example.txt').write_text('newer first line\nsecond changed line\n')
    keys('R')
    wait(lambda: 'newer first line' in js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    keys('C')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    assert 'Outdated' in js('Snacks.picker.get()[1]:items()[1].text')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    detail = '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    assert 'OUTDATED' in detail and 'first changed line' in detail and 'newer first line' not in detail
    keys('e')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('<Esc>ggVGc')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Revised request.\nKeep the original context.')
    keys('<C-s>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    assert 'Revised request.' in js('Snacks.picker.get()[1]:items()[1].text')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    assert 'first changed line' in '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    keys('q'); keys('q')
    keys(' av')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    keys('<CR>'); keys('C')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    assert 'Revised request.' in js('Snacks.picker.get()[1]:items()[1].text')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    keys('d')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 2)
    keys('<Down><CR>')
    wait(lambda: js('vim.wo.diff'))
    keys('C')
    assert lua('vim.bo.filetype') != 'snacks_picker_input'
    assert 'No comments yet' in lua('Snacks.notifier.get_history()[#Snacks.notifier.get_history()].msg')
    print('PASS: refresh marks outdated, editing preserves anchor, reopen retains drafts, explicit deletion')
    # One unified replacement can anchor both removed and added lines.
    keys('u')
    do('vim.fn.search("^-base$", "w")')
    keys('Vjjc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Unified replacement comment.')
    keys('<C-s>')
    wait(lambda: lua('vim.bo.filetype') == 'diff')
    keys('C')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get()[1]:items()') == 1)
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    detail = '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))
    assert 'Base L1 → Task L1–2' in detail and '\nbase\n' in detail and 'newer first line' in detail, detail
    assert not (Path(agent['directory'])/'input.bin').exists()
    records = list((root/'state/ai-nvim/review-comments').glob('*.json'))
    assert len(records) == 1 and records[0].stat().st_mode & 0o777 == 0o600
    assert records[0].parent.stat().st_mode & 0o777 == 0o700
    print('PASS: unified old/new anchors and private local storage')
    # A fresh editor reads saved drafts without starting or contacting an agent.
    try: do('vim.cmd("qa!")')
    except RuntimeError: pass
    proc.wait(timeout=10)
    script = root/'reopen-comments.lua'
    script.write_text('''
local ok, failure = pcall(function()
vim.t.uzume_task = vim.json.decode(%s)
vim.cmd("UzumeReview")
assert(vim.wait(10000,function() return #Snacks.picker.get()>0 end))
for _,picker in ipairs(Snacks.picker.get()) do picker:close() end
require("uzume.review").comments()
assert(vim.wait(5000,function()
  local p=Snacks.picker.get()[1]
  return p and p:items()[1] and p:items()[1].text:find("Unified replacement comment.",1,true)
end), "Saved draft was missing after editor restart")
assert(#require("uzume.agents").list()==0)
print("PASS: saved comment recovered in a fresh editor without agents")
end)
if not ok then print(failure); vim.cmd("cq") end
vim.cmd("qa!")
''' % json.dumps(json.dumps(agent['task'])))
    reopened = subprocess.run([NVIM,'--headless','-c','luafile ' + str(script)],env=env,cwd=checkout,capture_output=True,text=True,timeout=20)
    assert reopened.returncode == 0, reopened.stderr
    assert 'PASS: saved comment recovered' in reopened.stderr + reopened.stdout, reopened.stderr
    print('PASS: comment survives editor restart without agent delivery')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
