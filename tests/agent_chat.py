#!/usr/bin/env python3
"""Project chat: no branch/worktree, current file supplied per prompt, toggle keeps the CLI."""
from agent_harness import *

CHATS = '(function() local r={} for _,c in pairs(require("uzume.agents.chat").chats) do r[#r+1]={kind=c.kind,cwd=c.cwd,buf=c.buf,job=c.job,directory=c.directory} end return r end)()'

def prompt(directory):
    event_env = dict(env, UZUME_EVENTS=directory + '/events')
    result = subprocess.run(['python3', str(REPO / 'editor/agent/hook.py'), 'UserPromptSubmit'],
        input=json.dumps(dict(hook_event_name='UserPromptSubmit', prompt='PRIVATE_SENTINEL')),
        capture_output=True, text=True, env=event_env, check=True)
    return json.loads(result.stdout)['hookSpecificOutput']['additionalContext']

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("uzume.editor.sessions").adopt()')
    branches, worktrees = git('branch', '--list'), git('worktree', 'list')
    source = js('vim.api.nvim_get_current_win()')
    do('vim.api.nvim_win_set_cursor(0,{1,0})')
    keys(' ai')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
    chats = js(CHATS)
    assert len(chats) == 1 and chats[0]['kind'] == 'codex', chats
    chat = chats[0]
    assert lua('vim.bo.buftype') == 'terminal' and js('vim.api.nvim_get_current_buf()') == chat['buf']
    fixture = Path(chat['directory']) / 'fixture.json'
    wait(lambda: fixture.exists())
    assert Path(json.loads(fixture.read_text())['cwd']).resolve() == project
    assert git('branch', '--list') == branches and git('worktree', 'list') == worktrees, 'Chat created a branch/worktree'
    assert not js('vim.t.uzume_task'), 'Chat must not turn this window into a task'
    context = prompt(chat['directory'])
    assert str(project / 'example.txt') in context and 'line 1' in context, context

    # Hide keeps the process; showing again from another file reuses it and updates focus.
    keys('<Esc><Esc>'); keys('q')
    wait(lambda: js('vim.api.nvim_get_current_win()') == source)
    assert js('#vim.fn.win_findbuf(' + str(chat['buf']) + ')') == 0
    assert js('vim.fn.jobwait({' + str(chat['job']) + '},0)[1]') == -1, 'Hiding stopped the chat'
    do('vim.cmd.edit(' + json.dumps(str(project / 'z-extra.txt')) + ')')
    keys(' ai')
    wait(lambda: js('vim.api.nvim_get_current_buf()') == chat['buf'])
    assert len(js(CHATS)) == 1
    context = prompt(chat['directory'])
    assert str(project / 'z-extra.txt') in context and 'example.txt' not in context, context

    # Space ai from inside the chat hides it too.
    keys('<Esc><Esc>'); keys(' ai')
    wait(lambda: js('vim.api.nvim_get_current_win()') == source)
    keys(' aI')
    wait(lambda: len(js(CHATS)) == 2)
    assert js('vim.b.uzume_agent_kind') == 'claude'
    print('PASS: project chat starts without a branch, supplies the current file, toggles without restarting')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
