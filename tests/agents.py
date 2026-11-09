#!/usr/bin/env python3
"""Run with python3 tests/agents.py. Uses installed pinned packages, isolated state.
Exercises the actual editor/PTY, four mock CLIs and real disposable Git worktrees.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import shutil
import struct
import sys
import subprocess
import tempfile
import termios
import threading
import time

REPO = Path(__file__).resolve().parents[1]
NVIM = os.environ.get('UZUME_TEST_NVIM', shutil.which('nvim'))
BUNDLE = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'ai-nvim/releases'
root = Path(tempfile.mkdtemp(prefix='uzume-agents-')).resolve()
project = root / 'project with spaces'
project.mkdir()
def git(*args):
    return subprocess.check_output(['git', '-C', str(project), *args], text=True).strip()
git('init', '-q')
(project / 'example.txt').write_text('base\n')
(project / 'z-extra.txt').write_text('extra\n')
git('add', '.')
git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'base')
(project / 'example.txt').write_text('uncommitted source\n')
config = root / 'config/ai-nvim'
config.parent.mkdir()
config.symlink_to(REPO / 'editor')
data = root / 'data/ai-nvim'
data.mkdir(parents=True)
(data / 'releases').symlink_to(BUNDLE)
fixtures = root / 'bin'
fixtures.mkdir()
for name in ('codex', 'claude'):
    path = fixtures / name
    shutil.copy(REPO / 'tests/agent_fixture.py', path)
    path.chmod(0o755)
env = dict(os.environ, NVIM_APPNAME='ai-nvim', TERM='xterm-256color',
           XDG_CONFIG_HOME=str(root / 'config'), XDG_DATA_HOME=str(root / 'data'),
           XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'),
           PATH=str(fixtures) + os.pathsep + os.environ['PATH'])
sock = str(root / 'nvim.sock')
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 45, 150, 0, 0))
log = (root / 'editor.log').open('wb')
proc = subprocess.Popen([NVIM, '--listen', sock, str(project / 'example.txt')], cwd=project,
                        env=env, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
os.close(slave)
def drain():
    while True:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk: break
        log.write(chunk); log.flush()
threading.Thread(target=drain, daemon=True).start()
def lua(expr):
    response = subprocess.run([NVIM, '--clean', '--server', sock, '--remote-expr',
                               'luaeval(' + json.dumps(expr) + ')'], capture_output=True, text=True, timeout=10)
    if response.returncode: raise RuntimeError(response.stderr)
    return response.stdout.strip()
def do(code): return lua('(function() ' + code + '; return true end)()')
def js(expr): return json.loads(lua('vim.json.encode(' + expr + ')'))
def keys(text):
    lua("vim.api.nvim_input(" + json.dumps(text, ensure_ascii=False) + ")")
    time.sleep(.2)
def wait(fn):
    for _ in range(120):
        try:
            if fn(): return
        except (RuntimeError, ValueError, FileNotFoundError): pass
        time.sleep(.1)
    print('Editor diagnostics:', lua('vim.api.nvim_exec2("messages", {output=true}).output'), lua('vim.v.errmsg'))
    print('Notifications:', lua('vim.inspect(Snacks.notifier.get_history())'))
    raise AssertionError('Timed out')
def living(pid):
    response = subprocess.run(['ps', '-p', str(pid), '-o', 'stat='], capture_output=True, text=True)
    return response.returncode == 0 and not response.stdout.strip().startswith('Z')
def item(index): return js('require("uzume.agents").list()[' + str(index) + ']')
def emit(entry, event, **extra):
    event_env = dict(env, UZUME_EVENTS=entry['directory'] + '/events')
    result = subprocess.run(['python3', str(REPO / 'editor/agent/hook.py'), event],
        input=json.dumps(dict(hook_event_name=event, prompt='PRIVATE_SENTINEL', **extra)),
        capture_output=True, text=True, env=event_env, check=True)
    assert result.stdout.strip() == '{}'
try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt()')
    # Search and naming fields must allow deleting the first character too.
    for opener, filetype in (
        ('Snacks.picker.files({cwd=vim.fn.getcwd()})', 'snacks_picker_input'),
        ('Snacks.input({prompt="Name"},function() end)', 'snacks_input'),
    ):
        do(opener)
        wait(lambda: lua('vim.bo.filetype') == filetype)
        wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
        for text in ('abc', 'é', '界'):
            keys(text)
            for _ in text: keys('<BS>')
            assert js('vim.api.nvim_get_current_line()') == '', (filetype, text, lua('vim.api.nvim_get_current_line()'))
        keys('<Esc>')
        keys('<Esc>')
        do('for _,p in ipairs(Snacks.picker.get()) do p:close() end; vim.cmd.stopinsert()')
    if '--inputs-only' in sys.argv:
        print('PASS: search and naming fields delete all ASCII and multibyte characters')
        sys.exit(0)
    assert lua('vim.bo.buftype') == ''
    origin = js('vim.api.nvim_get_current_tabpage()')
    for count, kind in enumerate(('codex', 'claude', 'codex', 'claude'), 1):
        do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(origin) + ')')
        keys({1:' ac', 2:' aC', 3:' ae', 4:' aE'}[count])
        wait(lambda: js('#require("uzume.agents").list()') == count)
        if count <= 2:
            wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
            assert lua('vim.bo.filetype') != 'snacks_input'
            task = js('vim.t.uzume_task')
            assert len(task['context']['files']) == 1
            assert task['context']['files'][0]['path'] == task['cwd'] + '/example.txt'
            views = js('require("ainvim.sessions").windows(0)')
            editor = next(x for x in views if not x['terminal'])
            assert lua('vim.api.nvim_buf_get_name(' + str(editor['buf']) + ')') == task['cwd'] + '/example.txt'
        else:
            wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
            wait(lambda: js('#Snacks.picker.get({source="files"})[1]:items()') > 0)
            assert js('#vim.t.uzume_task.context.files') == 0
            keys('<CR>')
            wait(lambda: lua('vim.bo.filetype') != 'snacks_picker_input')
        visible = js('(function() local r={} for _,buf in ipairs(vim.api.nvim_list_bufs()) do if require("uzume.workspace_buffers").contains(buf) and vim.api.nvim_buf_get_name(buf):match("example.txt$") then r[#r+1]=buf end end return r end)()')
        assert len(visible) == 1, visible
        assert js('vim.api.nvim_buf_is_valid(vim.fn.bufnr(' + json.dumps(str(project/'example.txt')) + '))')
        if count == 1:
            # Selecting the existing agent must focus its pane, never mirror it
            # over the file. Exercise the real keyboard, mouse and picker routes.
            agent = item(1)
            terminal = next(p for p in views if p['terminal'])
            for route in ('cycle', 'tab-click', 'buffer-command', 'buffer-picker'):
                do('vim.cmd.stopinsert(); vim.api.nvim_set_current_win(' + str(editor['win']) + ')')
                if route == 'cycle':
                    keys('L')
                elif route == 'tab-click':
                    column = js('(function() local s=vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true,maxwidth=vim.o.columns}).str; local i=assert(s:find("Codex",1,true)); return vim.fn.strdisplaywidth(s:sub(1,i-1)) end)()')
                    do('vim.api.nvim_input_mouse("left","press","",0,0,' + str(column) + '); vim.api.nvim_input_mouse("left","release","",0,0,' + str(column) + ')')
                elif route == 'buffer-command':
                    do('vim.cmd.buffer(' + str(agent['buf']) + ')')
                else:
                    keys(' ,')
                    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
                    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
                    keys('python')
                    wait(lambda: js('#Snacks.picker.get({source="buffers"})[1]:items()') == 1)
                    keys('<CR>')
                wait(lambda: js('vim.api.nvim_get_current_win()') == terminal['win'])
                assert js('vim.fn.win_findbuf(' + str(agent['buf']) + ')') == [terminal['win']], route
                assert js('vim.api.nvim_win_get_buf(' + str(editor['win']) + ')') == editor['buf'], route
                assert js('#require("uzume.agents").list()') == 1, route
            # Swapping also briefly duplicates a buffer while assigning panes;
            # routing must wait for the operation rather than undo that layout.
            do('require("ainvim.panes").swap()')
            wait(lambda: js('vim.api.nvim_win_get_buf(' + str(editor['win']) + ')') == agent['buf'])
            assert js('vim.api.nvim_win_get_buf(' + str(terminal['win']) + ')') == editor['buf']
            do('require("ainvim.panes").swap()')
            wait(lambda: js('vim.api.nvim_win_get_buf(' + str(editor['win']) + ')') == editor['buf'])
            assert js('vim.fn.win_findbuf(' + str(agent['buf']) + ')') == [terminal['win']]

    do('require("uzume.agents").focus(require("uzume.agents").list()[4]); vim.cmd.startinsert()')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
    keys('<Esc><Esc>')
    wait(lambda: lua('vim.api.nvim_get_mode().mode').startswith('n'))
    keys('i')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
    entries = js('require("uzume.agents").list()')
    a, b = entries[:2]
    assert a['task']['cwd'] != b['task']['cwd'] and a['task']['branch'] != b['task']['branch']
    assert js('#require("ainvim.projects").list()') == 1
    assert js('#require("ainvim.projects").list()[1].windows') == 5
    for entry in entries:
        wait(lambda: (Path(entry['directory']) / 'fixture.json').exists())
        record = json.loads((Path(entry['directory']) / 'fixture.json').read_text())
        assert record['cwd'] == entry['task']['cwd']
        assert '--' not in record['args'], 'Launch submitted a prompt'
        assert 'prompt' not in json.loads((Path(entry['directory']) / 'launch.json').read_text())
        assert (Path(record['cwd']) / 'example.txt').read_text() == 'base\n'
        assert len(js('require("ainvim.sessions").windows(' + str(entry['tab']) + ')')) == 2
    assert (project / 'example.txt').read_text() == 'uncommitted source\n'
    # Marking is local, idempotent and allowed while the agent is working.
    current_task = js('vim.t.uzume_task')
    current = next(x for x in entries if x['task']['id'] == current_task['id'])
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_win(vim.fn.win_findbuf(vim.fn.bufnr(vim.t.ainvim_root .. "/example.txt"))[1])')
    keys(' af'); keys(' af')
    current = js('require("uzume.agents").instances[' + json.dumps(current_task['id']) + ']')
    assert len(current['task']['context']['files']) == 1
    reference = root / 'reference from another project.txt'
    reference.write_text('PRIVATE_REFERENCE_CONTENT')
    do('vim.cmd.edit(' + json.dumps(str(reference)) + ')')
    keys(' af')
    do('vim.cmd.edit(vim.t.ainvim_root .. "/example.txt")')
    current = js('require("uzume.agents").instances[' + json.dumps(current_task['id']) + ']')
    assert current['task']['context']['files'][1]['role'] == 'reference'
    assert not (Path(current['directory']) / 'input.bin').exists(), 'Marking typed into the CLI'
    result = subprocess.run(['python3', str(REPO/'editor/agent/hook.py'), 'UserPromptSubmit'],
        input=json.dumps({'hook_event_name':'UserPromptSubmit','prompt':'PRIVATE_SENTINEL'}), capture_output=True, text=True,
        env=dict(env, UZUME_EVENTS=current['directory']+'/events'), check=True)
    context = json.loads(result.stdout)['hookSpecificOutput']['additionalContext']
    assert str(reference) in context and current['task']['cwd']+'/example.txt' in context
    assert 'PRIVATE_REFERENCE_CONTENT' not in context and 'PRIVATE_SENTINEL' not in context
    wait(lambda: js('require("uzume.agents").instances[' + json.dumps(current_task['id']) + '].status.context_revision') == 2)
    assert reference.read_text() == 'PRIVATE_REFERENCE_CONTENT'
    keys(' aF')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    wait(lambda: js('#Snacks.picker.get({source="files"})[1]:items()') >= 2)
    keys('<Tab>'); keys('<Tab>'); keys('<CR>')
    wait(lambda: js('#vim.t.uzume_task.context.files') == 3)
    keys(' am')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>')
    wait(lambda: js('#vim.t.uzume_task.context.files') == 2)

    label = lua('vim.b[ ' + str(current['buf']) + '].uzume_agent_label')
    assert label.startswith(('Codex', 'Claude'))
    rendered = lua('vim.api.nvim_eval_statusline(vim.o.tabline,{use_tabline=true}).str')
    assert 'python3' not in rendered
    do('vim.cmd.stopinsert(); vim.api.nvim_set_current_tabpage(' + str(origin) + ')')
    emit(a, 'PermissionRequest')
    wait(lambda: js('require("uzume.agents").window_status(' + str(a['tab']) + ').state') == 'waiting')
    assert js('vim.api.nvim_get_current_tabpage()') == origin
    assert 'need you' in lua('require("uzume.agents").summary()')
    emit(a, 'Stop', agent_id='worker-1')
    time.sleep(.5)
    assert js('require("uzume.agents").window_status(' + str(a['tab']) + ').state') == 'waiting'
    emit(a, 'Stop')
    wait(lambda: js('require("uzume.agents").window_status(' + str(a['tab']) + ').state') == 'review')
    assert not any('PRIVATE_SENTINEL' in p.read_text() for p in Path(a['directory']).rglob('*.json'))
    do('require("ainvim.navigator").open("windows")')
    assert 'REVIEW' in '\n'.join(js('vim.api.nvim_buf_get_lines(require("ainvim.navigator").current.buf,0,-1,false)'))
    do('require("ainvim.navigator").close()')
    # Hide/restore/float retain the exact same running job; focus restores hidden panes.
    do('require("uzume.agents").focus(require("uzume.agents").instances[' + json.dumps(a['task']['id']) + ']); require("ainvim.panes").hide()')
    do('require("uzume.agents").focus(require("uzume.agents").instances[' + json.dumps(a['task']['id']) + ']); require("ainvim.panes").float(); require("ainvim.panes").zoom(); require("ainvim.panes").zoom(); require("ainvim.panes").dock()')
    panes = js('require("ainvim.sessions").windows(0)')
    assert len(panes) == 2 and sum(p['buf'] == a['buf'] for p in panes) == 1
    assert js('vim.api.nvim_get_current_buf()') == a['buf']
    assert lua('vim.api.nvim_buf_get_name(' + str(next(p['buf'] for p in panes if not p['terminal'])) + ')') == a['task']['cwd'] + '/example.txt'
    record_a = json.loads((Path(a['directory']) / 'fixture.json').read_text())
    record_b = json.loads((Path(b['directory']) / 'fixture.json').read_text())
    assert living(record_a['pid']) and living(record_b['pid'])
    # Interrupt is not termination.
    os.kill(record_a['pid'], 2)
    wait(lambda: (Path(a['directory']) / 'interrupted').exists())
    assert living(record_a['pid'])
    # Task shell cwd follows worktree, not primary project.
    do('require("ainvim.panes").split("below",true); vim.cmd.stopinsert()')
    assert lua('vim.fn.getcwd()') == a['task']['cwd']
    do('require("ainvim.panes").close()')
    # Closing one task kills its owned child while preserving another task and files.
    do('require("ainvim.projects").close({kind="window",tab=' + str(a['tab']) + '})')
    wait(lambda: not living(record_a['pid']) and not living(record_a['child']))
    assert living(record_b['pid']) and Path(a['task']['cwd']).is_dir()
    # Closing the agent pane stops the task process; restart retains its checkout.
    do('require("uzume.agents").focus(require("uzume.agents").instances[' + json.dumps(b['task']['id']) + ']); require("ainvim.panes").close()')
    wait(lambda: not living(record_b['pid']) and not living(record_b['child']))
    do('require("uzume.agents").restart(); vim.cmd.stopinsert()')
    b = js('require("uzume.agents").instances[' + json.dumps(b['task']['id']) + ']')
    wait(lambda: (Path(b['directory']) / 'fixture.json').exists())
    # Normal CLI exit collapses tiled, floating and hidden panes without focus theft.
    for entry, style in zip(js('require("uzume.agents").list()'), ('tiled', 'float', 'hidden')):
        wait(lambda: (Path(entry['directory']) / 'fixture.json').exists())
        record = json.loads((Path(entry['directory']) / 'fixture.json').read_text())
        if entry['task']['id'] == b['task']['id']:
            assert '--' not in record['args'], 'Restart replayed the initial task'
        do('require("uzume.agents").focus(require("uzume.agents").instances[' + json.dumps(entry['task']['id']) + ']); vim.cmd.stopinsert()')
        if style != 'tiled': do('require("ainvim.panes").' + ('float' if style == 'float' else 'hide') + '()')
        if style == 'tiled':
            focused = js('(function() for _,p in ipairs(require("ainvim.sessions").windows(0)) do if not p.terminal then return p.win end end end)()')
            do('vim.cmd.startinsert()')
        else:
            do('vim.api.nvim_set_current_tabpage(' + str(origin) + ')')
            focused = js('vim.api.nvim_get_current_win()')
        (Path(entry['directory']) / 'exit').write_text('0')
        wait(lambda: not js('vim.api.nvim_buf_is_valid(' + str(entry['buf']) + ')'))
        assert js('vim.api.nvim_get_current_win()') == focused
        assert len(js('require("ainvim.sessions").windows(' + str(entry['tab']) + ')')) == 1
        assert js('#require("ainvim.panes").hidden(' + str(entry['tab']) + ')') == 0
        assert Path(entry['task']['cwd']).is_dir()
        wait(lambda: not living(record['child']))
        do('vim.api.nvim_set_current_tabpage(' + str(entry['tab']) + '); require("uzume.agents").restart(); vim.cmd.stopinsert()')
        refreshed = js('require("uzume.agents").instances[' + json.dumps(entry['task']['id']) + ']')
        wait(lambda: (Path(refreshed['directory']) / 'fixture.json').exists())
    do('require("ainvim.sessions").save()')
    saved = json.loads((root / 'state/ai-nvim/navigator/snapshot.json').read_text())
    tasks = [x for x in saved['sessions'] if x.get('task')]
    assert len(tasks) == 3
    assert all(x['project_root'] == str(project) for x in tasks)
    records = [json.loads((Path(x['directory']) / 'fixture.json').read_text())
               for x in js('require("uzume.agents").list()')]
    # Modified source preflight must reject closing the entire project atomically.
    do('vim.api.nvim_set_current_tabpage(' + str(origin) + '); vim.api.nvim_buf_set_lines(0,0,1,false,{"unsaved"})')
    result = js('(function() local ok = pcall(require("ainvim.projects").close,{kind="project",project=' + json.dumps(str(project)) + '}); return ok end)()')
    assert result is False and all(living(x['pid']) for x in records), {'closed':result,'alive':[(x['pid'],living(x['pid'])) for x in records], 'buffer':js('{name=vim.api.nvim_buf_get_name(0),type=vim.bo.buftype,modified=vim.bo.modified}'), 'project':js('require("ainvim.projects").list()')}
    do('vim.bo.modified=false; require("ainvim.projects").close({kind="project",project=' + json.dumps(str(project)) + '})')
    wait(lambda: all(not living(x['pid']) and not living(x['child']) for x in records))
    assert all(Path(x['task']['cwd']).is_dir() for x in entries)
    # Restoring retains project/task identity but never launches an agent.
    do('require("ainvim.sessions").restore()')
    assert js('#require("ainvim.projects").list()') == 1
    assert js('#require("ainvim.projects").list()[1].windows') == 4
    assert js('#require("uzume.agents").list()') == 0
    do('for _,tab in ipairs(vim.api.nvim_list_tabpages()) do if vim.t[tab].uzume_task then vim.api.nvim_set_current_tabpage(tab); break end end; require("uzume.agents").restart(); vim.cmd.stopinsert()')
    final = item(1)
    wait(lambda: (Path(final['directory']) / 'fixture.json').exists())
    record = json.loads((Path(final['directory']) / 'fixture.json').read_text())
    # Exit should stop the restored task's CLI and its child.
    if "--crash" in sys.argv:
        proc.kill()
    else:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass  # RPC closes as the editor exits.
    proc.wait(timeout=10)
    wait(lambda: not living(record['pid']) and not living(record['child']))
    print('PASS: isolated task worktrees, project grouping, terminal launch, attention without focus theft, worker filtering, metadata privacy, panes, scoped close, modified-file guard, restart, snapshot restore without agents, editor shutdown' + (' (forced)' if '--crash' in sys.argv else ' (normal)'))
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
