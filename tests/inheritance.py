#!/usr/bin/env python3
"""Task launch inherits saved working state without altering its source checkout."""
from agent_harness import *

try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt()')
    origin = js('vim.api.nvim_get_current_tabpage()')
    for name, content in {'.gitignore':'ignored.txt\n','remove.txt':'remove me\n','partial.txt':'old\n','exec.sh':'#!/bin/sh\n','data.bin':'old'}.items():
        (project/name).write_text(content)
    git('add','.gitignore','remove.txt','partial.txt','exec.sh','data.bin')
    git('-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','inheritance fixture')
    (project/'partial.txt').write_text('staged version\n')
    git('add','partial.txt')
    (project/'partial.txt').write_text('saved version\n')
    (project/'remove.txt').unlink()
    (project/'z-extra.txt').rename(project/'renamed.txt')
    (project/'exec.sh').chmod(0o755)
    (project/'data.bin').write_bytes(b'\x00\xffbinary')
    new_name = 'new ü [file].txt'
    (project/new_name).write_text('new saved file\n')
    (project/'ignored.txt').write_text('excluded local configuration\n')
    hook = project/'.git/hooks/post-checkout'
    hook.write_text('#!/bin/sh\nprintf hook > "' + str(root/'hook-ran') + '"\n')
    hook.chmod(0o755)
    source_head = git('rev-parse','HEAD')
    source_index = (project/'.git/index').read_bytes()
    keys(' ac')
    choose_new_task()
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    checkout = Path(agent['task']['cwd'])
    assert (checkout/'example.txt').read_text() == 'uncommitted source\n', 'Launch reverted to the last committed copy'
    baseline = subprocess.check_output(['git','-C',str(checkout),'show',agent['task']['base']+':example.txt'],text=True)
    assert baseline == 'uncommitted source\n', 'Inherited edits are missing from the review baseline'
    assert (checkout/'partial.txt').read_text() == 'saved version\n'
    assert git('show',':partial.txt') == 'staged version'
    assert not (checkout/'remove.txt').exists() and not (checkout/'z-extra.txt').exists()
    assert (checkout/'renamed.txt').read_text() == 'extra\n'
    assert (checkout/'exec.sh').stat().st_mode & 0o111
    assert (checkout/'data.bin').read_bytes() == b'\x00\xffbinary'
    assert (checkout/new_name).read_text() == 'new saved file\n'
    assert not (checkout/'ignored.txt').exists()
    assert not (root/'hook-ran').exists(), 'Launch executed a repository hook'
    assert (project/'example.txt').read_text() == 'uncommitted source\n'
    assert git('rev-parse','HEAD') == source_head and (project/'.git/index').read_bytes() == source_index
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: 'No changes since this task started' in lua('vim.inspect(Snacks.notifier.get_history())'))
    print('PASS: saved changes inherited, review starts clean, source files/index/HEAD unchanged')
    # A task launched while reading another task inherits that task's checkout,
    # including its newer commits and saved, uncommitted work.
    do('require("uzume.review").close(); vim.cmd.stopinsert()')
    (checkout/'example.txt').write_text('parent committed change\n')
    subprocess.run(['git','-C',str(checkout),'add','example.txt'],check=True)
    subprocess.run(['git','-C',str(checkout),'-c','user.name=Fixture','-c','user.email=fixture@example.test','commit','-qm','parent work'],check=True)
    parent_head = subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'],text=True).strip()
    (checkout/new_name).write_text('parent saved edit\n')
    (checkout/'parent-only.txt').write_text('new parent file\n')
    do('vim.cmd.edit(vim.fn.fnameescape(' + json.dumps(str(checkout/new_name),ensure_ascii=False) + '))')
    keys(' aC')
    choose_new_task()
    wait(lambda: js('#require("uzume.agents").list()') == 2)
    child = next(x for x in js('require("uzume.agents").list()') if x['task']['id'] != agent['task']['id'])
    child_root = Path(child['task']['cwd'])
    assert child['task']['source_cwd'] == str(checkout) and child['task']['source_head'] == parent_head
    assert (child_root/new_name).read_text() == 'parent saved edit\n'
    assert (child_root/'example.txt').read_text() == 'parent committed change\n'
    assert (child_root/'parent-only.txt').read_text() == 'new parent file\n'
    (child_root/new_name).write_text('child-only edit\n')
    assert (checkout/new_name).read_text() == 'parent saved edit\n'
    assert (project/new_name).read_text() == 'new saved file\n'
    assert (project/'.git/index').read_bytes() == source_index and git('rev-parse','HEAD') == source_head
    print('PASS: nested task inherits its selected checkout, with independent files and preserved source staging')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
