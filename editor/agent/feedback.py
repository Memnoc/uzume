"""Consume explicitly published review batches once, without terminal injection."""
import json
import os
from pathlib import Path
import time


def take(events):
    for pending in sorted((Path(events).parent / 'feedback').glob('*.pending.json')):
        if pending.stat().st_size > 262144:
            continue
        value = json.loads(pending.read_text())
        if not isinstance(value.get('text'), str) or value.get('id') != pending.name.split('.')[0]:
            continue
        claimed = pending.with_name(value['id'] + '.claimed.json')
        try:
            pending.rename(claimed)
        except FileNotFoundError:
            continue  # Another hook or cancellation won the claim.
        return value['text'], claimed
    return None, None


def supplied(claimed, event):
    target = claimed.with_name(claimed.name.replace('.claimed.json', '.supplied.json'))
    temporary = target.with_suffix('.tmp')
    with open(temporary, 'x', opener=lambda path, flags: os.open(path, flags, 0o600)) as output:
        json.dump({'event': event, 'time': time.time()}, output)
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(target)
