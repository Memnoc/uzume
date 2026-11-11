#!/usr/bin/env python3
"""Run the editor regression suite; each case owns disposable state and mock CLIs."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASES = [
    ('migration', ['migration.py'], {}),
    ('installation', ['installation.py'], {}),
    ('dashboard', ['dashboard.py'], {}),
    ('keymaps', ['keymaps.py'], {}),
    ('commandline', ['commandline.py'], {}),
    ('language-packs', ['language_packs.py'], {}),
    ('extras-ui', ['extras_ui.py'], {}),
    ('shortcut-audit', ['shortcut_audit.py'], {}),
    ('pane-motion', ['pane_motion.py'], {}),
    ('agents', ['agents.py'], {}),
    ('agents-crash', ['agents.py', '--crash'], {}),
    ('inheritance', ['inheritance.py'], {}),
    ('task-navigation', ['task_navigation.py'], {}),
    ('named-launch', ['named_launch.py'], {}),
    ('branch-launch', ['branch_launch.py'], {}),
    ('review', ['review.py'], {}),
    ('review-comments', ['review_comments.py'], {}),
    ('feedback-codex', ['feedback.py', 'codex'], {}),
    ('feedback-claude', ['feedback.py', 'claude'], {}),
    ('integration', ['integration.py'], {}),
    ('integration-diff3', ['integration.py'], {'UZUME_TEST_CONFLICT_STYLE': 'diff3'}),
]

if __name__ == '__main__':
    failed = []
    for name, args, overrides in CASES:
        print(f'\n=== {name} ===', flush=True)
        result = subprocess.run([sys.executable, '-u', str(ROOT/'tests'/args[0]), *args[1:]],
                                cwd=ROOT, env=dict(os.environ, **overrides))
        if result.returncode:
            failed.append(name)
    print(f'\n{len(CASES)-len(failed)}/{len(CASES)} cases passed', flush=True)
    if failed:
        print('Failed: ' + ', '.join(failed))
    sys.exit(bool(failed))
