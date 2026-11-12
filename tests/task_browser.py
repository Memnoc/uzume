#!/usr/bin/env python3
"""Task browser navigation through real keys, Git and pinned Snacks UI."""
from agent_harness import *

def body():
    return '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))

try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    base = git('rev-parse', 'HEAD')
    records = data/'task-branches'; records.mkdir()
    for name in ('alpha', 'bravo', 'gamma'):
        checkout = data/'worktrees/fixture'/name
        git('worktree', 'add', '-qb', 'test/'+name, str(checkout))
        task = dict(id=name, label=name, branch='test/'+name, cwd=str(checkout), project=str(project), base=base)
        (records/(name+'.json')).write_text(json.dumps(task))
    keys(' at'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('test/'); keys('<Down>'); keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_task_cleanup')
    assert 'test/bravo' in body(), body()
    keys('<Esc>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert 'test/' in body(), body()
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype') == 'uzume_task_cleanup')
    assert 'test/bravo' in body(), 'Returning lost the selected task'
    assert 'Esc / b Back to tasks' in body() and 'q Close' in body(), body()
    keys('b'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype') == 'uzume_task_cleanup')
    keys('q')
    assert lua('vim.bo.filetype') not in ('snacks_picker_input', 'uzume_task_cleanup')
    print('PASS: task details return to the filtered list and selected branch; q closes')
    # Hold a real Git status call at the subprocess boundary to exercise slow IO.
    # Application modules and Git behavior are unchanged once the gate is released.
    gate, started = root/'hold-git', root/'git-started'
    real_git = shutil.which('git')
    wrapper = fixtures/'git'
    wrapper.write_text('#!' + sys.executable + '\nimport os, sys, time\nfrom pathlib import Path\n'
                       + f'gate = Path({str(gate)!r})\n'
                       + 'if "status" in sys.argv and gate.exists():\n'
                       + f'    Path({str(started)!r}).touch()\n'
                       + '    deadline = time.monotonic() + 10\n'
                       + '    while gate.exists() and time.monotonic() < deadline: time.sleep(0.05)\n'
                       + f'os.execv({real_git!r}, [{real_git!r}, *sys.argv[1:]])\n')
    wrapper.chmod(0o755)
    gate.touch()
    keys(' at'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('bravo'); keys('<CR>'); wait(started.exists)
    assert 'Checking task' in body() and 'test/bravo' in body(), body()
    assert 'Esc / b Back to tasks' in body() and 'q Close' in body(), body()
    keys('<Esc>'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert 'bravo' in body()
    gate.unlink()
    time.sleep(1)
    assert lua('vim.bo.filetype') == 'snacks_picker_input', 'An obsolete inspection stole focus'
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype') == 'uzume_task_cleanup')
    assert 'test/bravo' in body() and 'No task changes' in body(), body()
    keys('q')
    print('PASS: slow inspection shows progress; backing out ignores its late result')
    keys(' at'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('gamma')
    # Another tool can remove a task after discovery: show a readable error and
    # retry/back controls rather than leaving an eternal progress screen.
    gamma = data/'worktrees/fixture/gamma'
    git('worktree', 'remove', str(gamma)); (records/'gamma.json').unlink()
    keys('<CR>'); wait(lambda: lua('vim.bo.filetype') == 'uzume_task_check_failed')
    assert 'missing or ambiguous' in body() and 'r Retry' in body(), body()
    git('worktree', 'add', str(gamma), 'test/gamma')
    (records/'gamma.json').write_text(json.dumps(task))
    keys('r'); wait(lambda: lua('vim.bo.filetype') == 'uzume_task_cleanup')
    assert 'test/gamma' in body(), body()
    keys('<Esc>'); wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert 'gamma' in body(), body()
    keys('<Esc>')
    print('PASS: a failed check offers retry and back; retry reads current state')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
