#!/usr/bin/env python3
"""Explicit review handoff through real editor controls and CLI hook boundaries."""
from agent_harness import *


def hook(agent, event, **payload):
    result = subprocess.run(['python3', str(REPO/'editor/agent/hook.py'), event],
        input=json.dumps(dict(hook_event_name=event, **payload)),
        capture_output=True, text=True, check=True,
        env=dict(env, UZUME_EVENTS=agent['directory']+'/events'))
    return json.loads(result.stdout)


def text():
    return '\n'.join(js('vim.api.nvim_buf_get_lines(0,0,-1,false)'))


def review_comment(body):
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>')
    wait(lambda: js('vim.wo.diff'))
    keys('ggc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys(body); keys('<C-s>'); keys('s')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_feedback')


try:
    wait(lambda: lua('vim.fn.exists(":UzumeAgent")') == '2')
    kind = sys.argv[1] if len(sys.argv) > 1 else 'codex'
    do('require("smear_cursor").enabled=false; require("ainvim.sessions").adopt(); require("uzume.agents").start(' + json.dumps(kind) + ')')
    wait(lambda: js('#require("uzume.agents").list()') == 1)
    agent = item(1)
    wait(lambda: (Path(agent['directory'])/'fixture.json').exists())
    checkout = Path(agent['task']['cwd'])
    (checkout/'example.txt').write_text('first changed line\nsecond changed line\n')
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>')
    wait(lambda: js('vim.wo.diff'))
    keys('ggVjc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Please explain this change.\nAdd a focused test.')
    keys('<C-s>')
    wait(lambda: js('vim.wo.diff'))
    keys('s')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_feedback')
    assert 'Please explain this change.' in text() and 'first changed line' in text()
    assert 'example.txt' in text() and kind in text().lower()
    assert hook(agent, 'Stop') == {}, 'Preview sent unsent drafts'
    keys('<C-s>')
    wait(lambda: 'QUEUED' in text())
    assert not (Path(agent['directory'])/'input.bin').exists(), 'Queue typed into the terminal'
    output = hook(agent, 'Stop')
    assert output['decision'] == 'block'
    assert 'Please explain this change.' in output['reason'] and 'first changed line' in output['reason']
    assert 'second changed line' in output['reason'] and 'example.txt' in output['reason']
    assert hook(agent, 'Stop', stop_hook_active=True) == {}, 'Repeated delivery continued the turn again'
    keys('r')
    wait(lambda: 'SUPPLIED' in text())
    print('PASS: explicit batch preview, queued without terminal input, supplied once at turn end')
    keys('q')
    keys('ggc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Second request: explain this line.')
    keys('<C-s>')
    (checkout/'example.txt').write_text('a newer saved line\nsecond changed line\n')
    keys('R')
    wait(lambda: 'a newer saved line' in text())
    keys('s')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_feedback')
    assert 'OUTDATED' in text() and 'first changed line' in text()
    assert 'Please explain this change.' not in text(), 'Supplied comments were offered again'
    keys('<C-s>')
    wait(lambda: 'QUEUED' in text())
    assert hook(agent, 'Stop', agent_id='worker') == {}
    assert hook(agent, 'PermissionRequest') == {}
    assert hook(agent, 'Stop', stop_hook_active=True) == {}
    keys('x')
    wait(lambda: 'CANCELLED' in text())
    assert hook(agent, 'Stop') == {}, 'Cancelled review was sent'
    keys('q'); keys('s')
    wait(lambda: 'PREVIEW' in text())
    keys('<C-s>')
    wait(lambda: 'QUEUED' in text())
    output = hook(agent, 'UserPromptSubmit', prompt='apply the review')
    context = output['hookSpecificOutput']['additionalContext']
    assert output['hookSpecificOutput']['hookEventName'] == 'UserPromptSubmit'
    assert 'Uzume file context' in context and 'Second request:' in context and 'OUTDATED' in context
    assert 'Please explain this change.' not in context
    assert hook(agent, 'Stop') == {}
    keys('r')
    wait(lambda: 'SUPPLIED' in text())
    print('PASS: cancellation, outdated context, worker/permission isolation, next-prompt delivery with file context')
    keys('q'); keys('C')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert all('Supplied' in row['text'] for row in js('Snacks.picker.get()[1]:items()')), 'Comment list hid delivery status'
    keys('Second request')
    keys('<CR>')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment_detail')
    keys('e')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('<Esc>ggVGc')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Revised request after review.')
    keys('<C-s>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<Esc>'); keys('s')
    wait(lambda: 'PREVIEW' in text())
    assert 'Revised request after review.' in text()
    keys('<C-s>')
    wait(lambda: 'QUEUED' in text())
    do('require("uzume.review").close()')
    (Path(agent['directory'])/'exit').write_text('0')
    wait(lambda: item(1).get('exited'))
    keys(' ar')
    wait(lambda: item(1)['directory'] != agent['directory'])
    restarted = item(1)
    wait(lambda: (Path(restarted['directory'])/'fixture.json').exists())
    assert hook(restarted, 'Stop') == {}, 'Restart replayed feedback without another send action'
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>')
    wait(lambda: js('vim.wo.diff'))
    keys('s')
    wait(lambda: 'PREVIEW' in text())
    keys('<C-s>')
    wait(lambda: 'QUEUED' in text())
    assert hook(agent, 'Stop') == {}, 'Previous agent run retained the requeued batch'
    output = hook(restarted, 'Stop')
    assert 'Revised request after review.' in output['reason']
    assert not (Path(restarted['directory'])/'input.bin').exists()
    records = list((root/'state/ai-nvim/review-feedback').glob('*/*.json'))
    assert records and all(path.stat().st_mode & 0o777 == 0o600 for path in records)
    print('PASS: edited comments can be sent anew; restart requires explicit requeue; previous run cannot replay')
    keys('q'); keys('ggc')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_comment')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 'i')
    keys('Apply this final correction.')
    keys('<C-s>')
    hook(restarted, 'Stop')
    wait(lambda: item(1)['status']['state'] == 'review')
    keys('s')
    wait(lambda: lua('vim.bo.filetype') == 'uzume_review_feedback')
    keys('a')
    wait(lambda: (Path(restarted['directory'])/'input.bin').exists())
    wait(lambda: b'\r' in (Path(restarted['directory'])/'input.bin').read_bytes())
    sent = (Path(restarted['directory'])/'input.bin').read_bytes()
    assert b'Apply my queued Uzume review' in sent
    output = hook(restarted, 'UserPromptSubmit')
    assert 'Apply this final correction.' in output['hookSpecificOutput']['additionalContext']
    print('PASS: send-and-focus queues the preview and submits the idle-agent prompt automatically')
    before = (Path(restarted['directory'])/'input.bin').read_bytes()
    review_comment('Feedback while busy.')
    keys('a')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
    assert (Path(restarted['directory'])/'input.bin').read_bytes() == before, 'Send typed into a working CLI'
    assert 'Feedback while busy.' in hook(restarted, 'Stop')['reason']
    review_comment('Feedback after the permission question.')
    hook(restarted, 'PermissionRequest')
    keys('a')
    assert lua('vim.bo.filetype') == 'uzume_review_feedback'
    assert (Path(restarted['directory'])/'input.bin').read_bytes() == before, 'Send answered a permission dialog'
    hook(restarted, 'SessionStart')
    do('require("uzume.review").close(); require("uzume.agents").focus(require("uzume.agents").list()[1]); vim.cmd.startinsert()')
    wait(lambda: lua('vim.api.nvim_get_mode().mode') == 't')
    keys('unfinished personal draft')
    wait(lambda: b'unfinished personal draft' in (Path(restarted['directory'])/'input.bin').read_bytes())
    with_draft = (Path(restarted['directory'])/'input.bin').read_bytes()
    do('vim.cmd.stopinsert(); vim.cmd("UzumeReview")')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<CR>'); keys('s'); keys('a')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    assert 'unfinished draft' in lua('vim.inspect(Snacks.picker.get()[1].opts.title)')
    keys('<CR>')
    assert (Path(restarted['directory'])/'input.bin').read_bytes() == with_draft
    keys('a')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('Submit draft'); keys('<CR>')
    wait(lambda: (Path(restarted['directory'])/'input.bin').read_bytes().count(b'Apply my queued Uzume review') == 2)
    output = hook(restarted, 'UserPromptSubmit')
    assert 'Feedback after the permission question.' in output['hookSpecificOutput']['additionalContext']
    print('PASS: busy delivery remains queued; permission dialogs and existing drafts are protected')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
