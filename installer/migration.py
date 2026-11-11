"""Rename app storage without rewriting retained histories or Git worktrees."""
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tempfile

LEGACY = 'ai-nvim'
APP = 'uzume'
DEFAULTS = {'CONFIG': '.config', 'DATA': '.local/share', 'STATE': '.local/state', 'CACHE': '.cache'}


def roots():
    return {key: Path(os.environ.get('XDG_' + key + '_HOME', Path.home() / default)).expanduser().absolute()
            for key, default in DEFAULTS.items()}


def legacy_present():
    return any((base / LEGACY).exists() and not (
        (base / LEGACY).is_symlink() and (base / LEGACY).resolve() == (base / APP).resolve()
    ) for base in roots().values())


def active_editors(bases):
    # Inspect only Neovim processes, and never print their arguments/environment.
    listing = subprocess.run(['ps', '-axo', 'pid=,stat=,comm='], capture_output=True, text=True, check=True)
    found = []
    for line in listing.stdout.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3 or 'Z' in fields[1] or Path(fields[2]).name != 'nvim':
            continue
        pid = fields[0]
        try:
            if platform.system() == 'Linux':
                raw = Path('/proc/' + pid + '/environ').read_bytes().decode(errors='replace')
                values = dict(part.split('=', 1) for part in raw.split('\0') if '=' in part)
            else:
                process = subprocess.run(['ps', 'eww', '-p', pid, '-o', 'command='], capture_output=True, text=True)
                if process.returncode:
                    continue
                values = dict(re.findall(r'(?:^|\s)([A-Za-z_][A-Za-z0-9_]*)=(.*?)(?=\s[A-Za-z_][A-Za-z0-9_]*=|$)', process.stdout.strip()))
            if values.get('NVIM_APPNAME') not in (LEGACY, APP):
                continue
            # A fixture with isolated XDG roots must not block a different installation.
            home_path = Path(values.get('HOME', str(Path.home())))
            if any(Path(values.get('XDG_' + key + '_HOME', str(home_path / default))).resolve() == bases[key].resolve()
                   for key, default in DEFAULTS.items()):
                found.append(pid)
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            # Other users' processes cannot own this user's private app data.
            continue
    return found


def write_journal(path, record):
    fd, temporary = tempfile.mkstemp(prefix='.uzume-migration-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump(record, output, indent=2)
            output.flush(); os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def migrate():
    bases = roots()
    bases['STATE'].mkdir(parents=True, exist_ok=True)
    journal = bases['STATE'] / '.uzume-namespace-migration.json'
    lock_path = bases['STATE'] / '.uzume-namespace-migration.lock'
    with lock_path.open('a') as lock:
        os.chmod(lock_path, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another namespace migration is running') from None
        record = json.loads(journal.read_text()) if journal.exists() else {'version': 1, 'moves': []}
        if record.get('version') != 1 or not isinstance(record.get('moves'), list):
            raise RuntimeError('Unrecognized migration journal; inspect ' + str(journal))
        allowed = {(str(base / LEGACY), str(base / APP)) for base in bases.values()}
        for item in record['moves']:
            if (item.get('old'), item.get('new')) not in allowed:
                raise RuntimeError('Migration journal belongs to different XDG roots; inspect ' + str(journal))
        known = {item['old'] for item in record['moves']}
        for old_name, new_name in sorted(allowed):
            old, new = Path(old_name), Path(new_name)
            alias = old.is_symlink() and old.resolve() == new.resolve()
            if os.path.lexists(old) and not alias and old_name not in known:
                record['moves'].append({'old': old_name, 'new': new_name, 'done': False})
        # Validate every destination before moving any directory.
        for item in record['moves']:
            old, new = Path(item['old']), Path(item['new'])
            alias = old.is_symlink() and old.resolve() == new.resolve()
            if os.path.lexists(old) and os.path.lexists(new) and not alias:
                raise RuntimeError('Both app paths exist; migration will not merge them: ' + str(old) + ' and ' + str(new))
            if (old.exists() and not old.is_dir()) or (new.exists() and not new.is_dir()):
                raise RuntimeError('App storage must be a directory: ' + str(old))
            if not old.exists() and not new.exists():
                raise RuntimeError('Migration path is missing; inspect ' + str(old))
        if not record['moves']:
            print('No legacy app directories to migrate.')
            return
        active = active_editors(bases)
        if active:
            raise RuntimeError('Save and close Uzume before migrating (Neovim PIDs: ' + ', '.join(active) + ')')
        write_journal(journal, record)
        for item in record['moves']:
            old, new = Path(item['old']), Path(item['new'])
            if not os.path.lexists(new):
                old.rename(new)
            if not os.path.lexists(old):
                old.symlink_to(new.name, target_is_directory=True)
            item['done'] = True
            write_journal(journal, record)
            print('App directory: ' + str(new) + ' (legacy path remains a compatibility symlink)')
        print('Migration complete. Files, Git indexes and saved records were not rewritten.')
